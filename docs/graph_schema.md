# cran_graph schema and design notes

## Plain-language summary

`cran_graph` builds a single queryable snapshot of the CRAN dependency graph
with three properties that no single existing tool exposes together:

1. Every declared edge type is preserved as a typed relation
   (`Depends`, `Imports`, `LinkingTo`, `Suggests`, `Enhances`).
2. Every node carries a deprecation status derived from machine-readable
   signals (`Published` date, presence in `/Archive/`, `Maintainer:
   ORPHANED`).
3. The snapshot is a portable SQLite file that any process can open without
   bootstrapping an R installation.

Snapshot taken on 2026-05-09: 24,227 nodes, 240,075 edges, 152 packages
flagged `strong_deprecated`, 7,178 flagged `soft_deprecated`. Build took
~12s on a residential connection.

## Node schema

The `packages` table has one row per node (a package referenced anywhere in
the index, whether it has its own stanza or is only the target of an edge).

| Column                | Type    | Source                                                                           |
| --------------------- | ------- | -------------------------------------------------------------------------------- |
| `name`                | TEXT PK | `Package` field of the stanza                                                    |
| `version`             | TEXT    | `Version` field                                                                  |
| `license`             | TEXT    | `License` field                                                                  |
| `published`           | TEXT    | `Published` field (raw, UTC string)                                              |
| `needs_compilation`   | TEXT    | `NeedsCompilation` field                                                         |
| `md5sum`              | TEXT    | `MD5sum` field of the source tarball                                             |
| `status`              | TEXT    | one of `active`, `stale`, `soft_deprecated`, `strong_deprecated`, `base_or_recommended`, `unknown` |
| `is_deprecated`       | INT     | 1 when status is `soft_deprecated` or `strong_deprecated`                        |
| `is_orphaned`         | INT     | 1 when `Maintainer` line contains `ORPHANED`                                     |
| `deprecation_reason`  | TEXT    | short token explaining the status (e.g. `removed_from_cran`, `no_update_for_46.2_months`) |
| `months_since_update` | REAL    | computed from `published` against snapshot time                                  |
| `in_current_index`    | INT     | 0 when the node is referenced as a dependency but absent from the current index   |

## Edge schema

The `dependencies` table has one row per declared dependency edge. Multiple
edges may exist between the same pair when a package declares the same
target under more than one field (rare but legal).

| Column               | Type | Notes                                                                       |
| -------------------- | ---- | --------------------------------------------------------------------------- |
| `from_package`       | TEXT | consumer (writes the edge)                                                  |
| `to_package`         | TEXT | provider                                                                    |
| `dep_type`           | TEXT | one of `Depends`, `Imports`, `LinkingTo`, `Suggests`, `Enhances`             |
| `version_constraint` | TEXT | the parenthesized constraint, verbatim (e.g. `>= 4.0`) or NULL              |

The primary key is `(from_package, to_package, dep_type, version_constraint)`,
which lets a multi-constraint edge survive a roundtrip without merging.

## Deprecation heuristic

Status assignment, in order of precedence:

1. `strong_deprecated` if the package is present under `/Archive/` but not
   in the current `PACKAGES.gz` (signal: removed from CRAN), or if its
   `Maintainer` line contains `ORPHANED`.
2. `soft_deprecated` if the last `Published` date is more than 36 months
   before the snapshot.
3. `stale` if it is more than 12 months but less than 36 months old.
4. `active` otherwise.
5. `base_or_recommended` for nodes that name a package shipped with R
   itself (`base`, `stats`, `methods`, `utils`, `graphics`, `grDevices`,
   `datasets`, `splines`, `tcltk`, `parallel`, `compiler`, `grid`, plus
   the pseudo-node `R`). These are nodes-only because R does not list its
   own packages in `PACKAGES.gz`.
6. `unknown` for referenced-but-absent nodes that match neither category.

The 36-month threshold is the cutoff CRAN itself tends to apply when
prompting maintainers about archival risk. It is configurable via
`cran_graph.deprecation.SOFT_MONTHS` if a stricter or looser policy is
needed.

## What is not yet in the schema

- `downloads_30d` from cranlogs. Kept out of the Phase 1 snapshot to
  avoid 23k per-package HTTP calls during the build. To be added in
  Phase 2 when the optimizer needs a cost signal.
- GitHub issue/release activity. Same reason. The license field plus the
  `Published` date are sufficient to gate an install set without it.
- `Maintainer`-derived person graph. CRAN ships `Maintainer` only inside
  the `DESCRIPTION` of each tarball; capturing it would require either
  parsing each tarball or scraping the per-package web view. Deferred.

## How `cran_graph` differs from pak, renv, and crandep

| Tool                         | Scope                                                       | Deprecation flags                          | Persistent off-process queryable graph                | Optimization solver        |
| ---------------------------- | ----------------------------------------------------------- | ------------------------------------------ | ----------------------------------------------------- | -------------------------- |
| `pak` (Posit)                | install-time resolution; SAT-based                          | none                                       | no (in-memory during install only)                    | implicit (SAT)             |
| `renv` (Posit)               | per-project lockfile; reproducibility                       | none                                       | per-project, not global                               | none                       |
| `crandep` (CRAN)             | exploratory dependency analysis                             | none                                       | in-memory R object                                     | none                       |
| Posit Public Package Manager | mirror with versioned snapshots                             | none (reflects CRAN state, no flags)       | yes, but as a service, not a local file               | none                       |
| `cran_graph` (this project)  | global snapshot; typed edges; deprecation flags machine-readable | yes (4 statuses + base/unknown)        | yes (SQLite + NetworkX, language-agnostic file)       | planned (Phase 2 optimizer) |

The defensible niche is the combination: a portable file that any
language can open, with deprecation as a first-class column, ready to
feed an optimizer that minimizes install set size or download cost
under user-supplied constraints.

## Reproducing the snapshot

```bash
pip install -e . --break-system-packages
cran-graph build --output data/cran_snapshot_$(date -u +%Y-%m-%d).sqlite
cran-graph stats data/cran_snapshot_$(date -u +%Y-%m-%d).sqlite
```

The build is deterministic given a fixed `PACKAGES.gz` and `/Archive/`
listing; rerunning on the same day yields the same node and edge counts
within CRAN's intra-day publication cadence.
