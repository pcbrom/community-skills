"""Assemble the CRAN dependency graph and persist it to SQLite.

The in-memory representation is a :class:`networkx.MultiDiGraph` whose
nodes carry package metadata and whose edges carry the dependency type
(``Depends``, ``Imports``, ``LinkingTo``, ``Suggests``, ``Enhances``)
together with the optional version constraint.

The persistent representation is a SQLite database with two tables:

- ``packages`` (one row per node)
- ``dependencies`` (one row per edge)

Both representations are interchangeable through :func:`graph_to_sqlite`
and :func:`load_graph`.
"""
from __future__ import annotations

import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

import networkx as nx

from .deprecation import DeprecationFlag, classify_all
from .scrape import (
    DEPENDENCY_FIELDS,
    PackageRecord,
    fetch_archived_names,
    fetch_packages_index,
    parse_packages_index,
)

SCHEMA_VERSION = 1

_SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS packages (
    name TEXT PRIMARY KEY,
    version TEXT,
    license TEXT,
    published TEXT,
    needs_compilation TEXT,
    md5sum TEXT,
    status TEXT,
    is_deprecated INTEGER NOT NULL DEFAULT 0,
    is_orphaned INTEGER NOT NULL DEFAULT 0,
    deprecation_reason TEXT,
    months_since_update REAL,
    in_current_index INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS dependencies (
    from_package TEXT NOT NULL,
    to_package TEXT NOT NULL,
    dep_type TEXT NOT NULL,
    version_constraint TEXT,
    PRIMARY KEY (from_package, to_package, dep_type, version_constraint)
);
CREATE INDEX IF NOT EXISTS idx_dependencies_from ON dependencies(from_package);
CREATE INDEX IF NOT EXISTS idx_dependencies_to ON dependencies(to_package);
CREATE INDEX IF NOT EXISTS idx_packages_status ON packages(status);
"""


def build_graph(
    records: Iterable[PackageRecord],
    flags: dict[str, DeprecationFlag] | None = None,
    archived_only_names: set[str] | None = None,
) -> nx.MultiDiGraph:
    """Build a dependency :class:`MultiDiGraph` from parsed records.

    Edges are emitted from the consumer (``from_package``) to the provider
    (``to_package``), one edge per dependency-type/constraint pair.

    Provider nodes that are referenced but absent from ``records`` (for
    example, ``base`` packages or removed dependencies) are added with
    minimal metadata and ``in_current_index=False``.
    """
    records = list(records)
    by_name = {rec.name: rec for rec in records}
    archived_only_names = archived_only_names or set()
    if flags is None:
        flags = classify_all(records, archived_only_names=archived_only_names)

    g: nx.MultiDiGraph = nx.MultiDiGraph()
    for rec in records:
        flag = flags.get(rec.name)
        g.add_node(
            rec.name,
            version=rec.version,
            license=rec.license,
            published=rec.published,
            needs_compilation=rec.needs_compilation,
            md5sum=rec.md5sum,
            status=flag.status if flag else None,
            is_deprecated=bool(flag.is_deprecated) if flag else False,
            is_orphaned=bool(flag.is_orphaned) if flag else False,
            deprecation_reason=flag.reason if flag else None,
            months_since_update=flag.months_since_update if flag else None,
            in_current_index=True,
        )

    for rec in records:
        for dep_type in DEPENDENCY_FIELDS:
            for target, constraint in rec.dependencies.get(dep_type, []):
                if target not in g:
                    _add_external_node(g, target, archived_only_names)
                g.add_edge(rec.name, target, key=(dep_type, constraint),
                           dep_type=dep_type, version_constraint=constraint)
    return g


_BASE_OR_RECOMMENDED_NAMES = frozenset({
    "R", "base", "stats", "utils", "graphics", "grDevices",
    "methods", "tools", "datasets", "splines", "tcltk",
    "parallel", "compiler", "grid",
})


def _add_external_node(
    g: nx.MultiDiGraph,
    name: str,
    archived_only_names: set[str],
) -> None:
    """Add a referenced-but-absent node with minimal metadata.

    A base/recommended R package always wins over an /Archive/ name
    collision: when a CRAN stanza writes ``Imports: grid``, the intent is
    the base package shipped with R, not a homonymous archived CRAN
    package.
    """
    if name in _BASE_OR_RECOMMENDED_NAMES:
        status = "base_or_recommended"
        reason = "ships_with_r"
        is_deprecated = False
    elif name in archived_only_names:
        status = "strong_deprecated"
        reason = "removed_from_cran"
        is_deprecated = True
    else:
        status = "unknown"
        reason = "not_in_current_packages_index"
        is_deprecated = False
    g.add_node(
        name,
        version=None,
        license=None,
        published=None,
        needs_compilation=None,
        md5sum=None,
        status=status,
        is_deprecated=is_deprecated,
        is_orphaned=False,
        deprecation_reason=reason,
        months_since_update=None,
        in_current_index=False,
    )


def graph_to_sqlite(g: nx.MultiDiGraph, path: Path | str) -> Path:
    """Persist a graph to a SQLite database, replacing any existing file."""
    path = Path(path)
    if path.exists():
        path.unlink()
    path.parent.mkdir(parents=True, exist_ok=True)

    with sqlite3.connect(path) as conn:
        conn.executescript(_SCHEMA_SQL)
        conn.execute(
            "INSERT INTO meta(key, value) VALUES (?, ?)",
            ("schema_version", str(SCHEMA_VERSION)),
        )
        conn.execute(
            "INSERT INTO meta(key, value) VALUES (?, ?)",
            ("snapshot_taken_at", datetime.now(tz=timezone.utc).isoformat()),
        )
        conn.execute(
            "INSERT INTO meta(key, value) VALUES (?, ?)",
            ("node_count", str(g.number_of_nodes())),
        )
        conn.execute(
            "INSERT INTO meta(key, value) VALUES (?, ?)",
            ("edge_count", str(g.number_of_edges())),
        )

        conn.executemany(
            """
            INSERT OR REPLACE INTO packages
            (name, version, license, published, needs_compilation, md5sum,
             status, is_deprecated, is_orphaned, deprecation_reason,
             months_since_update, in_current_index)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                (
                    name,
                    data.get("version"),
                    data.get("license"),
                    data.get("published"),
                    data.get("needs_compilation"),
                    data.get("md5sum"),
                    data.get("status"),
                    int(bool(data.get("is_deprecated"))),
                    int(bool(data.get("is_orphaned"))),
                    data.get("deprecation_reason"),
                    data.get("months_since_update"),
                    int(bool(data.get("in_current_index"))),
                )
                for name, data in g.nodes(data=True)
            ),
        )

        conn.executemany(
            """
            INSERT OR REPLACE INTO dependencies
            (from_package, to_package, dep_type, version_constraint)
            VALUES (?, ?, ?, ?)
            """,
            (
                (
                    src,
                    dst,
                    data.get("dep_type"),
                    data.get("version_constraint"),
                )
                for src, dst, data in g.edges(data=True)
            ),
        )
        conn.commit()
    return path


