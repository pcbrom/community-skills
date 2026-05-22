"""cran_publisher: helpers for the CRAN publication pipeline.

Phase 5.1 (this release) ships three pieces:

- :mod:`cran_publisher.check` runs ``R CMD check`` on a package source
  tree and captures stdout, stderr, and exit code.
- :mod:`cran_publisher.error_parser` turns the textual log into a
  :class:`~cran_publisher.error_parser.CheckSummary` of structured
  issues.
- :mod:`cran_publisher.categorize` assigns each issue to a category
  drawn from a living taxonomy under
  ``cran_publisher/data/error_taxonomy.json``.

Phases 5.2 (Gemma fix loop), 5.3 (Claude escalation + report
generator), and 5.4 (bgumbel end-to-end submit) build on top of these
modules; see the sprint plan for the full sequence.
"""
from __future__ import annotations

from .agents import (
    EditProposal,
    FixProposal,
    apply_proposal,
    build_prompt,
    parse_proposal,
)
from .cost_tracker import (
    CallRecord,
    ClaudePricing,
    CostTracker,
)
from .categorize import (
    Category,
    CategorizedIssue,
    CategorizedSummary,
    classify_issue,
    classify_summary,
    load_taxonomy,
)
from .check import (
    DEFAULT_CHECK_FLAGS,
    DEFAULT_TIMEOUT_SECONDS,
    CheckResult,
    run_check,
)
from .error_parser import (
    VERDICT_ERROR,
    VERDICT_NOTE,
    VERDICT_OK,
    VERDICT_UNKNOWN,
    VERDICT_WARNING,
    CheckIssue,
    CheckSummary,
    issues_by_verdict,
    parse_check_log,
    parse_issues,
)
from .fix_loop import (
    FixAttempt,
    FixSession,
    attempt_fix,
    fix_session,
    run_full_session,
)
from .preflight import (
    Gate,
    PreflightResult,
    submission_preflight,
)
from .runiverse import (
    RuniversePreflightResult,
    RuniverseRegisterResult,
    RuniverseStatusResult,
    runiverse_preflight,
    runiverse_register,
    runiverse_status,
)
from .submit import (
    SubmitResult,
    submit_to_cran,
)
from .report import ReportInputs, render_report

__version__ = "0.1.0"

__all__ = [
    "CallRecord",
    "Category",
    "CategorizedIssue",
    "CategorizedSummary",
    "CheckIssue",
    "CheckResult",
    "CheckSummary",
    "ClaudePricing",
    "CostTracker",
    "DEFAULT_CHECK_FLAGS",
    "DEFAULT_TIMEOUT_SECONDS",
    "EditProposal",
    "FixAttempt",
    "FixProposal",
    "FixSession",
    "Gate",
    "PreflightResult",
    "ReportInputs",
    "RuniversePreflightResult",
    "RuniverseRegisterResult",
    "RuniverseStatusResult",
    "SubmitResult",
    "VERDICT_ERROR",
    "VERDICT_NOTE",
    "VERDICT_OK",
    "VERDICT_UNKNOWN",
    "VERDICT_WARNING",
    "apply_proposal",
    "attempt_fix",
    "build_prompt",
    "classify_issue",
    "classify_summary",
    "fix_session",
    "issues_by_verdict",
    "load_taxonomy",
    "parse_check_log",
    "parse_issues",
    "parse_proposal",
    "render_report",
    "run_check",
    "run_full_session",
    "runiverse_preflight",
    "runiverse_register",
    "runiverse_status",
    "submission_preflight",
    "submit_to_cran",
]
