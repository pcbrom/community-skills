"""Generate SKILL.md files for curated CRAN packages via Gemma 4 (Ollama).

Pipeline per package:

1. Read the triage entry (rank, downloads, version, license).
2. Download the source tarball and extract DESCRIPTION + NAMESPACE +
   selected Rd manual pages.
3. Render a prompt that pins the editorial contract (no em-dash, no
   forbidden buzzwords, no emojis).
4. Send the prompt to Ollama; receive markdown.
5. Validate: must start with ``---``, contain ``runtime: r`` and
   ``package: <name>``. Reject and retry on failure.
6. Write to ``skills/_staging/<package>/SKILL.md`` with a sibling
   ``_meta.json`` for audit.
7. Append a structured entry to ``data/skill_generation_log.jsonl``.

Output goes to a staging directory because every SKILL.md needs human
review before being promoted to ``skills/<package>/``.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import requests

# Ensure the package-local extractor module is importable when this file
# is executed directly via ``python scripts/generate_skills_via_gemma.py``.
sys.path.insert(0, str(Path(__file__).resolve().parent))

from extract_package_metadata import (  # type: ignore  # noqa: E402
    PackageMetadata,
    fetch_and_extract,
    metadata_to_dict,
)

OLLAMA_URL = "http://localhost:11434/api/generate"
DEFAULT_MODEL = "gemma4:26b-fast"
DEFAULT_OPTIONS = {
    "temperature": 0.2,
    "top_p": 0.9,
    "num_ctx": 8192,
    "num_predict": 4096,
}
DEFAULT_TIMEOUT_SECONDS = 240

# Computed via chr() so the literal character never appears in source.
EM_DASH = chr(0x2014)

FORBIDDEN_TERMS = (
    "crucial", "essential", "fundamental", "revolutionary", "incredible",
    "important", "robust",
)


PROMPT_TEMPLATE = """You are generating a SKILL.md file for an LLM-callable wrapper around an R package on CRAN. The output is a single markdown document, agent-readable, that goes verbatim into community-skills/skills/{package}/SKILL.md.

EDITORIAL CONTRACT (non-negotiable):

- Never use the U+2014 character. Use comma, colon or semicolon instead.
- Never use these words: crucial, essential, fundamental, revolutionary, incredible, important, robust.
- No emojis anywhere.
- Tone: formal, scientific, third person.
- Be 100 percent factual. If you do not know a paper or claim, omit it. Never invent citations or links.
- Keep prose tight: short paragraphs, concrete language.

OUTPUT FORMAT (exactly this structure, with the YAML front matter first):

---
name: {package}
runtime: r
package: {package}
package_source: CRAN
package_url: <copy from URL field of DESCRIPTION; if missing, use https://cran.r-project.org/package={package}>
package_version_pinned: ">={version}"
license: <copy from License field, single token if possible>
maintainer: "<copy Maintainer line of DESCRIPTION verbatim>"
---

# Skill: {package}

