"""Smoke tests for the cran_publisher skill (Python runtime).

Exercises the dispatcher through ``bridges.invoke`` to confirm the
JSON-in / JSON-out contract holds end-to-end. Heavy-weight handlers
(`run_check`, `fix_session`) are exercised by the package-level tests
in ``tests/test_cran_publisher.py``; here we cover only the contract.
"""
from __future__ import annotations

from bridges import invoke


CLEAN_LOG = (
    "* using R version 4.6.0\n"
    "* checking for file 'foo/DESCRIPTION' ... OK\n"
    "* checking package namespace information ... OK\n"
    "* DONE\n"
    "Status: OK\n"
)


NOTE_LOG = (
    "* using R version 4.6.0\n"
    "* checking R code for possible problems ... NOTE\n"
    "  foo: no visible binding for global variable 'bar'\n"
    "  Undefined global functions or variables:\n"
    "    bar\n"
    "* DONE\n"
    "Status: 1 NOTE\n"
)


def test_dispatcher_rejects_missing_fn():
    result = invoke("cran_publisher", {})
    assert result["ok"] is False
    assert "fn" in result["error"].lower()


def test_dispatcher_rejects_unknown_fn():
    result = invoke("cran_publisher", {"fn": "does_not_exist"})
    assert result["ok"] is False
    assert "Unknown" in result["error"]


def test_parse_log_returns_structured_summary():
    result = invoke("cran_publisher", {"fn": "parse_log", "stdout": NOTE_LOG})
    assert result["ok"] is True
    payload = result["result"]
    assert payload["n_notes"] == 1
    assert payload["n_errors"] == 0
    assert payload["n_warnings"] == 0
    assert any(i["verdict"] == "NOTE" for i in payload["issues"])


def test_parse_log_clean():
    result = invoke("cran_publisher", {"fn": "parse_log", "stdout": CLEAN_LOG})
    assert result["ok"] is True
    payload = result["result"]
    assert payload["passes_cran"] is True


def test_categorize_routes_undefined_globals():
    result = invoke("cran_publisher", {"fn": "categorize", "stdout": NOTE_LOG})
    assert result["ok"] is True
    payload = result["result"]
    assert payload["by_category"].get("undefined_globals") == 1


def test_run_check_requires_package_dir():
    result = invoke("cran_publisher", {"fn": "run_check"})
    assert result["ok"] is False
    assert "package_dir" in result["error"]


def test_fix_session_requires_repo_root():
    result = invoke("cran_publisher", {"fn": "fix_session"})
    assert result["ok"] is False
    assert "repo_root" in result["error"]
