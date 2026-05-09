"""Unit tests for cran_graph.

The tests exercise the parser, the deprecation heuristics, and the
graph-to-SQLite roundtrip without hitting the network. A separate
opt-in integration test (gated by ``CRAN_GRAPH_NETWORK=1``) downloads
a real CRAN snapshot.
"""
from __future__ import annotations

import os
from datetime import datetime, timezone
from pathlib import Path

import pytest

from cran_graph import (
    PackageRecord,
    build_graph,
    classify,
    classify_all,
    fetch_archived_names,
    fetch_packages_index,
    graph_to_sqlite,
    load_graph,
    parse_packages_index,
)
from cran_graph.deprecation import (
    STATUS_ACTIVE,
    STATUS_SOFT,
    STATUS_STALE,
    STATUS_STRONG,
)


SAMPLE_INDEX = """\
Package: alpha
Version: 1.2.3
Depends: R (>= 4.0)
Imports: Matrix, methods
Suggests: knitr,
        testthat (>= 3.0.0)
License: MIT
Published: 2026-04-01 12:00:00 UTC
NeedsCompilation: no
MD5sum: 0123456789abcdef0123456789abcdef

Package: beta
Version: 0.9.0
Depends: R (>= 3.5), alpha (>= 1.0)
Imports: rlang
License: GPL-3
Published: 2020-02-15 08:00:00 UTC
NeedsCompilation: yes
MD5sum: fedcba9876543210fedcba9876543210

Package: gamma
Version: 0.0.1
Imports: alpha
License: Apache License 2.0
Published: 2018-01-01 00:00:00 UTC
Maintainer: ORPHANED
NeedsCompilation: no
"""

NOW = datetime(2026, 5, 9, tzinfo=timezone.utc)


def test_parse_packages_index_three_records():
    records = parse_packages_index(SAMPLE_INDEX)
    assert [r.name for r in records] == ["alpha", "beta", "gamma"]
    assert records[0].version == "1.2.3"
    assert records[0].license == "MIT"


def test_parse_continuation_line_is_folded():
    records = parse_packages_index(SAMPLE_INDEX)
    suggests = records[0].dependencies["Suggests"]
    names = [n for n, _ in suggests]
    assert "testthat" in names


def test_parse_dependency_constraints_preserved():
    records = parse_packages_index(SAMPLE_INDEX)
    depends = records[0].dependencies["Depends"]
    assert depends == [("R", ">= 4.0")]
    beta_deps = records[1].dependencies["Depends"]
    assert ("alpha", ">= 1.0") in beta_deps


def test_classify_active_recent_publication():
    rec = PackageRecord(name="x", version="1", published="2026-04-01 12:00:00 UTC")
    flag = classify(rec, now=NOW)
    assert flag.status == STATUS_ACTIVE
    assert flag.is_deprecated is False


def test_classify_soft_deprecated_old_publication():
    rec = PackageRecord(name="x", version="1", published="2020-01-01 00:00:00 UTC")
    flag = classify(rec, now=NOW)
    assert flag.status == STATUS_SOFT
    assert flag.is_deprecated is True


def test_classify_stale_when_between_thresholds():
    rec = PackageRecord(name="x", version="1", published="2024-06-01 00:00:00 UTC")
    flag = classify(rec, now=NOW)
    assert flag.status == STATUS_STALE
    assert flag.is_deprecated is False


def test_classify_orphaned_maintainer():
    rec = PackageRecord(
        name="x",
        version="1",
        published="2026-04-01 12:00:00 UTC",
        raw={"Maintainer": "ORPHANED"},
    )
    flag = classify(rec, now=NOW)
    assert flag.status == STATUS_STRONG
    assert flag.is_orphaned is True


def test_classify_strong_when_archived_only():
    rec = PackageRecord(name="x", version="1", published="2026-04-01 12:00:00 UTC")
    flag = classify(rec, now=NOW, archived_only_names={"x"})
    assert flag.status == STATUS_STRONG
    assert flag.reason == "removed_from_cran"


