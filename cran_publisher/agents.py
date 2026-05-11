"""Agent-side helpers for Phase 5.2: ask Gemma to propose a fix for one
``R CMD check`` issue, parse the proposal as a structured edit list,
apply it to disk.

The agent is intentionally narrow:

- It knows how to read one :class:`~cran_publisher.categorize.CategorizedIssue`
  plus a snippet of the surrounding source files.
- It produces a JSON proposal of the shape
  ``{"thought": "...", "edits": [{"path": "...", "search": "...", "replace": "..."}]}``.
- It does not know about git or the check runner; the orchestrator wires
  those in :mod:`cran_publisher.fix_loop`.

The Claude escalation path is symmetrical (same JSON shape) and lives
in this file too, gated on a budget cap. Phase 5.2 only exercises the
Gemma path; Claude is wired up but not invoked by default until the
operator confirms the API key and the cost ceiling.
"""
from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable

import requests

from .categorize import CategorizedIssue

OLLAMA_URL = "http://localhost:11434/api/generate"
DEFAULT_MODEL = "gemma4:26b-fast"
DEFAULT_OPTIONS = {
    "temperature": 0.2,
    "top_p": 0.9,
    "num_ctx": 8192,
    "num_predict": 2048,
}
DEFAULT_TIMEOUT_S = 240


PROMPT_TEMPLATE = """You are debugging a CRAN R package. Propose ONE minimal edit that addresses this `R CMD check` issue. Output a single JSON object and nothing else.

EDITORIAL CONTRACT (non-negotiable):

- No U+2014. Use comma, colon or semicolon.
- No buzzwords: crucial, essential, fundamental, revolutionary, incredible, important, robust.
- No emojis.
- The fix must be minimal: change as few lines as possible.

PATH RULES:

- The ``path`` field is interpreted relative to the package source
  directory shown below as ``PACKAGE ROOT``. So when the file
  excerpts list ``DESCRIPTION``, you MUST output ``"path": "DESCRIPTION"``,
  not ``"<package_name>/DESCRIPTION"`` and not an absolute path.

OUTPUT SCHEMA (no fences, no preamble, no trailing prose):

{{
  "thought": "<one paragraph: what the issue says, why your edit fixes it>",
  "risk_level": "<low|medium|high>",
  "edits": [
    {{
      "path": "<package-relative path; same form as the headers in the FILE EXCERPTS section>",
      "search": "<exact substring to find; must be unique in the file>",
      "replace": "<replacement substring; same kind of content>"
    }}
  ]
}}

If the issue cannot be fixed by editing files (for example, the fix
requires a new R release or external infrastructure), output an object
with ``edits: []`` and explain in ``thought``.

PACKAGE ROOT: {package_root}

ISSUE:

verdict: {verdict}
category: {category} ({label})
description: {description}
detail:
{detail}

PACKAGE FILE EXCERPTS (only the files most likely relevant):

{file_context}
"""


@dataclass(slots=True)
class EditProposal:
    path: str
    search: str
    replace: str


@dataclass(slots=True)
class FixProposal:
    thought: str
    risk_level: str
    edits: list[EditProposal] = field(default_factory=list)
    raw_response: str = ""

    @property
    def is_empty(self) -> bool:
        return not self.edits


def build_prompt(
    issue: CategorizedIssue,
    file_excerpts: dict[str, str],
    *,
    package_root: str = "(unspecified)",
    strategy: int = 1,
    previous_attempt_reason: str | None = None,
) -> str:
    """Build the Gemma prompt for one fix attempt.

    The Phase 5.3 Gemma-only regime diversifies the prompt by attempt
    index to give the local critic room to explore different angles
    without paying for Claude escalation. Five strategies map to the
    five attempts allowed per issue:

    1. Minimal prompt, file excerpts truncated to 2 KB each.
    2. Same prompt with file excerpts expanded to 4 KB each.
    3. Same shape plus an explicit "previous attempt failed because
       <reason>, try a different angle" instruction.
    4. Risk-level limit raised to medium: edits may touch more lines
       or restructure short blocks (but still one fix per attempt).
    5. Final shot: instruct the model to return ``edits: []`` and
       explain in ``thought`` rather than guess, so the operator
       can pick up from there in a human-supervised pass.
    """
    per_file_budget = 4000 if strategy >= 2 else 2000
    file_context_chunks = []
    for path, content in file_excerpts.items():
        truncated = (content if len(content) <= per_file_budget
                     else content[:per_file_budget] + "\n...[truncated]")
        file_context_chunks.append(f"--- {path} ---\n{truncated}")
    file_context = "\n\n".join(file_context_chunks) or "(no file excerpts attached)"

    strategy_addendum = ""
    if strategy >= 3 and previous_attempt_reason:
        strategy_addendum += (
            f"\n\nDIVERSIFICATION HINT: a previous attempt did not improve the "
            f"check verdict because `{previous_attempt_reason}`. Avoid the same "
            f"angle; explain your new angle in the `thought` field.\n"
        )
    if strategy >= 4:
        strategy_addendum += (
            "\nRISK-LEVEL UPGRADE: edits with `risk_level: \"medium\"` are "
            "acceptable in this attempt. You may touch more lines or "
            "restructure a short block, still constrained to one logical fix.\n"
        )
    if strategy >= 5:
        strategy_addendum += (
            "\nFINAL ATTEMPT: if you cannot fix this issue with a confident "
            "one-edit proposal, return `edits: []` and explain in `thought` "
            "what context the operator needs to gather. Guessing here is "
            "worse than escalating to a human.\n"
        )

    return PROMPT_TEMPLATE.format(
        package_root=package_root,
        verdict=issue.verdict,
        category=issue.category,
        label=issue.label,
        description=issue.description,
        detail=issue.issue.detail or "(no detail block)",
        file_context=file_context,
    ) + strategy_addendum


