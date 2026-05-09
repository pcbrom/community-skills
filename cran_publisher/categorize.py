"""Categorize parsed ``R CMD check`` issues into a small taxonomy.

The taxonomy lives in :data:`TAXONOMY` and is loaded from
``data/error_taxonomy.json`` when the file is present (so the operator
can extend the patterns without redeploying code). Each category has a
stable key, a short human label, and a list of regular-expression
patterns matched against the issue's section description and detail
text. The first matching category wins; if no pattern fires the issue
is tagged ``other``.

The categories cover the most frequent CRAN gate failures. The list is
not exhaustive: a living document is the explicit design choice
(see ``data/error_taxonomy.json``).
"""
from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable

from .error_parser import CheckIssue, CheckSummary

DATA_DIR = Path(__file__).resolve().parent / "data"
DEFAULT_TAXONOMY_PATH = DATA_DIR / "error_taxonomy.json"


@dataclass(slots=True)
class Category:
    """One taxonomy entry."""

    key: str
    label: str
    patterns: tuple[re.Pattern, ...]

    @classmethod
    def from_dict(cls, payload: dict) -> "Category":
        return cls(
            key=payload["key"],
            label=payload["label"],
            patterns=tuple(re.compile(p, re.IGNORECASE) for p in payload.get("patterns", [])),
        )


@dataclass(slots=True)
class CategorizedIssue:
    """A :class:`CheckIssue` plus its assigned category."""

    issue: CheckIssue
    category: str
    label: str

    @property
    def description(self) -> str:
        return self.issue.description

    @property
    def verdict(self) -> str:
        return self.issue.verdict


@dataclass(slots=True)
class CategorizedSummary:
    """Aggregate view: original :class:`CheckSummary` with category labels."""

    n_errors: int
    n_warnings: int
    n_notes: int
    items: list[CategorizedIssue] = field(default_factory=list)

    @property
    def by_category(self) -> dict[str, int]:
        out: dict[str, int] = {}
        for it in self.items:
            out[it.category] = out.get(it.category, 0) + 1
        return out

    @property
    def by_verdict(self) -> dict[str, int]:
        return {
            "ERROR": self.n_errors,
            "WARNING": self.n_warnings,
            "NOTE": self.n_notes,
        }


def load_taxonomy(path: Path | str | None = None) -> list[Category]:
    """Load the taxonomy, falling back to :data:`BUILTIN_TAXONOMY`."""
    target = Path(path) if path else DEFAULT_TAXONOMY_PATH
    if target.is_file():
        payload = json.loads(target.read_text(encoding="utf-8"))
        return [Category.from_dict(c) for c in payload["categories"]]
    return [Category.from_dict(c) for c in BUILTIN_TAXONOMY]


def classify_issue(
    issue: CheckIssue,
    taxonomy: Iterable[Category] | None = None,
) -> CategorizedIssue:
    """Assign one category to one :class:`CheckIssue`."""
    cats = list(taxonomy) if taxonomy is not None else load_taxonomy()
    haystack = f"{issue.description}\n{issue.detail}"
    for cat in cats:
        for pat in cat.patterns:
            if pat.search(haystack):
                return CategorizedIssue(issue=issue, category=cat.key, label=cat.label)
    return CategorizedIssue(issue=issue, category="other", label="Other / unclassified")


def classify_summary(
    summary: CheckSummary,
    taxonomy: Iterable[Category] | None = None,
) -> CategorizedSummary:
    """Categorize every issue in a :class:`CheckSummary`."""
    cats = list(taxonomy) if taxonomy is not None else load_taxonomy()
    items = [classify_issue(it, taxonomy=cats) for it in summary.issues]
    return CategorizedSummary(
        n_errors=summary.n_errors,
        n_warnings=summary.n_warnings,
        n_notes=summary.n_notes,
        items=items,
    )


# --------------------------------------------------------------------------- #
# Built-in taxonomy used when ``data/error_taxonomy.json`` is absent.
# Keep in sync with the JSON file; the JSON is the source of truth at runtime.
# --------------------------------------------------------------------------- #


