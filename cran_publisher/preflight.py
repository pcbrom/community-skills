"""Submission readiness gate for a CRAN package.

``R CMD check`` answers "does the package check clean". It does not answer
"is this release ready to submit": that needs a handful of policy checks the
check does not make, such as a non-development version, a NEWS entry for the
version, and a populated ``cran-comments.md``. This module makes those checks
and returns one structured verdict.

The module deliberately stops at the verdict. It does not upload anything:
the actual submission, and the confirmation e-mail CRAN sends to the
maintainer, stay with the maintainer by design, since that e-mail is the
accountability gate for publishing under a person's name.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

from cran_publisher.error_parser import parse_check_log


@dataclass(slots=True)
class Gate:
    """One readiness check."""

    name: str
    passed: bool | None  # None means "could not be determined"
    blocking: bool
    detail: str


@dataclass(slots=True)
class PreflightResult:
    """Structured outcome of a submission preflight."""

    package: str
    version: str
    ready: bool
    gates: list[Gate] = field(default_factory=list)
    handoff: list[str] = field(default_factory=list)

    @property
    def blocking_failures(self) -> list[Gate]:
        return [g for g in self.gates if g.blocking and g.passed is False]


def _parse_dcf(text: str) -> dict[str, str]:
    """Parse the DESCRIPTION DCF into a field dictionary."""
    fields: dict[str, str] = {}
    key: str | None = None
    for line in text.splitlines():
        if line[:1].isspace():
            if key is not None:
                fields[key] += " " + line.strip()
        elif ":" in line:
            key, _, value = line.partition(":")
            key = key.strip()
            fields[key] = value.strip()
    return fields


def _is_development_version(version: str) -> bool:
    """A version with a fourth component of 9000 or more is a dev version."""
    parts = version.split(".")
    if len(parts) >= 4:
        tail = parts[3]
        return tail.isdigit() and int(tail) >= 9000
    return False


def submission_preflight(
    package_dir: Path | str,
    *,
    tarball: Path | str | None = None,
    check_stdout: str | None = None,
) -> PreflightResult:
    """Check whether a package source tree is ready for CRAN submission.

    Parameters
    ----------
    package_dir
        Path to the unpacked source tree (the directory with DESCRIPTION).
    tarball
        Optional path to a built source tarball; its size is reported.
    check_stdout
        Optional stdout of a prior ``R CMD check``. When given, the error
        and warning counts become blocking gates. When absent, the check
        gate is recorded as undetermined.
    """
    package_dir = Path(package_dir)
    gates: list[Gate] = []
    desc_path = package_dir / "DESCRIPTION"
    if not desc_path.is_file():
        return PreflightResult(
            package="(unknown)", version="(unknown)", ready=False,
            gates=[Gate("DESCRIPTION present", False, True,
                        f"no DESCRIPTION at {package_dir}")],
        )
    desc = _parse_dcf(desc_path.read_text(encoding="utf-8", errors="replace"))
    package = desc.get("Package", "(unknown)")
    version = desc.get("Version", "(unknown)")

    # Gate: required DESCRIPTION fields.
    required = ["Package", "Version", "Title", "Description", "License"]
    missing = [f for f in required if not desc.get(f)]
    has_authors = bool(desc.get("Authors@R")) or (
        bool(desc.get("Author")) and bool(desc.get("Maintainer"))
    )
    if not has_authors:
        missing.append("Authors@R (or Author + Maintainer)")
    gates.append(Gate(
        "DESCRIPTION required fields", not missing, True,
        "all present" if not missing else f"missing: {', '.join(missing)}",
    ))

    # Gate: the version is a release version, not a development version.
    dev = _is_development_version(version)
    well_formed = bool(re.fullmatch(r"\d+(\.\d+){1,3}", version))
    gates.append(Gate(
        "release version", well_formed and not dev, True,
        f"version {version}" + (
            "" if (well_formed and not dev)
            else "; a development version or malformed version cannot be "
                 "submitted"),
    ))

    # Gate: NEWS has an entry for this version.
    news = next((package_dir / n for n in ("NEWS.md", "NEWS")
                 if (package_dir / n).is_file()), None)
    if news is None:
        gates.append(Gate("NEWS entry", False, False,
                           "no NEWS.md or NEWS file"))
    else:
        news_text = news.read_text(encoding="utf-8", errors="replace")
        has_entry = any(
            line.lstrip().startswith("#") and version in line
            for line in news_text.splitlines()
        )
        gates.append(Gate(
            "NEWS entry", has_entry, False,
            f"{news.name} has a heading for {version}" if has_entry
            else f"{news.name} has no heading naming version {version}",
        ))

    # Gate: cran-comments.md exists and names the test environments.
    cc = package_dir / "cran-comments.md"
    if not cc.is_file():
        gates.append(Gate("cran-comments.md", False, True,
                           "cran-comments.md is absent"))
    else:
        cc_text = cc.read_text(encoding="utf-8", errors="replace").lower()
        names_env = "environment" in cc_text or "r cmd check" in cc_text
        gates.append(Gate(
            "cran-comments.md", names_env, True,
            "present and names the test environments" if names_env
            else "present but does not name the test environments",
        ))

    # Gate: the LICENSE file exists when DESCRIPTION points at one.
    if "file LICENSE" in desc.get("License", ""):
        has_license = (package_dir / "LICENSE").is_file()
        gates.append(Gate(
            "LICENSE file", has_license, True,
            "LICENSE present" if has_license
            else "License field names 'file LICENSE' but the file is absent",
        ))

    # Gate: the last R CMD check, when its log was supplied.
    if check_stdout is None:
        gates.append(Gate(
            "R CMD check", None, True,
            "no check log supplied; run run_check and pass its stdout",
        ))
    else:
        summary = parse_check_log(check_stdout)
        clean = summary.n_errors == 0 and summary.n_warnings == 0
        gates.append(Gate(
            "R CMD check", clean, True,
            f"{summary.n_errors} errors, {summary.n_warnings} warnings, "
            f"{summary.n_notes} notes",
        ))

    # Gate, non-blocking: the built tarball, when supplied.
    tb = Path(tarball) if tarball is not None else None
    if tb is None:
        cand = sorted(package_dir.glob(f"{package}_*.tar.gz"))
        tb = cand[-1] if cand else None
    if tb is not None and tb.is_file():
        size_mb = tb.stat().st_size / 1_048_576
        gates.append(Gate(
            "source tarball", True, False,
            f"{tb.name}, {size_mb:.1f} MB",
        ))
    else:
        gates.append(Gate("source tarball", None, False,
                           "no built tarball found; run R CMD build"))

    ready = not any(g.blocking and g.passed is not True for g in gates)

    handoff: list[str] = []
    if ready:
        handoff = [
            "All blocking gates pass. The remaining steps are the "
            "maintainer's, by design:",
            "1. Confirm the win-builder and R-hub results are clean.",
            "2. Submit: run devtools::submit_cran() in the package "
            "directory, or upload the tarball at "
            "https://cran.r-project.org/submit.html.",
            "3. Confirm the e-mail CRAN sends to the maintainer address. "
            "This step is not automated: the confirmation is the "
            "accountability gate for the submission.",
        ]
    else:
        handoff = ["Not ready. Resolve the blocking gates above, then "
                   "run the preflight again."]

    return PreflightResult(
        package=package, version=version, ready=ready,
        gates=gates, handoff=handoff,
    )


__all__ = ["Gate", "PreflightResult", "submission_preflight"]
