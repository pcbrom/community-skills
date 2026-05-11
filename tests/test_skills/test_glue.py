"""Smoke tests for the glue skill.

Skipped when Rscript is missing or the upstream `glue` package is not
installed.
"""
from __future__ import annotations

import shutil
import subprocess

import pytest

from bridges import invoke


def _glue_installed() -> bool:
    if shutil.which("Rscript") is None:
        return False
    completed = subprocess.run(
        ["Rscript", "-e", 'cat(requireNamespace("glue", quietly = TRUE))'],
        capture_output=True, text=True, timeout=20,
    )
    return completed.returncode == 0 and completed.stdout.strip() == "TRUE"


pytestmark = pytest.mark.skipif(
    not _glue_installed(),
    reason="R or upstream glue package not available",
)


def test_glue_collapse_joins_with_separator():
    r = invoke("glue", {"fn": "glue_collapse", "x": ["a", "b", "c"], "sep": "+"})
    assert r["ok"]
    assert r["result"] == "a+b+c"


def test_as_glue_marks_string_as_glue():
    r = invoke("glue", {"fn": "as_glue", "x": "hello"})
    assert r["ok"]
    assert r["result"] == "hello"


def test_unknown_fn_returns_error():
    r = invoke("glue", {"fn": "does_not_exist"})
    assert r["ok"] is False
    assert "Unknown" in r["error"] or "not" in r["error"].lower()