def test_classify_handles_missing_published_date():
    rec = PackageRecord(name="x", version="1", published=None)
    flag = classify(rec, now=NOW)
    assert flag.status == STATUS_STALE
    assert flag.reason == "missing_published_date"


def test_build_graph_node_and_edge_counts():
    records = parse_packages_index(SAMPLE_INDEX)
    flags = classify_all(records, now=NOW)
    g = build_graph(records, flags=flags)
    assert g.number_of_nodes() >= 5  # alpha, beta, gamma + R + Matrix + methods + ...
    assert g.number_of_edges() >= 5
    assert "alpha" in g
    assert g.has_edge("beta", "alpha")


def test_build_graph_marks_base_package_R():
    records = parse_packages_index(SAMPLE_INDEX)
    g = build_graph(records, flags=classify_all(records, now=NOW))
    assert g.nodes["R"]["status"] == "base_or_recommended"
    assert g.nodes["R"]["in_current_index"] is False


def test_build_graph_marks_archived_only_referenced_node():
    records = parse_packages_index(SAMPLE_INDEX)
    g = build_graph(
        records,
        flags=classify_all(records, now=NOW, archived_only_names={"alpha"}),
        archived_only_names={"Matrix"},
    )
    assert g.nodes["Matrix"]["status"] == "strong_deprecated"
    assert g.nodes["Matrix"]["deprecation_reason"] == "removed_from_cran"


def test_build_graph_base_package_wins_over_archive_collision():
    """A name shipped with R (e.g. 'grid') must always classify as
    base_or_recommended, even if a homonym appears in /Archive/."""
    rec = PackageRecord(
        name="x",
        version="1.0",
        published="2026-04-01 00:00:00 UTC",
        dependencies={"Imports": [("grid", None), ("splines", None)]},
    )
    flags = classify_all([rec], now=NOW)
    g = build_graph(
        [rec],
        flags=flags,
        archived_only_names={"grid", "splines"},
    )
    assert g.nodes["grid"]["status"] == "base_or_recommended"
    assert g.nodes["splines"]["status"] == "base_or_recommended"
    assert g.nodes["grid"]["is_deprecated"] is False


def test_graph_sqlite_roundtrip_preserves_topology(tmp_path: Path):
    records = parse_packages_index(SAMPLE_INDEX)
    g = build_graph(records, flags=classify_all(records, now=NOW))
    snap = tmp_path / "snap.sqlite"
    graph_to_sqlite(g, snap)
    restored = load_graph(snap)
    assert restored.number_of_nodes() == g.number_of_nodes()
    assert restored.number_of_edges() == g.number_of_edges()
    for name in g.nodes():
        assert restored.nodes[name]["status"] == g.nodes[name]["status"]
    for src, dst, key in g.edges(keys=True):
        assert restored.has_edge(src, dst)


def test_graph_to_sqlite_replaces_existing_file(tmp_path: Path):
    snap = tmp_path / "snap.sqlite"
    snap.write_bytes(b"not a sqlite file")
    records = parse_packages_index(SAMPLE_INDEX)
    g = build_graph(records, flags=classify_all(records, now=NOW))
    graph_to_sqlite(g, snap)
    restored = load_graph(snap)
    assert restored.number_of_nodes() > 0


def test_load_graph_missing_file_raises(tmp_path: Path):
    with pytest.raises(FileNotFoundError):
        load_graph(tmp_path / "nope.sqlite")


@pytest.mark.skipif(
    os.environ.get("CRAN_GRAPH_NETWORK") != "1",
    reason="set CRAN_GRAPH_NETWORK=1 to run network-bound tests",
)
def test_fetch_packages_index_returns_text():
    text = fetch_packages_index()
    assert "Package:" in text
    assert text.count("\nPackage:") > 1000


@pytest.mark.skipif(
    os.environ.get("CRAN_GRAPH_NETWORK") != "1",
    reason="set CRAN_GRAPH_NETWORK=1 to run network-bound tests",
)
def test_fetch_archived_names_returns_set():
    names = fetch_archived_names()
    assert isinstance(names, set)
    assert len(names) > 1000
