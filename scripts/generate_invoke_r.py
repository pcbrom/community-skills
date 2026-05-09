"""Generate ``invoke.R`` for a staged SKILL.md, validate, write to skills/.

Inputs:

- ``skills/_staging/<pkg>/SKILL.md`` (the LLM-drafted contract).
- ``skills/_staging/<pkg>/_meta.json`` (DESCRIPTION + NAMESPACE + Rd
  excerpts captured at draft time).
- ``skills/bgumbel/invoke.R`` as the few-shot anchor.

Output: ``skills/<pkg>/invoke.R`` if the generated dispatcher parses
under ``Rscript -e 'parse(...)'`` without error.

The script never overwrites an existing ``skills/<pkg>/invoke.R``
without ``--force``: promotion is irreversible and a half-failed pass
should leave the prior dispatcher in place.
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path

import requests

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))

from extract_package_metadata import (  # type: ignore  # noqa: E402
    PackageMetadata,
    fetch_and_extract,
    metadata_to_dict,
)

OLLAMA_URL = "http://localhost:11434/api/generate"
DEFAULT_MODEL = "gemma4:26b-fast"
DEFAULT_OPTIONS = {
    "temperature": 0.15,
    "top_p": 0.9,
    "num_ctx": 12288,
    "num_predict": 4500,
}
DEFAULT_TIMEOUT_SECONDS = 240


PROMPT_TEMPLATE = """You are generating an invoke.R dispatcher for an LLM-callable skill that wraps the CRAN package `{package}`.

The dispatcher reads one JSON object from stdin, routes on the `fn` field, calls the named function from `{package}`, and writes one JSON object to stdout. On failure it writes `{{"ok": false, "error": "..."}}` and exits non-zero.

Hard requirements (no exceptions):

- The first non-comment line must be `#!/usr/bin/env Rscript`.
- Use `jsonlite` for JSON parse and emit. Check that both `jsonlite` and `{package}` are installed via `requireNamespace`; on missing install, call `emit_error` with the install hint.
- Redirect package banners to stderr (`sink(stderr(), type = "output")`) so stdout carries only the final JSON.
- Define helpers: `emit_error(msg, fn_name = NA, code = 1L)`, `emit_ok(result, fn_name)`, `require_field(name, payload, fn_name)`.
- Implement a `dispatch(payload)` function that switches on `payload$fn` and calls one handler per exposed function.
- For each handler, read the JSON payload using EXACTLY the upstream R argument names listed in the UPSTREAM SIGNATURES block below. Do not rename arguments to match the SKILL.md narrative; the upstream signature is the contract. If the SKILL.md says `x` but the upstream signature lists `txt`, the JSON payload key is `txt`.
- Coerce numeric arrays via `as.numeric(...)`, integers via `as.integer(...)`, characters via `as.character(...)`. Pass them to the wrapped function.
- For arguments documented as optional (default values present in the upstream Rd), only pass them through if `payload[[name]]` is non-NULL. Never invent default values; let R use the upstream default.
- The result of the wrapped function goes through `emit_ok(result, fn_name)`. If the wrapped function raises, wrap the call in `tryCatch` and route the message through `emit_error`.
- If `payload$fn` does not match any known handler, `emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)`.

Use the bgumbel dispatcher below as the canonical structural template. Follow its layout exactly: header, imports, helpers, main body, dispatch.

EDITORIAL CONTRACT (non-negotiable):

- Never use the U+2014 character. Use comma, colon or semicolon.
- Never use buzzwords: crucial, essential, fundamental, revolutionary, incredible, important, robust.
- No emojis.
- Comments are short and in English without accents.