def call_gemma(prompt: str, model: str = DEFAULT_MODEL,
               timeout: float = DEFAULT_TIMEOUT_S) -> str:
    response = requests.post(
        OLLAMA_URL,
        json={
            "model": model,
            "prompt": prompt,
            "stream": False,
            "think": False,
            "options": DEFAULT_OPTIONS,
        },
        timeout=timeout,
    )
    response.raise_for_status()
    return response.json()["response"]


_FENCE_RE = re.compile(r"^```(?:json|markdown)?\s*\n(.*?)\n```\s*$", re.DOTALL)


def parse_proposal(raw: str) -> FixProposal:
    """Parse the LLM output. Strips a code-fence wrapper if present and
    falls back to scanning for the first balanced JSON object."""
    s = raw.strip()
    m = _FENCE_RE.match(s)
    if m:
        s = m.group(1).strip()
    payload = _first_json_object(s)
    if payload is None:
        return FixProposal(thought="(failed to parse LLM proposal)",
                           risk_level="unknown",
                           edits=[],
                           raw_response=raw)
    edits = [
        EditProposal(path=e.get("path", ""),
                     search=e.get("search", ""),
                     replace=e.get("replace", ""))
        for e in payload.get("edits", [])
        if isinstance(e, dict)
    ]
    return FixProposal(
        thought=str(payload.get("thought", "")),
        risk_level=str(payload.get("risk_level", "unknown")),
        edits=edits,
        raw_response=raw,
    )


def _first_json_object(s: str) -> dict | None:
    """Scan ``s`` for the first balanced ``{...}`` block and parse it."""
    start = s.find("{")
    while start != -1:
        depth = 0
        for i in range(start, len(s)):
            c = s[i]
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    chunk = s[start: i + 1]
                    try:
                        return json.loads(chunk)
                    except json.JSONDecodeError:
                        break
        start = s.find("{", start + 1)
    return None


def apply_proposal(proposal: FixProposal, repo_root: Path | str) -> list[str]:
    """Apply each edit to the repository. Returns the list of touched paths.

    Raises :class:`ValueError` when ``search`` is missing, empty, ambiguous,
    or out-of-tree, so the caller can revert via git.
    """
    repo_root = Path(repo_root)
    touched: list[str] = []
    for e in proposal.edits:
        if not e.path:
            raise ValueError("edit has empty path")
        target = (repo_root / e.path).resolve()
        try:
            target.relative_to(repo_root.resolve())
        except ValueError as exc:
            raise ValueError(f"edit path escapes repo root: {e.path}") from exc
        if not target.is_file():
            raise ValueError(f"edit path is not a file: {e.path}")
        if not e.search:
            raise ValueError(f"edit search is empty for {e.path}")
        text = target.read_text(encoding="utf-8")
        count = text.count(e.search)
        if count == 0:
            raise ValueError(f"search string not found in {e.path}")
        if count > 1:
            raise ValueError(f"search string is ambiguous in {e.path} ({count} matches)")
        text = text.replace(e.search, e.replace, 1)
        target.write_text(text, encoding="utf-8")
        touched.append(e.path)
    return touched


def gather_excerpts(
    repo_root: Path | str,
    paths: Iterable[str],
    *,
    max_chars: int = 2000,
) -> dict[str, str]:
    """Read a small bundle of files for the prompt context."""
    repo_root = Path(repo_root)
    out: dict[str, str] = {}
    for p in paths:
        target = repo_root / p
        if target.is_file():
            text = target.read_text(encoding="utf-8", errors="replace")
            out[p] = text if len(text) <= max_chars else text[:max_chars] + "\n...[truncated]"
    return out


__all__ = [
    "EditProposal",
    "FixProposal",
    "apply_proposal",
    "build_prompt",
    "call_gemma",
    "gather_excerpts",
    "parse_proposal",
]
