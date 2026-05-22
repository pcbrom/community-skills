"""r-universe distribution helpers for cran_publisher.

CRAN rejects a source tarball above 10 MB. A package whose build vendors a
large dependency tree, such as an R package with a Rust component, can cross
that limit for reasons that are arithmetic, not quality: ``cargo vendor``
carries every crate in the lock file, optional features included. r-universe
is the other distribution channel of the R ecosystem. It builds source and
binaries from a Git repository, with no tarball size limit and no incoming
pretest, and serves them from ``https://<universe>.r-universe.dev``.

This module mirrors the CRAN side of cran_publisher for the r-universe
channel:

- :func:`runiverse_preflight` is the readiness gate. It is lighter than
  :func:`cran_publisher.preflight.submission_preflight` because r-universe
  drops the rules CRAN enforces: it accepts a development version, needs no
  ``cran-comments.md``, does not archive a package for using more than two
  cores, and has no tarball size limit. It keeps the rules r-universe still
  needs: a valid ``DESCRIPTION`` and a Git repository for the universe to
  pull from.
- :func:`runiverse_register` produces or updates the ``packages.json`` entry
  that a universe (a ``<user>.r-universe.dev`` repository) uses to list a
  package.
- :func:`runiverse_status` reads the r-universe JSON API for the build and
  per-platform check state of a package already in a universe.

The module stops short of ``git push``. Registering a package means adding
its entry to ``packages.json`` and pushing that repository; the push is the
maintainer's act, the point at which a package starts being published under
a person's universe. :func:`runiverse_register` writes the file behind a
``confirm`` gate and hands the commit and push back to the maintainer.
"""
from __future__ import annotations

import json
import re
import subprocess
from dataclasses import dataclass, field
from pathlib import Path

import requests

from cran_publisher.error_parser import parse_check_log
from cran_publisher.preflight import Gate, _parse_dcf

DEFAULT_API_TIMEOUT_SECONDS = 30
PACKAGES_JSON = "packages.json"


@dataclass(slots=True)
class RuniversePreflightResult:
    """Structured outcome of an r-universe submission preflight."""

    package: str
    version: str
    ready: bool
    gates: list[Gate] = field(default_factory=list)
    handoff: list[str] = field(default_factory=list)

    @property
    def blocking_failures(self) -> list[Gate]:
        return [g for g in self.gates if g.blocking and g.passed is False]


@dataclass(slots=True)
class RuniverseRegisterResult:
    """Structured outcome of a packages.json registration."""

    universe_dir: str
    package: str
    action: str  # "added", "updated", or "unchanged"
    written: bool
    dry_run: bool
    entry: dict
    entries: list[dict] = field(default_factory=list)
    next_step: str = ""


@dataclass(slots=True)
class RuniverseStatusResult:
    """Structured outcome of an r-universe API status query."""

    universe: str
    package: str | None
    found: bool
    reason: str
    status: str | None = None
    version: str | None = None
    build_url: str | None = None
    remote_url: str | None = None
    remote_sha: str | None = None
    published: str | None = None
    binaries: list[dict] = field(default_factory=list)
    jobs: list[dict] = field(default_factory=list)
    packages: list[dict] = field(default_factory=list)


