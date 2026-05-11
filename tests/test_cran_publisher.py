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


# --------------------------------------------------------------------------- #
# Phase 5.2: agents.parse_proposal + apply_proposal + git_ops on tmp repos
# --------------------------------------------------------------------------- #


def test_parse_proposal_happy_path():
    from cran_publisher.agents import parse_proposal
    raw = """
    Some preamble the LLM may emit.
    {
      "thought": "Add Maintainer field derived from Authors@R.",
      "risk_level": "low",
      "edits": [
        {
          "path": "DESCRIPTION",
          "search": "Authors@R: c(person",
          "replace": "Maintainer: Foo <foo@example.com>\\nAuthors@R: c(person"
        }
      ]
    }
    Trailing commentary.
    """
    p = parse_proposal(raw)
    assert p.is_empty is False
    assert p.risk_level == "low"
    assert len(p.edits) == 1
    assert p.edits[0].path == "DESCRIPTION"


def test_parse_proposal_returns_empty_on_garbage():
    from cran_publisher.agents import parse_proposal
    p = parse_proposal("not json at all, no braces here.")
    assert p.is_empty


def test_apply_proposal_writes_edit(tmp_path):
    from cran_publisher.agents import EditProposal, FixProposal, apply_proposal
    target = tmp_path / "FILE.txt"
    target.write_text("alpha beta gamma\n", encoding="utf-8")
    proposal = FixProposal(
        thought="t", risk_level="low",
        edits=[EditProposal(path="FILE.txt", search="beta", replace="bravo")],
    )
    touched = apply_proposal(proposal, tmp_path)
    assert touched == ["FILE.txt"]
    assert target.read_text(encoding="utf-8") == "alpha bravo gamma\n"


def test_apply_proposal_rejects_ambiguous_search(tmp_path):
    from cran_publisher.agents import EditProposal, FixProposal, apply_proposal
    target = tmp_path / "F.txt"
    target.write_text("aa aa aa", encoding="utf-8")
    proposal = FixProposal(
        thought="t", risk_level="low",
        edits=[EditProposal(path="F.txt", search="aa", replace="bb")],
    )
    with pytest.raises(ValueError, match="ambiguous"):
        apply_proposal(proposal, tmp_path)


def test_apply_proposal_rejects_path_escape(tmp_path):
    from cran_publisher.agents import EditProposal, FixProposal, apply_proposal
    proposal = FixProposal(
        thought="t", risk_level="low",
        edits=[EditProposal(path="../escape.txt", search="x", replace="y")],
    )
    with pytest.raises(ValueError):
        apply_proposal(proposal, tmp_path)


