"""Smoke tests for the gtsummary skill.

Skipped when Rscript is missing or the upstream `gtsummary` package is
not installed. The dispatcher itself is exercised structurally; the
upstream signatures are validated by the staging gate during generation.
"""
from __future__ import annotations

import shutil
import subprocess

import pytest

from bridges import invoke


def _pkg_installed() -> bool:
    if shutil.which("Rscript") is None:
        return False
    completed = subprocess.run(
        ["Rscript", "-e", 'cat(requireNamespace("gtsummary", quietly = TRUE))'],
        capture_output=True, text=True, timeout=20,
    )
    return completed.returncode == 0 and completed.stdout.strip() == "TRUE"


pytestmark = pytest.mark.skipif(
    not _pkg_installed(),
    reason="R or upstream gtsummary package not available",
)


def test_dispatcher_loads_and_rejects_unknown_fn():
    r = invoke("gtsummary", {"fn": "does_not_exist_certainly_xyz"})
    assert r["ok"] is False
    assert "error" in r


def test_dispatcher_rejects_missing_fn_field():
    r = invoke("gtsummary", {})
    assert r["ok"] is False
