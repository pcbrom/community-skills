"""Tests for cran_publisher: parser, categorizer, end-to-end check on bgumbel.

Fixtures live inline; the smoke test against the real bgumbel source is
gated behind ``CRAN_PUBLISHER_RUN_RCMD=1`` because ``R CMD check`` takes
30 seconds and pollutes the working directory with ``.Rcheck``.
"""
from __future__ import annotations

import os
from pathlib import Path

import pytest

from cran_publisher import (
    CheckIssue,
    CheckResult,
    classify_summary,
    issues_by_verdict,
    load_taxonomy,
    parse_check_log,
    parse_issues,
    run_check,
)
from cran_publisher.error_parser import (
    VERDICT_ERROR,
    VERDICT_NOTE,
    VERDICT_OK,
    VERDICT_WARNING,
)


# --------------------------------------------------------------------------- #
# Fixtures: typical R CMD check stdout shapes
# --------------------------------------------------------------------------- #


CLEAN_LOG = """\
* using log directory '/tmp/foo.Rcheck'
* using R version 4.6.0 (2026-04-24)
* using platform: x86_64-pc-linux-gnu
* using session charset: UTF-8
* checking for file 'foo/DESCRIPTION' ... OK
* this is package 'foo' version '0.1.0'
* checking package namespace information ... OK
* checking package dependencies ... OK
* checking R files for syntax errors ... OK
* checking whether the package can be loaded ... OK
* DONE

Status: OK
"""


NOTES_AND_WARNINGS_LOG = """\
* using R version 4.6.0
* checking for file 'foo/DESCRIPTION' ... OK
* checking R code for possible problems ... NOTE
foo: no visible binding for global variable 'bar'
foo: no visible global function definition for 'baz'
Undefined global functions or variables:
  bar baz
* checking Rd files ... WARNING
prepare_Rd: missing documentation entries:
  'qux'
* checking examples ... ERROR
Running examples in 'foo-Ex.R' failed
Error: object 'undefined_obj' not found
Execution halted

Status: 1 ERROR, 1 WARNING, 1 NOTE
"""


URL_NOTE_LOG = """\
* checking URL ... NOTE
Found the following (possibly) invalid URLs:
  URL: http://example.com/missing
    From: README.md
    Status: 404
    Message: Not Found

Status: 1 NOTE
"""


# --------------------------------------------------------------------------- #
# parse_check_log / parse_issues
# --------------------------------------------------------------------------- #


def test_parse_clean_log_produces_no_issues():
    summary = parse_check_log(CLEAN_LOG)
    assert summary.ok
    assert summary.passes_cran
    assert summary.n_errors == 0
    assert summary.n_warnings == 0
    assert summary.n_notes == 0
    assert summary.issues == []


def test_parse_aggregate_status_counts():
    summary = parse_check_log(NOTES_AND_WARNINGS_LOG)
    assert summary.n_errors == 1
    assert summary.n_warnings == 1
    assert summary.n_notes == 1
    assert summary.ok is False
    assert summary.passes_cran is False


def test_parse_issues_collects_each_section():
    issues = parse_issues(NOTES_AND_WARNINGS_LOG)
    by_verdict = {i.verdict for i in issues}
    assert VERDICT_NOTE in by_verdict
    assert VERDICT_WARNING in by_verdict
    assert VERDICT_ERROR in by_verdict


def test_parse_issue_detail_block_captured():
    issues = parse_issues(NOTES_AND_WARNINGS_LOG)
    by_desc = {i.description: i for i in issues}
    note = by_desc.get("R code for possible problems")
    assert note is not None
    assert "no visible binding" in note.detail
    assert "Undefined global functions" in note.detail


def test_parse_issues_with_url_note():
    summary = parse_check_log(URL_NOTE_LOG)
    assert summary.n_notes == 1
    assert summary.passes_cran  # NOTE alone does not block CRAN
    issue = summary.issues[0]
    assert issue.verdict == VERDICT_NOTE
    assert "404" in issue.detail


def test_issues_by_verdict_groups_correctly():
    summary = parse_check_log(NOTES_AND_WARNINGS_LOG)
    by_v = issues_by_verdict(summary)
    assert len(by_v[VERDICT_ERROR]) == 1
    assert len(by_v[VERDICT_WARNING]) == 1
    assert len(by_v[VERDICT_NOTE]) == 1


# --------------------------------------------------------------------------- #
# Categorizer
# --------------------------------------------------------------------------- #


def test_taxonomy_loads_from_default_path():
    cats = load_taxonomy()
    assert len(cats) > 5
    keys = {c.key for c in cats}
    assert "missing_documentation" in keys
    assert "undefined_globals" in keys
    assert "url_check" in keys


def test_classify_summary_assigns_categories():
    summary = parse_check_log(NOTES_AND_WARNINGS_LOG)
    classified = classify_summary(summary)
    by_cat = classified.by_category
    assert by_cat.get("undefined_globals") == 1
    assert by_cat.get("missing_documentation") == 1
    # The ERROR is on examples
    assert by_cat.get("examples") == 1


def test_classify_url_note():
    summary = parse_check_log(URL_NOTE_LOG)
    classified = classify_summary(summary)
    assert classified.by_category.get("url_check") == 1


def test_classify_unknown_falls_back_to_other():
    issue = CheckIssue(description="some weird new check", verdict=VERDICT_NOTE,
                        detail="never seen before")
    from cran_publisher.categorize import classify_issue
    cat = classify_issue(issue)
    assert cat.category == "other"


# --------------------------------------------------------------------------- #
# Smoke test against the real bgumbel source.
# Gated by CRAN_PUBLISHER_RUN_RCMD=1 because R CMD check takes ~30s.
# --------------------------------------------------------------------------- #


BGUMBEL_SOURCE = Path("cran_graph_extra/bgumbel")


@pytest.mark.skipif(
    os.environ.get("CRAN_PUBLISHER_RUN_RCMD") != "1",
    reason="set CRAN_PUBLISHER_RUN_RCMD=1 to run the real R CMD check",
)
@pytest.mark.skipif(
    not BGUMBEL_SOURCE.is_dir(),
    reason="cran_graph_extra/bgumbel/ not present; clone it first",
)
def test_run_check_on_bgumbel_real(tmp_path):
    result = run_check(BGUMBEL_SOURCE, output_dir=tmp_path / "checkdir")
    assert isinstance(result, CheckResult)
    assert isinstance(result.stdout, str)
    audit = result.write_audit(tmp_path / "audit")
    assert (audit / "stdout.log").is_file()
    summary = parse_check_log(result.stdout)
    classified = classify_summary(summary)
    # We do not assert pass/fail; the contract is that parsing + categorization
    # work end-to-end on a real package without raising.
    assert isinstance(classified.by_verdict, dict)
    assert isinstance(classified.by_category, dict)
