"""Render a fix-session into a Markdown report.

The report follows the durable plain-language-first rule: a one-liner
verdict, a structured decomposition into sub-questions, a synthesis
paragraph, a strategic next-step block, and only at the bottom the
audit-trail table.

The renderer reads from :class:`cran_publisher.fix_loop.FixSession`
plus optional :class:`cran_publisher.cost_tracker.CostTracker` and
emits a plain string. There is no Jinja dependency; format strings
are enough for this surface and they keep the install graph clean.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable

from .cost_tracker import CostTracker
from .fix_loop import FixAttempt, FixSession


@dataclass(slots=True)
class ReportInputs:
    session: FixSession
    package_name: str = "(unknown package)"
    cost: CostTracker | None = None


def render_report(inputs: ReportInputs) -> str:
    s = inputs.session
    cost = inputs.cost
    pkg = inputs.package_name

    accepted = [a for a in s.attempts if a.accepted]
    rejected = [a for a in s.attempts if not a.accepted]
    issues_seen = sorted({a.issue_description for a in s.attempts})
    accepted_issues = sorted({a.issue_description for a in accepted})
    pending_issues = [d for d in issues_seen if d not in accepted_issues]

    pre = _earliest_summary(s.attempts)
    post = _latest_summary(s.attempts)

    parts: list[str] = []
    parts.append(f"# CRAN publisher report: {pkg}\n")

    parts.append("## Plain-language verdict\n")
    parts.append(_verdict(pre, post, accepted, pending_issues) + "\n")

    parts.append("## Decomposition\n")
    parts.append("### Where did the package start?\n")
    parts.append(_summary_paragraph(pre, "Initial") + "\n")
    parts.append("### What did the loop attempt?\n")
    parts.append(_attempt_breakdown(s.attempts) + "\n")
    parts.append("### What was accepted?\n")
    parts.append(_acceptance_breakdown(accepted, rejected) + "\n")
    parts.append("### Where did the package end?\n")
    parts.append(_summary_paragraph(post, "Final") + "\n")

    parts.append("## Synthesis\n")
    parts.append(_synthesis(pre, post, accepted, pending_issues) + "\n")

    parts.append("## Strategic next steps\n")
    parts.append(_strategy(post, pending_issues, cost) + "\n")

    parts.append("## Audit trail\n")
    parts.append(_audit_table(s.attempts) + "\n")

    if cost is not None:
        parts.append("## Cost accounting\n")
        parts.append(_cost_block(cost) + "\n")

    return "".join(parts)


# --------------------------------------------------------------------------- #
# Section builders
# --------------------------------------------------------------------------- #


def _verdict(pre: dict | None, post: dict | None,
             accepted: list[FixAttempt], pending: list[str]) -> str:
    if pre is None or post is None:
        return ("The session produced no measurable check verdicts. "
                "No automated decision is possible; review the audit log "
                "and rerun the loop after committing any pending edits.\n")
    delta_e = pre["n_errors"] - post["n_errors"]
    delta_w = pre["n_warnings"] - post["n_warnings"]
    delta_n = pre["n_notes"] - post["n_notes"]
    if post["n_errors"] == 0 and post["n_warnings"] == 0:
        tail = "the package now passes the CRAN gate (NOTEs only)."
    elif post["n_errors"] == 0:
        tail = ("the package no longer carries ERRORs but still has "
                f"{post['n_warnings']} WARNING(s) that block CRAN submission.")
    else:
        tail = (f"{post['n_errors']} ERROR(s) remain; the package is not "
                "submission-ready.")
    n_acc = len(accepted)
    n_pend = len(pending)
    return (
        f"The fix loop accepted {n_acc} patch(es) and left {n_pend} issue(s) "
        f"unresolved. Across the run, ERRORs moved {pre['n_errors']} to "
        f"{post['n_errors']} ({_signed(delta_e)}), WARNINGs "
        f"{pre['n_warnings']} to {post['n_warnings']} ({_signed(delta_w)}), "
        f"NOTEs {pre['n_notes']} to {post['n_notes']} ({_signed(delta_n)}). "
        f"Operationally, {tail}\n"
    )


def _summary_paragraph(summary: dict | None, label: str) -> str:
    if summary is None:
        return f"{label} verdict: not captured.\n"
    issues = summary.get("issue_descriptions") or []
    issue_list = ("Active issue descriptions: " + ", ".join(f"`{d}`" for d in issues)
                  if issues else "No active issues.")
    return (f"{label} verdict: {summary['n_errors']} ERROR, "
            f"{summary['n_warnings']} WARNING, {summary['n_notes']} NOTE. "
            f"{issue_list}\n")


def _attempt_breakdown(attempts: list[FixAttempt]) -> str:
    if not attempts:
        return "No attempts were dispatched. The pre-check was already clean.\n"
    by_issue: dict[str, list[FixAttempt]] = {}
    for a in attempts:
        by_issue.setdefault(a.issue_description, []).append(a)
    lines: list[str] = []
    lines.append(f"Attempts targeted {len(by_issue)} distinct issue(s); "
                 f"{len(attempts)} total dispatcher invocation(s).\n")
    for desc, group in by_issue.items():
        lines.append(f"- `{desc}`: {len(group)} attempt(s), "
                     f"{sum(1 for g in group if g.accepted)} accepted.")
    return "\n".join(lines) + "\n"


def _acceptance_breakdown(accepted: list[FixAttempt],
                          rejected: list[FixAttempt]) -> str:
    if not accepted and not rejected:
        return "No attempts to evaluate.\n"
    parts: list[str] = []
    if accepted:
        parts.append(f"Accepted ({len(accepted)}):")
        for a in accepted:
            parts.append(f"  - `{a.issue_description}` "
                         f"(category `{a.issue_category}`, branch `{a.branch}`).")
    if rejected:
        parts.append(f"Rejected or aborted ({len(rejected)}):")
        for a in rejected:
            parts.append(f"  - `{a.issue_description}` "
                         f"(reason `{a.reason}`).")
    return "\n".join(parts) + "\n"


def _synthesis(pre: dict | None, post: dict | None,
               accepted: list[FixAttempt], pending: list[str]) -> str:
    if pre is None:
        return ("The session did not produce a comparable pair of check "
                "summaries; treat the audit log as the canonical record.\n")
    if not accepted and pending:
        return ("The loop made no accepted progress on this run. The "
                "issues fall into a class the local critic could not "
                "patch with one minimal edit. Two options: relax the "
                "per-issue attempt budget, or escalate to the Claude "
                "backend (Phase 5.3, gated by operator approval).\n")
    if accepted and not pending:
        return ("Every issue surfaced by the initial check was addressed "
                "and merged into the run branch. The remaining work, if "
                "any, comes from issues that surfaced only after the "
                "leading ERRORs were resolved (latent WARNINGs / NOTEs); "
                "rerun the loop to address those.\n")
    return ("The loop made partial progress: some issues are resolved on "
            "the run branch, others remain unaddressed. The audit table "
            "below records why each rejected attempt was rolled back.\n")


def _strategy(post: dict | None, pending: list[str],
              cost: CostTracker | None) -> str:
    bullets: list[str] = []
    if post is None:
        bullets.append("- Reread the audit log; the post-check did not run.")
    else:
        if post["n_errors"] > 0:
            bullets.append(f"- {post['n_errors']} ERROR(s) still block CRAN "
                           "submission. Inspect the audit log entries marked "
                           "`rejected:*` for the failed attempts.")
        if post["n_warnings"] > 0:
            bullets.append(f"- {post['n_warnings']} WARNING(s) need a "
                           "second pass; CRAN treats WARNINGs as blockers "
                           "even when no ERROR remains.")
        if post["n_errors"] == 0 and post["n_warnings"] == 0 and post["n_notes"] > 0:
            bullets.append(f"- {post['n_notes']} NOTE(s) remain. CRAN "
                           "tolerates NOTEs in many cases; review each one "
                           "and decide whether to address before submission.")
    if pending:
        bullets.append("- Pending issue descriptions to revisit: "
                       + ", ".join(f"`{d}`" for d in pending) + ".")
    if cost is not None and cost.exceeded_hard_cap():
        bullets.append(f"- Cost ceiling hit: ${cost.total_cost_usd:.2f} "
                       f">= ${cost.hard_cap_usd:.2f}. Disable Claude "
                       "escalation before the next session.")
    elif cost is not None and cost.approaching_soft_cap():
        bullets.append(f"- Cost soft cap reached: ${cost.total_cost_usd:.2f} "
                       f">= ${cost.soft_cap_usd:.2f}. The next session "
                       "should rely on local Gemma only.")
    if not bullets:
        bullets.append("- No outstanding action; the package is "
                       "submission-ready under the layered policy.")
    return "\n".join(bullets) + "\n"


def _audit_table(attempts: list[FixAttempt]) -> str:
    if not attempts:
        return "_(no attempts dispatched)_\n"
    header = "| # | Issue | Category | Branch | Pre | Post | Accepted | Wall-clock |"
    sep = "|---|---|---|---|---|---|---|---|"
    rows = [header, sep]
    for i, a in enumerate(attempts, start=1):
        pre = (f"E{a.pre_summary['n_errors']}/W{a.pre_summary['n_warnings']}"
               f"/N{a.pre_summary['n_notes']}")
        post = ("(no check)" if a.post_summary is None
                else f"E{a.post_summary['n_errors']}/W{a.post_summary['n_warnings']}"
                     f"/N{a.post_summary['n_notes']}")
        rows.append(
            f"| {i} | `{a.issue_description}` | `{a.issue_category}` | "
            f"`{a.branch}` | {pre} | {post} | {a.accepted} | "
            f"{a.wall_clock_s:.1f}s |"
        )
    return "\n".join(rows) + "\n"


def _cost_block(cost: CostTracker) -> str:
    s = cost.summary()
    lines = [
        f"- Calls: {s['n_calls']} (input {s['total_input_tokens']:,} tokens, "
        f"output {s['total_output_tokens']:,} tokens).",
        f"- Cost: ${s['total_cost_usd']:.4f} "
        f"(soft cap ${s['soft_cap_usd']:.2f}, hard cap ${s['hard_cap_usd']:.2f}).",
    ]
    for backend, agg in s["by_backend"].items():
        lines.append(
            f"- `{backend}`: {agg['n_calls']} call(s), "
            f"input {agg['input_tokens']:,}, output {agg['output_tokens']:,}, "
            f"cost ${agg['cost_usd']:.4f}."
        )
    return "\n".join(lines) + "\n"


def _earliest_summary(attempts: list[FixAttempt]) -> dict | None:
    return attempts[0].pre_summary if attempts else None


def _latest_summary(attempts: list[FixAttempt]) -> dict | None:
    for a in reversed(attempts):
        if a.post_summary is not None:
            return a.post_summary
    return _earliest_summary(attempts)


def _signed(delta: int) -> str:
    if delta > 0:
        return f"-{delta}"
    if delta < 0:
        return f"+{abs(delta)}"
    return "no change"


__all__ = ["ReportInputs", "render_report"]
