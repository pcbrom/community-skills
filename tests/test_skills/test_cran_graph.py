"""Smoke tests for the cran_graph skill (Python runtime).

Exercises the dispatcher through ``bridges.invoke`` to confirm the
JSON-in / JSON-out contract holds. Network-bound `build_snapshot`
is gated behind `CRAN_GRAPH_NETWORK=1`.
"""
from __future__ import annotations

import os
from pathlib import Path

import pytest

from bridges import invoke

SNAPSHOT_PATH = Path("data/cran_snapshot_2026-05-09.sqlite")


pytestmark = pytest.mark.skipif(
    not SNAPSHOT_PATH.is_file(),
    reason="snapshot fixture not present; run cran-graph build first",
)


def test_dispatcher_rejects_missing_fn():
    r = invoke("cran_graph", {})
    assert r["ok"] is False
    assert "fn" in r["error"].lower()


def test_dispatcher_rejects_unknown_fn():
    r = invoke("cran_graph", {"fn": "does_not_exist"})
    assert r["ok"] is False


def test_stats_returns_aggregate_counts():
    r = invoke("cran_graph", {"fn": "stats", "snapshot": str(SNAPSHOT_PATH)})
    assert r["ok"] is True
    payload = r["result"]
    assert payload["node_count"] > 1000
    assert payload["edge_count"] > 1000
    assert "active" in payload["by_status"]
    assert "Imports" in payload["by_edge_type"]


def test_optimize_resolves_ggplot2():
    r = invoke("cran_graph", {
        "fn": "optimize",
        "snapshot": str(SNAPSHOT_PATH),
        "targets": ["ggplot2"],
    })
    assert r["ok"] is True
    payload = r["result"]
    assert payload["ok"] is True
    assert "ggplot2" in payload["install_set"]
    assert payload["install_count"] >= 5


def test_optimize_strict_active_flips_with_deprecated_dep():
    r = invoke("cran_graph", {
        "fn": "optimize",
        "snapshot": str(SNAPSHOT_PATH),
        "targets": ["ggplot2"],
        "strict_active": True,
    })
    assert r["ok"] is True
    payload = r["result"]
    # ggplot2 closure includes RColorBrewer (soft_deprecated) on the 2026-05-09
    # snapshot; strict-active should surface it as a conflict.
    assert payload["ok"] is False
    assert any("deprecated" in c for c in payload["conflicts"])


def test_optimize_missing_target_returns_structured_error():
    r = invoke("cran_graph", {
        "fn": "optimize",
        "snapshot": str(SNAPSHOT_PATH),
        "targets": ["this_package_does_not_exist_zzz"],
    })
    assert r["ok"] is True  # bridge OK; the optimizer's own ok is False
    payload = r["result"]
    assert payload["ok"] is False
    assert payload["missing_targets"]


def test_plot_closure_writes_png(tmp_path):
    target = tmp_path / "ggplot2.png"
    r = invoke("cran_graph", {
        "fn": "plot_closure",
        "snapshot": str(SNAPSHOT_PATH),
        "targets": ["ggplot2"],
        "output_path": str(target),
        "dpi": 100,
    })
    assert r["ok"] is True
    assert target.is_file()
    assert target.stat().st_size > 5000  # non-empty PNG


@pytest.mark.skipif(
    os.environ.get("CRAN_GRAPH_NETWORK") != "1",
    reason="set CRAN_GRAPH_NETWORK=1 to run network-bound build_snapshot",
)
def test_build_snapshot_writes_sqlite(tmp_path):
    target = tmp_path / "snap.sqlite"
    r = invoke("cran_graph", {
        "fn": "build_snapshot",
        "output_path": str(target),
        "fetch_archive": False,  # faster test
    })
    assert r["ok"] is True
    assert target.is_file()
    assert r["result"]["node_count"] > 1000
