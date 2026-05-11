"""Phase 5.2 fix loop: pick one issue, ask Gemma for a minimal patch,
apply it on an attempt branch, re-run ``R CMD check``, accept the patch
when it strictly improves the verdict count or revert it otherwise.

The loop is intentionally per-issue and per-attempt: it does one
proposal at a time, never batches, and never amends the run-branch
history. Failed attempts leave the run branch untouched. Successful
attempts produce a single merge commit so the audit log can be replayed.

Escalation to Claude API is wired through the same proposal contract
but defaults to off; flip ``escalate=True`` after the operator confirms
the API key and the cost ceiling.
"""
from __future__ import annotations

import json
import time
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Iterable

from . import git_ops as g
from .agents import (
    FixProposal,
    apply_proposal,
    build_prompt,
    call_gemma,
    gather_excerpts,
    parse_proposal,
)
from .categorize import CategorizedIssue, classify_summary
from .check import CheckResult, run_check
from .cost_tracker import CostTracker
from .error_parser import CheckSummary, parse_check_log

DEFAULT_MAX_ATTEMPTS_PER_ISSUE = 5  # Phase 5.3 Gemma-only: 5 attempts with prompt diversification
DEFAULT_SOFT_WALL_CLOCK_S = 180.0   # soft cap per package (Gemma-only regime)
DEFAULT_HARD_WALL_CLOCK_S = 600.0   # hard cap per package (Gemma-only regime)


@dataclass(slots=True)
class FixAttempt:
    issue_description: str
    issue_category: str
    attempt_idx: int
    branch: str
    proposal: FixProposal
    pre_summary: dict
    post_summary: dict | None
    accepted: bool
    reason: str
    wall_clock_s: float

    def to_dict(self) -> dict:
        d = asdict(self)
        # FixProposal has nested EditProposal which is also a dataclass.
        return d


@dataclass(slots=True)
class FixSession:
    repo_root: Path
    package_dir: Path
    run_branch: str
    attempts: list[FixAttempt] = field(default_factory=list)
    cost: CostTracker | None = None
    soft_cap_hit: bool = False
    hard_cap_hit: bool = False

    def append_audit(self, audit_path: Path | str) -> Path:
        target = Path(audit_path)
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open("a", encoding="utf-8") as fh:
            for a in self.attempts:
                fh.write(json.dumps(a.to_dict(), ensure_ascii=False, default=str) + "\n")
        return target


def _summary_dict(summary: CheckSummary) -> dict:
    return {
        "n_errors": summary.n_errors,
        "n_warnings": summary.n_warnings,
        "n_notes": summary.n_notes,
        "issue_descriptions": [i.description for i in summary.issues],
    }


def _summary_strictly_better(before: CheckSummary, after: CheckSummary) -> bool:
    """Decide whether to accept a patch.

    ``R CMD check`` aborts the section sequence as soon as an ERROR
    fires, so resolving an ERROR can expose latent WARNINGs and NOTEs
    that were never reported before. Treating that as a regression
    would block legitimate progress, so the policy is layered:

    1. ERRORs must never increase.
    2. If ERRORs strictly decrease, accept regardless of WARNINGs and
       NOTEs: the new findings were always there, just masked.
    3. If ERRORs are equal, WARNINGs must not increase. NOTEs are
       tolerated within the legacy strict contract: WARNINGs strictly
       drop, or NOTEs strictly drop, or both stay equal but at least
       one issue is removed.
    """
    if after.n_errors > before.n_errors:
        return False
    if after.n_errors < before.n_errors:
        return True
    if after.n_warnings > before.n_warnings:
        return False
    if after.n_warnings < before.n_warnings:
        return True
    if after.n_notes < before.n_notes:
        return True
    return False


