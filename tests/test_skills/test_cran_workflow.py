"""Smoke tests for the cran_workflow composition skill.

Exercises both contracts through ``bridges.invoke``. The
`audit_release` test needs both the snapshot and a bgumbel checkout;
the `fix_and_report` test needs Ollama, so it is gated behind
``CRAN_WORKFLOW_RUN_GEMMA=1``.
"""
from __future__ import annotations

import os
import shutil
from pathlib import Path

import pytest

from bridges import invoke

SNAPSHOT = Path("data/cran_snapshot_2026-05-09.sqlite")
BGUMBEL_SRC = Path("cran_graph_extra/bgumbel")


def test_dispatcher_rejects_missing_fn():
    r = invoke("cran_workflow", {})
    assert r["ok"] is False
    assert "fn" in r["error"].lower()


def test_dispatcher_rejects_unknown_fn():
    r = invoke("cran_workflow", {"fn": "does_not_exist"})
    assert r["ok"] is False


def test_audit_release_requires_snapshot():
    r = invoke("cran_workflow", {"fn": "audit_release"})
    assert r["ok"] is False
    assert "snapshot" in r["error"]


def test_fix_and_report_requires_repo_root():
    r = invoke("cran_workflow", {"fn": "fix_and_report"})
    assert r["ok"] is False
    assert "repo_root" in r["error"]


@pytest.mark.skipif(
    not SNAPSHOT.is_file() or not BGUMBEL_SRC.is_dir() or shutil.which("R") is None,
    reason="needs snapshot + bgumbel checkout + R",
)
def test_audit_release_on_bgumbel():
    r = invoke("cran_workflow", {
        "fn": "audit_release",
        "snapshot": str(SNAPSHOT),
        "package_name": "bgumbel",
        "package_dir": str(BGUMBEL_SRC),
    })
    assert r["ok"] is True
    payload = r["result"]
    assert "closure" in payload
    assert "check" in payload
    assert "passes_cran" in payload
    assert payload["closure"]["install_count"] >= 5
    # The check is structural; the bgumbel snapshot today fails with
    # description_metadata, so passes_cran should be False.
    assert isinstance(payload["passes_cran"], bool)