BUILTIN_TAXONOMY: list[dict] = [
    {
        "key": "missing_documentation",
        "label": "Missing or incomplete Rd documentation",
        "patterns": [
            r"missing documentation entries",
            r"functions? without documentation",
            r"undocumented (code|argument|data sets)",
            r"missing description",
            r"\\arguments missing",
        ],
    },
    {
        "key": "undefined_globals",
        "label": "Undefined global functions or variables",
        "patterns": [
            r"no visible (binding|global function definition)",
            r"undefined global functions or variables",
        ],
    },
    {
        "key": "namespace",
        "label": "NAMESPACE / imports / exports issue",
        "patterns": [
            r"object .* (is|are) not exported",
            r"in .NAMESPACE.",
            r"importFrom",
            r"undeclared imports?",
            r"exports? .+ not present",
            r"namespace dependencies not required",
        ],
    },
    {
        "key": "deprecated_api",
        "label": "Deprecated or defunct R API usage",
        "patterns": [
            r"is deprecated",
            r"\.Defunct",
            r"\.Deprecated",
            r"will be removed in a future version",
        ],
    },
    {
        "key": "rd_syntax",
        "label": "Rd file syntax / cross-reference issue",
        "patterns": [
            r"missing link",
            r"unknown macro",
            r"problems? with .Rd .*",
            r"unmatched .{|}",
            r"checking .Rd files",
        ],
    },
    {
        "key": "examples",
        "label": "Examples failing or excessively slow",
        "patterns": [
            r"examples? .* failed",
            r"examples? .* error",
            r"running examples?",
            r"checking examples? .* (WARNING|ERROR|NOTE)",
            r"\\dontrun .* not allowed",
        ],
    },
    {
        "key": "tests",
        "label": "Test suite failure",
        "patterns": [
            r"checking tests? .*",
            r"test ?that failed",
            r"running .R unit tests.",
            r"failures? in tests?",
        ],
    },
    {
        "key": "vignettes",
        "label": "Vignette build issue",
        "patterns": [
            r"checking (re-)?building of vignettes?",
            r"vignette .* (failed|error)",
        ],
    },

    {
        "key": "url_check",
        "label": "Broken URL or DOI",
        "patterns": [
            r"^URL$",
            r"\bURLs?\b",
            r"invalid URLs?",
            r"non-standard.*URL",
            r"moved permanently",
            r"unable to resolve host",
            r"\bDOI[s]?\b",
            r"\(404\)",
            r"\(403\)",
        ],
    },
    {
        "key": "license",
        "label": "License field issue",
        "patterns": [
            r"checking package license",
            r"license is .* unknown",
            r"file LICEN[SC]E",
            r"non-standard license specification",
        ],
    },
    {
        "key": "encoding",
        "label": "Encoding / non-ASCII content",
        "patterns": [
            r"non-ASCII",
            r"declared encoding",
            r"unable to translate",
            r"invalid (multi)?byte string",
        ],
    },
    {
        "key": "build_compile",
        "label": "C / C++ / Fortran compilation issue",
        "patterns": [
            r"checking compilation flags",
            r"package native routines",
            r"undefined reference",
            r"call to (un)?registered routines?",
            r"compilation failed",
        ],
    },
    {
        "key": "size",
        "label": "Package or sub-directory size issue",
        "patterns": [
            r"installed size",
            r"sub-directory .* is large",
            r"checking package size",
        ],
    },
    {
        "key": "incoming_feasibility",
        "label": "CRAN incoming feasibility (initial submission gate)",
        "patterns": [
            r"checking CRAN incoming feasibility",
            r"new submission",
            r"version contains.*",
            r"days/since/last/release",
        ],
    },
    {
        "key": "description_metadata",
        "label": "DESCRIPTION metadata field issue",
        "patterns": [
            r"for file .+DESCRIPTION",
            r"required fields? (missing|empty|absent|ausente)",
            r"campos? requeridos? ausentes",
            r"\bAuthor\b.*(missing|empty)",
            r"\bMaintainer\b.*(missing|empty)",
            r"Authors@R",
            r"malformed (Title|Description) field",
        ],
    },
]


__all__ = [
    "BUILTIN_TAXONOMY",
    "Category",
    "CategorizedIssue",
    "CategorizedSummary",
    "classify_issue",
    "classify_summary",
    "load_taxonomy",
]
