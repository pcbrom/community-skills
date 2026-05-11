---
name: cran_graph
runtime: python
package: cran_graph
package_source: in-tree
package_url: https://github.com/pcbrom/community-skills
package_version_pinned: ">=0.1.0"
license: MIT
maintainer: "Pedro Carvalho Brom <pcbrom@gmail.com>"
---

# Skill: cran_graph

Wraps the in-tree `cran_graph` Python sub-package as an LLM-callable
skill. The agent invokes one of four contracts: build a fresh CRAN
dependency-graph snapshot to a SQLite file; load an existing snapshot
and report aggregate statistics; resolve the install closure of one or
more target packages with version-constraint validation; and render
the closure as a layered PNG figure.

## Prerequisites

- Python 3.10 or later available on `PATH`.
- Network access to `https://cran.r-project.org` (only when `fn` is
  `build_snapshot`).
- `matplotlib >= 3.5` (only when `fn` is `plot_closure`); install via
  `pip install community-skills[viz]`.
- The community-skills repository checked out: the skill imports the
  in-tree `cran_graph` Python package via PYTHONPATH.

## Functions exposed

The dispatcher selects on the `fn` field of the JSON payload.

### `build_snapshot`: download CRAN, classify, write the SQLite snapshot

**Input**

```json
{
  "fn": "build_snapshot",
  "output_path": "string (where to write the SQLite file)",
  "fetch_archive": "boolean (optional; default true; off skips the /Archive/ scrape)"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "build_snapshot",
  "result": {
    "output_path": "string",
    "node_count": "integer",
    "edge_count": "integer"
  }
}
```

### `stats`: load an existing snapshot and summarize

**Input**

```json
{
  "fn": "stats",
  "snapshot": "string (path to a SQLite snapshot)"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "stats",
  "result": {
    "node_count": "integer",
    "edge_count": "integer",
    "by_status": "object (status -> count)",
    "by_edge_type": "object (dep_type -> count)"
  }
}
```

### `optimize`: resolve install set for one or more targets

**Input**

```json
{
  "fn": "optimize",
  "snapshot": "string (path to a SQLite snapshot)",
  "targets": "array of strings",
  "include_suggests": "boolean (optional; default false)",
  "include_enhances": "boolean (optional; default false)",
  "exclude": "array of strings (optional)",
  "strict_active": "boolean (optional; default false; fails if any soft- or strong-deprecated package would enter)",
  "r_version": "string (optional; checked against `Depends: R (op X)` constraints)"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "optimize",
  "result": {
    "ok": "boolean (the inner OptimizerResult flag)",
    "targets": "array of strings",
    "install_set": "array of strings (topological order, dependencies first)",
    "install_count": "integer",
    "by_status": "object",
    "warnings": "array of strings",
    "conflicts": "array of strings",
    "skipped_base": "array of strings",
    "missing_targets": "array of strings"
  }
}
```

### `plot_closure`: render the closure as a layered PNG

**Input**

```json
{
  "fn": "plot_closure",
  "snapshot": "string (path to a SQLite snapshot)",
  "targets": "array of strings",
  "output_path": "string (PNG destination)",
  "include_suggests": "boolean (optional; default false)",
  "include_base": "boolean (optional; default false)",
  "dpi": "integer (optional; default 200)",
  "seed": "integer (optional; default 0)",
  "title": "string (optional)"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "plot_closure",
  "result": {
    "output_path": "string"
  }
}
```

## When to invoke

- The agent has a target CRAN package and wants to know the full
  install closure plus deprecation status of every transitive
  dependency, without spawning R.
- The agent operates a CI pipeline that needs a daily snapshot of the
  CRAN graph as a portable file for downstream queries by other tools
  (Python, Julia, shell scripts, agent harnesses).
- The agent prepares documentation or a slide deck and wants a layered
  PNG of the install closure of `tidyverse`, `shiny`, or any user
  package, with deprecation status surfaced through node colour.
- The agent enforces a strict-active policy on a release branch and
  needs the closure to fail when a soft-deprecated transitive
  dependency would enter, so the operator can pin or replace it.

## Error contract

Any failure inside the dispatcher returns:

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

Examples: required field missing (`output_path` for `build_snapshot`,
`snapshot` for `stats` / `optimize` / `plot_closure`); the snapshot
file does not exist; a target name is absent from the snapshot;
matplotlib is not installed when `plot_closure` is requested.

## Worked examples

```bash
# 1. Build today's snapshot.
echo '{
  "fn": "build_snapshot",
  "output_path": "data/cran_snapshot_2026-05-09.sqlite"
}' | python3 skills/cran_graph/invoke.py

# 2. Resolve ggplot2 with strict-active.
echo '{
  "fn": "optimize",
  "snapshot": "data/cran_snapshot_2026-05-09.sqlite",
  "targets": ["ggplot2"],
  "strict_active": true
}' | python3 skills/cran_graph/invoke.py

# 3. Render the tidyverse closure to PNG.
echo '{
  "fn": "plot_closure",
  "snapshot": "data/cran_snapshot_2026-05-09.sqlite",
  "targets": ["tidyverse"],
  "output_path": "tidyverse_closure.png"
}' | python3 skills/cran_graph/invoke.py
```