UPSTREAM SIGNATURES (extracted from /man/*.Rd \\arguments{{}} blocks; use these names verbatim in payload reads):

{signatures_block}

SKILL.md (background context, but the upstream signatures above override any field-name mismatch):

```markdown
{skill_md}
```

EXEMPLAR DISPATCHER (bgumbel/invoke.R, follow this structure):

```r
{exemplar}
```

Now produce only the contents of `skills/{package}/invoke.R`. Do not wrap in code fences. Begin with `#!/usr/bin/env Rscript`."""


def _format_signatures_block(md: PackageMetadata) -> str:
    if not md.function_docs:
        return "(no Rd files extracted; rely on SKILL.md and refuse to fabricate signatures.)"
    chunks: list[str] = []
    for d in md.function_docs:
        if d.arguments:
            arg_lines = "\n".join(f"  - {name}: {desc}" for name, desc in d.arguments)
        else:
            arg_lines = "  (no \\arguments{} block in the Rd file; refuse to invent arguments)"
        chunks.append(f"### {d.name}\n{arg_lines}")
    return "\n\n".join(chunks)


# --------------------------------------------------------------------------- #
# Validation
# --------------------------------------------------------------------------- #


@dataclass(slots=True)
class GenerationResult:
    package: str
    ok: bool
    output_path: Path | None
    issues: list[str]
    wall_clock_s: float
    raw_chars: int


def _strip_fences(text: str) -> str:
    s = text.strip()
    if s.startswith("```"):
        first_newline = s.find("\n")
        if first_newline != -1:
            s = s[first_newline + 1:]
        if s.endswith("```"):
            s = s[: -3]
    return s.rstrip() + "\n"


def validate_invoke_r(text: str, package: str) -> list[str]:
    """Return a list of failure tokens; empty list means OK."""
    issues: list[str] = []
    if not text.lstrip().startswith("#!/usr/bin/env Rscript"):
        issues.append("missing_shebang")
    if "jsonlite" not in text:
        issues.append("no_jsonlite_reference")
    if "dispatch" not in text:
        issues.append("no_dispatch_function")
    if "emit_error" not in text:
        issues.append("no_emit_error")
    if "emit_ok" not in text:
        issues.append("no_emit_ok")
    if package not in text:
        issues.append(f"no_reference_to_{package}")
    if chr(0x2014) in text:
        issues.append("contains_em_dash")

    rscript = shutil.which("Rscript")
    if rscript is None:
        issues.append("no_rscript_for_parse_check")
        return issues

    with tempfile.NamedTemporaryFile(mode="w", suffix=".R", delete=False, encoding="utf-8") as tmp:
        tmp.write(text)
        tmp_path = tmp.name
    try:
        completed = subprocess.run(
            [rscript, "-e", f"parse(file = '{tmp_path}')"],
            capture_output=True, timeout=20, check=False,
        )
        if completed.returncode != 0:
            stderr = completed.stderr.decode("utf-8", errors="replace")
            issues.append(f"r_parse_failed:{stderr.strip()[:300]}")
    finally:
        Path(tmp_path).unlink(missing_ok=True)
    return issues


# --------------------------------------------------------------------------- #
# Ollama call
# --------------------------------------------------------------------------- #


def call_ollama(prompt: str, model: str = DEFAULT_MODEL,
                options: dict | None = None,
                timeout: float = DEFAULT_TIMEOUT_SECONDS) -> str:
    response = requests.post(
        OLLAMA_URL,
        json={
            "model": model,
            "prompt": prompt,
            "stream": False,
            "think": False,
            "options": options or DEFAULT_OPTIONS,
        },
        timeout=timeout,
    )
    response.raise_for_status()
    return response.json()["response"]


# --------------------------------------------------------------------------- #
# Orchestrator
# --------------------------------------------------------------------------- #


def generate_invoke_r(
    package: str,
    *,
    staging_dir: Path = REPO_ROOT / "skills" / "_staging",
    skills_dir: Path = REPO_ROOT / "skills",
    exemplar_path: Path = REPO_ROOT / "skills" / "bgumbel" / "invoke.R",
    force: bool = False,
    max_attempts: int = 2,
    model: str = DEFAULT_MODEL,
    write_to_staging: bool = True,
) -> GenerationResult:
    """Generate one invoke.R via Gemma and write it to disk.

    By default the dispatcher is written next to the staged SKILL.md
    (``skills/_staging/<package>/invoke.R``); the human reviewer
    promotes it to ``skills/<package>/`` after auditing both files.
    Pass ``write_to_staging=False`` to write directly to
    ``skills/<package>/invoke.R``: this skips the human gate and is
    only safe in batch sessions where the reviewer is the operator.
    """
    started = time.time()
    src = staging_dir / package
    if not (src / "SKILL.md").is_file():
        return GenerationResult(package=package, ok=False, output_path=None,
                                issues=["staged_skill_missing"],
                                wall_clock_s=time.time() - started, raw_chars=0)

    if write_to_staging:
        target_dir = staging_dir / package
    else:
        target_dir = skills_dir / package
    target = target_dir / "invoke.R"
    if target.exists() and not force:
        return GenerationResult(package=package, ok=False, output_path=target,
                                issues=["exists_pass_force"],
                                wall_clock_s=time.time() - started, raw_chars=0)

    skill_md = (src / "SKILL.md").read_text(encoding="utf-8")
    exemplar = exemplar_path.read_text(encoding="utf-8")

    # Re-fetch upstream metadata so we have the \arguments{} blocks even if
    # the staged _meta.json was produced before the extractor learned to
    # capture them. Reading version straight from the staged metadata keeps
    # the signatures aligned with the SKILL.md the reviewer is looking at.
    meta_path = src / "_meta.json"
    if not meta_path.is_file():
        return GenerationResult(package=package, ok=False, output_path=None,
                                issues=["staged_meta_json_missing"],
                                wall_clock_s=time.time() - started, raw_chars=0)
    staged_meta = json.loads(meta_path.read_text(encoding="utf-8"))
    version = staged_meta.get("version") or ""
    md = fetch_and_extract(package, version)

    prompt = PROMPT_TEMPLATE.format(
        package=package,
        skill_md=skill_md,
        exemplar=exemplar,
        signatures_block=_format_signatures_block(md),
    )

    last_issues: list[str] = []
    raw_chars = 0
    for attempt in range(1, max_attempts + 1):
        raw = call_ollama(prompt, model=model)
        raw_chars = len(raw)
        body = _strip_fences(raw)
        last_issues = validate_invoke_r(body, package)
        if not last_issues:
            target_dir.mkdir(parents=True, exist_ok=True)
            target.write_text(body, encoding="utf-8")
            return GenerationResult(package=package, ok=True, output_path=target,
                                    issues=[], wall_clock_s=time.time() - started,
                                    raw_chars=raw_chars)

    return GenerationResult(package=package, ok=False, output_path=None,
                            issues=last_issues,
                            wall_clock_s=time.time() - started, raw_chars=raw_chars)


def promote_skill_md(package: str,
                     staging_dir: Path = REPO_ROOT / "skills" / "_staging",
                     skills_dir: Path = REPO_ROOT / "skills") -> Path:
    """Copy SKILL.md from staging to the promoted directory."""
    src = staging_dir / package / "SKILL.md"
    target_dir = skills_dir / package
    target_dir.mkdir(parents=True, exist_ok=True)
    target = target_dir / "SKILL.md"
    target.write_bytes(src.read_bytes())
    return target


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("packages", nargs="+", help="Names of packages to promote.")
    parser.add_argument("--force", action="store_true",
                        help="Overwrite an existing invoke.R.")
    parser.add_argument("--also-promote-skill-md", action="store_true",
                        help="Copy SKILL.md from staging at the same time. Implies promotion to skills/.")
    parser.add_argument("--promote-now", action="store_true",
                        help="Write to skills/<pkg>/ instead of staging. Skips the human gate.")
    args = parser.parse_args(argv)

    write_to_staging = not (args.promote_now or args.also_promote_skill_md)

    ok = 0
    for pkg in args.packages:
        if args.also_promote_skill_md or args.promote_now:
            if args.also_promote_skill_md:
                promoted = promote_skill_md(pkg)
                print(f"[promote] copied {promoted}", file=sys.stderr)
        result = generate_invoke_r(pkg, force=args.force, write_to_staging=write_to_staging)
        status = "OK " if result.ok else "FAIL"
        print(f"[{status}] {pkg:<14} t={result.wall_clock_s:.1f}s "
              f"chars={result.raw_chars} issues={result.issues}",
              file=sys.stderr)
        if result.ok:
            ok += 1

    print(f"[generate_invoke_r] ok {ok}/{len(args.packages)}", file=sys.stderr)
    return 0 if ok == len(args.packages) else 2


if __name__ == "__main__":
    raise SystemExit(main())
