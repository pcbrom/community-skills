"""Command-line entry point for cran_graph.

Usage:

.. code-block:: shell

    cran-graph build --output data/cran_snapshot_2026-05-09.sqlite
    cran-graph stats data/cran_snapshot_2026-05-09.sqlite
    cran-graph optimize ggplot2 --snapshot data/cran_snapshot_2026-05-09.sqlite
    cran-graph optimize shiny dplyr --r-version 4.0 --strict-active
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from datetime import date
from pathlib import Path

from .build import build_snapshot, load_graph
from .optimize import optimize


def _cmd_build(args: argparse.Namespace) -> int:
    output = Path(args.output)
    print(f"[cran-graph] downloading CRAN PACKAGES index", file=sys.stderr)
    build_snapshot(output, fetch_archive=not args.no_archive)
    g = load_graph(output)
    print(
        f"[cran-graph] wrote {output}: "
        f"nodes={g.number_of_nodes()}, edges={g.number_of_edges()}",
        file=sys.stderr,
    )
    return 0


def _cmd_stats(args: argparse.Namespace) -> int:
    g = load_graph(args.snapshot)
    statuses: Counter[str] = Counter()
    for _, data in g.nodes(data=True):
        statuses[data.get("status") or "unknown"] += 1
    edge_types: Counter[str] = Counter()
    for _, _, data in g.edges(data=True):
        edge_types[data.get("dep_type") or "unknown"] += 1

    print(f"nodes: {g.number_of_nodes()}")
    print(f"edges: {g.number_of_edges()}")
    print("status:")
    for status, count in sorted(statuses.items(), key=lambda kv: -kv[1]):
        print(f"  {status}: {count}")
    print("edge type:")
    for dtype, count in sorted(edge_types.items(), key=lambda kv: -kv[1]):
        print(f"  {dtype}: {count}")
    return 0


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="cran-graph",
        description="Build and inspect CRAN dependency-graph snapshots.",
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_build = sub.add_parser("build", help="Download CRAN and write a SQLite snapshot.")
    p_build.add_argument(
        "--output",
        "-o",
        default=f"data/cran_snapshot_{date.today().isoformat()}.sqlite",
        help="Output SQLite path (default: data/cran_snapshot_<TODAY>.sqlite).",
    )
    p_build.add_argument(
        "--no-archive",
        action="store_true",
        help="Skip the /Archive/ scrape (faster; loses removed-from-CRAN flag).",
    )
    p_build.set_defaults(func=_cmd_build)

    p_stats = sub.add_parser("stats", help="Print summary statistics for a snapshot.")
    p_stats.add_argument("snapshot", help="Path to a SQLite snapshot.")
    p_stats.set_defaults(func=_cmd_stats)

    p_opt = sub.add_parser("optimize", help="Resolve the install set for one or more targets.")
    p_opt.add_argument("targets", nargs="+", help="One or more package names to install.")
    p_opt.add_argument(
        "--snapshot",
        "-s",
        default=f"data/cran_snapshot_{date.today().isoformat()}.sqlite",
        help="Path to a SQLite snapshot (default: today's data/cran_snapshot_<TODAY>.sqlite).",
    )
    p_opt.add_argument(
        "--with-suggests",
        action="store_true",
        help="Walk Suggests edges in addition to Depends/Imports/LinkingTo.",
    )
    p_opt.add_argument(
        "--with-enhances",
        action="store_true",
        help="Walk Enhances edges.",
    )
    p_opt.add_argument(
        "--exclude",
        "-x",
        action="append",
        default=[],
        help="Package name to exclude. Can be passed multiple times.",
    )
    p_opt.add_argument(
        "--strict-active",
        action="store_true",
        help="Fail (ok=false) if any soft- or strong-deprecated package appears in the closure.",
    )
    p_opt.add_argument(
        "--r-version",
        default=None,
        help="R version available locally; checked against `Depends: R (op X)` constraints.",
    )
    p_opt.add_argument(
        "--json",
        action="store_true",
        help="Emit the structured result as a single JSON object on stdout.",
    )
    p_opt.set_defaults(func=_cmd_optimize)

    p_plot = sub.add_parser("plot", help="Render the install closure of one or more targets to PNG.")
    p_plot.add_argument("targets", nargs="+", help="One or more package names.")
    p_plot.add_argument("--snapshot", "-s",
                        default=f"data/cran_snapshot_{date.today().isoformat()}.sqlite",
                        help="Path to a SQLite snapshot.")
    p_plot.add_argument("--output", "-o", required=True, help="Output PNG path.")
    p_plot.add_argument("--with-suggests", action="store_true",
                        help="Walk Suggests edges as well.")
    p_plot.add_argument("--with-base", action="store_true",
                        help="Include base / recommended R packages in the rendering.")
    p_plot.add_argument("--dpi", type=int, default=200, help="Output DPI (default 200).")
    p_plot.add_argument("--seed", type=int, default=0, help="Layout RNG seed.")
    p_plot.add_argument("--title", default=None, help="Optional figure title override.")
    p_plot.set_defaults(func=_cmd_plot)

    return parser


def _cmd_plot(args: argparse.Namespace) -> int:
    from .viz import plot_closure  # lazy import: matplotlib is optional
    g = load_graph(args.snapshot)
    out = plot_closure(
        g,
        args.targets,
        args.output,
        include_suggests=args.with_suggests,
        include_base=args.with_base,
        dpi=args.dpi,
        seed=args.seed,
        title=args.title,
    )
    print(f"[cran-graph] wrote {out}", file=sys.stderr)
    return 0


def _cmd_optimize(args: argparse.Namespace) -> int:
    g = load_graph(args.snapshot)
    result = optimize(
        g,
        args.targets,
        include_suggests=args.with_suggests,
        include_enhances=args.with_enhances,
        exclude=args.exclude,
        strict_active=args.strict_active,
        r_version=args.r_version,
    )
    if args.json:
        json.dump(result.to_dict(), sys.stdout, indent=2)
        sys.stdout.write("\n")
        return 0 if result.ok else 2

    print(f"targets: {' '.join(result.targets)}")
    print(f"install_count: {result.install_count}")
    print(f"ok: {result.ok}")
    if result.skipped_base:
        print(f"skipped_base ({len(result.skipped_base)}): {' '.join(sorted(result.skipped_base))}")
    if result.by_status:
        print("by_status:")
        for status, count in sorted(result.by_status.items(), key=lambda kv: -kv[1]):
            print(f"  {status}: {count}")
    if result.warnings:
        print(f"warnings ({len(result.warnings)}):")
        for w in result.warnings[:20]:
            print(f"  {w}")
        if len(result.warnings) > 20:
            print(f"  ... {len(result.warnings) - 20} more")
    if result.conflicts:
        print(f"conflicts ({len(result.conflicts)}):")
        for c in result.conflicts:
            print(f"  {c}")
    print("install_set:")
    for n in result.install_set:
        print(f"  {n}")
    return 0 if result.ok else 2


def main(argv: list[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
