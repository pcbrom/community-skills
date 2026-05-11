#!/usr/bin/env python3
"""cran_workflow skill dispatcher.

Composes `cran_graph` and `cran_publisher` behind one JSON contract.
"""
from __future__ import annotations

import json
import sys
import traceback
from pathlib import Path

REPORT_TRUNCATE = 16_000


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
    return s if len(s) <= n else s[: n - 3] + "..."


def handle_audit_release(payload: dict) -> dict:
    from cran_graph import load_graph, optimize
    from cran_publisher import classify_summary, parse_check_log, run_check

    snap = Path(require_field("snapshot", payload, "audit_release"))
    pkg_name = require_field("package_name", payload, "audit_release")
    pkg_dir = Path(require_field("package_dir", payload, "audit_release"))

    g = load_graph(snap)
    opt = optimize(
        g, [pkg_name],
        strict_active=bool(payload.get("strict_active", False)),
        r_version=payload.get("r_version"),
    )
    closure_payload = {
        "install_set": opt.install_set,
        "install_count": opt.install_count,
        "by_status": dict(opt.by_status),
        "warnings": list(opt.warnings),
        "conflicts": list(opt.conflicts),
    }

    check_result = run_check(pkg_dir)
    summary = parse_check_log(check_result.stdout)
    classified = classify_summary(summary)
    check_payload = {
        "exit_code": check_result.exit_code,
        "n_errors": summary.n_errors,
        "n_warnings": summary.n_warnings,
        "n_notes": summary.n_notes,
        "by_category": classified.by_category,
        "issues": [
            {"verdict": it.verdict, "category": it.category,
             "description": it.description}
            for it in classified.items
        ],
    }

    return {
        "closure": closure_payload,
        "check": check_payload,
        "passes_cran": summary.passes_cran,
    }


def handle_fix_and_report(payload: dict) -> dict:
    from cran_publisher import run_full_session

    repo_root = Path(require_field("repo_root", payload, "fix_and_report"))
    package_dir = Path(require_field("package_dir", payload, "fix_and_report"))
    package_name = require_field("package_name", payload, "fix_and_report")
    audit_path = Path(payload.get("audit_path") or "data/fix_session.jsonl")
    report_path = payload.get("report_path")
    if report_path is not None:
        report_path = Path(report_path)
    max_attempts = int(payload.get("max_attempts_per_issue") or 5)
    soft = float(payload.get("soft_wall_clock_s") or 180.0)
    hard = float(payload.get("hard_wall_clock_s") or 600.0)

    session, report = run_full_session(
        repo_root=repo_root,
        package_dir=package_dir,
        package_name=package_name,
        audit_path=audit_path,
        report_path=report_path,
        max_attempts_per_issue=max_attempts,
        soft_wall_clock_s=soft,
        hard_wall_clock_s=hard,
    )
    return {
        "run_branch": session.run_branch,
        "n_attempts": len(session.attempts),
        "n_accepted": sum(1 for a in session.attempts if a.accepted),
        "soft_cap_hit": session.soft_cap_hit,
        "hard_cap_hit": session.hard_cap_hit,
        "report_markdown": _truncate(report, REPORT_TRUNCATE),
        "report_path": str(report_path) if report_path is not None else None,
    }


HANDLERS = {
    "audit_release": handle_audit_release,
    "fix_and_report": handle_fix_and_report,
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
