# Changelog

All notable changes to this project are documented in this file. This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Each release receives a Zenodo DOI. The DOI is added to the entry below once the deposit completes.

## [Unreleased]

### Added (Phase 5.1 of cran-graph sprint, 2026-05-09)
- `cran_publisher/`: new sub-package for the CRAN publication pipeline.
  - `cran_publisher.check`: subprocess wrapper around `R CMD check` that captures stdout, stderr, exit code, wall-clock seconds, and writes an audit directory with the raw logs.
  - `cran_publisher.error_parser`: line-based parser of the check log that produces a `CheckSummary` with one structured `CheckIssue` per non-OK section, including the indented detail block.
  - `cran_publisher.categorize`: classifier with a 15-category living taxonomy under `cran_publisher/data/error_taxonomy.json`, ranging from `missing_documentation` and `undefined_globals` to `description_metadata`, `url_check`, and `incoming_feasibility`.
- `tests/test_cran_publisher.py`: 11 tests (10 offline + 1 smoke gated by `CRAN_PUBLISHER_RUN_RCMD=1`) covering parser shapes, aggregate counts, and category assignment.
- Smoke validation against the real bgumbel source: `R CMD check --as-cran` returns 1 ERROR, the parser captures one issue, the categorizer routes it to `description_metadata` (DESCRIPTION lacks legacy `Author`/`Maintainer` fields, only carries `Authors@R`). The pipeline classifies the failure end-to-end without raising. The fix itself is Phase 5.2 work.

### Added (Phase 3 promotion path, 2026-05-09)
- `scripts/generate_invoke_r.py`: orchestrator that takes a staged `SKILL.md`, calls Gemma 4 26b-fast with the bgumbel dispatcher as a few-shot anchor, validates the output via `Rscript -e 'parse(file=...)'`, and writes the dispatcher next to the staged SKILL.md (default) or directly to `skills/<package>/` when `--promote-now` is set.
- 5 candidate dispatchers generated and parked in staging awaiting human review of signature accuracy: `skills/_staging/{glue,jsonlite,digest,yaml,viridisLite}/invoke.R`. All five parse cleanly under `Rscript -e 'parse(...)'` and follow the bgumbel structural template (helpers `emit_error` / `emit_ok` / `require_field`, `dispatch` switch, `tryCatch` wrappers, banner redirection to stderr). Smoke probes confirm 3 of the dispatchers execute correctly on a sample fn (glue/glue_collapse, jsonlite/toJSON); the others surface field-name mismatches between the LLM-drafted SKILL.md and the upstream R signatures (for example, jsonlite/fromJSON expects `txt` upstream but the SKILL.md declared `x`). These mismatches are exactly what the staging gate exists to catch.

### Added (visualization, 2026-05-09)
- `cran_graph.viz`: layered-layout PNG renderer for the install closure of one or more targets. Nodes coloured by deprecation status, target highlighted with a black ring, providers stacked above consumers via `nx.topological_generations`. Lazy import of `matplotlib` so the rest of `cran_graph` stays import-cheap.
- `cran-graph plot` CLI subcommand (`--with-suggests`, `--with-base`, `--dpi`, `--seed`, `--title`).
- `pyproject.toml`: optional dependency group `[viz]` with `matplotlib>=3.5`.
- Two reference renders embedded in `docs/optimize_examples.md`:
  - `docs/images/closure_ggplot2.png`: 17 nodes, 31 edges, one soft-deprecated provider (`RColorBrewer`).
  - `docs/images/closure_tidyverse.png`: 99 nodes, 358 edges, 11 soft-deprecated transitive dependencies; the umbrella node itself is soft-deprecated under the 36-month threshold.

