# Changelog

All notable changes to this project are documented in this file. This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Each release receives a Zenodo DOI. The DOI is added to the entry below once the deposit completes.

## [Unreleased]

### Public artefacts aligned with v0.2.0 (2026-05-11)
- `pyproject.toml` version bumped to 0.2.0; package description rewritten for the R-only scope; keywords updated (added `cran`, `r-packages`, `dependency-graph`, `r-cmd-check`; removed `package-wrapping` as generic).
- `CITATION.cff` and `.zenodo.json` rewritten to describe the v0.2.0 deliverables (`cran_graph`, `cran_publisher`, `cran_workflow`, `autoresearch`, plus 89 LLM-drafted R skills) and to drop the legacy multi-language framing.
- `docs/citation.md` updated to v0.2.0 with BibTeX and APA pointing at the new title.
- `docs/pattern.md` adds the explicit "Why R-only" section recording the 2026-05-09 scope decision; the `Why JSON instead of binary or RPC` block stays unchanged.
- `docs/skill_generation.md` pipeline diagram extended with the `generate_invoke_r.py` and `promote_all.py` stages that landed during Phase 3.
- `.github/ISSUE_TEMPLATE/new_skill.yml` simplified: only R-package proposals are accepted; the legacy runtime dropdown (R/Python/Julia/Stata) is gone.
- `README.md`: badge counter updated from "Skills: 1" to "Skills: 94"; CI badge moved from "pending" to "passing"; the "Available skills" table replaced with a Core (5) + CRAN top-100 (89) split; the "How a skill is shaped" section drops Julia.
- `skills/README.md` replaces the long inline list with a Core-vs-CRAN-top-100 split and points at `data/audit_stratified_2026-05-11.json` for the audit results.
- `.gitignore` reorganized into two labelled groups (standard exclusions vs operator-local exclusions) so a fresh clone reads the contract immediately.
- `PUBLISH_CHECKLIST.md`: the v0.1.0 block is retained for audit trail under a "historical" heading; the v0.2.0 block stays as the active release plan.

### Repositioned R-only (2026-05-11)
- Project scope narrowed to R packages on CRAN. The hub no longer advertises Python or Julia external-package wrappers as future work. The in-tree Python skills (`cran_graph`, `cran_publisher`, `cran_workflow`, `autoresearch`) remain in the gallery because they serve the R workflow.
- `bridges/julia.py` deleted; `templates/new_python_skill/` and `templates/new_julia_skill/` deleted. `bridges/__init__.py` updated: a `runtime: julia` SKILL.md is now reported as `unknown runtime` rather than dispatched. `tests/test_bridges.py` carries a regression that pins this behaviour.
- README, `skills/README.md`, `docs/architecture.md`, and `CONTRIBUTING.md` reflect the R-only narrative. The repository hierarchy in the README lists every concrete sub-package and template that survived the cut.
- Plan canonical header amended: "sprint 2-4 semanas" replaced with "sprint 4-12 semanas with Phase 5.4 conditioned"; the R-only scope decision and the Julia exclusion are recorded inline so future session resumes read consistent.

### Snapshot 2026-05-11 (refresh of 2026-05-09)
- nodes 24,227 (unchanged); edges 240,116 (+41 vs 2026-05-09); active 9,721 (-19), stale 6,758 (+10), soft_deprecated 7,188 (+10), strong_deprecated 149 (-3), base_or_recommended 14 (unchanged), unknown 397 (-1). Pipeline reproducible: a 2-day delta produces the small migrations expected from the 12-month and 36-month threshold heuristic.

### Stratified audit (2026-05-11)
- 15-skill random sample (seed 11) drawn from the 28 installed-locally R skills: `cli, commonmark, cpp11, desc, digest, magrittr, pkgbuild, processx, ps, purrr, rlang, stringr, withr, xfun, yaml`.
- Outcome: 3 / 15 `clean_pass` (function accepts the empty payload and returns a non-trivial result: `digest`, `ps`, `yaml`); 12 / 15 `structural_pass` (dispatcher rejects the empty payload with a `Field X is required` message); 0 / 15 `functional_fail`; 0 / 15 `no_fns_detected`. Audit serialized to `data/audit_stratified_2026-05-11.json`.
- Interpretation: the generator + promotion pipeline produces dispatchers that are structurally robust against empty-payload abuse. Per-function semantic correctness is still gated on hand audit per skill; this audit only measures the structural contract.

### Promotion manifest refreshed (2026-05-11)
- 88 skills `already_promoted`. 2 skills (`stringi`, `yaml`) flagged `exists_pass_force` because their promoted `invoke.R` diverges from the staged draft after a manual fix landed during the audit cycle; this is the intended behaviour, the divergence is recorded for review. 1 skill (`rmarkdown`) remains `skipped: missing_skill_or_invoke` (large-surface package; manual hand-write recommended).

