"""R bridge: subprocess + Rscript + JSON.

Spawn `Rscript` with a per-skill `invoke.R` dispatcher, send the JSON payload
on stdin, and parse the JSON response from stdout. This avoids R-Python
embedding (rpy2) and keeps the dependency surface to stdlib + an R install.
"""
from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path
from typing import Any

DEFAULT_TIMEOUT_SECONDS = 60


def _which_rscript() -> str | None:
    """Return path to Rscript or None if missing."""
    return shutil.which("Rscript")


def invoke(
    skill_dir: Path | str,
    payload: dict[str, Any],
    timeout: float = DEFAULT_TIMEOUT_SECONDS,
) -> dict[str, Any]:
    """Invoke an R-runtime skill by spawning Rscript and exchanging JSON.

    Parameters
    ----------
    skill_dir : Path | str
        Path to the skill directory (must contain `invoke.R`).
    payload : dict
        Dictionary serialized to JSON and written to Rscript's stdin.
    timeout : float
        Wall-clock seconds before the subprocess is killed. Default 60.

    Returns
    -------
    dict
        Structured result. On success: `{"ok": True, "fn": ..., "result": ...}`.
        On failure: `{"ok": False, "error": ...}` plus `stderr`/`returncode`
        when applicable.
    """
    skill_dir = Path(skill_dir)
    invoke_r = skill_dir / "invoke.R"
    if not invoke_r.is_file():
        return {"ok": False, "error": f"missing invoke.R in {skill_dir}"}

    rscript = _which_rscript()
    if rscript is None:
        return {
            "ok": False,
            "error": (
                "Rscript not found on PATH. Install R from https://cran.r-project.org "
                "and ensure `Rscript` is callable from the shell."
            ),
        }

    try:
        payload_bytes = json.dumps(payload).encode("utf-8")
    except (TypeError, ValueError) as exc:
        return {"ok": False, "error": f"payload is not JSON-serializable: {exc}"}

    try:
        completed = subprocess.run(
            [rscript, "--vanilla", str(invoke_r)],
            input=payload_bytes,
            capture_output=True,
            timeout=timeout,
            check=False,
        )
    except subprocess.TimeoutExpired:
        return {"ok": False, "error": f"R skill timed out after {timeout}s"}
    except OSError as exc:
        return {"ok": False, "error": f"failed to spawn Rscript: {exc}"}

    stdout = completed.stdout.decode("utf-8", errors="replace").strip()
    stderr = completed.stderr.decode("utf-8", errors="replace").strip()

    if not stdout:
        return {
            "ok": False,
            "error": "R skill produced no stdout",
            "returncode": completed.returncode,
            "stderr": stderr,
        }

    try:
        result = json.loads(stdout)
    except json.JSONDecodeError as exc:
        return {
            "ok": False,
            "error": f"R skill emitted non-JSON stdout: {exc}",
            "returncode": completed.returncode,
            "stdout": stdout,
            "stderr": stderr,
        }

    if not isinstance(result, dict):
        return {
            "ok": False,
            "error": f"R skill emitted non-object JSON (got {type(result).__name__})",
            "result": result,
            "stderr": stderr,
        }

    if completed.returncode != 0 and result.get("ok") is not False:
        result["ok"] = False
        result.setdefault("error", "R skill exited non-zero")
        result.setdefault("returncode", completed.returncode)
        result.setdefault("stderr", stderr)

    return result


__all__ = ["invoke"]