### Added (Phase 3 of cran-graph sprint, 2026-05-09)
- `scripts/triage_top_cran.py`: rank top-N CRAN packages by recent downloads (cranlogs API), cross-reference each name with a `cran_graph` snapshot to read version, license, and deprecation status, and drop packages that are deprecated, removed, or already covered by an existing skill in `skills/`.
- `scripts/extract_package_metadata.py`: download a CRAN source tarball and parse DESCRIPTION (Debian-style), NAMESPACE (`export(...)`, `S3method(...)`, `exportPattern(...)`), and selected `man/*.Rd` files (heuristic balanced-brace extraction of `\name`, `\title`, `\description`, `\examples`).
- `scripts/generate_skills_via_gemma.py`: orchestrator that pipes triage entries through the extractor, builds a prompt that pins the editorial contract (no em-dash, no forbidden buzzwords, no emojis, formal tone), calls Ollama (`gemma4:26b-fast` by default), validates the YAML front matter and required sections, retries once, and writes accepted output to `skills/_staging/<package>/SKILL.md` with a sibling `_meta.json`. An append-only JSONL log captures each attempt for audit.
- `tests/test_phase3.py`: 15 offline tests covering triage filtering, NAMESPACE parsing, Rd block extraction with nested braces, end-to-end tarball walking on a synthetic in-memory archive, and the SKILL.md validator (front matter, required sections, em-dash detection, forbidden-term detection, package-field consistency).

### Triage results (2026-05-09)
- cranlogs returned 100 packages over the last month (the public API caps the response at 100 even when more are requested).
- 92 survivors after filtering 8 (1 already-covered: bgumbel; 7 statuses outside `active`/`stale`).
- First 12 by downloads: rlang, cli, vctrs, ggplot2, lifecycle, dplyr, Rcpp, magrittr, glue, R6, tibble, fs.

### Generation policy (Phase 3 partial)
- The first batch of 10 SKILL.md files is written to `skills/_staging/` and gated by human review. Promotion to `skills/<package>/` happens only after the maintainer audits the staging output. The acceptance criterion mirrors the sprint plan: at least 8 of the first 10 must pass review, otherwise the prompt template is reformulated before scaling to the next batch.

### Bugs surfaced and fixed during Phase 3 (2026-05-09)
- **Gemma 4 26b-fast empty responses.** All 26B Gemma variants on the local Ollama instance are tagged with the `thinking` capability. In single-shot calls via `/api/generate`, the chain-of-thought trace consumed the full `num_predict` budget before producing any visible output, so every call returned empty content with `done_reason=length`. Fix: pass `"think": false` in the Ollama request payload. After the fix, `rlang` SKILL.md generated in 8.7 s on the first attempt with the expected frontmatter and four documented functions.
- **Tarball extractor read test-fixture metadata.** Several CRAN tarballs (Rcpp is the canonical example, with seven `NAMESPACE` files) embed in-tree test fixtures under `inst/tinytest/`. The naive walk let the last-encountered fixture overwrite the real metadata, zeroing `n_exports` and degrading the prompt. Fix: accept only `<package>/DESCRIPTION`, `<package>/NAMESPACE`, and `<package>/man/<*.Rd>` at the top level. Result on Rcpp: `n_exports` 0 → 20; the SKILL.md now documents `cppFunction`, `sourceCpp`, `Module`, `Rcpp.package.skeleton`, `populate`. Regression test `test_extract_ignores_inst_fixtures` added.

### Phase 3 batch results (2026-05-09)
- 60 SKILL.md drafts written to `skills/_staging/`, all OK on first attempt after the two fixes above.
- Total wall-clock for the 60-skill batch: ~8 minutes; average 7.78 s/skill (min 4.86 s, max 14.23 s).
- Average per-skill exports parsed: 76.2; average Rd files folded into the prompt: 3.88.
- Post-write violations (frontmatter missing, sections missing, em-dash, forbidden terms): 0/60.
- Test suite at the close of Phase 3: 72 passed, 2 skipped (network-bound).

### Added (Phase 2 of cran-graph sprint, 2026-05-09)
- `cran_graph.optimize`: greedy install-set solver with reverse-topological output, version-constraint validation (`>=`, `>`, `==`, `!=`, `<`, `<=`), R-version gating, exclude lists, and a strict-active mode that fails when any soft- or strong-deprecated package appears in the closure.
- `cran-graph optimize` CLI subcommand with `--with-suggests`, `--with-enhances`, `--exclude`, `--strict-active`, `--r-version`, and `--json` flags.
- `tests/test_optimize.py`: 21 tests covering version helpers, closure correctness, topological order, base-package skipping, deprecation gating, and JSON serializability.
- `docs/optimize_examples.md`: 8 worked examples against the 2026-05-09 snapshot, including ggplot2, knitr, shiny+dplyr, strict-active, R-version mismatch, bgumbel, missing-target, and JSON output.

