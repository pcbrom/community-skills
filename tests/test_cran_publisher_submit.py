"""Tests for the cran_publisher gated CRAN submission step.

The live upload path (confirm=True) is never exercised here: it would
submit to CRAN. The tests cover the two gates, the preflight gate and the
confirm gate, which is where the safety of the function lives.
"""
from __future__ import annotations

from pathlib import Path

from cran_publisher import SubmitResult, submit_to_cran

CLEAN_CHECK = "* using log directory\nStatus: 1 NOTE\n"

DESCRIPTION = """\
Package: demopkg
Version: 0.1.0
Title: A Demonstration Package
Description: A small package used to exercise the submission gate.
License: MIT + file LICENSE
Authors@R: person("A", "Maintainer", email = "a@example.org",
    role = c("aut", "cre"))
"""


def _make_pkg(root: Path, *, cran_comments: bool = True) -> Path:
    pkg = root / "demopkg"
    pkg.mkdir()
    (pkg / "DESCRIPTION").write_text(DESCRIPTION, encoding="utf-8")
    (pkg / "LICENSE").write_text("YEAR: 2026\nCOPYRIGHT HOLDER: A\n",
                                 encoding="utf-8")
    (pkg / "NEWS.md").write_text("# demopkg 0.1.0\n\n* First.\n",
                                 encoding="utf-8")
    if cran_comments:
        (pkg / "cran-comments.md").write_text(
            "## Test environments\n- win-builder\n", encoding="utf-8")
    return pkg


def test_preflight_failure_blocks_the_upload(tmp_path):
    # No cran-comments.md: the preflight has a blocking failure.
    pkg = _make_pkg(tmp_path, cran_comments=False)
    result = submit_to_cran(pkg, confirm=True, check_stdout=CLEAN_CHECK)
    assert isinstance(result, SubmitResult)
    assert result.uploaded is False
    assert result.preflight_ready is False
    assert "preflight" in result.reason.lower()


def test_ready_without_confirm_is_a_dry_run(tmp_path):
    pkg = _make_pkg(tmp_path)
    result = submit_to_cran(pkg, check_stdout=CLEAN_CHECK)
    assert result.uploaded is False
    assert result.dry_run is True
    assert result.preflight_ready is True
    assert "dry run" in result.reason.lower()


def test_confirm_false_is_still_a_dry_run(tmp_path):
    pkg = _make_pkg(tmp_path)
    result = submit_to_cran(pkg, confirm=False, check_stdout=CLEAN_CHECK)
    assert result.uploaded is False
    assert result.dry_run is True


def test_dry_run_names_the_next_step(tmp_path):
    pkg = _make_pkg(tmp_path)
    result = submit_to_cran(pkg, check_stdout=CLEAN_CHECK)
    assert "confirm=true" in result.next_step.lower()
