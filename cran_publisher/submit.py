"""Gated CRAN submission step for cran_publisher.

The function uploads a package to CRAN through ``devtools::submit_cran()``,
behind two gates: the submission preflight must pass, and the caller must
pass ``confirm=True``. With ``confirm`` unset it is a dry run that reports
the preflight and the command it would run.

It stops at the upload. The confirmation e-mail CRAN sends to the
maintainer is never touched: clicking that link is the maintainer's act,
the accountability gate for publishing under a person's name. A skill that
clicked it would be removing a deliberate human checkpoint, not adding a
feature.
"""
from __future__ import annotations

import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path

from cran_publisher.preflight import submission_preflight

DEFAULT_SUBMIT_TIMEOUT_SECONDS = 1800


@dataclass(slots=True)
class SubmitResult:
    """Structured outcome of a gated CRAN submission attempt."""

    package: str
    version: str
    uploaded: bool
    reason: str
    preflight_ready: bool
    dry_run: bool
    rscript_exit_code: int | None = None
    output: str = ""
    next_step: str = ""


def submit_to_cran(
    package_dir: Path | str,
    *,
    confirm: bool = False,
    check_stdout: str | None = None,
    tarball: Path | str | None = None,
    timeout: float = DEFAULT_SUBMIT_TIMEOUT_SECONDS,
) -> SubmitResult:
    """Upload a package to CRAN behind the preflight and confirm gates.

    Parameters
    ----------
    package_dir
        Path to the package source tree.
    confirm
        The upload runs only when this is exactly ``True``. With it unset
        the call is a dry run: it reports the preflight and the command it
        would run, and uploads nothing.
    check_stdout
        Stdout of a prior ``R CMD check``, passed through to the preflight.
        A clean-environment log, such as win-builder, is the right input.
    tarball
        Optional path to a built source tarball, passed to the preflight.
    timeout
        Wall-clock seconds for ``devtools::submit_cran()``, which rebuilds
        the package.
    """
    package_dir = Path(package_dir)
    pre = submission_preflight(package_dir, tarball=tarball,
                               check_stdout=check_stdout)

    # Gate 1: the preflight must pass.
    if not pre.ready:
        return SubmitResult(
            package=pre.package, version=pre.version, uploaded=False,
            reason="submission preflight is not ready; resolve the blocking "
                   "gates before submitting",
            preflight_ready=False, dry_run=False,
        )

    # Gate 2: confirm must be exactly True; otherwise this is a dry run.
    if confirm is not True:
        return SubmitResult(
            package=pre.package, version=pre.version, uploaded=False,
            reason="dry run: the preflight passes; call again with "
                   "confirm=true to upload to CRAN",
            preflight_ready=True, dry_run=True,
            next_step="Re-call with confirm=true to run "
                      "devtools::submit_cran() from the package directory.",
        )

    rscript = shutil.which("Rscript")
    if rscript is None:
        return SubmitResult(
            package=pre.package, version=pre.version, uploaded=False,
            reason="Rscript not found on PATH; cannot run "
                   "devtools::submit_cran()",
            preflight_ready=True, dry_run=False,
        )

    # Both gates pass and confirm is set: run the upload.
    try:
        proc = subprocess.run(
            [rscript, "-e", "devtools::submit_cran()"],
            cwd=package_dir, capture_output=True, timeout=timeout, check=False,
        )
    except subprocess.TimeoutExpired:
        return SubmitResult(
            package=pre.package, version=pre.version, uploaded=False,
            reason=f"devtools::submit_cran() exceeded the {timeout:.0f}s "
                   "timeout",
            preflight_ready=True, dry_run=False,
        )
    output = (proc.stdout.decode("utf-8", errors="replace")
              + proc.stderr.decode("utf-8", errors="replace"))
    uploaded = proc.returncode == 0
    return SubmitResult(
        package=pre.package, version=pre.version, uploaded=uploaded,
        reason="devtools::submit_cran() completed" if uploaded
               else "devtools::submit_cran() returned a non-zero status; "
                    "read the output",
        preflight_ready=True, dry_run=False,
        rscript_exit_code=proc.returncode, output=output,
        next_step="CRAN sends a confirmation e-mail to the maintainer "
                  "address. The submission is complete only once the "
                  "maintainer clicks the link in that e-mail. That step is "
                  "not automated, by design.",
    )


__all__ = ["DEFAULT_SUBMIT_TIMEOUT_SECONDS", "SubmitResult", "submit_to_cran"]