### Phase 5.3 wired as Gemma-only (2026-05-09)
- Plan and BRIEFING amended: Phase 5.3 no longer escalates to Claude API. All five attempts per issue run on Gemma 4 26b-fast local with prompt diversification keyed off the attempt index. The reportable milestone shifts to "the diversification regime produced at least one accepted fix that the minimal prompt had rejected." Anthropic API key + dollar ceiling are no longer blocking prerequisites; the structures stay in the code for an optional future opt-in.
- `cran_publisher.agents.build_prompt` extended with five strategies: (1) minimal, (2) expanded file context (4 KB per file), (3) "previous attempt failed because X, try a different angle", (4) risk-level upgrade to medium, (5) final shot that explicitly asks the model to return `edits: []` and explain rather than guess.
- `cran_publisher.fix_loop`:
  - `DEFAULT_MAX_ATTEMPTS_PER_ISSUE` raised to 5 (was 3); each attempt picks the strategy matching its index.
  - `fix_session` accepts `soft_wall_clock_s` (default 180 s) and `hard_wall_clock_s` (default 600 s) per package; soft cap aborts further strategies on the current issue once at least one rejected record is in hand, hard cap aborts the whole session.
  - Tokens captured into `CostTracker` per call using the 4-chars-per-token rule of thumb so the cost block in the report can show input/output volumes alongside cost_usd=0.
  - `run_full_session` end-to-end entry point: runs the loop, renders the report via `cran_publisher.report.render_report`, optionally writes the report to disk, and returns both the session record and the Markdown string.
- 2 new tests: prompt diversification by strategy (5 levels distinct) and full-session-with-report end-to-end with mocked Gemma + check.

### Added: cran_workflow skill (composition, 2026-05-09)
- `skills/cran_workflow/`: higher-order Python skill that composes `cran_graph` and `cran_publisher` behind one JSON contract. Two functions: `audit_release` (read-only: closure + check + categorize) and `fix_and_report` (full Phase 5.3 loop + rendered report). 5 smoke tests; the bgumbel `audit_release` is exercised against the live snapshot and produces the structural verdict in around 1 s.
- `bridges/python.py`: default subprocess timeout raised from 60 s to 900 s. Python-runtime skills can shell out to `R CMD check` or Ollama, both multi-minute on a real package. Per-invocation `timeout` override remains available.

