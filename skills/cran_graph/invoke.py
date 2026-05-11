#!/usr/bin/env python3
"""cran_graph skill dispatcher.

Reads one JSON object from stdin, routes on the `fn` field, calls the
matching cran_graph function, writes one JSON object to stdout.
Errors come back as ``{"ok": false, "error": "..."}`` with non-zero
exit code.
"""
from __future__ import annotations

import json
import sys
import traceback
from collections import Counter
from pathlib import Path


def emit_ok(fn_name: str, result) -> None:
    sys.stdout.write(json.dumps({"ok": True, "fn": fn_name, "result": result},
                                default=str))
    sys.stdout.write("\n")


def emit_error(message: str, fn_name: str | None = None, code: int = 1) -> None:
    payload: dict = {"ok": False, "error": message}
    if fn_name is not None:
        payload["fn"] = fn_name
    sys.stdout.write(json.dumps(payload))
    sys.stdout.write("\n")
    sys.exit(code)


def require_field(name: str, payload: dict, fn_name: str):
    if name not in payload or payload[name] in (None, ""):
        emit_error(f"Field `{name}` is required for fn={fn_name}.", fn_name)
    return payload[name]


def handle_build_snapshot(payload: dict) -> dict:
    from cran_graph import build_snapshot, load_graph
    output_path = Path(require_field("output_path", payload, "build_snapshot"))
    fetch_archive = bool(payload.get("fetch_archive", True))
    written = build_snapshot(output_path, fetch_archive=fetch_archive)
    g = load_graph(written)
    return {
        "output_path": str(written),
        "node_count": g.number_of_nodes(),
        "edge_count": g.number_of_edges(),
    }


def handle_stats(payload: dict) -> dict:
    from cran_graph import load_graph
    snap = Path(require_field("snapshot", payload, "stats"))
    g = load_graph(snap)
    statuses: Counter = Counter()
    for _, data in g.nodes(data=True):
        statuses[data.get("status") or "unknown"] += 1
    edge_types: Counter = Counter()
    for _, _, data in g.edges(data=True):
        edge_types[data.get("dep_type") or "unknown"] += 1
    return {
        "node_count": g.number_of_nodes(),
        "edge_count": g.number_of_edges(),
        "by_status": dict(statuses),
        "by_edge_type": dict(edge_types),
    }


def handle_optimize(payload: dict) -> dict:
    from cran_graph import load_graph, optimize
    snap = Path(require_field("snapshot", payload, "optimize"))
    targets = require_field("targets", payload, "optimize")
    if not isinstance(targets, list) or not targets:
        emit_error("Field `targets` must be a non-empty list of strings.", "optimize")
    g = load_graph(snap)
    result = optimize(
        g,
        targets,
        include_suggests=bool(payload.get("include_suggests", False)),
        include_enhances=bool(payload.get("include_enhances", False)),
        exclude=payload.get("exclude") or [],
        strict_active=bool(payload.get("strict_active", False)),
        r_version=payload.get("r_version"),
    )
    return result.to_dict()


def handle_plot_closure(payload: dict) -> dict:
    try:
        from cran_graph import load_graph
        from cran_graph.viz import plot_closure
    except ImportError as exc:
        emit_error(
            f"plot_closure requires matplotlib. Install via "
            f"`pip install community-skills[viz]`. (import error: {exc})",
            "plot_closure",
        )
    snap = Path(require_field("snapshot", payload, "plot_closure"))
    targets = require_field("targets", payload, "plot_closure")
    if not isinstance(targets, list) or not targets:
        emit_error("Field `targets` must be a non-empty list of strings.", "plot_closure")
    output_path = Path(require_field("output_path", payload, "plot_closure"))
    g = load_graph(snap)
    result_path = plot_closure(
        g,
        targets,
        output_path,
        include_suggests=bool(payload.get("include_suggests", False)),
        include_base=bool(payload.get("include_base", False)),
        dpi=int(payload.get("dpi") or 200),
        seed=int(payload.get("seed") or 0),
        title=payload.get("title"),
    )
    return {"output_path": str(result_path)}


HANDLERS = {
    "build_snapshot": handle_build_snapshot,
    "stats": handle_stats,
    "optimize": handle_optimize,
    "plot_closure": handle_plot_closure,
}


def main() -> int:
    raw = sys.stdin.read().strip()
    if not raw:
        emit_error("No JSON payload received on stdin.")
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as exc:
        emit_error(f"Invalid JSON on stdin: {exc}")
    if not isinstance(payload, dict):
        emit_error(f"Payload must be a JSON object (got {type(payload).__name__}).")

    fn_name = payload.get("fn")
    if not fn_name:
        emit_error("Field `fn` is required.")

    handler = HANDLERS.get(fn_name)
    if handler is None:
        emit_error(
            f"Unknown fn '{fn_name}'. Supported: {sorted(HANDLERS)}.",
            fn_name,
        )

    try:
        result = handler(payload)
    except SystemExit:
        raise
    except Exception as exc:  # noqa: BLE001
        tb = traceback.format_exc(limit=4)
        emit_error(f"{type(exc).__name__}: {exc}\n{tb}", fn_name)

    emit_ok(fn_name, result)
    return 0


if __name__ == "__main__":
    sys.exit(main())
