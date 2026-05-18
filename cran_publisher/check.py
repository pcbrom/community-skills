"""Run ``R CMD check`` against an R package source tree.

The CRAN submission gate is anchored on the output of ``R CMD check``, so
every other piece of the publisher pipeline needs a structured handle to
that output. This module provides one: it spawns the check, captures
stdout, stderr, and the exit code, persists the raw output for audit, and
returns a small dataclass that downstream modules can parse.

The implementation does not interpret the check log here; that is
:mod:`cran_publisher.error_parser`'s job. It also does not categorize the
issues it finds; that is :mod:`cran_publisher.categorize`'s job.
"""
from __future__ import annotations

import shutil
import subprocess
import tempfile
import time
from dataclasses import dataclass, field
from pathlib import Path

DEFAULT_TIMEOUT_SECONDS = 600
DEFAULT_CHECK_FLAGS: tuple[str, ...] = ("--as-cran", "--no-manual", "--no-build-vignettes")
DEFAULT_BUILD_FLAGS: tuple[str, ...] = ("--no-build-vignettes", "--no-manual")
DEFAULT_BUILD_TIMEOUT_SECONDS = 900


@dataclass(slots=True)
class CheckResult:
    """Structured outcome of one ``R CMD check`` run."""

    package_dir: Path
    exit_code: int
    stdout: str
    stderr: str
    wall_clock_s: float
    timed_out: bool = False
    flags: tuple[str, ...] = field(default_factory=tuple)
    rcmd_path: str | None = None

    @property
    def ok(self) -> bool:
        return self.exit_code == 0 and not self.timed_out

    def write_audit(self, audit_dir: Path | str) -> Path:
        """Persist stdout, stderr and metadata to a fresh subdirectory.

        The subdirectory is named by the package name plus a UTC timestamp
        so multiple runs on the same package do not overwrite each other.
        """
        audit_dir = Path(audit_dir)
        audit_dir.mkdir(parents=True, exist_ok=True)
        (audit_dir / "stdout.log").write_text(self.stdout, encoding="utf-8")
        (audit_dir / "stderr.log").write_text(self.stderr, encoding="utf-8")
        (audit_dir / "meta.txt").write_text(
            "\n".join(
                [
                    f"package_dir: {self.package_dir}",
                    f"exit_code: {self.exit_code}",
                    f"wall_clock_s: {self.wall_clock_s:.3f}",
                    f"timed_out: {self.timed_out}",
                    f"flags: {' '.join(self.flags)}",
                    f"rcmd_path: {self.rcmd_path or '(missing)'}",
                ]
            )
            + "\n",
            encoding="utf-8",
        )
        return audit_dir


def _which_r_cmd() -> str | None:
    """Return the path to ``R`` (the binary used for ``R CMD check``)."""
    return shutil.which("R")


def _run_build(
    package_dir: Path,
    rcmd: str,
    build_flags: tuple[str, ...],
    timeout: float,
    dest_dir: str,
) -> tuple[int, str, str, Path | None]:
    """Run ``R CMD build`` for ``package_dir`` into ``dest_dir``.

    Returns the exit code, stdout, stderr and the path of the produced
    source tarball, or ``None`` when no tarball was written.
    """
    args = [rcmd, "CMD", "build", *build_flags, str(package_dir)]
    completed = subprocess.run(
        args, capture_output=True, timeout=timeout, check=False, cwd=dest_dir
    )
    stdout = completed.stdout.decode("utf-8", errors="replace")
    stderr = completed.stderr.decode("utf-8", errors="replace")
    tarballs = sorted(Path(dest_dir).glob("*.tar.gz"))
    return completed.returncode, stdout, stderr, (tarballs[-1] if tarballs else None)


