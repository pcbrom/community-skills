"""Triage: rank top-N CRAN packages by recent downloads and filter.

Pipeline:

1. Fetch the top-N package list from cranlogs (`https://cranlogs.r-pkg.org`).
2. Cross-reference each name with a `cran_graph` SQLite snapshot to read
   metadata (version, license, deprecation status) without re-fetching
   DESCRIPTION files.
3. Drop packages that are deprecated, orphaned, removed from CRAN, or
   already covered by an existing skill in `skills/`.
4. Emit a JSON list ordered by downloads, ready for the metadata
   extractor to consume.

Output schema (one entry per surviving package):

    {
      "package": str,
      "downloads_last_month": int,
      "version": str,
      "license": str | null,
      "status": str,
      "rank": int
    }

Usage:

    python -m scripts.triage_top_cran \\
        --snapshot data/cran_snapshot_2026-05-09.sqlite \\
        --top 200 \\
        --output data/top_cran_curated.json
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import requests

from cran_graph import load_graph

CRANLOGS_URL = "https://cranlogs.r-pkg.org/top/last-month/{n}"
DEFAULT_TIMEOUT_SECONDS = 30
USER_AGENT = "community-skills/triage_top_cran (+https://github.com/pcbrom/community-skills)"


def fetch_top_n(n: int = 200, timeout: float = DEFAULT_TIMEOUT_SECONDS) -> list[dict]:
    """Fetch the top-N most-downloaded CRAN packages over the last month."""
    response = requests.get(
        CRANLOGS_URL.format(n=n),
        timeout=timeout,
        headers={"User-Agent": USER_AGENT},
    )
    response.raise_for_status()
    payload = response.json()
    out: list[dict] = []
    for entry in payload.get("downloads", []):
        out.append({
            "package": entry["package"],
            "downloads_last_month": int(entry["downloads"]),
        })
    return out


def existing_skill_names(skills_dir: Path) -> set[str]:
    """Return the set of skill directory names that already exist."""
    if not skills_dir.is_dir():
        return set()
    return {
        p.name
        for p in skills_dir.iterdir()
        if p.is_dir() and not p.name.startswith("_") and not p.name.startswith(".")
    }


def filter_candidates(
    top: list[dict],
    graph,
    excluded_names: set[str],
    keep_statuses: tuple[str, ...] = ("active", "stale"),
) -> list[dict]:
    """Cross-reference cranlogs entries with the graph and filter.

    Drops entries whose snapshot status is not in ``keep_statuses``,
    whose name is missing from the snapshot, or that are already covered
    by an existing skill.
    """
    out: list[dict] = []
    for rank, entry in enumerate(top, start=1):
        name = entry["package"]
        if name in excluded_names:
            continue
        if name not in graph:
            continue
        node = graph.nodes[name]
        if node.get("status") not in keep_statuses:
            continue
        out.append({
            "package": name,
            "downloads_last_month": entry["downloads_last_month"],
            "version": node.get("version"),
            "license": node.get("license"),
            "status": node.get("status"),
            "rank": rank,
        })
    return out


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--snapshot", required=True,
        help="Path to a cran_graph SQLite snapshot (built via cran-graph build).",
    )
    parser.add_argument(
        "--top", type=int, default=200,
        help="Top-N to fetch from cranlogs (default 200).",
    )
    parser.add_argument(
        "--output", required=True,
        help="JSON output path.",
    )
    parser.add_argument(
        "--skills-dir", default="skills",
        help="Directory of existing skills (used as exclusion list).",
    )
    parser.add_argument(
        "--keep-statuses", default="active,stale",
        help="Comma-separated list of statuses to keep (default: active,stale).",
    )
    parser.add_argument(
        "--limit", type=int, default=None,
        help="Optional cap on the number of survivors emitted.",
    )
    args = parser.parse_args(argv)

    keep = tuple(s.strip() for s in args.keep_statuses.split(",") if s.strip())

    print(f"[triage] fetching top {args.top} from cranlogs", file=sys.stderr)
    top = fetch_top_n(n=args.top)
    print(f"[triage] cranlogs returned {len(top)} entries", file=sys.stderr)

    graph = load_graph(args.snapshot)
    excluded = existing_skill_names(Path(args.skills_dir))
    if excluded:
        print(f"[triage] excluding existing skills: {sorted(excluded)}", file=sys.stderr)

    survivors = filter_candidates(top, graph, excluded, keep_statuses=keep)
    if args.limit is not None:
        survivors = survivors[: args.limit]

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(survivors, indent=2) + "\n", encoding="utf-8")

    print(
        f"[triage] wrote {output}: {len(survivors)} survivors "
        f"(filtered {len(top) - len(survivors)})",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
