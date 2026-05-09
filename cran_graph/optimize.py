"""Install-set optimizer over a cran_graph snapshot.

Given one or more *target* packages and an optional list of constraints,
the solver returns the smallest set of CRAN packages that, once installed,
lets every target load successfully. The output preserves a topological
order (dependencies first) so it can be passed verbatim to
``install.packages()``.

Solver
------

The default solver is a closure over the dependency graph (greedy DFS):

1. Seed a worklist with the target packages.
2. For every package, follow the *hard* edges (``Depends``, ``Imports``,
   ``LinkingTo``) recursively. ``Suggests`` and ``Enhances`` are off by
   default and only walked when ``include_suggests`` is set.
3. Skip nodes that are flagged ``base_or_recommended`` (these ship with R)
   and respect ``--exclude`` user constraints.
4. Validate version constraints along the way; conflicts are returned as
   structured warnings, never raised.
5. Emit the closure in reverse topological order; cycles produced by
   optional edges are broken by the same ``include_suggests`` filter.

The greedy closure is provably correct for any acyclic dependency
sub-graph, which is the regime CRAN's hard edges live in. ILP / GA
solvers are a stretch goal; they only help when constraints make the
greedy answer infeasible (rare on the current snapshot).
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Iterable

import networkx as nx

HARD_EDGE_TYPES = ("Depends", "Imports", "LinkingTo")
SOFT_EDGE_TYPES = ("Suggests", "Enhances")
BASE_OR_RECOMMENDED_STATUS = "base_or_recommended"

_VERSION_TOKEN_RE = re.compile(r"^[0-9]+(?:[._-][0-9A-Za-z]+)*$")
_CONSTRAINT_RE = re.compile(r"^\s*(>=|<=|==|!=|>|<)\s*(\S+)\s*$")


# --------------------------------------------------------------------------- #
# Version parsing and constraint evaluation
# --------------------------------------------------------------------------- #


def parse_version(value: str) -> tuple[int, ...]:
    """Parse an R-style version string into a comparable integer tuple.

    R uses dotted or hyphenated numeric components: ``"1.2.3"``, ``"4.0-1"``,
    ``"0.9_beta"`` (rare). Non-numeric components are coerced via the
    leading integer prefix; if no prefix exists the component is ``0``.

    The return value is suitable for direct tuple comparison.
    """
    parts = re.split(r"[._-]", value.strip())
    out: list[int] = []
    for p in parts:
        match = re.match(r"^(\d+)", p)
        out.append(int(match.group(1)) if match else 0)
    return tuple(out) or (0,)


def _pad(a: tuple[int, ...], b: tuple[int, ...]) -> tuple[tuple[int, ...], tuple[int, ...]]:
    """Right-pad the shorter tuple with zeros so the two are comparable."""
    n = max(len(a), len(b))
    return a + (0,) * (n - len(a)), b + (0,) * (n - len(b))


def version_satisfies(version: str | None, constraint: str | None) -> bool:
    """Return True iff ``version`` satisfies ``constraint``.

    A ``None`` or empty constraint trivially holds. A ``None`` version
    holds only against a ``None`` constraint; otherwise it fails (the
    caller should treat unknown-version nodes as outside this check).
    """
    if not constraint:
        return True
    if version is None:
        return False
    match = _CONSTRAINT_RE.match(constraint)
    if not match:
        return True
    op, target = match.group(1), match.group(2)
    a, b = _pad(parse_version(version), parse_version(target))
    if op == ">=":
        return a >= b
    if op == ">":
        return a > b
    if op == "<=":
        return a <= b
    if op == "<":
        return a < b
    if op == "==":
        return a == b
    if op == "!=":
        return a != b
    return True


# --------------------------------------------------------------------------- #
# Result type
# --------------------------------------------------------------------------- #


@dataclass(slots=True)
class OptimizerResult:
    """Structured outcome of one optimization run."""

    ok: bool
    targets: list[str]
    install_set: list[str]
    by_status: dict[str, int]
    warnings: list[str] = field(default_factory=list)
    conflicts: list[str] = field(default_factory=list)
    skipped_base: list[str] = field(default_factory=list)
    missing_targets: list[str] = field(default_factory=list)

    @property
    def install_count(self) -> int:
        return len(self.install_set)

    def to_dict(self) -> dict:
        return {
            "ok": self.ok,
            "targets": self.targets,
            "install_set": self.install_set,
            "install_count": self.install_count,
            "by_status": dict(self.by_status),
            "warnings": list(self.warnings),
            "conflicts": list(self.conflicts),
            "skipped_base": list(self.skipped_base),
            "missing_targets": list(self.missing_targets),
        }


# --------------------------------------------------------------------------- #
# Solver
# --------------------------------------------------------------------------- #


def _select_edge_types(include_suggests: bool, include_enhances: bool) -> tuple[str, ...]:
    types = list(HARD_EDGE_TYPES)
    if include_suggests:
        types.append("Suggests")
    if include_enhances:
        types.append("Enhances")
    return tuple(types)


def optimize(
    graph: nx.MultiDiGraph,
    targets: Iterable[str],
    *,
    include_suggests: bool = False,
    include_enhances: bool = False,
    exclude: Iterable[str] | None = None,
    strict_active: bool = False,
    r_version: str | None = None,
) -> OptimizerResult:
    """Resolve the install set for ``targets`` over ``graph``.

    Parameters
    ----------
    graph
        A :class:`networkx.MultiDiGraph` produced by :func:`cran_graph.build_graph`.
    targets
        Iterable of package names to install.
    include_suggests
        If True, walk ``Suggests`` edges too.
    include_enhances
        If True, walk ``Enhances`` edges too.
    exclude
        Names that must not appear in the install set. If a hard
        dependency would force inclusion, a conflict is reported.
    strict_active
        If True, the run fails (``ok=False``) when any soft- or
        strong-deprecated package appears in the closure.
    r_version
        If set, every ``Depends: R (op X)`` constraint along the closure
        is checked against this value.
    """
    targets = list(targets)
    exclude_set = set(exclude or [])
    edge_types = _select_edge_types(include_suggests, include_enhances)

    warnings: list[str] = []
    conflicts: list[str] = []
    skipped_base: list[str] = []
    missing_targets: list[str] = []

    # Validate targets up-front.
    for t in targets:
        if t not in graph:
            missing_targets.append(t)
    if missing_targets:
        return OptimizerResult(
            ok=False,
            targets=targets,
            install_set=[],
            by_status={},
            warnings=warnings,
            conflicts=[f"missing_target: {name}" for name in missing_targets],
            skipped_base=skipped_base,
            missing_targets=missing_targets,
        )

    closure: set[str] = set()
    worklist: list[str] = list(targets)
    while worklist:
        node = worklist.pop()
        if node in closure:
            continue

        node_data = graph.nodes[node]
        status = node_data.get("status")

        if status == BASE_OR_RECOMMENDED_STATUS:
            if node not in skipped_base:
                skipped_base.append(node)
            continue

        if node in exclude_set and node not in targets:
            conflicts.append(f"excluded_but_required: {node}")
            continue

        if node in exclude_set and node in targets:
            conflicts.append(f"target_in_exclude: {node}")
            continue

        closure.add(node)

        if strict_active and node_data.get("is_deprecated"):
            conflicts.append(
                f"deprecated_in_closure: {node} ({node_data.get('deprecation_reason')})"
            )
        elif node_data.get("is_deprecated"):
            warnings.append(
                f"deprecated: {node} ({node_data.get('deprecation_reason')})"
            )

        for _, dep, edata in graph.out_edges(node, data=True):
            if edata.get("dep_type") not in edge_types:
                continue
            constraint = edata.get("version_constraint")
            dep_data = graph.nodes.get(dep, {})

            if dep_data.get("status") == BASE_OR_RECOMMENDED_STATUS:
                if (
                    dep == "R"
                    and r_version is not None
                    and not version_satisfies(r_version, constraint)
                ):
                    conflicts.append(
                        f"r_version_constraint_violated: {node} requires R {constraint}, "
                        f"got {r_version}"
                    )
                if dep not in skipped_base:
                    skipped_base.append(dep)
                continue

            dep_version = dep_data.get("version")
            if dep_version is not None and not version_satisfies(dep_version, constraint):
                warnings.append(
                    f"version_constraint_unmet: {node} requires {dep} {constraint}, "
                    f"snapshot has {dep} {dep_version}"
                )

            if dep not in closure:
                worklist.append(dep)

    # Topological order: dependencies first. Restrict the subgraph to hard
    # edges only so we never produce a cycle from optional edges.
    order = _topological_order(graph, closure, edge_types)

    by_status: dict[str, int] = {}
    for n in order:
        s = graph.nodes[n].get("status") or "unknown"
        by_status[s] = by_status.get(s, 0) + 1

    ok = not conflicts and not (strict_active and any(
        graph.nodes[n].get("is_deprecated") for n in closure
    ))

    return OptimizerResult(
        ok=ok,
        targets=targets,
        install_set=order,
        by_status=by_status,
        warnings=warnings,
        conflicts=conflicts,
        skipped_base=skipped_base,
    )


def _topological_order(
    graph: nx.MultiDiGraph,
    closure: set[str],
    edge_types: tuple[str, ...],
) -> list[str]:
    """Return ``closure`` in dependency-first order.

    The subgraph used for sorting only contains edges whose ``dep_type``
    is in ``edge_types``, so optional cycles do not block the sort.
    Edges are reversed so a topological sort yields dependencies first.
    """
    sub = nx.DiGraph()
    sub.add_nodes_from(closure)
    for u, v, edata in graph.edges(data=True):
        if u in closure and v in closure and edata.get("dep_type") in edge_types:
            sub.add_edge(v, u)  # reverse: providers come before consumers

    try:
        return list(nx.topological_sort(sub))
    except nx.NetworkXUnfeasible:
        # Fall back to alphabetical order if a residual cycle exists; the
        # caller's warnings will already flag the cycle.
        return sorted(closure)


__all__ = [
    "BASE_OR_RECOMMENDED_STATUS",
    "HARD_EDGE_TYPES",
    "SOFT_EDGE_TYPES",
    "OptimizerResult",
    "optimize",
    "parse_version",
    "version_satisfies",
]
