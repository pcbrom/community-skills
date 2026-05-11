"""Extract DESCRIPTION + NAMESPACE + selected Rd files from a CRAN tarball.

Each CRAN source tarball contains:

- ``<pkg>/DESCRIPTION``: full canonical metadata (Title, Description, Author,
  Maintainer, License, URL, BugReports, ...).
- ``<pkg>/NAMESPACE``: ``export(name)`` directives plus S3/S4 method
  declarations.
- ``<pkg>/man/*.Rd``: per-function manual pages with ``\\name``, ``\\title``,
  ``\\description``, and ``\\examples`` blocks.

This module downloads a tarball, parses the relevant pieces, and returns
a structured dict suitable for the SKILL.md generator.

The Rd parser is deliberately heuristic: full Rd syntax is non-trivial,
but for the purpose of extracting ``\\name``, ``\\title``,
``\\description`` (truncated), and one ``\\examples`` block per file, a
brace-balanced regex is sufficient.
"""
from __future__ import annotations

import io
import re
import tarfile
from dataclasses import dataclass, field
from typing import Iterable

import requests

CRAN_TARBALL_URL = "https://cran.r-project.org/src/contrib/{package}_{version}.tar.gz"
DEFAULT_TIMEOUT_SECONDS = 60
USER_AGENT = "community-skills/extract_package_metadata (+https://github.com/pcbrom/community-skills)"

MAX_DESCRIPTION_CHARS = 1_500
MAX_TITLE_CHARS = 200
MAX_RD_EXAMPLE_CHARS = 800
MAX_RD_FILES = 4


@dataclass(slots=True)
class FunctionDoc:
    name: str
    title: str
    description: str
    example: str
    arguments: list[tuple[str, str]] = field(default_factory=list)


@dataclass(slots=True)
class PackageMetadata:
    package: str
    version: str
    title: str | None = None
    description: str | None = None
    license: str | None = None
    author: str | None = None
    maintainer: str | None = None
    url: str | None = None
    bug_reports: str | None = None
    imports: list[str] = field(default_factory=list)
    depends: list[str] = field(default_factory=list)
    exported_functions: list[str] = field(default_factory=list)
    s3_methods: list[str] = field(default_factory=list)
    function_docs: list[FunctionDoc] = field(default_factory=list)


# --------------------------------------------------------------------------- #
# Tarball download
# --------------------------------------------------------------------------- #


def fetch_tarball(
    package: str,
    version: str,
    timeout: float = DEFAULT_TIMEOUT_SECONDS,
    *,
    max_attempts: int = 3,
) -> bytes:
    """Download the source tarball for ``package`` at ``version``.

    Retries up to ``max_attempts`` times on connection / chunked-encoding
    failures, with a short backoff. CRAN occasionally truncates large
    tarballs mid-stream; the loop covers that without burdening the
    caller.
    """
    url = CRAN_TARBALL_URL.format(package=package, version=version)
    last_exc: Exception | None = None
    for attempt in range(1, max_attempts + 1):
        try:
            response = requests.get(
                url, timeout=timeout, headers={"User-Agent": USER_AGENT},
            )
            response.raise_for_status()
            return response.content
        except (requests.exceptions.ChunkedEncodingError,
                requests.exceptions.ConnectionError,
                requests.exceptions.ReadTimeout) as exc:
            last_exc = exc
            if attempt < max_attempts:
                import time as _time
                _time.sleep(2 * attempt)
                continue
    assert last_exc is not None
    raise last_exc


# --------------------------------------------------------------------------- #
# DESCRIPTION parser (Debian-style, same shape as PACKAGES.gz stanzas)
# --------------------------------------------------------------------------- #


def _fold_description(text: str) -> dict[str, str]:
    """Collapse continuation lines into a flat field map."""
    fields: dict[str, str] = {}
    current: str | None = None
    for line in text.split("\n"):
        if not line:
            continue
        if line[0] in (" ", "\t"):
            if current is None:
                continue
            fields[current] = fields[current] + " " + line.strip()
            continue
        head, sep, value = line.partition(":")
        if not sep:
            continue
        current = head.strip()
        fields[current] = value.strip()
    return fields


_DEP_TOKEN_RE = re.compile(r"^\s*([A-Za-z0-9_.]+)")


def _parse_dep_list(value: str | None) -> list[str]:
    if not value:
        return []
    out: list[str] = []
    for token in value.split(","):
        match = _DEP_TOKEN_RE.match(token)
        if match:
            out.append(match.group(1))
    return out


# --------------------------------------------------------------------------- #
# NAMESPACE parser
# --------------------------------------------------------------------------- #


