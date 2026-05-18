"""Smoke tests for the cran_publisher skill (Python runtime).

Exercises the dispatcher through ``bridges.invoke`` to confirm the
JSON-in / JSON-out contract holds end-to-end for all six functions.
Heavy-weight handlers (`run_check`, `fix_session`) and the policy
internals of `submission_preflight` / `submit` are exercised by the
package-level tests in ``tests/test_cran_publisher.py`` and
``tests/test_cran_publisher_preflight.py``; here we cover only the
skill contract.
"""
from __future__ import annotations

from pathlib import Path

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


# --------------------------------------------------------------------------- #
# submission_preflight and submit: the Phase 5.4 functions, skill-level contract
# --------------------------------------------------------------------------- #


def test_submission_preflight_requires_package_dir():
    result = invoke("cran_publisher", {"fn": "submission_preflight"})
    assert result["ok"] is False
    assert "package_dir" in result["error"]


def test_submit_requires_package_dir():
    result = invoke("cran_publisher", {"fn": "submit"})
    assert result["ok"] is False
    assert "package_dir" in result["error"]


def _minimal_pkg(tmp_path: Path) -> Path:
    """Build a minimal R package source tree for the contract tests."""
    pkg = tmp_path / "fakepkg"
    pkg.mkdir()
    (pkg / "DESCRIPTION").write_text(
        "Package: fakepkg\nVersion: 0.1.0\nTitle: Fake Package\n"
        "Description: A package used for skill contract tests.\n"
        "License: MIT\nAuthors@R: c(person(\"T\", \"P\", role = c(\"aut\", \"cre\"), "
        "email = \"t@e.com\"))\n",
        encoding="utf-8",
    )
    (pkg / "NAMESPACE").write_text("export(foo)\n", encoding="utf-8")
    return pkg


def test_submission_preflight_returns_structured_verdict(tmp_path):
    """The preflight gate returns a structured verdict without raising,
    even for a package that is not submission-ready."""
    pkg = _minimal_pkg(tmp_path)
    result = invoke("cran_publisher", {
        "fn": "submission_preflight",
        "package_dir": str(pkg),
    })
    assert result["ok"] is True
    payload = result["result"]
    assert payload["package"] == "fakepkg"
    assert payload["version"] == "0.1.0"
    assert isinstance(payload["ready"], bool)
    assert isinstance(payload["gates"], list) and payload["gates"]
    # A minimal package lacks NEWS, cran-comments, LICENSE file, tarball:
    # the verdict must not be ready.
    assert payload["ready"] is False
    assert payload["blocking_failures"]


def test_submit_blocked_by_failing_preflight(tmp_path):
    """`submit` never uploads when the preflight gate fails. A minimal
    package lacks NEWS, cran-comments, LICENSE and a tarball, so the
    preflight blocks it: `uploaded` is false, `preflight_ready` is false,
    and the call stops before reaching the upload or even the dry run."""
    pkg = _minimal_pkg(tmp_path)
    result = invoke("cran_publisher", {
        "fn": "submit",
        "package_dir": str(pkg),
    })
    assert result["ok"] is True
    payload = result["result"]
    assert payload["uploaded"] is False
    assert payload["preflight_ready"] is False
    assert "preflight" in payload["reason"].lower()
