"""Unit tests for cran_graph.optimize.

The fixtures build small synthetic graphs that exercise each branch of
the solver without touching the network.
"""
from __future__ import annotations

from datetime import datetime, timezone

import networkx as nx
import pytest

from cran_graph import build_graph, classify_all, optimize, parse_version, version_satisfies
from cran_graph.scrape import PackageRecord, parse_packages_index

NOW = datetime(2026, 5, 9, tzinfo=timezone.utc)


# --------------------------------------------------------------------------- #
# Version helpers
# --------------------------------------------------------------------------- #


def test_parse_version_dotted():
    assert parse_version("4.0.1") == (4, 0, 1)


def test_parse_version_hyphen_and_underscore():
    assert parse_version("4.0-1") == (4, 0, 1)
    assert parse_version("0.9_3") == (0, 9, 3)


def test_parse_version_handles_alpha_suffix():
    # No leading integer prefix on the alpha component falls back to 0,
    # matching the documented contract in parse_version.
    assert parse_version("1.2.0-rc1") == (1, 2, 0, 0)


def test_version_satisfies_truthy_when_no_constraint():
    assert version_satisfies("1.0", None) is True
    assert version_satisfies(None, None) is True


def test_version_satisfies_geq():
    assert version_satisfies("4.0.1", ">= 4.0") is True
    assert version_satisfies("3.5", ">= 4.0") is False


def test_version_satisfies_pads_short_versions():
    assert version_satisfies("4", ">= 4.0.0") is True
    assert version_satisfies("4.0", "< 4.0.0.1") is True


def test_version_satisfies_eq_and_neq():
    assert version_satisfies("1.2.3", "== 1.2.3") is True
    assert version_satisfies("1.2.4", "!= 1.2.3") is True
    assert version_satisfies("1.2.3", "!= 1.2.3") is False


# --------------------------------------------------------------------------- #
# Graph fixtures
# --------------------------------------------------------------------------- #


SYNTHETIC_INDEX = """\
Package: alpha
Version: 1.0.0
Depends: R (>= 4.0)
Imports: beta, gamma (>= 0.5)
Suggests: delta
Published: 2026-04-01 12:00:00 UTC

Package: beta
Version: 0.9.0
Imports: gamma
Suggests: alpha
Published: 2026-03-01 12:00:00 UTC

Package: gamma
Version: 0.6.0
Depends: R (>= 3.5)
Published: 2026-02-01 12:00:00 UTC

Package: delta
Version: 0.0.1
Imports: alpha
Published: 2018-01-01 00:00:00 UTC

Package: epsilon
Version: 2.0.0
Imports: beta, gamma
Published: 2025-11-01 12:00:00 UTC
"""


@pytest.fixture()
def synthetic_graph() -> nx.MultiDiGraph:
    records = parse_packages_index(SYNTHETIC_INDEX)
    flags = classify_all(records, now=NOW)
    return build_graph(records, flags=flags)


# --------------------------------------------------------------------------- #
# Greedy closure
# --------------------------------------------------------------------------- #


def test_optimize_resolves_hard_dependencies(synthetic_graph):
    res = optimize(synthetic_graph, ["alpha"])
    assert res.ok
    assert set(res.install_set) == {"alpha", "beta", "gamma"}


def test_optimize_topological_order_dependencies_first(synthetic_graph):
    res = optimize(synthetic_graph, ["alpha"])
    pos = {name: i for i, name in enumerate(res.install_set)}
    assert pos["gamma"] < pos["beta"] < pos["alpha"]


def test_optimize_skips_base_package_R(synthetic_graph):
    res = optimize(synthetic_graph, ["alpha"])
    assert "R" not in res.install_set
    assert "R" in res.skipped_base


def test_optimize_excludes_suggests_by_default(synthetic_graph):
    res = optimize(synthetic_graph, ["alpha"])
    assert "delta" not in res.install_set


def test_optimize_includes_suggests_when_flag_set(synthetic_graph):
    res = optimize(synthetic_graph, ["alpha"], include_suggests=True)
    assert "delta" in res.install_set


def test_optimize_multiple_targets_share_closure(synthetic_graph):
    res = optimize(synthetic_graph, ["alpha", "epsilon"])
    assert set(res.targets) == {"alpha", "epsilon"}
    assert "beta" in res.install_set
    assert "gamma" in res.install_set
    assert res.install_set.count("beta") == 1


def test_optimize_missing_target_returns_structured_error(synthetic_graph):
    res = optimize(synthetic_graph, ["does_not_exist"])
    assert res.ok is False
    assert "does_not_exist" in res.missing_targets
    assert any("missing_target" in c for c in res.conflicts)
    assert res.install_set == []


def test_optimize_exclude_blocks_optional_walk(synthetic_graph):
    res = optimize(synthetic_graph, ["epsilon"], exclude=["beta"])
    assert any("excluded_but_required" in c for c in res.conflicts)


def test_optimize_exclude_target_itself_is_conflict(synthetic_graph):
    res = optimize(synthetic_graph, ["alpha"], exclude=["alpha"])
    assert any("target_in_exclude" in c for c in res.conflicts)


def test_optimize_r_version_constraint_passes(synthetic_graph):
    res = optimize(synthetic_graph, ["alpha"], r_version="4.1")
    assert res.ok
    assert not any("r_version_constraint" in c for c in res.conflicts)


def test_optimize_r_version_constraint_violation(synthetic_graph):
    res = optimize(synthetic_graph, ["alpha"], r_version="3.6")
    assert res.ok is False
    assert any("r_version_constraint_violated" in c for c in res.conflicts)


def test_optimize_strict_active_fails_on_soft_deprecated_dep():
    rec_old = PackageRecord(
        name="old_lib",
        version="0.0.1",
        published="2018-01-01 00:00:00 UTC",
    )
    rec_new = PackageRecord(
        name="new_app",
        version="1.0.0",
        published="2026-04-01 00:00:00 UTC",
        dependencies={"Imports": [("old_lib", None)]},
    )
    flags = classify_all([rec_old, rec_new], now=NOW)
    g = build_graph([rec_old, rec_new], flags=flags)
    res = optimize(g, ["new_app"], strict_active=True)
    assert res.ok is False
    assert any("deprecated_in_closure" in c for c in res.conflicts)


def test_optimize_warns_on_unmet_version_constraint():
    """A constraint snapshot fails to satisfy is reported as warning, not error."""
    rec_low = PackageRecord(
        name="low",
        version="0.1.0",
        published="2026-04-01 00:00:00 UTC",
    )
    rec_high = PackageRecord(
        name="needs_high",
        version="1.0.0",
        published="2026-04-01 00:00:00 UTC",
        dependencies={"Imports": [("low", ">= 1.0")]},
    )
    flags = classify_all([rec_low, rec_high], now=NOW)
    g = build_graph([rec_low, rec_high], flags=flags)
    res = optimize(g, ["needs_high"])
    assert any("version_constraint_unmet" in w for w in res.warnings)


def test_optimize_result_to_dict_is_json_serializable(synthetic_graph):
    import json
    res = optimize(synthetic_graph, ["alpha"])
    payload = res.to_dict()
    serialized = json.dumps(payload)
    assert "alpha" in serialized
    assert payload["install_count"] == len(payload["install_set"])
