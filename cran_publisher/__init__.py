"""cran_publisher: helpers for publishing an R package.

The sub-package covers the two distribution channels of the R
ecosystem.

The CRAN channel:

- :mod:`cran_publisher.check` runs ``R CMD check`` on a package source
  tree and captures stdout, stderr, and exit code.
- :mod:`cran_publisher.error_parser` turns the textual log into a
  :class:`~cran_publisher.error_parser.CheckSummary` of structured
  issues.
- :mod:`cran_publisher.categorize` assigns each issue to a category
  drawn from a living taxonomy under
  ``cran_publisher/data/error_taxonomy.json``.
- :mod:`cran_publisher.fix_loop` proposes minimal patches with a local
  Gemma model, validates each through a fresh check, and merges the
  accepted ones onto a session branch.
- :mod:`cran_publisher.report` renders the fix session as Markdown.
- :mod:`cran_publisher.preflight` is the submission readiness gate, and
  :mod:`cran_publisher.submit` runs the gated upload.

The r-universe channel:

- :mod:`cran_publisher.runiverse` carries the r-universe readiness
  gate, the ``packages.json`` registration, and the build-status query.
  r-universe is the channel for a package CRAN cannot take, such as one
  whose vendored dependency tree pushes the tarball past the 10 MB
  limit.
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
