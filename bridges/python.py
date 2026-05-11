"""Python bridge: subprocess + Python + JSON.

Spawn the current Python interpreter (``sys.executable`` by default) with
the skill's ``invoke.py`` as the entry point, send the JSON payload on
stdin, and parse the JSON response from stdout.

The bridge mirrors :mod:`bridges.r` design: standard-library only on the
host side, JSON-only on the wire, structured ``ok / error`` contract.
A skill's ``invoke.py`` may freely import third-party Python packages
that the operator has installed; the bridge does not enforce a
virtualenv (the same way :mod:`bridges.r` does not enforce a per-skill
R library).
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any

# Default kept generous: Python-runtime skills (e.g. cran_publisher,
# cran_workflow) may shell out to R CMD check or Ollama, both of which
# can run for several minutes on a real package. Per-invocation override
# is available via the ``timeout`` keyword.
DEFAULT_TIMEOUT_SECONDS = 900


def invoke(
    skill_dir: Path | str,
    payload: dict[str, Any],
    timeout: float = DEFAULT_TIMEOUT_SECONDS,
    python_executable: str | None = None,
) -> dict[str, Any]:
    """Invoke a Python-runtime skill by spawning Python and exchanging JSON.

    Parameters
    ----------
    skill_dir
        Path to the skill directory (must contain ``invoke.py``).
    payload
        Dictionary serialized to JSON and written to the subprocess stdin.
    timeout
        Wall-clock seconds before the subprocess is killed. Default 60.
    python_executable
        Override the Python binary. Defaults to ``sys.executable`` so the
        skill runs in the same interpreter (and same site-packages set)
        as the agent harness.

    Returns
    -------
    dict
        Structured result. On success: ``{"ok": True, "fn": ..., "result": ...}``.
        On failure: ``{"ok": False, "error": ...}`` plus ``stderr`` /
        ``returncode`` when applicable.
    """
    skill_dir = Path(skill_dir)
    invoke_py = skill_dir / "invoke.py"
    if not invoke_py.is_file():
        return {"ok": False, "error": f"missing invoke.py in {skill_dir}"}

    python_bin = python_executable or sys.executable
    if not python_bin:
        return {
            "ok": False,
            "error": (
                "no Python executable found; sys.executable is empty and no "
                "override was provided"
            ),
        }

    try:
        payload_bytes = json.dumps(payload).encode("utf-8")
    except (TypeError, ValueError) as exc:
        return {"ok": False, "error": f"payload is not JSON-serializable: {exc}"}

    # Add the repo root to PYTHONPATH so the skill can import community-skills
    # sub-packages (cran_graph, cran_publisher, ...) without an editable install.
    env = os.environ.copy()
    repo_root = str(skill_dir.resolve().parent.parent)
    env["PYTHONPATH"] = repo_root + os.pathsep + env.get("PYTHONPATH", "")

    try:
        completed = subprocess.run(
            [python_bin, str(invoke_py)],
            input=payload_bytes,
            capture_output=True,
            timeout=timeout,
            check=False,
            env=env,
        )
    except subprocess.TimeoutExpired:
        return {"ok": False, "error": f"Python skill timed out after {timeout}s"}
    except OSError as exc:
        return {"ok": False, "error": f"failed to spawn Python: {exc}"}

    stdout = completed.stdout.decode("utf-8", errors="replace").strip()
    stderr = completed.stderr.decode("utf-8", errors="replace").strip()

    if not stdout:
        return {
            "ok": False,
            "error": "Python skill produced no stdout",
            "returncode": completed.returncode,
            "stderr": stderr,
        }

    try:
        result = json.loads(stdout)
    except json.JSONDecodeError as exc:
        return {
            "ok": False,
            "error": f"Python skill emitted non-JSON stdout: {exc}",
            "returncode": completed.returncode,
            "stdout": stdout,
            "stderr": stderr,
        }

    if not isinstance(result, dict):
        return {
            "ok": False,
            "error": f"Python skill emitted non-object JSON (got {type(result).__name__})",
            "result": result,
            "stderr": stderr,
        }

    if completed.returncode != 0 and result.get("ok") is not False:
        result["ok"] = False
        result.setdefault("error", "Python skill exited non-zero")
        result.setdefault("returncode", completed.returncode)
        result.setdefault("stderr", stderr)

    return result


__all__ = ["invoke"]