def _candidate_files_for_issue(
    package_dir: Path,
    issue: CategorizedIssue,
) -> list[str]:
    """Return repo-relative paths the LLM should see for this issue.

    The list is conservative: DESCRIPTION + NAMESPACE are always included
    because they are short and most CRAN-gate failures touch one or both.
    A NOTE about a specific R file or Rd file pulls that file in too.
    """
    out: list[str] = []
    base = package_dir.name + "/"
    for rel in ("DESCRIPTION", "NAMESPACE"):
        if (package_dir / rel).is_file():
            out.append(rel)
    detail = issue.issue.detail or ""
    for line in detail.splitlines():
        for tok in line.split():
            tok = tok.strip("'\"`,;:")
            if tok.endswith(".R") or tok.endswith(".Rd") or tok.endswith(".Rmd"):
                if (package_dir / tok).is_file():
                    out.append(tok)
                else:
                    # Many \detail lines reference R/<file>.R or man/<file>.Rd
                    candidate = ("R/" + tok) if tok.endswith(".R") else ("man/" + tok)
                    if (package_dir / candidate).is_file():
                        out.append(candidate)
    # Deduplicate while preserving order.
    seen: set[str] = set()
    uniq: list[str] = []
    for p in out:
        if p not in seen:
            seen.add(p)
            uniq.append(p)
    return uniq


