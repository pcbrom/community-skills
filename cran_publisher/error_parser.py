"""Parse the textual output of ``R CMD check`` into structured issues.

The check log is line-based and follows a stable shape: a top-level
section starts with ``* checking <description> ... <verdict>`` where
``<verdict>`` is one of ``OK``, ``NOTE``, ``WARNING``, ``ERROR``, or a
hyphen continuation. Verdicts that are not ``OK`` are followed by an
indented detail block (each line starts with at least two spaces or one
tab) until the next ``*`` line or a blank line that introduces a new
section.

This module converts the log into a list of :class:`CheckIssue` records
plus an aggregate :class:`CheckSummary`. The classifier of error kinds
(undefined-globals, missing documentation, namespace issues, ...) lives
in :mod:`cran_publisher.categorize`.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Iterable

VERDICT_OK = "OK"
VERDICT_NOTE = "NOTE"
VERDICT_WARNING = "WARNING"
VERDICT_ERROR = "ERROR"
VERDICT_UNKNOWN = "UNKNOWN"

# Section header: ``* checking <description> ... <verdict>``.
_SECTION_RE = re.compile(
    r"^\*\s+checking\s+(?P<desc>.+?)\s*\.\.\.\s*(?P<verdict>OK|NOTE|WARNING|ERROR)?\s*$"
)
# Generic ``* something else`` line that is not a "checking" header (for example,
# the leading ``* using R version ...`` lines or the ``* DONE`` footer).
_NON_CHECKING_STAR_RE = re.compile(r"^\*\s")
# Final summary line(s) like ``Status: 1 ERROR, 2 WARNINGs, 3 NOTEs``.
_STATUS_RE = re.compile(
    r"^Status:\s*(?:(?P<errors>\d+)\s+ERRORs?\s*,?\s*)?"
    r"(?:(?P<warnings>\d+)\s+WARNINGs?\s*,?\s*)?"
    r"(?:(?P<notes>\d+)\s+NOTEs?)?",
    re.IGNORECASE,
)


@dataclass(slots=True)
class CheckIssue:
    """One non-OK section of the ``R CMD check`` output."""

    description: str
    verdict: str
    detail: str

    @property
    def first_detail_line(self) -> str:
        for line in self.detail.splitlines():
            stripped = line.strip()
            if stripped:
                return stripped
        return ""


@dataclass(slots=True)
class CheckSummary:
    """Aggregate verdict counts over a parsed log."""

    n_errors: int = 0
    n_warnings: int = 0
    n_notes: int = 0
    issues: list[CheckIssue] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return self.n_errors == 0 and self.n_warnings == 0 and self.n_notes == 0

    @property
    def passes_cran(self) -> bool:
        """CRAN tolerates NOTEs in many cases; ERROR and WARNING are blockers."""
        return self.n_errors == 0 and self.n_warnings == 0


def parse_check_log(text: str) -> CheckSummary:
    """Tokenize ``R CMD check`` stdout into a :class:`CheckSummary`.

    The parser is forgiving: a section without a recognized verdict is
    classified as ``UNKNOWN`` and kept, so the caller never silently
    drops a finding. The aggregate counts come from the explicit
    ``Status:`` line when present, falling back to the per-issue tally
    when it is absent (older R releases or truncated logs).
    """
    issues = parse_issues(text)

    # Aggregate counts: prefer the explicit Status: line.
    n_err = sum(1 for i in issues if i.verdict == VERDICT_ERROR)
    n_warn = sum(1 for i in issues if i.verdict == VERDICT_WARNING)
    n_note = sum(1 for i in issues if i.verdict == VERDICT_NOTE)

    for line in text.splitlines():
        m = _STATUS_RE.match(line.strip())
        if m and (m.group("errors") or m.group("warnings") or m.group("notes")):
            n_err = int(m.group("errors") or 0)
            n_warn = int(m.group("warnings") or 0)
            n_note = int(m.group("notes") or 0)
            break

    return CheckSummary(
        n_errors=n_err,
        n_warnings=n_warn,
        n_notes=n_note,
        issues=issues,
    )


def parse_issues(text: str) -> list[CheckIssue]:
    """Extract every non-OK section from the log."""
    out: list[CheckIssue] = []
    lines = text.splitlines()
    i = 0
    n = len(lines)
    while i < n:
        line = lines[i]
        m = _SECTION_RE.match(line)
        if not m:
            i += 1
            continue
        verdict = m.group("verdict") or _scan_for_continuation_verdict(lines, i + 1)
        description = m.group("desc")
        if verdict == VERDICT_OK or verdict is None:
            i += 1
            continue
        detail_lines, consumed = _read_detail_block(lines, i + 1)
        out.append(
            CheckIssue(
                description=description,
                verdict=verdict if verdict in {VERDICT_NOTE, VERDICT_WARNING, VERDICT_ERROR} else VERDICT_UNKNOWN,
                detail="\n".join(detail_lines).rstrip(),
            )
        )
        i = consumed
    return out


def _scan_for_continuation_verdict(lines: list[str], start: int) -> str | None:
    """Some R versions split the verdict to the next line. Look at the
    next non-empty line for ``OK``, ``NOTE``, ``WARNING``, ``ERROR``.
    """
    for j in range(start, min(start + 3, len(lines))):
        s = lines[j].strip()
        if not s:
            continue
        for cand in (VERDICT_ERROR, VERDICT_WARNING, VERDICT_NOTE, VERDICT_OK):
            if cand in s.split():
                return cand
        return None
    return None


def _read_detail_block(lines: list[str], start: int) -> tuple[list[str], int]:
    """Read the indented continuation block following a section header.

    Returns the list of detail lines (with leading whitespace stripped to
    a uniform left margin) and the index of the line immediately after.
    """
    out: list[str] = []
    j = start
    n = len(lines)
    while j < n:
        line = lines[j]
        stripped = line.rstrip()
        if not stripped:
            # blank line ends the detail block only if the next non-blank line
            # is a new section header or a non-checking star line.
            k = j + 1
            while k < n and not lines[k].strip():
                k += 1
            if k < n and (_SECTION_RE.match(lines[k]) or _NON_CHECKING_STAR_RE.match(lines[k])):
                return out, k
            if k >= n:
                return out, k
            # otherwise treat the blank line as part of the detail block
            out.append("")
            j += 1
            continue
        if line.startswith((" ", "\t")):
            out.append(stripped)
            j += 1
            continue
        # New section header or new top-level `*` line
        if _SECTION_RE.match(line) or _NON_CHECKING_STAR_RE.match(line):
            return out, j
        # An unindented non-section line (rare); attach it to the detail block.
        out.append(stripped)
        j += 1
    return out, j


def issues_by_verdict(summary: CheckSummary) -> dict[str, list[CheckIssue]]:
    """Group issues into ``{ERROR: [...], WARNING: [...], NOTE: [...]}``."""
    out: dict[str, list[CheckIssue]] = {
        VERDICT_ERROR: [],
        VERDICT_WARNING: [],
        VERDICT_NOTE: [],
        VERDICT_UNKNOWN: [],
    }
    for i in summary.issues:
        out.setdefault(i.verdict, []).append(i)
    return out


__all__ = [
    "VERDICT_OK",
    "VERDICT_NOTE",
    "VERDICT_WARNING",
    "VERDICT_ERROR",
    "VERDICT_UNKNOWN",
    "CheckIssue",
    "CheckSummary",
    "issues_by_verdict",
    "parse_check_log",
    "parse_issues",
]
