"""Tests for the cran_publisher submission preflight gate."""
from __future__ import annotations

from pathlib import Path

import pytest

from cran_publisher import PreflightResult, submission_preflight


def _failed_gate_names(result: PreflightResult) -> list[str]:
    """The names of the blocking gates that failed."""
    return [g.name for g in result.blocking_failures]

CLEAN_CHECK = "* using log directory\nStatus: 2 NOTEs\n"
WARN_CHECK = "* checking foo ... WARNING\ndetail\nStatus: 1 WARNING\n"

DESCRIPTION = """\
Package: demopkg
Version: {version}
Title: A Demonstration Package
Description: A small package used to exercise the submission preflight.
License: MIT + file LICENSE
Authors@R: person("A", "Maintainer", email = "a@example.org",
    role = c("aut", "cre"))
"""


def _make_pkg(root: Path, *, version="0.1.0", news=True, cran_comments=True,
              license_file=True) -> Path:
    """Write a minimal package source tree and return its path."""
    pkg = root / "demopkg"
    pkg.mkdir()
    (pkg / "DESCRIPTION").write_text(DESCRIPTION.format(version=version),
                                     encoding="utf-8")
    if license_file:
        (pkg / "LICENSE").write_text("YEAR: 2026\nCOPYRIGHT HOLDER: A\n",
                                     encoding="utf-8")
    if news:
        (pkg / "NEWS.md").write_text(f"# demopkg {version}\n\n* First.\n",
                                     encoding="utf-8")
    if cran_comments:
        (pkg / "cran-comments.md").write_text(
            "## Test environments\n- local\n\n## R CMD check results\nclean\n",
            encoding="utf-8")
    return pkg


def test_ready_package_passes_every_blocking_gate(tmp_path):
    pkg = _make_pkg(tmp_path)
    result = submission_preflight(pkg, check_stdout=CLEAN_CHECK)
    assert isinstance(result, PreflightResult)
    assert result.ready is True
    assert result.blocking_failures == []
    assert any("maintainer" in line.lower() for line in result.handoff)


def test_development_version_blocks(tmp_path):
    pkg = _make_pkg(tmp_path, version="0.0.0.9000")
    result = submission_preflight(pkg, check_stdout=CLEAN_CHECK)
    assert result.ready is False
    assert "release version" in _failed_gate_names(result)


def test_check_warning_blocks(tmp_path):
    pkg = _make_pkg(tmp_path)
    result = submission_preflight(pkg, check_stdout=WARN_CHECK)
    assert result.ready is False
    assert "R CMD check" in _failed_gate_names(result)


def test_missing_check_log_is_undetermined_and_blocks(tmp_path):
    pkg = _make_pkg(tmp_path)
    result = submission_preflight(pkg)
    assert result.ready is False
    check_gate = next(g for g in result.gates if g.name == "R CMD check")
    assert check_gate.passed is None


def test_missing_cran_comments_blocks(tmp_path):
    pkg = _make_pkg(tmp_path, cran_comments=False)
    result = submission_preflight(pkg, check_stdout=CLEAN_CHECK)
    assert result.ready is False
    assert "cran-comments.md" in _failed_gate_names(result)


def test_missing_news_entry_is_non_blocking(tmp_path):
    pkg = _make_pkg(tmp_path, news=False)
    result = submission_preflight(pkg, check_stdout=CLEAN_CHECK)
    # No NEWS file is a non-blocking gate, so the package stays ready.
    assert result.ready is True
    news_gate = next(g for g in result.gates if g.name == "NEWS entry")
    assert news_gate.passed is False
    assert news_gate.blocking is False


def test_missing_description_returns_not_ready(tmp_path):
    empty = tmp_path / "empty"
    empty.mkdir()
    result = submission_preflight(empty)
    assert result.ready is False