_EXPORT_RE = re.compile(r"^\s*export\s*\(\s*([^)]+?)\s*\)", re.MULTILINE)
_EXPORT_PATTERN_RE = re.compile(r"^\s*exportPattern\s*\(", re.MULTILINE)
_S3METHOD_RE = re.compile(r"^\s*S3method\s*\(\s*([^,]+)\s*,\s*([^)]+)\s*\)", re.MULTILINE)


def parse_namespace(text: str) -> tuple[list[str], list[str], bool]:
    """Return ``(exports, s3_methods, has_export_pattern)``.

    Multiple comma-separated names within a single ``export()`` are split.
    Quoted names have their quotes stripped.
    """
    exports: list[str] = []
    for match in _EXPORT_RE.finditer(text):
        for raw in match.group(1).split(","):
            name = raw.strip().strip('"').strip("'")
            if name:
                exports.append(name)

    s3: list[str] = []
    for match in _S3METHOD_RE.finditer(text):
        generic = match.group(1).strip().strip('"').strip("'")
        cls = match.group(2).strip().strip('"').strip("'")
        s3.append(f"{generic}.{cls}")

    has_pattern = bool(_EXPORT_PATTERN_RE.search(text))
    return exports, s3, has_pattern


# --------------------------------------------------------------------------- #
# Rd parser: balanced brace extraction for \name, \title, \description, \examples
# --------------------------------------------------------------------------- #


def _read_balanced_braces(text: str, start_idx: int) -> tuple[str, int] | None:
    """Read a balanced ``{...}`` block starting at ``start_idx``.

    Returns ``(content, end_idx_after_close)`` or ``None`` if the block is
    not balanced (truncated file, malformed Rd).
    """
    if start_idx >= len(text) or text[start_idx] != "{":
        return None
    depth = 0
    i = start_idx
    while i < len(text):
        c = text[i]
        if c == "\\" and i + 1 < len(text):
            i += 2
            continue
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return text[start_idx + 1: i], i + 1
        i += 1
    return None


def _extract_rd_field(text: str, tag: str) -> str | None:
    """Find ``\\tag{...}`` and return the inner text, or None."""
    needle = f"\\{tag}"
    idx = text.find(needle)
    if idx == -1:
        return None
    open_brace = text.find("{", idx)
    if open_brace == -1:
        return None
    block = _read_balanced_braces(text, open_brace)
    if not block:
        return None
    return block[0].strip()


def parse_rd(text: str) -> FunctionDoc | None:
    """Extract a single :class:`FunctionDoc` from Rd text."""
    name = _extract_rd_field(text, "name") or ""
    title = (_extract_rd_field(text, "title") or "").strip()
    description = (_extract_rd_field(text, "description") or "").strip()
    example = (_extract_rd_field(text, "examples") or "").strip()
    arguments = _extract_rd_arguments(text)
    if not name:
        return None
    return FunctionDoc(
        name=name.strip(),
        title=_truncate(title, MAX_TITLE_CHARS),
        description=_truncate(description, MAX_DESCRIPTION_CHARS),
        example=_truncate(example, MAX_RD_EXAMPLE_CHARS),
        arguments=arguments,
    )


_ITEM_HEAD_RE = re.compile(r"\\item\s*\{")


def _extract_rd_arguments(text: str) -> list[tuple[str, str]]:
    """Parse the ``\\arguments{ \\item{name}{desc} ... }`` block.

    Returns a list of ``(argument_name, short_description)`` pairs in
    declaration order. ``\\item{x, y}{...}`` produces two entries
    sharing the same description. Descriptions are truncated to keep
    the downstream prompt small.
    """
    block = _extract_rd_field(text, "arguments")
    if not block:
        return []
    out: list[tuple[str, str]] = []
    i = 0
    n = len(block)
    while i < n:
        m = _ITEM_HEAD_RE.search(block, i)
        if not m:
            break
        # Position of the first '{' that opens \item{...}
        open_brace = m.end() - 1
        head = _read_balanced_braces(block, open_brace)
        if head is None:
            i = m.end()
            continue
        names_text, after_names = head
        j = after_names
        while j < n and block[j].isspace():
            j += 1
        if j >= n or block[j] != "{":
            i = j
            continue
        body = _read_balanced_braces(block, j)
        if body is None:
            i = j + 1
            continue
        desc_text, after_body = body
        for raw_name in names_text.split(","):
            arg_name = raw_name.strip().strip('"').strip("'")
            if arg_name:
                out.append((arg_name, _truncate(desc_text.strip(), 240)))
        i = after_body
    return out