### Verification on 2026-05-09 snapshot
- Greedy solver resolves 8 / 8 real-world targets without insoluble conflicts: ggplot2 (17 deps), shiny (30), dplyr (15), knitr (5), bgumbel (11), data.table (1), tidyverse (99), Rcpp (1).
- Closures expose 1 to 11 soft-deprecated dependencies per target. ILP / GA solvers stay deferred: greedy never failed on the current snapshot, and ILP only adds value once multi-version history is present.

### Fixed (Phase 1 follow-up)
- `_add_external_node`: base / recommended R packages now win over an `/Archive/` name collision. Previously, names like `grid` and `splines` could be misclassified as `strong_deprecated` because a homonymous package existed in `/Archive/`. Regression test `test_build_graph_base_package_wins_over_archive_collision` added. Snapshot stats moved from `base_or_recommended=11, strong_deprecated=152` to `14, 149`.

### Added (Phase 1 of cran-graph sprint, 2026-05-09)
- `cran_graph/`: new Python sub-package that builds a global queryable snapshot of the CRAN dependency graph.
  - `cran_graph.scrape`: download and parse `PACKAGES.gz` plus the `/Archive/` directory listing.
  - `cran_graph.deprecation`: heuristic classifier with four statuses (`active`, `stale`, `soft_deprecated`, `strong_deprecated`) plus `base_or_recommended` and `unknown` for referenced-but-absent nodes.
  - `cran_graph.build`: assemble a `networkx.MultiDiGraph` and persist it to a portable SQLite snapshot; `load_graph` rehydrates the same shape.
  - `cran_graph.cli`: `cran-graph build` and `cran-graph stats` entry points.
- `tests/test_graph.py`: 17 tests covering parser, heuristics, and SQLite roundtrip; 2 opt-in network tests behind `CRAN_GRAPH_NETWORK=1`.
- `docs/graph_schema.md`: schema reference and comparison against `pak`, `renv`, `crandep`, Posit Public Package Manager.

### First snapshot (2026-05-09)
- 24,227 nodes; 240,075 edges.
- Status distribution: 9,740 active; 6,748 stale; 7,178 soft_deprecated; 152 strong_deprecated; 11 base_or_recommended; 398 unknown.
- Edge types: 123,846 Imports; 82,493 Suggests; 26,567 Depends; 6,530 LinkingTo; 639 Enhances.
- Build wall-clock: ~12 s on residential connection.

### Dependencies
- Added `networkx>=3.0` and `requests>=2.28` to `pyproject.toml` (previously `dependencies = []`).

## [0.1.0] - 2026-05-06

Initial public release.

### Added
- `bridges/r.py`: subprocess + Rscript + JSON bridge for R packages.
- `bridges/__init__.py`: auto-router that dispatches a skill invocation to the bridge declared by the skill's `runtime` field.
- `bridges/python.py` and `bridges/julia.py`: placeholders raising `NotImplementedError`; community contributions invited.
- `skills/bgumbel/`: first canonical skill (R runtime) wrapping the [bgumbel](https://github.com/pcbrom/bgumbel) CRAN package, exposing `dbgumbel`, `pbgumbel`, `qbgumbel`, `rbgumbel`, `m1bgumbel`, `m2bgumbel`, and `mlebgumbel`.
- `templates/new_r_skill/`: copy-paste scaffold for new R skills.
- `docs/pattern.md`, `docs/architecture.md`, `docs/citation.md`, `docs/adding_r_skill.md`: design rationale and contribution guides.
- `CONTRIBUTING.md`, `CITATION.cff`, `.zenodo.json`, `pyproject.toml`, `LICENSE` (MIT).
- `tests/`: unit test for the R bridge and a smoke test for the bgumbel skill.
- `.github/workflows/ci.yml`: GitHub Actions matrix that installs R, the `bgumbel` package, and runs `pytest`.

### Zenodo DOI
- TBD (added after first release deposit).

### References
- Otiniano, C. E. G.; Vila, R.; Brom, P. C.; Bourguignon, M. (2023). *On the Bimodal Gumbel Model with Application to Environmental Data*. Austrian Journal of Statistics, **52**, 45-65. [DOI 10.17713/ajs.v52i2.1392](https://doi.org/10.17713/ajs.v52i2.1392).