<one or two short paragraphs explaining what the package does and what kind of agent task triggers its use. Stay grounded in the DESCRIPTION text below; do not invent capabilities.>

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("{package}")`.

## Functions exposed

For each function the dispatcher should expose, write one subsection with input/output JSON schemas. Prefer the most useful 3 to 6 exported functions; do not document every export.

### `<function_name>`: <one-line summary>

**Input**

```json
{{ "fn": "<function_name>", "<arg1>": <schema>, "<arg2>": <schema> }}
```

**Output**

```json
{{ "ok": true, "fn": "<function_name>", "result": <schema> }}
```

(repeat per function)

## When to invoke

Bullet list of concrete task patterns where an agent should reach for this skill. Each bullet must be specific (kind of input data, kind of analytical question). Avoid generic phrases like "data analysis" or "statistics".

## Error contract

```json
{{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }}
```

## Worked example

```bash
echo '<one minimal JSON payload>' | Rscript --vanilla skills/{package}/invoke.R
```

PACKAGE METADATA (use this as your only source of truth; do not pull facts from training data):

Title: {title}
Description: {description}
License: {license}
URL: {url}
Maintainer: {maintainer}
Imports: {imports}
Exported functions ({n_exported}): {exported_functions}
S3 methods ({n_s3}): {s3_methods}

PER-FUNCTION DOCUMENTATION (sampled from /man/*.Rd):

{function_docs_block}

NOW produce only the SKILL.md content. Do not wrap in code fences. Begin with the YAML front matter `---` line."""


def _format_function_docs_block(md: PackageMetadata) -> str:
    if not md.function_docs:
        return "(no Rd files extracted; use the exported function list above.)"
    chunks: list[str] = []
    for d in md.function_docs:
        chunks.append(
            f"### {d.name}\n"
            f"Title: {d.title}\n"
            f"Description: {d.description}\n"
            f"Example:\n```r\n{d.example}\n```"
        )
    return "\n\n".join(chunks)


def build_prompt(md: PackageMetadata) -> str:
    return PROMPT_TEMPLATE.format(
        package=md.package,
        version=md.version,
        title=md.title or "(missing)",
        description=md.description or "(missing)",
        license=md.license or "(missing)",
        url=md.url or "(missing)",
        maintainer=md.maintainer or "(missing)",
        imports=", ".join(md.imports) or "(none)",
        exported_functions=", ".join(md.exported_functions[:80]) or "(none)",
        n_exported=len(md.exported_functions),
        s3_methods=", ".join(md.s3_methods[:40]) or "(none)",
        n_s3=len(md.s3_methods),
        function_docs_block=_format_function_docs_block(md),
    )


def call_ollama(
    prompt: str,
    model: str = DEFAULT_MODEL,
    timeout: float = DEFAULT_TIMEOUT_SECONDS,
    options: dict | None = None,
) -> str:
    """One-shot generate. Streaming is disabled to keep the call simple."""
    response = requests.post(
        OLLAMA_URL,
        json={
            "model": model,
            "prompt": prompt,
            "stream": False,
            # gemma4 26b variants are tagged with the "thinking" capability;
            # if not disabled, the chain-of-thought trace consumes the
            # entire num_predict budget and the visible response is empty.
            "think": False,
            "options": options or DEFAULT_OPTIONS,
        },
        timeout=timeout,
    )
    response.raise_for_status()
    payload = response.json()
    return payload["response"]


@dataclass(slots=True)
class ValidationResult:
    ok: bool
    issues: list[str]


_FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---", re.DOTALL)


def validate_skill_md(text: str, expected_package: str) -> ValidationResult:
    issues: list[str] = []
    stripped = text.strip()

    if "```" in stripped[:30]:
        stripped = re.sub(r"^```(?:markdown|md)?\s*\n", "", stripped, count=1)
        stripped = re.sub(r"\n```\s*$", "", stripped, count=1)

    if not stripped.startswith("---"):
        issues.append("missing_yaml_frontmatter")
        return ValidationResult(False, issues)

    fm_match = _FRONTMATTER_RE.match(stripped)
    if not fm_match:
        issues.append("unbalanced_yaml_frontmatter")
        return ValidationResult(False, issues)

    fm = fm_match.group(1)
    if not re.search(r"(?mi)^runtime\s*:\s*r\s*$", fm):
        issues.append("missing_runtime_r")
    if not re.search(rf"(?mi)^package\s*:\s*{re.escape(expected_package)}\s*$", fm):
        issues.append("missing_or_wrong_package_field")
    if not re.search(rf"(?mi)^name\s*:\s*{re.escape(expected_package)}\s*$", fm):
        issues.append("missing_or_wrong_name_field")

    body = stripped[fm_match.end():]
    if "## Functions exposed" not in body:
        issues.append("missing_functions_section")
    if "## When to invoke" not in body:
        issues.append("missing_when_to_invoke_section")

    if EM_DASH in stripped:
        issues.append("contains_em_dash")
    lower = stripped.lower()
    for term in FORBIDDEN_TERMS:
        if re.search(rf"\b{re.escape(term)}\b", lower):
            issues.append(f"contains_forbidden_term:{term}")

    return ValidationResult(not issues, issues)


