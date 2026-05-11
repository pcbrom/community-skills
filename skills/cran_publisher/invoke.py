#!/usr/bin/env python3
"""cran_publisher skill dispatcher.

Reads one JSON object from stdin, routes on the `fn` field, calls the
matching cran_publisher function, and writes one JSON object to stdout.
Errors are reported as ``{"ok": false, "error": "..."}`` with non-zero
exit code.

The dispatcher is invoked by ``bridges.python``, which prepends the
repository root to ``PYTHONPATH``, so imports resolve to the in-tree
``cran_publisher`` package without an editable install.
"""
from __future__ import annotations

import json
import sys
import traceback
from pathlib import Path

DEFAULT_AUDIT_PATH = "data/fix_session.jsonl"
STDOUT_TRUNCATE = 16_000
STDERR_TRUNCATE = 4_000


def emit_ok(fn_name: str, result) -> None:
    sys.stdout.write(json.dumps({"ok": True, "fn": fn_name, "result": result},
                                default=str))
    sys.stdout.write("\n")


def emit_error(message: str, fn_name: str | None = None, code: int = 1) -> None:
    payload: dict = {"ok": False, "error": message}
    if fn_name is not None:
        payload["fn"] = fn_name
    sys.stdout.write(json.dumps(payload))
    sys.stdout.write("\n")
    sys.exit(code)


def require_field(name: str, payload: dict, fn_name: str):
    if name not in payload or payload[name] in (None, ""):
        emit_error(f"Field `{name}` is required for fn={fn_name}.", fn_name)
    return payload[name]


def _truncate(s: str, n: int) -> str:
    if len(s) <= n:
        return s
    return s[: n - 3] + "..."


def handle_run_check(payload: dict) -> dict:
    from cran_publisher import run_check
    package_dir = Path(require_field("package_dir", payload, "run_check"))
    flags = tuple(payload.get("flags") or
                  ("--as-cran", "--no-manual", "--no-build-vignettes"))
    timeout = float(payload.get("timeout") or 600)
    result = run_check(package_dir, flags=flags, timeout=timeout)
    return {
        "exit_code": result.exit_code,
        "wall_clock_s": result.wall_clock_s,
        "timed_out": result.timed_out,
        "stdout": _truncate(result.stdout, STDOUT_TRUNCATE),
        "stderr": _truncate(result.stderr, STDERR_TRUNCATE),
        "ok": result.ok,
    }


def handle_parse_log(payload: dict) -> dict:
    from cran_publisher import parse_check_log
    text = require_field("stdout", payload, "parse_log")
    summary = parse_check_log(text)
    return {
        "n_errors": summary.n_errors,
        "n_warnings": summary.n_warnings,
        "n_notes": summary.n_notes,
        "passes_cran": summary.passes_cran,
        "issues": [
            {"verdict": i.verdict, "description": i.description, "detail": i.detail}
            for i in summary.issues
        ],
    }


def handle_categorize(payload: dict) -> dict:
    from cran_publisher import classify_summary, parse_check_log
    text = require_field("stdout", payload, "categorize")
    classified = classify_summary(parse_check_log(text))
    return {
        "n_errors": classified.n_errors,
        "n_warnings": classified.n_warnings,
        "n_notes": classified.n_notes,
        "by_category": classified.by_category,
        "items": [
            {
                "verdict": it.verdict,
                "description": it.description,
                "category": it.category,
                "label": it.label,
            }
            for it in classified.items
        ],
    }


def handle_fix_session(payload: dict) -> dict:
    from cran_publisher import fix_session
    repo_root = Path(require_field("repo_root", payload, "fix_session"))
    package_dir = Path(require_field("package_dir", payload, "fix_session"))
    audit_path = Path(payload.get("audit_path") or DEFAULT_AUDIT_PATH)
    max_attempts = int(payload.get("max_attempts_per_issue") or 3)
    session = fix_session(
        repo_root=repo_root,
        package_dir=package_dir,
        audit_path=audit_path,
        max_attempts_per_issue=max_attempts,
    )
    return {
        "run_branch": session.run_branch,
        "n_attempts": len(session.attempts),
        "n_accepted": sum(1 for a in session.attempts if a.accepted),
        "attempts": [
            {
                "issue_description": a.issue_description,
                "issue_category": a.issue_category,
                "attempt_idx": a.attempt_idx,
                "branch": a.branch,
                "accepted": a.accepted,
                "reason": a.reason,
                "wall_clock_s": a.wall_clock_s,
            }
            for a in session.attempts
        ],
    }


HANDLERS = {
    "run_check": handle_run_check,
    "parse_log": handle_parse_log,
    "categorize": handle_categorize,
    "fix_session": handle_fix_session,
}


def main() -> int:
    raw = sys.stdin.read().strip()
    if not raw:
        emit_error("No JSON payload received on stdin.")
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as exc:
        emit_error(f"Invalid JSON on stdin: {exc}")
    if not isinstance(payload, dict):
        emit_error(f"Payload must be a JSON object (got {type(payload).__name__}).")

    fn_name = payload.get("fn")
    if not fn_name:
        emit_error("Field `fn` is required.")

    handler = HANDLERS.get(fn_name)
    if handler is None:
        emit_error(
            f"Unknown fn '{fn_name}'. Supported: {sorted(HANDLERS)}.",
            fn_name,
        )

    try:
        result = handler(payload)
    except SystemExit:
        raise
    except Exception as exc:  # noqa: BLE001
        tb = traceback.format_exc(limit=4)
        emit_error(f"{type(exc).__name__}: {exc}\n{tb}", fn_name)

    emit_ok(fn_name, result)
    return 0


if __name__ == "__main__":
    sys.exit(main())