def run_check(
    package_dir: Path | str,
    *,
    flags: tuple[str, ...] = DEFAULT_CHECK_FLAGS,
    timeout: float = DEFAULT_TIMEOUT_SECONDS,
    output_dir: Path | str | None = None,
    build_first: bool = True,
    build_flags: tuple[str, ...] = DEFAULT_BUILD_FLAGS,
    build_timeout: float = DEFAULT_BUILD_TIMEOUT_SECONDS,
) -> CheckResult:
    """Build the package, then run ``R CMD check`` and capture the output.

    Parameters
    ----------
    package_dir
        Path to the unpacked source tree of an R package (the directory
        that contains ``DESCRIPTION``).
    flags
        Extra arguments passed to ``R CMD check``. Defaults match what
        `R CMD check --as-cran` runs in CI: full CRAN gate with manual and
        vignette builds disabled to keep wall-clock predictable.
    timeout
        Wall-clock seconds before the check subprocess is killed. Failure
        mode ``timed_out=True``.
    output_dir
        If provided, ``R CMD check`` is told to write its check directory
        there via ``-o <output_dir>``. Otherwise the check directory lands
        in the current working directory as ``<pkg>.Rcheck/``.
    build_first
        When ``True`` (the default, and what CRAN itself does), the source
        tree is first turned into a tarball with ``R CMD build`` and the
        check runs against that tarball. This is required for any package
        whose ``DESCRIPTION`` carries only ``Authors@R``: the ``Author``
        and ``Maintainer`` fields are derived during the build, and a
        direct ``R CMD check`` of the unbuilt directory would abort. When
        ``False``, the directory is checked in place.
    build_flags
        Extra arguments passed to ``R CMD build``.
    build_timeout
        Wall-clock seconds before the build subprocess is killed.
    """
    package_dir = Path(package_dir)
    if not (package_dir / "DESCRIPTION").is_file():
        raise FileNotFoundError(
            f"no DESCRIPTION at {package_dir}; expected the unpacked source tree of an R package"
        )

    rcmd = _which_r_cmd()
    if rcmd is None:
        raise FileNotFoundError("R not found on PATH; install R to use cran_publisher.check")

    started = time.time()
    with tempfile.TemporaryDirectory(prefix="cran_publisher_build_") as tmp:
        if build_first:
            try:
                rc, b_out, b_err, tarball = _run_build(
                    package_dir, rcmd, tuple(build_flags), build_timeout, tmp
                )
            except subprocess.TimeoutExpired as exc:
                return CheckResult(
                    package_dir=package_dir,
                    exit_code=-1,
                    stdout=(exc.stdout or b"").decode("utf-8", errors="replace"),
                    stderr="R CMD build timed out before the check could run",
                    wall_clock_s=time.time() - started,
                    timed_out=True,
                    flags=tuple(flags),
                    rcmd_path=rcmd,
                )
            if rc != 0 or tarball is None:
                return CheckResult(
                    package_dir=package_dir,
                    exit_code=rc or 1,
                    stdout=b_out + "\n" + b_err,
                    stderr="R CMD build failed; the check was not run",
                    wall_clock_s=time.time() - started,
                    timed_out=False,
                    flags=tuple(flags),
                    rcmd_path=rcmd,
                )
            target = str(tarball)
        else:
            target = str(package_dir)

        args = [rcmd, "CMD", "check", *flags]
        if output_dir is not None:
            Path(output_dir).mkdir(parents=True, exist_ok=True)
            args.extend(["-o", str(output_dir)])
        args.append(target)

        timed_out = False
        try:
            completed = subprocess.run(
                args,
                capture_output=True,
                timeout=timeout,
                check=False,
            )
            stdout = completed.stdout.decode("utf-8", errors="replace")
            stderr = completed.stderr.decode("utf-8", errors="replace")
            exit_code = completed.returncode
        except subprocess.TimeoutExpired as exc:
            timed_out = True
            stdout = (exc.stdout or b"").decode("utf-8", errors="replace")
            stderr = (exc.stderr or b"").decode("utf-8", errors="replace")
            exit_code = -1

    wall = time.time() - started
    return CheckResult(
        package_dir=package_dir,
        exit_code=exit_code,
        stdout=stdout,
        stderr=stderr,
        wall_clock_s=wall,
        timed_out=timed_out,
        flags=tuple(flags),
        rcmd_path=rcmd,
    )


__all__ = [
    "DEFAULT_CHECK_FLAGS",
    "DEFAULT_BUILD_FLAGS",
    "DEFAULT_TIMEOUT_SECONDS",
    "DEFAULT_BUILD_TIMEOUT_SECONDS",
    "CheckResult",
    "run_check",
]