def _strip_code_fences_if_wrapping(text: str) -> str:
    s = text.strip()
    if s.startswith("```"):
        s = re.sub(r"^```(?:markdown|md)?\s*\n", "", s, count=1)
        s = re.sub(r"\n```\s*$", "", s, count=1)
    return s


def generate_one(
    triage_entry: dict[str, Any],
    output_dir: Path,
    log_path: Path,
    model: str = DEFAULT_MODEL,
    max_attempts: int = 2,
) -> dict:
    package = triage_entry["package"]
    version = triage_entry["version"]
    started = time.time()

    try:
        md = fetch_and_extract(package, version)
    except Exception as exc:
        record = {
            "package": package,
            "version": version,
            "ok": False,
            "stage": "extract",
            "error": str(exc),
            "wall_clock_s": round(time.time() - started, 2),
        }
        _append_log(log_path, record)
        return record

    prompt = build_prompt(md)
    last_issues: list[str] = []
    for attempt in range(1, max_attempts + 1):
        try:
            raw = call_ollama(prompt, model=model)
        except Exception as exc:
            record = {
                "package": package,
                "version": version,
                "ok": False,
                "stage": f"ollama_attempt_{attempt}",
                "error": str(exc),
                "wall_clock_s": round(time.time() - started, 2),
            }
            _append_log(log_path, record)
            return record

        body = _strip_code_fences_if_wrapping(raw)
        result = validate_skill_md(body, package)
        last_issues = result.issues
        if result.ok:
            target_dir = output_dir / package
            target_dir.mkdir(parents=True, exist_ok=True)
            (target_dir / "SKILL.md").write_text(body + "\n", encoding="utf-8")
            (target_dir / "_meta.json").write_text(
                json.dumps(metadata_to_dict(md), indent=2) + "\n",
                encoding="utf-8",
            )
            record = {
                "package": package,
                "version": version,
                "ok": True,
                "stage": "ok",
                "attempts": attempt,
                "wall_clock_s": round(time.time() - started, 2),
                "n_exports": len(md.exported_functions),
                "n_rd_docs": len(md.function_docs),
                "rank": triage_entry.get("rank"),
                "downloads_last_month": triage_entry.get("downloads_last_month"),
            }
            _append_log(log_path, record)
            return record

    record = {
        "package": package,
        "version": version,
        "ok": False,
        "stage": "validation_after_retries",
        "issues": last_issues,
        "wall_clock_s": round(time.time() - started, 2),
    }
    _append_log(log_path, record)
    return record


def _append_log(path: Path, record: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(record, ensure_ascii=False) + "\n")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--triage", required=True, help="JSON produced by triage_top_cran.py")
    parser.add_argument("--output-dir", default="skills/_staging", help="Where to write generated SKILL.md.")
    parser.add_argument("--log", default="data/skill_generation_log.jsonl", help="Append-only log path.")
    parser.add_argument("--model", default=DEFAULT_MODEL, help=f"Ollama model name (default: {DEFAULT_MODEL}).")
    parser.add_argument("--limit", type=int, default=10, help="How many packages to process.")
    parser.add_argument("--skip-existing", action="store_true",
                        help="Skip packages that already have a SKILL.md in the output dir.")
    args = parser.parse_args(argv)

    triage = json.loads(Path(args.triage).read_text(encoding="utf-8"))
    output_dir = Path(args.output_dir)
    log_path = Path(args.log)

    processed = 0
    ok = 0
    for entry in triage:
        if processed >= args.limit:
            break
        if args.skip_existing and (output_dir / entry["package"] / "SKILL.md").is_file():
            print(f"[gen] skip {entry['package']}: already in output dir", file=sys.stderr)
            continue
        print(
            f"[gen] {entry['rank']:>3}. {entry['package']} v{entry['version']} "
            f"({entry['downloads_last_month']:,} dl)",
            file=sys.stderr,
        )
        record = generate_one(entry, output_dir, log_path, model=args.model)
        status = "OK " if record["ok"] else "FAIL"
        print(
            f"      [{status}] stage={record.get('stage')} t={record.get('wall_clock_s')}s",
            file=sys.stderr,
        )
        processed += 1
        if record["ok"]:
            ok += 1

    print(f"[gen] processed {processed}, ok {ok}, fail {processed - ok}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