def load_graph(path: Path | str) -> nx.MultiDiGraph:
    """Hydrate a graph from a SQLite snapshot produced by :func:`graph_to_sqlite`."""
    path = Path(path)
    if not path.is_file():
        raise FileNotFoundError(f"snapshot not found: {path}")
    g: nx.MultiDiGraph = nx.MultiDiGraph()
    with sqlite3.connect(path) as conn:
        conn.row_factory = sqlite3.Row
        for row in conn.execute("SELECT * FROM packages"):
            g.add_node(
                row["name"],
                version=row["version"],
                license=row["license"],
                published=row["published"],
                needs_compilation=row["needs_compilation"],
                md5sum=row["md5sum"],
                status=row["status"],
                is_deprecated=bool(row["is_deprecated"]),
                is_orphaned=bool(row["is_orphaned"]),
                deprecation_reason=row["deprecation_reason"],
                months_since_update=row["months_since_update"],
                in_current_index=bool(row["in_current_index"]),
            )
        for row in conn.execute("SELECT * FROM dependencies"):
            g.add_edge(
                row["from_package"],
                row["to_package"],
                key=(row["dep_type"], row["version_constraint"]),
                dep_type=row["dep_type"],
                version_constraint=row["version_constraint"],
            )
    return g


def build_snapshot(
    output_path: Path | str,
    *,
    fetch_archive: bool = True,
    now: datetime | None = None,
) -> Path:
    """End-to-end: download CRAN, classify, build graph, persist to SQLite."""
    text = fetch_packages_index()
    records = parse_packages_index(text)
    archive_names: set[str] = set()
    if fetch_archive:
        archive_names = fetch_archived_names()

    current_names = {rec.name for rec in records}
    archived_only = archive_names - current_names

    flags = classify_all(records, archived_only_names=archived_only, now=now)
    g = build_graph(records, flags=flags, archived_only_names=archived_only)
    return graph_to_sqlite(g, output_path)


__all__ = [
    "SCHEMA_VERSION",
    "build_graph",
    "build_snapshot",
    "graph_to_sqlite",
    "load_graph",
]