def test_git_ops_basic_branch_lifecycle(tmp_path):
    from cran_publisher import git_ops as g
    import subprocess
    repo = tmp_path / "repo"
    repo.mkdir()
    subprocess.run(["git", "init", "-b", "main"], cwd=repo, check=True, capture_output=True)
    subprocess.run(["git", "config", "user.email", "t@e.com"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.name", "Tester"], cwd=repo, check=True)
    (repo / "F.txt").write_text("hello", encoding="utf-8")
    g.add_and_commit(repo, ["F.txt"], "init")
    assert g.is_inside_work_tree(repo)
    assert g.current_branch(repo) == "main"
    assert g.is_clean(repo)

    g.create_branch(repo, "topic")
    assert g.current_branch(repo) == "topic"
    (repo / "F.txt").write_text("hello world", encoding="utf-8")
    g.add_and_commit(repo, ["F.txt"], "edit")
    assert g.is_clean(repo)
    g.checkout(repo, "main")
    g.merge_no_ff(repo, "topic", "merge topic")
    g.delete_branch(repo, "topic", force=True)
    assert "world" in (repo / "F.txt").read_text(encoding="utf-8")


# --------------------------------------------------------------------------- #
# Fix-loop end-to-end on a synthetic repo with the LLM call mocked out.
# --------------------------------------------------------------------------- #


def _bootstrap_synthetic_pkg(tmp_path):
    """Build a minimal R package that fails R CMD check exactly the way
    bgumbel does today: DESCRIPTION lacks the legacy Author and Maintainer
    fields. The synthetic version skips real R execution and instead lets
    the test inject scripted check results."""
    import subprocess
    repo = tmp_path / "repo"
    repo.mkdir()
    subprocess.run(["git", "init", "-b", "main"], cwd=repo, check=True, capture_output=True)
    subprocess.run(["git", "config", "user.email", "t@e.com"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.name", "Tester"], cwd=repo, check=True)

    pkg = repo / "fakepkg"
    pkg.mkdir()
    desc = pkg / "DESCRIPTION"
    desc.write_text(
        "Package: fakepkg\n"
        "Version: 0.0.1\n"
        "Title: Fake Package\n"
        "Description: A package used for fix-loop tests.\n"
        "License: MIT\n"
        "Authors@R: c(person(\"Tester\", \"Person\", email = \"t@e.com\", role = c(\"aut\", \"cre\")))\n",
        encoding="utf-8",
    )
    (pkg / "NAMESPACE").write_text("export(foo)\n", encoding="utf-8")
    subprocess.run(["git", "add", "-A"], cwd=repo, check=True)
    subprocess.run(["git", "commit", "-m", "init"], cwd=repo, check=True, capture_output=True)
    return repo, pkg


def _make_check_log(has_author_fields: bool) -> str:
    if has_author_fields:
        return (
            "* using R version 4.6.0\n"
            "* checking for file 'fakepkg/DESCRIPTION' ... OK\n"
            "* checking package metadata ... OK\n"
            "* DONE\n"
            "Status: OK\n"
        )
    return (
        "* using R version 4.6.0\n"
        "* checking for file 'fakepkg/DESCRIPTION' ... ERROR\n"
        "Required fields missing or empty:\n"
        "  'Author' 'Maintainer'\n"
        "* DONE\n"
        "Status: 1 ERROR\n"
    )


# --------------------------------------------------------------------------- #
# Phase 5.3 partial: cost tracker + report renderer (no Claude wiring yet).
# --------------------------------------------------------------------------- #


def test_cost_tracker_aggregates_local_calls():
    from cran_publisher import CostTracker
    t = CostTracker()
    t.record_gemma_call(input_tokens=1200, output_tokens=400, purpose="agents:fix_proposal")
    t.record_gemma_call(input_tokens=800,  output_tokens=300, purpose="agents:fix_proposal")
    s = t.summary()
    assert s["n_calls"] == 2
    assert s["total_input_tokens"] == 2000
    assert s["total_output_tokens"] == 700
    assert s["total_cost_usd"] == 0.0
    assert s["by_backend"]["gemma_local"]["n_calls"] == 2


def test_cost_tracker_applies_pricing_to_claude_calls():
    from cran_publisher import ClaudePricing, CostTracker
    pricing = ClaudePricing(
        input_per_mtok={"claude-sonnet-4-6": 3.0},
        output_per_mtok={"claude-sonnet-4-6": 15.0},
    )
    t = CostTracker(pricing=pricing, soft_cap_usd=0.05, hard_cap_usd=0.20)
    t.record_claude_call(input_tokens=1_000_000, output_tokens=200_000,
                          model="claude-sonnet-4-6", purpose="agents:escalation")
    # 1 USD per 1M input + 0.2 * 15 = 3 + 3 = 6 USD
    assert abs(t.total_cost_usd - 6.0) < 1e-6
    assert t.exceeded_hard_cap()


def test_cost_tracker_unknown_model_charges_zero():
    from cran_publisher import CostTracker
    t = CostTracker()
    t.record_claude_call(input_tokens=1_000_000, output_tokens=1_000_000,
                          model="unknown-model")
    assert t.total_cost_usd == 0.0


def test_render_report_plain_language_first(tmp_path, monkeypatch):
    """Report must lead with the plain-language verdict, not the audit table."""
    from cran_publisher import (
        CostTracker,
        ReportInputs,
        render_report,
    )
    from cran_publisher.fix_loop import FixAttempt, FixSession
    from cran_publisher.agents import FixProposal, EditProposal

    pkg_dir = tmp_path / "pkg"
    pkg_dir.mkdir()
    session = FixSession(
        repo_root=tmp_path, package_dir=pkg_dir, run_branch="run-1",
        attempts=[
            FixAttempt(
                issue_description="for file 'pkg/DESCRIPTION'",
                issue_category="description_metadata",
                attempt_idx=1, branch="fix/desc-attempt-1",
                proposal=FixProposal(
                    thought="Add Author and Maintainer.",
                    risk_level="low",
                    edits=[EditProposal(path="DESCRIPTION", search="x", replace="y")],
                ),
                pre_summary={"n_errors": 1, "n_warnings": 0, "n_notes": 0,
                              "issue_descriptions": ["for file 'pkg/DESCRIPTION'"]},
                post_summary={"n_errors": 0, "n_warnings": 2, "n_notes": 3,
                               "issue_descriptions": ["URL", "package size"]},
                accepted=True, reason="accepted", wall_clock_s=65.8,
            ),
        ],
    )
    cost = CostTracker()
    cost.record_gemma_call(input_tokens=1200, output_tokens=400)

    report = render_report(ReportInputs(session=session, package_name="bgumbel", cost=cost))

    # Section ordering: plain-language verdict appears before the audit table.
    assert report.index("## Plain-language verdict") < report.index("## Audit trail")
    # Verdict synthesizes the count delta.
    assert "ERRORs moved 1 to 0" in report
    # Audit table contains the structured row.
    assert "fix/desc-attempt-1" in report
    # Cost block is present.
    assert "## Cost accounting" in report
    # Editorial contract: no em-dash, no forbidden buzzwords.
    assert chr(0x2014) not in report
    for term in ("crucial", "essential", "fundamental", "revolutionary",
                 "incredible", "important", "robust"):
        import re as _re
        assert not _re.search(rf"\b{term}\b", report.lower()), \
            f"forbidden term `{term}` leaked into the report"


def test_build_prompt_diversifies_by_strategy():
    """Phase 5.3 Gemma-only: each strategy level should change the prompt."""
    from cran_publisher.agents import build_prompt
    from cran_publisher.categorize import CategorizedIssue
    from cran_publisher.error_parser import CheckIssue

    issue = CategorizedIssue(
        issue=CheckIssue(description="for file 'pkg/DESCRIPTION'", verdict="ERROR",
                          detail="missing fields"),
        category="description_metadata",
        label="DESCRIPTION metadata field issue",
    )
    excerpts = {"DESCRIPTION": "Package: pkg\nVersion: 0.0.1\n"}

    p1 = build_prompt(issue, excerpts, package_root="/p", strategy=1)
    p2 = build_prompt(issue, excerpts, package_root="/p", strategy=2)
    p3 = build_prompt(issue, excerpts, package_root="/p", strategy=3,
                       previous_attempt_reason="rejected:errors_1->1")
    p4 = build_prompt(issue, excerpts, package_root="/p", strategy=4,
                       previous_attempt_reason="rejected:errors_1->1")
    p5 = build_prompt(issue, excerpts, package_root="/p", strategy=5,
                       previous_attempt_reason="rejected:errors_1->1")

    assert "DIVERSIFICATION HINT" not in p1
    assert "DIVERSIFICATION HINT" not in p2
    assert "DIVERSIFICATION HINT" in p3
    assert "RISK-LEVEL UPGRADE" in p4
    assert "FINAL ATTEMPT" in p5
    # Strategy >= 2 lifts the per-file budget; previous_attempt_reason is
    # echoed verbatim from strategy 3 onward.
    assert "rejected:errors_1->1" in p3


def test_run_full_session_writes_report(tmp_path, monkeypatch):
    """End-to-end entry point: fix_session + render_report bundled."""
    from cran_publisher import fix_loop as fl
    import subprocess

    # Build a minimal repo+package the same way the earlier fix-loop test does.
    repo = tmp_path / "repo"
    repo.mkdir()
    subprocess.run(["git", "init", "-b", "main"], cwd=repo, check=True, capture_output=True)
    subprocess.run(["git", "config", "user.email", "t@e.com"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.name", "Tester"], cwd=repo, check=True)
    pkg = repo / "fakepkg"
    pkg.mkdir()
    (pkg / "DESCRIPTION").write_text(
        "Package: fakepkg\nVersion: 0.0.1\nTitle: Fake\nDescription: F.\nLicense: MIT\n"
        "Authors@R: c(person(\"T\", \"P\", email = \"t@e.com\", role = c(\"aut\", \"cre\")))\n",
        encoding="utf-8",
    )
    (pkg / "NAMESPACE").write_text("export(foo)\n", encoding="utf-8")
    subprocess.run(["git", "add", "-A"], cwd=repo, check=True)
    subprocess.run(["git", "commit", "-m", "init"], cwd=repo, check=True, capture_output=True)

    # Stub Gemma and R CMD check the same way as the earlier test.
    proposal = (
        '{"thought": "Add Author + Maintainer.", "risk_level": "low", '
        '"edits": [{"path": "DESCRIPTION", "search": "Version: 0.0.1\\nTitle:", '
        '"replace": "Version: 0.0.1\\nAuthor: T P\\nMaintainer: T P <t@e.com>\\nTitle:"}]}'
    )
    monkeypatch.setattr(fl, "call_gemma", lambda prompt, **kw: proposal)
    def fake_check(package_dir, **kwargs):
        desc = (package_dir / "DESCRIPTION").read_text(encoding="utf-8")
        has = "Author:" in desc and "Maintainer:" in desc
        return type("R", (), {
            "stdout": (
                "* checking for file 'fakepkg/DESCRIPTION' ... OK\n* DONE\nStatus: OK\n"
                if has else
                "* checking for file 'fakepkg/DESCRIPTION' ... ERROR\n"
                "Required fields missing or empty: 'Author' 'Maintainer'\n* DONE\nStatus: 1 ERROR\n"
            ),
            "stderr": "", "exit_code": 0 if has else 1,
            "wall_clock_s": 0.1, "package_dir": package_dir,
        })()
    monkeypatch.setattr(fl, "run_check", fake_check)

    report_path = tmp_path / "report.md"
    session, report = fl.run_full_session(
        repo_root=repo, package_dir=pkg, package_name="fakepkg",
        audit_path=tmp_path / "audit.jsonl",
        report_path=report_path,
    )
    assert report_path.is_file()
    assert "## Plain-language verdict" in report
    assert session.cost is not None
    assert session.cost.total_cost_usd == 0.0
    # Token tracking captured at least one Gemma call.
    assert session.cost.summary()["by_backend"].get("gemma_local", {}).get("n_calls", 0) >= 1


def test_render_report_no_attempts_handles_clean_path(tmp_path):
    from cran_publisher import ReportInputs, render_report
    from cran_publisher.fix_loop import FixSession
    pkg_dir = tmp_path / "pkg"
    pkg_dir.mkdir()
    session = FixSession(repo_root=tmp_path, package_dir=pkg_dir,
                          run_branch="run-empty", attempts=[])
    report = render_report(ReportInputs(session=session, package_name="bgumbel"))
    assert "No automated decision is possible" in report or "No attempts" in report
    assert "## Audit trail" in report


def test_fix_loop_accepts_proposal_that_strictly_improves(tmp_path, monkeypatch):
    """End-to-end fix-loop on a synthetic repo: the mocked critic proposes
    adding Author + Maintainer derived from Authors@R, and the mocked
    check runner returns a strictly-better summary, so the proposal lands
    on the run branch."""
    repo, pkg = _bootstrap_synthetic_pkg(tmp_path)
    audit = tmp_path / "audit.jsonl"

    # Stub out the network-bound LLM call with a deterministic proposal.
    proposal_json = (
        '{"thought": "Add Author and Maintainer derived from Authors@R.", '
        '"risk_level": "low", '
        '"edits": [{"path": "DESCRIPTION", '
        '"search": "Authors@R: c(person", '
        '"replace": "Author: Tester Person [aut, cre]\\n'
        'Maintainer: Tester Person <t@e.com>\\n'
        'Authors@R: c(person"}]}'
    )
    from cran_publisher import fix_loop as fl
    monkeypatch.setattr(fl, "call_gemma", lambda prompt, **kw: proposal_json)

    # Stub the R CMD check runner: the first call sees the broken state,
    # subsequent calls (after the edit lands) see the fixed state.
    state = {"calls": 0}

    def fake_run_check(package_dir, **kwargs):
        state["calls"] += 1
        desc_text = (package_dir / "DESCRIPTION").read_text(encoding="utf-8")
        has_author = "Author:" in desc_text and "Maintainer:" in desc_text
        return type("R", (), {
            "stdout": _make_check_log(has_author),
            "stderr": "",
            "exit_code": 0 if has_author else 1,
            "wall_clock_s": 0.1,
            "package_dir": package_dir,
        })()

    monkeypatch.setattr(fl, "run_check", fake_run_check)

    session = fl.fix_session(
        repo_root=repo, package_dir=pkg, audit_path=audit,
        max_attempts_per_issue=2,
    )
    assert audit.is_file()
    assert session.attempts, "expected at least one attempt"
    accepted = [a for a in session.attempts if a.accepted]
    assert accepted, f"expected an accepted attempt, got {[a.reason for a in session.attempts]}"
    desc_after = (pkg / "DESCRIPTION").read_text(encoding="utf-8")
    assert "Author: " in desc_after
    assert "Maintainer: " in desc_after