def _truncate(s: str, n: int) -> str:
    if len(s) <= n:
        return s
    return s[: n - 3].rstrip() + "..."


# --------------------------------------------------------------------------- #
# Tarball walker
# --------------------------------------------------------------------------- #


def _select_rd_files(
    rd_payloads: dict[str, str],
    exported_functions: list[str],
    max_files: int = MAX_RD_FILES,
) -> Iterable[str]:
    """Pick up to ``max_files`` Rd files: prefer ones whose stem matches an
    exported function name. Fall back to alphabetical order."""
    chosen: list[str] = []
    by_stem: dict[str, str] = {}
    for path, _ in rd_payloads.items():
        stem = path.rsplit("/", 1)[-1]
        if stem.endswith(".Rd"):
            by_stem[stem[:-3]] = path
    for fn in exported_functions:
        if fn in by_stem and by_stem[fn] not in chosen:
            chosen.append(by_stem[fn])
        if len(chosen) >= max_files:
            return chosen
    for path in sorted(rd_payloads):
        if path not in chosen:
            chosen.append(path)
        if len(chosen) >= max_files:
            break
    return chosen


def extract_from_tarball_bytes(
    raw: bytes,
    package: str,
    version: str,
) -> PackageMetadata:
    """Parse a CRAN source tarball and produce :class:`PackageMetadata`.

    Top-level package files only: a CRAN tarball can ship multiple
    ``DESCRIPTION``, ``NAMESPACE`` and ``man/*.Rd`` files for in-tree test
    fixtures under ``inst/tinytest/`` and similar. The real package metadata
    lives at ``<package>/<file>`` and ``<package>/man/<*.Rd>``; everything
    deeper is filtered out.
    """
    md = PackageMetadata(package=package, version=version)
    rd_payloads: dict[str, str] = {}

    desc_path = f"{package}/DESCRIPTION"
    ns_path = f"{package}/NAMESPACE"
    man_prefix = f"{package}/man/"

    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar:
        for member in tar.getmembers():
            if not member.isfile():
                continue
            name = member.name
            try:
                payload = tar.extractfile(member).read().decode("utf-8", errors="replace")
            except Exception:
                continue
            if name == desc_path:
                _populate_from_description(md, payload)
            elif name == ns_path:
                exports, s3, _ = parse_namespace(payload)
                md.exported_functions = exports
                md.s3_methods = s3
            elif (
                name.startswith(man_prefix)
                and name.endswith(".Rd")
                and "/" not in name[len(man_prefix):]
            ):
                rd_payloads[name] = payload

    chosen = list(_select_rd_files(rd_payloads, md.exported_functions))
    docs: list[FunctionDoc] = []
    for path in chosen:
        doc = parse_rd(rd_payloads[path])
        if doc:
            docs.append(doc)
    md.function_docs = docs
    return md


def _populate_from_description(md: PackageMetadata, text: str) -> None:
    fields = _fold_description(text)
    md.title = _truncate(fields.get("Title", "") or "", MAX_TITLE_CHARS) or None
    md.description = _truncate(fields.get("Description", "") or "", MAX_DESCRIPTION_CHARS) or None
    md.license = fields.get("License")
    md.author = fields.get("Author")
    md.maintainer = fields.get("Maintainer")
    md.url = fields.get("URL")
    md.bug_reports = fields.get("BugReports")
    md.imports = _parse_dep_list(fields.get("Imports"))
    md.depends = _parse_dep_list(fields.get("Depends"))


def fetch_and_extract(package: str, version: str) -> PackageMetadata:
    """Convenience: download the tarball and run :func:`extract_from_tarball_bytes`."""
    raw = fetch_tarball(package, version)
    return extract_from_tarball_bytes(raw, package, version)


def metadata_to_dict(md: PackageMetadata) -> dict:
    return {
        "package": md.package,
        "version": md.version,
        "title": md.title,
        "description": md.description,
        "license": md.license,
        "author": md.author,
        "maintainer": md.maintainer,
        "url": md.url,
        "bug_reports": md.bug_reports,
        "imports": list(md.imports),
        "depends": list(md.depends),
        "exported_functions": list(md.exported_functions),
        "s3_methods": list(md.s3_methods),
        "function_docs": [
            {
                "name": d.name,
                "title": d.title,
                "description": d.description,
                "example": d.example,
                "arguments": [list(a) for a in d.arguments],
            }
            for d in md.function_docs
        ],
    }


__all__ = [
    "FunctionDoc",
    "PackageMetadata",
    "extract_from_tarball_bytes",
    "fetch_and_extract",
    "fetch_tarball",
    "metadata_to_dict",
    "parse_namespace",
    "parse_rd",
]