### Added: autoresearch skill (2026-05-09)
- `skills/autoresearch/`: third Python skill on the hub. Wraps the `autoresearch` package (Trabalho do Dr. Brom, [DOI 10.5281/zenodo.19772195](https://doi.org/10.5281/zenodo.19772195)) and exposes six single-shot CLI subcommands (`init`, `run`, `critic`, `analyze`, `audit`, `state`). The long-running `loop` and the interactive `wizard` are intentionally out of scope of the skill contract.
- The dispatcher shells out to the `autoresearch` CLI so the skill stays decoupled from upstream API refactors. 5 smoke tests cover missing/unknown `fn`, required-field surfacing for `init`, and a `critic --dry-run` round-trip that returns a structured subprocess outcome without touching Ollama.
- Strategic role: this skill is the instrumental anchor of Phase 6 of the sprint. The same propose-validate-iterate loop becomes the motor of `forks/glmnet-fast/` and `forks/survival-fast/` optimization once the equivalence harness lands.

### Phase 3 audit pass + targeted fixes (2026-05-09)
- Structural audit over the 29 promoted R skills whose upstream package is installed locally (R6, backports, bgumbel, callr, cli, commonmark, cpp11, desc, digest, evaluate, glue, highr, jsonlite, knitr, lifecycle, magrittr, pkgbuild, processx, ps, purrr, rlang, rprojroot, stringi, stringr, vctrs, withr, xfun, xml2, yaml). Each was invoked with the first exposed function and a minimal payload; the pass rate moved from 26 / 29 to 29 / 29 after one round of targeted re-generation and one manual `do.call(yaml::as.yaml, args)` patch.
- Specific fixes that landed in promoted dispatchers:
  - `stringr/invoke.R`: re-generated; `str_c` no longer passes `sep=NULL` when the field is absent.
  - `vctrs/invoke.R`: re-generated; the `...` malformation in `data_frame` cleared.
  - `yaml/invoke.R`: regenerated and then patched manually; the `do.call(yaml::as.yaml(do.call(args)))` typo was a generator-level slip the parse-check could not detect.
  - `stringi/invoke.R`: round-tripped `stri_count` across all four modes (`pattern`, `regex`, `fixed`, `charclass`).

### Added (Phase 5.3 partial: report + cost_tracker, no Claude wiring)
- `cran_publisher.cost_tracker`: aggregates token counts and dollar cost for the fix loop. Local Gemma calls record at zero cost; Claude API calls take a per-model `ClaudePricing` table that the operator wires when Phase 5.3 is approved. Soft and hard caps default to the policy levels ($1 and $5 per package). The orchestrator queries `approaching_soft_cap()` / `exceeded_hard_cap()` between calls; the tracker never makes the call itself.
- `cran_publisher.report`: pure-Python (no Jinja) renderer that turns a `FixSession` plus an optional `CostTracker` into a Markdown report following the durable plain-language-first contract. Section ordering pinned: verdict, decomposition, synthesis, strategy, audit table, cost block. The audit table sits at the bottom; nothing before it is a transcript.
- 6 new tests covering token aggregation, pricing-table application, unknown-model zero-charge, the plain-language section ordering, the empty-session path, and the editorial contract (no em-dash, no forbidden buzzwords inside the rendered report).

### Phase 3 generator improvements (2026-05-09)
- `scripts/generate_invoke_r.py`: prompt now spells out per-type coercion rules (`as.character` / `as.integer` / `as.numeric` / `as.logical`) keyed off the `\arguments{}` description, plus an explicit multi-modal one-of fallback rule for clusters like `regex` / `fixed` / `coll` / `charclass`. The validator gained a doubled-prefix typo guard catching `charcharclass`-style identifiers that R parses but fails at runtime.
- `skills/stringi/invoke.R` patched to round-trip `stri_count` across all four modes (`pattern`, `regex`, `fixed`, `charclass`), with the generic `pattern` field routed to `regex` when no specific mode is set. Smoke now passes 4 of 4 (was 1 of 4 before the fix).

### Promoted: cran_graph as Python skill (2026-05-09)
- `skills/cran_graph/`: second Python skill on the hub, exposes four contracts of the in-tree `cran_graph` sub-package: `build_snapshot`, `stats`, `optimize`, `plot_closure`. The dispatcher imports lazily, so an agent that only needs `optimize` does not pay the matplotlib import cost.
- 8 smoke tests in `tests/test_skills/test_cran_graph.py` (7 pass, 1 skipped behind `CRAN_GRAPH_NETWORK=1` for the network-bound build), all gated on the presence of a 2026-05-09 snapshot under `data/`.

### Test surface
- 170 passed, 128 skipped. The skips are unchanged: smoke tests for skills whose upstream R package is not installed locally plus the two opt-in network-bound checks.

### Added (Python bridge + first Python skill, 2026-05-09)
- `bridges/python.py`: subprocess-based Python bridge promoted from placeholder. Spawns ``sys.executable`` with the skill's ``invoke.py``, sends JSON via stdin, parses JSON from stdout, and prepends the repository root to ``PYTHONPATH`` so in-tree sub-packages are importable without an editable install. Same structured ``ok / error`` contract as the R bridge.
- `tests/test_bridges.py`: replaced the placeholder test with three real smoke tests covering missing-invoke-py, non-serializable payload, and a happy-path one-line dispatcher.
- `skills/cran_publisher/`: first Python skill on the hub. Wraps the in-tree `cran_publisher` sub-package and exposes four contracts: `run_check`, `parse_log`, `categorize`, and `fix_session`. SKILL.md documents schemas; `invoke.py` dispatches via a `fn` switch with `emit_ok` / `emit_error` helpers mirroring the R reference.
- `tests/test_skills/test_cran_publisher.py`: 7 smoke tests through `bridges.invoke` covering missing/unknown `fn`, parse-log shape, categorize routing, and required-field surfacing for `run_check` and `fix_session`.

### Phase 3 sample audit (2026-05-09)
- 8 invocations across 5 representative skills (`stringi`, `cli`, `rlang`, `digest`, `processx`) using the functions each dispatcher actually exposes. Result: 7/8 pass (88%); the single failure is `stringi::stri_count` which requires one of `regex`, `fixed`, `coll`, or `charclass` and the dispatcher passes only `pattern`. Documented as a multi-modal-signature edge case for the next pass of `generate_invoke_r.py`.
- Coverage finding (not a defect): each LLM-drafted SKILL.md exposes 3 to 6 functions out of 100 to 400+ NAMESPACE exports. The skills are seed kits, not full ports; expansion happens by hand per skill as the maintainer audits each.

### Added (Phase 5.2 of cran-graph sprint, 2026-05-09)
- `cran_publisher.git_ops`: minimal subprocess wrapper around `git` (branch, checkout, commit, merge --no-ff, reset --hard, short SHA). Captures stdout, stderr, and return code so the fix loop can attach them to its audit trail.
- `cran_publisher.agents`: prompt + LLM call + structured-proposal parser. The proposal contract is `{thought, risk_level, edits[{path, search, replace}]}`. Patches are applied via uniqueness-checked search/replace; ambiguous matches and out-of-tree paths are rejected before any edit lands. Default backend is Gemma 4 26b-fast on local Ollama with `think: false`. Claude API escalation is wired through the same contract but stays off until the operator confirms the API key and the cost ceiling.
- `cran_publisher.fix_loop`: per-issue attempt loop. Each attempt opens a branch `fix/<category>-<hash>-attempt-<n>` off the run branch, asks Gemma for one minimal edit, applies it, commits, re-runs `R CMD check`, and either merges back (when `_summary_strictly_better` accepts) or reverts via `git reset --hard`. The acceptance policy is layered: any drop in ERROR count wins (latent WARNINGs/NOTEs that were masked by the ERROR are tolerated), otherwise WARNINGs and NOTEs follow the usual non-regression rule. Audit lines land in `data/fix_session_<package>.jsonl`.
- `tests/test_cran_publisher.py`: 6 new tests covering proposal parsing, search/replace edit application (happy path, ambiguous-search rejection, path-escape rejection), git operations on a tmp repo, and a full fix-loop end-to-end with the LLM call mocked out.

### End-to-end validation on bgumbel real
- Ran `fix_session(repo_root=cran_graph_extra/bgumbel)` with Gemma 4 26b-fast and live `R CMD check`. Outcome: one accepted attempt at 65.8 s wall-clock; the issue `for file 'bgumbel/DESCRIPTION'` (Required fields missing or empty: 'Author' 'Maintainer') flipped from `1 ERROR` to `0 ERROR / 2 WARNING / 3 NOTE`. The diff Gemma produced inserts the legacy `Author:` and `Maintainer:` fields above the existing `Authors@R:` block, derived from the upstream maintainer record. Merge commit `bdec19f` lives on the `cran-publisher-run-<ts>` branch of the bgumbel checkout under `cran_graph_extra/bgumbel/`. Phase 5.2 reportable milestone met.
- During the run, two policy bugs surfaced and were fixed before the second attempt: (a) the original acceptance rule rejected the proposal because R CMD check exposed previously masked WARNINGs and NOTEs once the leading ERROR was resolved; (b) the prompt did not declare the package root, so Gemma occasionally emitted `<pkgname>/<file>` paths instead of package-relative paths. Both fixes ship in this release.

### Added (Phase 3 promotion, 2026-05-09)
- `scripts/promote_all.py`: idempotent promotion of staged skills. For each `skills/_staging/<pkg>/` with both `SKILL.md` and `invoke.R`, the script runs a structural smoke screen (the dispatcher must surface a JSON `ok: false` for an unknown `fn` instead of crashing or hanging), copies both files to `skills/<pkg>/`, and writes a stub smoke test under `tests/test_skills/test_<pkg>.py` that runs only when the upstream R package is installed locally. Manifest written to `data/promotion_manifest.json`.
- 90 R skills promoted on 2026-05-09 from the top-100 most-downloaded CRAN packages (cranlogs last-month window). All 90 dispatchers parse cleanly and pass the structural smoke screen. One package (`rmarkdown`) failed to produce a parse-clean dispatcher across 4 generation attempts and remains in `_staging/`.
- `scripts/extract_package_metadata.py` extended to capture `\arguments{}` blocks from Rd files. The `FunctionDoc` dataclass now carries a list of `(arg_name, short_description)` pairs in declaration order. Regression test `test_parse_rd_extracts_arguments_block` covers `\item{x, y}{...}` syntax.
- `scripts/generate_invoke_r.py` re-prompted: the upstream signatures from `\arguments{}` are now passed verbatim and the prompt instructs the model to use them as the source of truth, overriding the SKILL.md narrative when they disagree. Result on the first 5 candidates: 9 of 9 sampled function calls succeed end-to-end (was 3 of 7 before the re-prompt).
- Tarball download in `extract_package_metadata.fetch_tarball` retries up to 3 times on `ChunkedEncodingError` / `ConnectionError` / `ReadTimeout`. The orchestrator's loop catches network and Ollama exceptions per-package so a single transient failure no longer aborts the whole batch.
- Validator additions in `generate_invoke_r.validate_invoke_r`: typo guard against `\bfn\.name\b` (R reads it as a separate identifier from the canonical `fn_name`).

### Test surface
- 149 passing, 127 skipped at the close of this batch. The skips are smoke tests for skills whose upstream R package is not installed on the build machine; CI installs the relevant subset and runs them green per skill.

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
