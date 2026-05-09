"""cran_graph: a queryable dependency graph for the CRAN ecosystem.

The package builds a snapshot of every currently available CRAN package
together with its declared dependencies (``Depends``, ``Imports``,
``LinkingTo``, ``Suggests``, ``Enhances``) and machine-readable deprecation
flags. The graph is persisted to SQLite and rehydrated as a
:class:`networkx.MultiDiGraph`.

Public entry points
-------------------

- :func:`build_snapshot` downloads CRAN, classifies records, and writes
  the SQLite snapshot in one call. Used by the ``cran-graph`` CLI.
- :func:`load_graph` hydrates a previously written snapshot.
- :func:`build_graph` assembles a graph from already-parsed records,
  useful for tests and offline pipelines.

Example
-------

.. code-block:: python

    from cran_graph import build_snapshot, load_graph

    build_snapshot("data/cran_snapshot_2026-05-09.sqlite")
    g = load_graph("data/cran_snapshot_2026-05-09.sqlite")
    print(g.number_of_nodes(), g.number_of_edges())
"""
from __future__ import annotations

from .build import (
    SCHEMA_VERSION,
    build_graph,
    build_snapshot,
    graph_to_sqlite,
    load_graph,
)
from .deprecation import (
    DeprecationFlag,
    classify,
    classify_all,
)
from .optimize import (
    OptimizerResult,
    optimize,
    parse_version,
    version_satisfies,
)
from .scrape import (
    PackageRecord,
    fetch_archived_names,
    fetch_packages_index,
    parse_packages_index,
)

__version__ = "0.1.0"

__all__ = [
    "SCHEMA_VERSION",
    "DeprecationFlag",
    "OptimizerResult",
    "PackageRecord",
    "build_graph",
    "build_snapshot",
    "classify",
    "classify_all",
    "fetch_archived_names",
    "fetch_packages_index",
    "graph_to_sqlite",
    "load_graph",
    "optimize",
    "parse_packages_index",
    "parse_version",
    "version_satisfies",
]
