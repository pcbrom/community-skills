"""Download and parse the CRAN PACKAGES index.

CRAN distributes a single Debian-style index at
``https://cran.r-project.org/src/contrib/PACKAGES.gz`` that lists every
currently available source package together with its declared dependencies.
The format is one stanza per package, fields separated by ``\\n``, and
continuation lines indented by whitespace.

This module exposes three entry points:

- :func:`fetch_packages_index` downloads the gzipped index and returns the
  decompressed text.
- :func:`parse_packages_index` tokenizes the index into a list of dicts.
- :func:`fetch_archived_names` scrapes the ``/Archive/`` directory listing
  to identify packages that once lived on CRAN. The set difference between
  archive entries and current-index entries is the set of removed packages
  (one signal used by :mod:`cran_graph.deprecation`).
"""
from __future__ import annotations

import gzip
import re
from dataclasses import dataclass, field
from typing import Iterable

import requests

CRAN_PACKAGES_URL = "https://cran.r-project.org/src/contrib/PACKAGES.gz"
CRAN_ARCHIVE_URL = "https://cran.r-project.org/src/contrib/Archive/"

DEFAULT_TIMEOUT_SECONDS = 60
USER_AGENT = "community-skills/cran_graph (+https://github.com/pcbrom/community-skills)"

DEPENDENCY_FIELDS = ("Depends", "Imports", "LinkingTo", "Suggests", "Enhances")

_ARCHIVE_DIR_RE = re.compile(r'<a href="([^"/]+)/">[^<]+/</a>')


@dataclass(slots=True)
class PackageRecord:
    """One stanza from the CRAN PACKAGES index, normalized.

    The :attr:`raw` mapping keeps the verbatim values; :attr:`dependencies`
    is the parsed form used to build edges.
    """

    name: str
    version: str
    license: str | None = None
    published: str | None = None
    needs_compilation: str | None = None
    md5sum: str | None = None
    dependencies: dict[str, list[tuple[str, str | None]]] = field(default_factory=dict)
    raw: dict[str, str] = field(default_factory=dict)


def fetch_packages_index(
    url: str = CRAN_PACKAGES_URL,
    timeout: float = DEFAULT_TIMEOUT_SECONDS,
) -> str:
    """Download ``PACKAGES.gz`` and return the decompressed text."""
    response = requests.get(url, timeout=timeout, headers={"User-Agent": USER_AGENT})
    response.raise_for_status()
    return gzip.decompress(response.content).decode("utf-8", errors="replace")


def fetch_archived_names(
    url: str = CRAN_ARCHIVE_URL,
    timeout: float = DEFAULT_TIMEOUT_SECONDS,
) -> set[str]:
    """Return package names that have a directory under ``/Archive/``.

    The Apache directory listing exposes one ``<a href="NAME/">`` link per
    archived package. Packages that appear here but not in the current
    PACKAGES index are considered removed from CRAN.
    """
    response = requests.get(url, timeout=timeout, headers={"User-Agent": USER_AGENT})
    response.raise_for_status()
    return {match for match in _ARCHIVE_DIR_RE.findall(response.text)}


def parse_packages_index(text: str) -> list[PackageRecord]:
    """Tokenize the PACKAGES index into a list of :class:`PackageRecord`."""
    return [_parse_stanza(stanza) for stanza in _iter_stanzas(text) if stanza]


def _iter_stanzas(text: str) -> Iterable[str]:
    """Yield one stanza per blank-line-separated block."""
    buf: list[str] = []
    for line in text.splitlines():
        if line.strip() == "":
            if buf:
                yield "\n".join(buf)
                buf = []
            continue
        buf.append(line)
    if buf:
        yield "\n".join(buf)


def _fold_continuation_lines(stanza: str) -> dict[str, str]:
    """Collapse Debian-style continuation lines into a flat field map."""
    fields: dict[str, str] = {}
    current_key: str | None = None
    for line in stanza.split("\n"):
        if not line:
            continue
        if line[0] in (" ", "\t"):
            if current_key is None:
                continue
            fields[current_key] = fields[current_key] + " " + line.strip()
            continue
        head, _, value = line.partition(":")
        if not _:
            continue
        current_key = head.strip()
        fields[current_key] = value.strip()
    return fields


_DEP_TOKEN_RE = re.compile(r"^\s*([A-Za-z0-9_.]+)\s*(?:\(([^)]*)\))?\s*$")


def _parse_dependency_field(value: str) -> list[tuple[str, str | None]]:
    """Parse a dependency string such as ``"R (>= 4.0), Matrix, methods"``.

    Returns a list of ``(package_name, version_constraint_or_None)``.
    """
    parsed: list[tuple[str, str | None]] = []
    for token in value.split(","):
        token = token.strip()
        if not token:
            continue
        match = _DEP_TOKEN_RE.match(token)
        if not match:
            continue
        name = match.group(1)
        constraint = match.group(2)
        parsed.append((name, constraint.strip() if constraint else None))
    return parsed


def _parse_stanza(stanza: str) -> PackageRecord:
    fields = _fold_continuation_lines(stanza)
    name = fields.get("Package", "")
    version = fields.get("Version", "")
    deps: dict[str, list[tuple[str, str | None]]] = {}
    for key in DEPENDENCY_FIELDS:
        if key in fields:
            deps[key] = _parse_dependency_field(fields[key])
    return PackageRecord(
        name=name,
        version=version,
        license=fields.get("License"),
        published=fields.get("Published"),
        needs_compilation=fields.get("NeedsCompilation"),
        md5sum=fields.get("MD5sum"),
        dependencies=deps,
        raw=fields,
    )


__all__ = [
    "CRAN_PACKAGES_URL",
    "CRAN_ARCHIVE_URL",
    "DEPENDENCY_FIELDS",
    "PackageRecord",
    "fetch_packages_index",
    "fetch_archived_names",
    "parse_packages_index",
]
