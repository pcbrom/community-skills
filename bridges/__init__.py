"""community-skills bridges.

A bridge takes a skill name and a JSON-serializable payload, dispatches the
call to the appropriate language runtime (declared by `runtime:` in the
skill's `SKILL.md`), and returns a Python dict with at least an `ok` field.

Public API
----------

    from bridges import invoke
    result = invoke("bgumbel", {"fn": "dbgumbel", "x": [0.0], "mu1": -1, "mu2": 1, "delta": 0.5})
"""
from __future__ import annotations

import re
from pathlib import Path
from typing import Any

from .r import invoke as _invoke_r

REPO_ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = REPO_ROOT / "skills"


def _read_runtime(skill_md: Path) -> str:
    """Extract the `runtime:` field from a SKILL.md front matter or body.

    The contract is permissive: the first line that matches `^runtime:\\s*(\\w+)`
    wins. This avoids requiring a YAML parser as a runtime dependency.
    """
    text = skill_md.read_text(encoding="utf-8")
    match = re.search(r"(?mi)^runtime:\s*([\w\-]+)\s*$", text)
    if not match:
        raise ValueError(
            f"SKILL.md at {skill_md} does not declare a `runtime:` field "
            f"(expected one of: r, python, julia)"
        )
    return match.group(1).strip().lower()


def invoke(skill: str, payload: dict[str, Any]) -> dict[str, Any]:
    """Invoke a skill by name with a JSON-serializable payload.

    Parameters
    ----------
    skill : str
        Directory name under `skills/` (for example, `"bgumbel"`).
    payload : dict
        JSON-serializable dictionary. The `fn` key must name an exposed function.

    Returns
    -------
    dict
        Always contains `ok: bool`. On success, also `fn: str` and `result: Any`.
        On failure, also `error: str`.

    Notes
    -----
    Supported runtimes today: ``r`` (canonical, all wrapped CRAN packages)
    and ``python`` (in-tree infra skills such as ``cran_graph`` and
    ``cran_publisher`` that serve the R workflow). Julia is intentionally
    out of scope for this project (decided 2026-05-09).
    """
    skill_dir = SKILLS_DIR / skill
    if not skill_dir.is_dir():
        return {"ok": False, "error": f"skill not found: {skill}"}

    skill_md = skill_dir / "SKILL.md"
    if not skill_md.is_file():
        return {"ok": False, "error": f"missing SKILL.md in {skill_dir}"}

    runtime = _read_runtime(skill_md)

    if runtime == "r":
        return _invoke_r(skill_dir, payload)
    if runtime == "python":
        from .python import invoke as _invoke_py
        return _invoke_py(skill_dir, payload)

    return {
        "ok": False,
        "error": (
            f"unknown runtime '{runtime}' declared in {skill_md}. "
            f"Supported: r, python."
        ),
    }


__all__ = ["invoke"]
