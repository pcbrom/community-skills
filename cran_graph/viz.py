"""Render the install closure of one or more targets as a PNG figure.

The figure is intended as a single readable artefact: nodes coloured by
deprecation status, target nodes highlighted, edges thin and undirected
in appearance to keep visual noise low. Layout uses Kamada-Kawai for
small closures and a sparse spring layout for larger ones.

This module is intentionally optional: it imports ``matplotlib`` at call
time so that ``import cran_graph`` stays cheap when the user only needs
the SQLite snapshot or the optimizer.
"""
from __future__ import annotations

from pathlib import Path
from typing import Iterable

import networkx as nx

from .optimize import HARD_EDGE_TYPES, optimize

STATUS_COLORS: dict[str, str] = {
    "active": "#1b9e77",
    "stale": "#d4a017",
    "soft_deprecated": "#e6550d",
    "strong_deprecated": "#a50f15",
    "base_or_recommended": "#7f7f7f",
    "unknown": "#999999",
}
TARGET_RING_COLOR = "#0b0b0b"


def plot_closure(
    graph: nx.MultiDiGraph,
    targets: list[str] | tuple[str, ...] | str,
    output_path: Path | str,
    *,
    include_suggests: bool = False,
    include_base: bool = False,
    figsize: tuple[float, float] = (12.0, 9.0),
    dpi: int = 200,
    title: str | None = None,
    seed: int = 0,
) -> Path:
    """Render the install closure of ``targets`` to ``output_path`` (PNG).

    Parameters
    ----------
    graph
        A :class:`networkx.MultiDiGraph` produced by
        :func:`cran_graph.build_graph` or hydrated by
        :func:`cran_graph.load_graph`.
    targets
        One package name or a list of names. The closure is the union of
        each target's reachable set under hard edges
        (``Depends`` / ``Imports`` / ``LinkingTo``).
    output_path
        Destination PNG path.
    include_suggests
        Walk ``Suggests`` edges as well. Default false (matches the
        optimizer's default).
    include_base
        Include base or recommended R packages (R itself, ``stats``,
        ``utils`` and so on) in the rendering. Default false because
        these nodes inflate the graph without changing the install set.
    figsize, dpi
        Standard matplotlib figure parameters.
    title
        Optional title; defaults to ``Install closure of <targets>``.
    seed
        Layout RNG seed for reproducibility.
    """
    import matplotlib  # noqa: WPS433  intentional lazy import
    matplotlib.use("Agg")
    import matplotlib.lines as mlines
    import matplotlib.patches as mpatches
    import matplotlib.pyplot as plt

    if isinstance(targets, str):
        targets = [targets]
    targets = list(targets)

    result = optimize(graph, targets, include_suggests=include_suggests)
    closure = list(result.install_set)
    if not include_base:
        closure = [n for n in closure if graph.nodes[n].get("status") != "base_or_recommended"]

    if not closure:
        raise ValueError(f"empty closure for targets={targets}")

    sub = _project_subgraph(graph, closure, include_suggests=include_suggests)
    pos = _layout(sub, seed=seed)

    fig, ax = plt.subplots(figsize=figsize)
    ax.set_axis_off()

    target_set = set(targets)
    node_colors = [STATUS_COLORS.get(graph.nodes[n].get("status") or "unknown", "#777777")
                   for n in sub.nodes()]
    node_sizes = [620 if n in target_set else 220 for n in sub.nodes()]
    edge_colors = ["#bdbdbd" for _ in sub.edges()]

    nx.draw_networkx_edges(sub, pos, ax=ax, edge_color=edge_colors,
                           arrows=False, width=0.6, alpha=0.6)
    nx.draw_networkx_nodes(sub, pos, ax=ax,
                           node_color=node_colors, node_size=node_sizes,
                           linewidths=[1.6 if n in target_set else 0.4 for n in sub.nodes()],
                           edgecolors=[TARGET_RING_COLOR if n in target_set else "white"
                                       for n in sub.nodes()])

    label_threshold = 60
    if len(sub) <= label_threshold:
        labels = {n: n for n in sub.nodes()}
    else:
        # For large closures, label only targets, hubs (top in-degree),
        # and any deprecated node.
        deg = dict(sub.degree())
        hubs = sorted(deg, key=deg.get, reverse=True)[: max(8, len(sub) // 12)]
        deprecated = [n for n in sub.nodes() if graph.nodes[n].get("is_deprecated")]
        labels = {n: n for n in set(target_set) | set(hubs) | set(deprecated)}
    nx.draw_networkx_labels(sub, pos, labels=labels, ax=ax,
                            font_size=8, font_color="#111111")

    ax.set_title(title or _default_title(targets, sub),
                 fontsize=12, loc="left", pad=10)

    legend_handles = [
        mpatches.Patch(color=color, label=status)
        for status, color in STATUS_COLORS.items()
        if any(graph.nodes[n].get("status") == status for n in sub.nodes())
    ]
    legend_handles.append(
        mlines.Line2D([], [], marker="o", linestyle="None",
                      markerfacecolor="#ffffff",
                      markeredgecolor=TARGET_RING_COLOR,
                      markeredgewidth=1.6, markersize=10,
                      label="target")
    )
    ax.legend(handles=legend_handles, loc="lower right",
              frameon=False, fontsize=8, ncol=2)

    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output_path, dpi=dpi, bbox_inches="tight")
    plt.close(fig)
    return output_path


def _project_subgraph(
    graph: nx.MultiDiGraph,
    nodes: list[str],
    *,
    include_suggests: bool,
) -> nx.DiGraph:
    """Project the multidigraph to a simple directed graph over ``nodes``,
    keeping only the edge types we want to render."""
    keep_types = set(HARD_EDGE_TYPES)
    if include_suggests:
        keep_types.add("Suggests")
    sub = nx.DiGraph()
    sub.add_nodes_from(nodes)
    nodeset = set(nodes)
    for u, v, data in graph.edges(data=True):
        if u in nodeset and v in nodeset and data.get("dep_type") in keep_types:
            sub.add_edge(u, v)
    return sub


def _layout(sub: nx.DiGraph, seed: int) -> dict:
    """Layered layout for dependency graphs.

    Edges in the optimizer projection point ``consumer -> provider``.
    A topological-generation layering puts providers (deepest deps)
    at the top of the figure and consumers (the targets) at the
    bottom, which matches the way an installer thinks about the set.

    For a closure with a residual cycle (rare; happens only when
    ``include_suggests=True`` produced one), fall back to the spring
    layout so we never raise.
    """
    try:
        generations = list(nx.topological_generations(sub))
    except nx.NetworkXUnfeasible:
        n = sub.number_of_nodes()
        return nx.spring_layout(sub, k=1.8 / max(1.0, n ** 0.5),
                                iterations=300, seed=seed)

    if not generations:
        return {}

    pos: dict[str, tuple[float, float]] = {}
    n_layers = len(generations)
    for layer_idx, gen in enumerate(generations):
        members = sorted(gen)
        n_in_layer = max(1, len(members))
        for i, node in enumerate(members):
            x = (i + 0.5) / n_in_layer
            y = (n_layers - 1 - layer_idx)
            pos[node] = (x, y)
    return pos


def _default_title(targets: Iterable[str], sub: nx.DiGraph) -> str:
    targets = list(targets)
    if len(targets) == 1:
        return (
            f"Install closure of {targets[0]}: "
            f"{sub.number_of_nodes()} packages, {sub.number_of_edges()} edges"
        )
    joined = ", ".join(targets)
    return (
        f"Install closure of {joined}: "
        f"{sub.number_of_nodes()} packages, {sub.number_of_edges()} edges"
    )


__all__ = ["plot_closure", "STATUS_COLORS"]