def attempt_fix(
    *,
    repo_root: Path,
    package_dir: Path,
    run_branch: str,
    issue: CategorizedIssue,
    pre_summary: CheckSummary,
    attempt_idx: int,
    audit_path: Path,
    extra_files: Iterable[str] = (),
    previous_reason: str | None = None,
    cost: CostTracker | None = None,
) -> FixAttempt:
    """One fix attempt: ask Gemma, apply, re-check, accept or revert.

    ``attempt_idx`` (1..N) selects the diversification strategy in
    :func:`cran_publisher.agents.build_prompt`. ``previous_reason``
    is the reason string from the most recent rejected attempt and is
    interpolated into the prompt starting at strategy 3.
    """
    started = time.time()
    branch = (
        f"fix/{issue.category}-{abs(hash(issue.description)) % 1_000_000:06d}"
        f"-attempt-{attempt_idx}"
    )

    # Capture file context for the prompt.
    files = _candidate_files_for_issue(package_dir, issue)
    files.extend(extra_files)
    excerpts = gather_excerpts(package_dir, files)
    prompt = build_prompt(
        issue, excerpts,
        package_root=str(package_dir),
        strategy=attempt_idx,
        previous_attempt_reason=previous_reason,
    )

    # Branch off the run branch so a failed attempt does not pollute it.
    g.create_branch(repo_root, branch, from_ref=run_branch)
    try:
        raw = call_gemma(prompt)
        if cost is not None:
            # Token counts are approximations: 4 chars per token is the
            # rule of thumb used by the Ollama community for English-leaning
            # prompts. The point here is bookkeeping consistency, not
            # billing accuracy.
            cost.record_gemma_call(
                input_tokens=max(1, len(prompt) // 4),
                output_tokens=max(1, len(raw) // 4),
                purpose=f"fix_loop:attempt_{attempt_idx}",
            )
    except Exception as exc:
        g.checkout(repo_root, run_branch)
        g.delete_branch(repo_root, branch, force=True)
        return FixAttempt(
            issue_description=issue.description,
            issue_category=issue.category,
            attempt_idx=attempt_idx,
            branch=branch,
            proposal=FixProposal(thought="", risk_level="unknown", edits=[]),
            pre_summary=_summary_dict(pre_summary),
            post_summary=None,
            accepted=False,
            reason=f"gemma_call_failed:{exc}",
            wall_clock_s=time.time() - started,
        )

    proposal = parse_proposal(raw)
    if proposal.is_empty:
        g.checkout(repo_root, run_branch)
        g.delete_branch(repo_root, branch, force=True)
        return FixAttempt(
            issue_description=issue.description,
            issue_category=issue.category,
            attempt_idx=attempt_idx,
            branch=branch,
            proposal=proposal,
            pre_summary=_summary_dict(pre_summary),
            post_summary=None,
            accepted=False,
            reason="empty_or_unparseable_proposal",
            wall_clock_s=time.time() - started,
        )

    # Apply the proposal. If `apply_proposal` raises, revert.
    try:
        touched = apply_proposal(proposal, package_dir)
    except ValueError as exc:
        g.reset_hard(repo_root, run_branch)
        g.checkout(repo_root, run_branch)
        g.delete_branch(repo_root, branch, force=True)
        return FixAttempt(
            issue_description=issue.description,
            issue_category=issue.category,
            attempt_idx=attempt_idx,
            branch=branch,
            proposal=proposal,
            pre_summary=_summary_dict(pre_summary),
            post_summary=None,
            accepted=False,
            reason=f"apply_failed:{exc}",
            wall_clock_s=time.time() - started,
        )

    # Commit the proposed edits before re-running the check.
    rel_paths = [str((package_dir / p).resolve().relative_to(repo_root.resolve()))
                 for p in touched]
    g.add_and_commit(
        repo_root, rel_paths,
        message=f"cran_publisher: attempt {attempt_idx} for issue '{issue.description}'",
    )

    # Re-run the check on the patched tree.
    re_check = run_check(package_dir)
    post_summary = parse_check_log(re_check.stdout)

    accepted = _summary_strictly_better(pre_summary, post_summary)
    if accepted:
        g.checkout(repo_root, run_branch)
        g.merge_no_ff(
            repo_root, branch,
            message=(f"cran_publisher: accept attempt {attempt_idx} "
                     f"for '{issue.description}' "
                     f"(errors {pre_summary.n_errors}->{post_summary.n_errors}, "
                     f"warnings {pre_summary.n_warnings}->{post_summary.n_warnings}, "
                     f"notes {pre_summary.n_notes}->{post_summary.n_notes})"),
        )
        g.delete_branch(repo_root, branch, force=True)
        reason = "accepted"
    else:
        g.checkout(repo_root, run_branch)
        g.reset_hard(repo_root, run_branch)
        g.delete_branch(repo_root, branch, force=True)
        reason = (
            f"rejected:errors_{pre_summary.n_errors}->{post_summary.n_errors}_"
            f"warnings_{pre_summary.n_warnings}->{post_summary.n_warnings}_"
            f"notes_{pre_summary.n_notes}->{post_summary.n_notes}"
        )

    return FixAttempt(
        issue_description=issue.description,
        issue_category=issue.category,
        attempt_idx=attempt_idx,
        branch=branch,
        proposal=proposal,
        pre_summary=_summary_dict(pre_summary),
        post_summary=_summary_dict(post_summary),
        accepted=accepted,
        reason=reason,
        wall_clock_s=time.time() - started,
    )


def fix_session(
    *,
    repo_root: Path,
    package_dir: Path,
    audit_path: Path,
    max_attempts_per_issue: int = DEFAULT_MAX_ATTEMPTS_PER_ISSUE,
    extra_files: Iterable[str] = (),
    soft_wall_clock_s: float = DEFAULT_SOFT_WALL_CLOCK_S,
    hard_wall_clock_s: float = DEFAULT_HARD_WALL_CLOCK_S,
    cost: CostTracker | None = None,
) -> FixSession:
    """Run a full fix session: re-check, iterate over issues, attempt fixes,
    stop when no issue remains or we hit the per-issue attempt cap.

    Phase 5.3 Gemma-only regime: ``max_attempts_per_issue`` defaults to 5
    and each attempt picks a diversification strategy in
    :func:`attempt_fix`. The session stops early when either wall-clock
    cap is hit; ``soft_wall_clock_s`` is observed at the start of every
    new attempt as a polite stop, ``hard_wall_clock_s`` is enforced
    aggressively between issues.

    The session always operates on its own ``cran-publisher-run-<ts>``
    branch; the caller is expected to be on the package's main branch
    when this is invoked. The function returns the session record but
    does not delete the run branch: the operator inspects it before
    merging or discarding.
    """
    repo_root = Path(repo_root)
    package_dir = Path(package_dir)
    if not g.is_inside_work_tree(repo_root):
        raise RuntimeError(f"{repo_root} is not a git work tree")
    if not g.is_clean(repo_root):
        raise RuntimeError("repo has uncommitted changes; commit or stash first")

    main_ref = g.current_branch(repo_root)
    run_branch = f"cran-publisher-run-{int(time.time())}"
    g.create_branch(repo_root, run_branch, from_ref=main_ref)

    session = FixSession(repo_root=repo_root, package_dir=package_dir,
                          run_branch=run_branch, cost=cost)
    session_started = time.time()

    initial_check = run_check(package_dir)
    summary = parse_check_log(initial_check.stdout)
    if summary.passes_cran:
        # Nothing to do; CRAN gate is already green.
        session.append_audit(audit_path)
        return session

    classified = classify_summary(summary)
    for issue in classified.items:
        if time.time() - session_started >= hard_wall_clock_s:
            session.hard_cap_hit = True
            break
        previous_reason: str | None = None
        for k in range(1, max_attempts_per_issue + 1):
            elapsed = time.time() - session_started
            if elapsed >= hard_wall_clock_s:
                session.hard_cap_hit = True
                break
            if elapsed >= soft_wall_clock_s and k > 1:
                # Soft cap: stop attempting more strategies on this issue once
                # we have produced at least one (rejected) record, so the
                # report can show partial progress.
                session.soft_cap_hit = True
                break
            current_check = run_check(package_dir)
            current_summary = parse_check_log(current_check.stdout)
            attempt = attempt_fix(
                repo_root=repo_root,
                package_dir=package_dir,
                run_branch=run_branch,
                issue=issue,
                pre_summary=current_summary,
                attempt_idx=k,
                audit_path=audit_path,
                extra_files=extra_files,
                previous_reason=previous_reason,
                cost=cost,
            )
            session.attempts.append(attempt)
            previous_reason = attempt.reason
            if attempt.accepted:
                break

    session.append_audit(audit_path)
    return session


def run_full_session(
    *,
    repo_root: Path,
    package_dir: Path,
    package_name: str,
    audit_path: Path,
    report_path: Path | None = None,
    max_attempts_per_issue: int = DEFAULT_MAX_ATTEMPTS_PER_ISSUE,
    soft_wall_clock_s: float = DEFAULT_SOFT_WALL_CLOCK_S,
    hard_wall_clock_s: float = DEFAULT_HARD_WALL_CLOCK_S,
) -> tuple[FixSession, str]:
    """End-to-end Phase 5.3 entry point: fix session plus rendered report.

    Returns the :class:`FixSession` and the rendered Markdown report.
    When ``report_path`` is provided, the report is also written to disk.
    """
    # Local import to keep fix_loop import-cheap.
    from .report import ReportInputs, render_report

    cost = CostTracker()
    session = fix_session(
        repo_root=repo_root,
        package_dir=package_dir,
        audit_path=audit_path,
        max_attempts_per_issue=max_attempts_per_issue,
        soft_wall_clock_s=soft_wall_clock_s,
        hard_wall_clock_s=hard_wall_clock_s,
        cost=cost,
    )
    report = render_report(ReportInputs(
        session=session, package_name=package_name, cost=cost,
    ))
    if report_path is not None:
        Path(report_path).parent.mkdir(parents=True, exist_ok=True)
        Path(report_path).write_text(report, encoding="utf-8")
    return session, report


__all__ = [
    "DEFAULT_HARD_WALL_CLOCK_S",
    "DEFAULT_MAX_ATTEMPTS_PER_ISSUE",
    "DEFAULT_SOFT_WALL_CLOCK_S",
    "FixAttempt",
    "FixSession",
    "attempt_fix",
    "fix_session",
    "run_full_session",
]
