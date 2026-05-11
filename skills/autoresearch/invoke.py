#!/usr/bin/env python3
"""autoresearch skill dispatcher.

Reads one JSON object from stdin, routes on the `fn` field, spawns
``autoresearch <subcommand>`` with the appropriate flags, and writes
one JSON object to stdout. The dispatcher does not import the
autoresearch library directly; it shells out so the contract stays
stable across upstream refactors.
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
import traceback

DEFAULT_TIMEOUT_SECONDS = 300
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
    return s if len(s) <= n else s[: n - 3] + "..."


def _run_subcmd(argv: list[str], fn_name: str,
                timeout: float = DEFAULT_TIMEOUT_SECONDS) -> dict:
    cli = shutil.which("autoresearch")
    if cli is None:
        emit_error(
            "The `autoresearch` CLI is not on PATH. Install via "
            "`pip install autoresearch` or `pip install -e <source>`.",
            fn_name,
        )
    try:
        completed = subprocess.run(
            [cli, *argv],
            capture_output=True, timeout=timeout, check=False,
        )
    except subprocess.TimeoutExpired:
        emit_error(f"autoresearch subcommand timed out after {timeout}s", fn_name)
    return {
        "exit_code": completed.returncode,
        "stdout": _truncate(completed.stdout.decode("utf-8", errors="replace"),
                            STDOUT_TRUNCATE),
        "stderr": _truncate(completed.stderr.decode("utf-8", errors="replace"),
                            STDERR_TRUNCATE),
    }


def handle_init(payload: dict) -> dict:
    problem = require_field("problem", payload, "init")
    target = require_field("target", payload, "init")
    argv = ["init", "--problem", problem, "--target", target]
    if payload.get("tag"):
        argv.extend(["--tag", str(payload["tag"])])
    return _run_subcmd(argv, "init")


def handle_run(payload: dict) -> dict:
    argv = ["run"]
    if payload.get("problem"):
        argv.extend(["--problem", str(payload["problem"])])
    return _run_subcmd(argv, "run", timeout=600)


def handle_critic(payload: dict) -> dict:
    argv = ["critic"]
    if payload.get("problem"):
        argv.extend(["--problem", str(payload["problem"])])
    if payload.get("dry_run"):
        argv.append("--dry-run")
    return _run_subcmd(argv, "critic")


def handle_analyze(payload: dict) -> dict:
    argv = ["analyze"]
    if payload.get("project"):
        argv.extend(["--project", str(payload["project"])])
    if payload.get("problem"):
        argv.extend(["--problem", str(payload["problem"])])
    lib = payload.get("lower_is_better")
    if lib is not None:
        argv.extend(["--lower-is-better", "true" if lib else "false"])
    return _run_subcmd(argv, "analyze")


def handle_audit(payload: dict) -> dict:
    argv = ["audit"]
    if payload.get("problem"):
        argv.extend(["--problem", str(payload["problem"])])
    if payload.get("out_md"):
        argv.extend(["--out-md", str(payload["out_md"])])
    if payload.get("out_json"):
        argv.extend(["--out-json", str(payload["out_json"])])
    return _run_subcmd(argv, "audit")


def handle_state(payload: dict) -> dict:
    argv = ["state"]
    if payload.get("problem"):
        argv.extend(["--problem", str(payload["problem"])])
    if payload.get("force"):
        argv.append("--force")
    return _run_subcmd(argv, "state")


HANDLERS = {
    "init": handle_init,
    "run": handle_run,
    "critic": handle_critic,
    "analyze": handle_analyze,
    "audit": handle_audit,
    "state": handle_state,
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
