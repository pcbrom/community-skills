"""Smoke tests for the jsonlite skill.

Skipped when Rscript is missing or the upstream `jsonlite` package is
not installed.
"""
from __future__ import annotations

import json
import shutil
import subprocess

import pytest

from bridges import invoke


def _jsonlite_installed() -> bool:
    if shutil.which("Rscript") is None:
        return False
    completed = subprocess.run(
        ["Rscript", "-e", 'cat(requireNamespace("jsonlite", quietly = TRUE))'],
        capture_output=True, text=True, timeout=20,
    )
    return completed.returncode == 0 and completed.stdout.strip() == "TRUE"


pytestmark = pytest.mark.skipif(
    not _jsonlite_installed(),
    reason="R or upstream jsonlite package not available",
)


def test_to_json_serializes_array():
    r = invoke("jsonlite", {"fn": "toJSON", "x": [1, 2, 3]})
    assert r["ok"]
    parsed = json.loads(r["result"]) if isinstance(r["result"], str) else r["result"]
    assert parsed == [1, 2, 3]


def test_from_json_roundtrip_array():
    r = invoke("jsonlite", {"fn": "fromJSON", "txt": "[1,2,3]"})
    assert r["ok"]
    assert list(r["result"]) == [1, 2, 3]


def test_prettify_indents_object():
    r = invoke("jsonlite", {"fn": "prettify", "txt": '{"a":1}'})
    assert r["ok"]
    assert "\n" in r["result"]


def test_unknown_fn_returns_error():
    r = invoke("jsonlite", {"fn": "does_not_exist"})
    assert r["ok"] is False