def _git_remote_url(package_dir: Path) -> str | None:
    """Return the ``origin`` remote URL of the repo holding ``package_dir``.

    Returns ``None`` when the directory is not inside a Git work tree, when
    Git is not installed, or when no ``origin`` remote is configured.
    """
    try:
        proc = subprocess.run(
            ["git", "-C", str(package_dir), "config", "--get",
             "remote.origin.url"],
            capture_output=True, timeout=15, check=False,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None
    if proc.returncode != 0:
        return None
    url = proc.stdout.decode("utf-8", errors="replace").strip()
    return url or None


def runiverse_preflight(
    package_dir: Path | str,
    *,
    check_stdout: str | None = None,
) -> RuniversePreflightResult:
    """Check whether a package source tree is ready for r-universe.

    Parameters
    ----------
    package_dir
        Path to the unpacked source tree (the directory with DESCRIPTION).
    check_stdout
        Optional stdout of a prior ``R CMD check``. When given, the error
        count becomes a blocking gate; warnings and notes are reported but
        do not block, because r-universe publishes a package with check
        warnings, it only renders the badge. When absent, the check gate is
        recorded as undetermined and non-blocking, since r-universe runs its
        own check on every build.
    """
    package_dir = Path(package_dir)
    gates: list[Gate] = []
    desc_path = package_dir / "DESCRIPTION"
    if not desc_path.is_file():
        return RuniversePreflightResult(
            package="(unknown)", version="(unknown)", ready=False,
            gates=[Gate("DESCRIPTION present", False, True,
                        f"no DESCRIPTION at {package_dir}")],
        )
    desc = _parse_dcf(desc_path.read_text(encoding="utf-8", errors="replace"))
    package = desc.get("Package", "(unknown)")
    version = desc.get("Version", "(unknown)")

    # Gate: required DESCRIPTION fields. r-universe needs the same core
    # metadata CRAN does to build and index the package.
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

    # Gate: the version is well formed. Unlike the CRAN preflight, a
    # development version (a fourth component of 9000 or more) is accepted:
    # r-universe builds and serves development versions as a matter of
    # course.
    well_formed = bool(re.fullmatch(r"\d+(\.\d+){1,3}", version))
    gates.append(Gate(
        "version well formed", well_formed, True,
        f"version {version}" + (
            "" if well_formed
            else "; the Version field is malformed and would break the "
                 "build"),
    ))

    # Gate: the package is in a Git repository with an origin remote.
    # r-universe pulls each package from a Git URL, so a tree with no
    # reachable remote cannot be built by a universe.
    remote = _git_remote_url(package_dir)
    gates.append(Gate(
        "git origin remote", remote is not None, True,
        f"origin -> {remote}" if remote is not None
        else "no Git origin remote found; r-universe pulls each package "
             "from a Git URL",
    ))

    # Gate: the last R CMD check, when its log was supplied. Errors block a
    # build. Warnings and notes do not block: r-universe publishes the
    # package and renders the check badge. The CRAN two-core note is not a
    # gate here, r-universe does not archive a package for it.
    if check_stdout is None:
        gates.append(Gate(
            "R CMD check", None, False,
            "no check log supplied; r-universe runs its own check on each "
            "build, so a local check is informative, not required",
        ))
    else:
        summary = parse_check_log(check_stdout)
        detail = (f"{summary.n_errors} errors, {summary.n_warnings} "
                  f"warnings, {summary.n_notes} notes")
        if summary.n_warnings or summary.n_notes:
            detail += ("; warnings and notes do not block on r-universe, "
                       "they render the badge")
        gates.append(Gate("R CMD check", summary.n_errors == 0, True, detail))

    # Gate, non-blocking: a NEWS file. r-universe renders it on the package
    # page; its absence is a missed opportunity, not a blocker.
    news = next((package_dir / n for n in ("NEWS.md", "NEWS")
                 if (package_dir / n).is_file()), None)
    gates.append(Gate(
        "NEWS file", news is not None, False,
        f"{news.name} present" if news is not None
        else "no NEWS.md or NEWS file; r-universe renders one when present",
    ))

    ready = not any(g.blocking and g.passed is not True for g in gates)

    if ready:
        handoff = [
            "All blocking gates pass. The package is ready for r-universe.",
            "1. Register it: add an entry to the packages.json of your "
            "universe with runiverse_register.",
            "2. Commit and push the universe repository. The push is the "
            "maintainer's act and is not automated.",
            "3. r-universe builds source and binaries within minutes; "
            "track the build with runiverse_status.",
        ]
    else:
        handoff = ["Not ready. Resolve the blocking gates above, then run "
                   "the preflight again."]

    return RuniversePreflightResult(
        package=package, version=version, ready=ready,
        gates=gates, handoff=handoff,
    )


def _load_packages_json(path: Path) -> list[dict]:
    """Load a packages.json file into a list of entries.

    An absent file is treated as an empty universe. A file holding a JSON
    object rather than an array is wrapped into a one-element list, the
    single-package shorthand some universes use.
    """
    if not path.is_file():
        return []
    raw = path.read_text(encoding="utf-8", errors="replace").strip()
    if not raw:
        return []
    data = json.loads(raw)
    if isinstance(data, dict):
        return [data]
    if isinstance(data, list):
        return [e for e in data if isinstance(e, dict)]
    raise ValueError(
        f"{path} holds a JSON {type(data).__name__}; expected an array of "
        "package entries"
    )


def runiverse_register(
    universe_dir: Path | str,
    *,
    package: str,
    url: str,
    branch: str | None = None,
    subdir: str | None = None,
    confirm: bool = False,
) -> RuniverseRegisterResult:
    """Add or update a package entry in a universe's packages.json.

    A universe is a ``<user>.r-universe.dev`` Git repository whose root
    ``packages.json`` lists the packages the universe builds. This function
    merges one entry into that file, idempotently: an existing entry for the
    same package name is replaced, otherwise the entry is appended.

    Parameters
    ----------
    universe_dir
        Path to a local clone of the universe repository (the directory
        that holds, or will hold, ``packages.json``).
    package
        The package name, the ``Package`` field of its DESCRIPTION.
    url
        The Git URL r-universe pulls the package from.
    branch
        Optional branch name; omitted entries track the repository default.
    subdir
        Optional subdirectory, for a package that does not sit at the
        repository root (a monorepo layout).
    confirm
        The file is written only when this is exactly ``True``. With it
        unset the call is a dry run: it reports the merge it would make and
        writes nothing.
    """
    universe_dir = Path(universe_dir)
    if not universe_dir.is_dir():
        raise FileNotFoundError(
            f"universe directory {universe_dir} does not exist; clone the "
            "<user>.r-universe.dev repository first"
        )
    path = universe_dir / PACKAGES_JSON
    entries = _load_packages_json(path)

    entry: dict = {"package": package, "url": url}
    if branch:
        entry["branch"] = branch
    if subdir:
        entry["subdir"] = subdir

    action = "added"
    new_entries: list[dict] = []
    replaced = False
    for existing in entries:
        if existing.get("package") == package:
            replaced = True
            action = "unchanged" if existing == entry else "updated"
            new_entries.append(entry)
        else:
            new_entries.append(existing)
    if not replaced:
        new_entries.append(entry)

    written = False
    if confirm is True and action != "unchanged":
        path.write_text(
            json.dumps(new_entries, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
        written = True

    if action == "unchanged":
        next_step = (f"{package} is already registered with this exact "
                     "entry; nothing to write.")
    elif written:
        next_step = (f"{PACKAGES_JSON} updated. Commit and push the "
                     "universe repository; the push is the maintainer's "
                     "act and triggers the r-universe build.")
    else:
        next_step = (f"dry run: call again with confirm=true to write the "
                     f"{action} entry to {PACKAGES_JSON}.")

    return RuniverseRegisterResult(
        universe_dir=str(universe_dir), package=package, action=action,
        written=written, dry_run=confirm is not True, entry=entry,
        entries=new_entries, next_step=next_step,
    )


def _normalize_universe(universe: str) -> str:
    """Return the bare universe host, e.g. ``pcbrom`` from a name or URL.

    Accepts ``pcbrom``, ``pcbrom.r-universe.dev``, and
    ``https://pcbrom.r-universe.dev`` and returns the first label.
    """
    u = universe.strip()
    u = re.sub(r"^https?://", "", u)
    u = u.split("/", 1)[0]
    if u.endswith(".r-universe.dev"):
        u = u[: -len(".r-universe.dev")]
    return u


def runiverse_status(
    universe: str,
    package: str | None = None,
    *,
    timeout: float = DEFAULT_API_TIMEOUT_SECONDS,
) -> RuniverseStatusResult:
    """Read the r-universe JSON API for the build state of a universe.

    Parameters
    ----------
    universe
        The universe, given as a bare name (``pcbrom``), a host
        (``pcbrom.r-universe.dev``), or a URL.
    package
        When given, the call reports that single package: its build status,
        version, the build-log URL, the binaries, and the per-platform
        check verdicts. When omitted, the call lists every package in the
        universe with its version and status.
    timeout
        Wall-clock seconds for the HTTP request.
    """
    host = _normalize_universe(universe)
    base = f"https://{host}.r-universe.dev"

    if package is not None:
        api_url = f"{base}/api/packages/{package}"
    else:
        api_url = f"{base}/api/packages"

    try:
        resp = requests.get(api_url, timeout=timeout)
    except requests.exceptions.RequestException as exc:
        return RuniverseStatusResult(
            universe=host, package=package, found=False,
            reason=f"the r-universe API could not be reached: {exc}",
        )

    if resp.status_code == 404:
        what = (f"package '{package}' in universe '{host}'"
                if package is not None else f"universe '{host}'")
        return RuniverseStatusResult(
            universe=host, package=package, found=False,
            reason=f"{what} was not found (HTTP 404); check the names and "
                   "that the universe has been built at least once",
        )
    if resp.status_code != 200:
        return RuniverseStatusResult(
            universe=host, package=package, found=False,
            reason=f"the r-universe API returned HTTP {resp.status_code}",
        )
    try:
        data = resp.json()
    except ValueError:
        return RuniverseStatusResult(
            universe=host, package=package, found=False,
            reason="the r-universe API response was not valid JSON",
        )

    if package is None:
        listed = [
            {"package": p.get("Package"), "version": p.get("Version"),
             "status": p.get("_status")}
            for p in data if isinstance(p, dict)
        ]
        return RuniverseStatusResult(
            universe=host, package=None, found=True,
            reason=f"{len(listed)} packages in universe '{host}'",
            packages=listed,
        )

    return RuniverseStatusResult(
        universe=host, package=package, found=True,
        reason=f"package '{package}' is in universe '{host}'",
        status=data.get("_status"),
        version=data.get("Version"),
        build_url=data.get("_buildurl"),
        remote_url=data.get("RemoteUrl"),
        remote_sha=data.get("RemoteSha"),
        published=data.get("_published"),
        binaries=[b for b in data.get("_binaries", []) if isinstance(b, dict)],
        jobs=[{"config": j.get("config"), "check": j.get("check")}
              for j in data.get("_jobs", []) if isinstance(j, dict)],
    )


__all__ = [
    "DEFAULT_API_TIMEOUT_SECONDS",
    "PACKAGES_JSON",
    "RuniversePreflightResult",
    "RuniverseRegisterResult",
    "RuniverseStatusResult",
    "runiverse_preflight",
    "runiverse_register",
    "runiverse_status",
]
