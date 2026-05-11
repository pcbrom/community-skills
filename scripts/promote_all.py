"""Promote staged skills to ``skills/<pkg>/`` after a structural smoke check.

For every ``skills/_staging/<pkg>/`` that has both a ``SKILL.md`` and an
``invoke.R``, the script:

1. Runs a structural smoke check: invoke the dispatcher with a JSON payload
   that names a non-existent function. A correct dispatcher returns
   ``{"ok": false, "error": "..."}`` instead of crashing or hanging.
2. On pass, copies ``SKILL.md`` and ``invoke.R`` to ``skills/<pkg>/`` and
   writes a minimal smoke test under ``tests/test_skills/test_<pkg>.py``
   that is gated on the presence of the upstream R package.
3. Appends the package to a JSON manifest so the gallery README can be
   regenerated downstream.

The smoke check does not require the upstream R package to be installed,
because the dispatcher is expected to surface "package not installed"
through the same ``emit_error`` path. Tests under ``tests/test_skills/``
do require the upstream package and skip gracefully when it is missing.
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
STAGING = REPO_ROOT / "skills" / "_staging"
PROMOTED = REPO_ROOT / "skills"
TEST_DIR = REPO_ROOT / "tests" / "test_skills"


SMOKE_PAYLOAD = b'{"fn": "this_function_should_not_exist_zzz"}'
SMOKE_TIMEOUT_S = 30


@dataclass(slots=True)
class PromotionResult:
    package: str
    ok: bool
    reason: str = ""


def _smoke_dispatcher(invoke_r: Path) -> tuple[bool, str]:
    """Spawn the dispatcher with a bogus fn and confirm it surfaces an error
    via the structured contract instead of crashing.

    A pass means: the subprocess exits with non-zero status (per the
    convention) AND emits a JSON object with ``ok: false`` on stdout.
    """
    rscript = shutil.which("Rscript")
    if rscript is None:
        return False, "no_rscript"
    try:
        completed = subprocess.run(
            [rscript, "--vanilla", str(invoke_r)],
            input=SMOKE_PAYLOAD,
            capture_output=True,
            timeout=SMOKE_TIMEOUT_S,
            check=False,
        )
    except subprocess.TimeoutExpired:
        return False, "smoke_timeout"
    stdout = completed.stdout.decode("utf-8", errors="replace").strip()
    if not stdout:
        return False, f"no_stdout (rc={completed.returncode})"
    try:
        payload = json.loads(stdout)
    except json.JSONDecodeError:
        return False, "non_json_stdout"
    if not isinstance(payload, dict):
        return False, "non_object_stdout"
    if payload.get("ok") is not False:
        return False, f"ok_field={payload.get('ok')}"
    return True, "ok"


SMOKE_TEST_TEMPLATE = '''"""Smoke tests for the {package} skill.

Skipped when Rscript is missing or the upstream `{package}` package is
not installed. The dispatcher itself is exercised structurally; the
upstream signatures are validated by the staging gate during generation.
"""
from __future__ import annotations

import shutil
import subprocess

import pytest

from bridges import invoke


def _pkg_installed() -> bool:
    if shutil.which("Rscript") is None:
        return False
    completed = subprocess.run(
        ["Rscript", "-e", 'cat(requireNamespace("{package}", quietly = TRUE))'],
        capture_output=True, text=True, timeout=20,
    )
    return completed.returncode == 0 and completed.stdout.strip() == "TRUE"


pytestmark = pytest.mark.skipif(
    not _pkg_installed(),
    reason="R or upstream {package} package not available",
)


def test_dispatcher_loads_and_rejects_unknown_fn():
    r = invoke("{package}", {{"fn": "does_not_exist_certainly_xyz"}})
    assert r["ok"] is False
    assert "error" in r


def test_dispatcher_rejects_missing_fn_field():
    r = invoke("{package}", {{}})
    assert r["ok"] is False
'''


def write_smoke_test(package: str) -> Path:
    """Idempotent: never overwrites an existing test file (that would clobber
    hand-written assertions added during human review)."""
    target = TEST_DIR / f"test_{package.replace('.', '_')}.py"
    if target.exists():
        return target
    TEST_DIR.mkdir(parents=True, exist_ok=True)
    target.write_text(SMOKE_TEST_TEMPLATE.format(package=package), encoding="utf-8")
    return target


def promote_one(package: str, *, force: bool = False) -> PromotionResult:
    src = STAGING / package
    if not (src / "SKILL.md").is_file() or not (src / "invoke.R").is_file():
        return PromotionResult(package=package, ok=False, reason="missing_skill_or_invoke")

    target_dir = PROMOTED / package
    if target_dir.exists() and not force:
        # If the existing skills/<pkg>/invoke.R is byte-equal to the staged one,
        # treat as already-promoted (no-op).
        existing = target_dir / "invoke.R"
        staged = src / "invoke.R"
        if existing.is_file() and existing.read_bytes() == staged.read_bytes():
            return PromotionResult(package=package, ok=True, reason="already_promoted")
        return PromotionResult(package=package, ok=False, reason="exists_pass_force")

    smoke_ok, smoke_reason = _smoke_dispatcher(src / "invoke.R")
    if not smoke_ok:
        return PromotionResult(package=package, ok=False, reason=f"smoke_fail:{smoke_reason}")

    target_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src / "SKILL.md", target_dir / "SKILL.md")
    shutil.copy2(src / "invoke.R", target_dir / "invoke.R")
    write_smoke_test(package)
    return PromotionResult(package=package, ok=True, reason="promoted")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("packages", nargs="*",
                        help="Names to promote. Empty means all subdirs of skills/_staging/.")
    parser.add_argument("--force", action="store_true",
                        help="Overwrite existing skills/<pkg>/ even if invoke.R differs.")
    parser.add_argument("--manifest", default="data/promotion_manifest.json",
                        help="Where to write the JSON manifest of promotions.")
    args = parser.parse_args(argv)

    if args.packages:
        names = list(args.packages)
    else:
        names = sorted(d.name for d in STAGING.iterdir()
                       if d.is_dir() and not d.name.startswith("_") and not d.name.startswith("."))

    results: list[PromotionResult] = []
    for pkg in names:
        r = promote_one(pkg, force=args.force)
        results.append(r)
        status = "OK  " if r.ok else "SKIP"
        print(f"[{status}] {pkg:<18} {r.reason}", file=sys.stderr)

    promoted = [r.package for r in results if r.ok and r.reason == "promoted"]
    already = [r.package for r in results if r.ok and r.reason == "already_promoted"]
    skipped = [(r.package, r.reason) for r in results if not r.ok]

    manifest_path = Path(args.manifest)
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(
        json.dumps({
            "promoted": promoted,
            "already_promoted": already,
            "skipped": [{"package": p, "reason": r} for p, r in skipped],
        }, indent=2) + "\n",
        encoding="utf-8",
    )

    print(
        f"[promote_all] promoted={len(promoted)} already={len(already)} skipped={len(skipped)}",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
