# community-skills

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![tests](https://img.shields.io/badge/tests-passing-brightgreen.svg)](https://github.com/pcbrom/community-skills/actions/workflows/ci.yml)
[![Skills: 110](https://img.shields.io/badge/skills-110-blue.svg)](skills/)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.20543565.svg)](https://doi.org/10.5281/zenodo.20543565)

## What this repository is

community-skills is an R-focused hub that turns CRAN packages into machine-readable skills that an LLM agent can invoke autonomously through a single contract: read JSON from stdin, write JSON to stdout. The project does not wrap Python or Julia packages and does not aim to be a multi-language registry (decision 2026-05-09).

The hub ships three independent products that compose:

1. **A pattern.** One pinned contract (SKILL.md + per-runtime dispatcher + shared Python bridge) that any agent harness with subprocess support can call. There is no IDE-specific dependency.
2. **A curated gallery of R skills.** Reference R skills built on the pattern, starting with [bgumbel](skills/bgumbel/) (+48k CRAN downloads). New R skills land through community PRs and through a generation pipeline described below.
3. **`cran_graph` and friends.** Internal Python sub-packages that serve the R workflow: a portable SQLite snapshot of the entire CRAN dependency graph (`cran_graph`); an `R CMD check` parser, categorizer and fix loop (`cran_publisher`); and a composition skill that audits a CRAN release end-to-end (`cran_workflow`). These ship as Python-runtime skills inside `skills/` because the agent invokes them; the Python is implementation, not a competing ecosystem.

## What it is for

Two independent audiences share the same repository:

- **Agent operators.** A Claude Code, Codex, or OpenCode session that needs to call an R function gets a uniform `invoke(skill, payload)` interface and a documented JSON schema, instead of writing per-package glue. Examples: fit a bimodal Gumbel via [bgumbel](skills/bgumbel/), reason about CRAN dependencies via the [cran_graph](skills/cran_graph/) skill, run `R CMD check` and a Gemma-driven fix loop via [cran_publisher](skills/cran_publisher/), or compose the two via [cran_workflow](skills/cran_workflow/).
- **R / CRAN operators.** Anyone who needs a queryable global graph of CRAN packages gets a SQLite file with version, license, deprecation status, and typed dependency edges, plus a CLI optimizer that resolves install sets under user-supplied constraints. The first snapshot (2026-05-09) covers 24,227 nodes and 240,075 edges and builds in about 12 seconds on a residential connection.

## Why this matters: token-cost reduction

When an agent invokes an R function without a skill available, it runs a loop of *load documentation context, generate R code, spawn Rscript, parse error or output, retry*. For non-trivial tasks this consumes 15,000 to 40,000 tokens per analysis, mostly driven by retries when the agent guesses an argument name the upstream function does not accept.

When the same call goes through a skill, the loop collapses to *load the SKILL.md contract, serialize a JSON payload that matches the schema, invoke the bridge, use the structured result*. Same task, 700 to 2,000 tokens. The dispatcher returns `{"ok": false, "error": "Field X is required"}` on missing fields, so failures are diagnosable without re-prompting.

A static cost model built from measured SKILL.md sizes and standard agent-loop assumptions (1 token ~ 4 chars) gives the following per-task estimates:

| Task | Without skill | With skill | Ratio |
|---|---|---|---|
| `lme4` mixed-effects fit (`Reaction ~ Days + (Days \| Subject)` on `sleepstudy`) | 12,000 | 1,800 | **6.7x** |
| `ggplot2` faceted scatter on `mpg` | 8,000 | 2,500 | **3.2x** |
| `dplyr` filter / group / summarize on `mtcars` | 7,500 | 1,500 | **5.0x** |
| `bgumbel` MLE parameter recovery on simulated data | 28,000 | 1,400 | **20.0x** |
| **Mean** | | | **8.7x** |

The savings spread is the point: well-known packages (ggplot2, dplyr) save 3 to 5x because the agent already has the API memorized; long-tail packages (bgumbel and the bulk of CRAN) save 15 to 20x because the agent otherwise burns retries on hallucinated argument names. Expect 5 to 10x average savings on workflows that mix both. Time savings track tokens: a non-trivial inline analysis takes 90 to 180 seconds against 25 to 35 seconds with a skill.

The numbers above are static estimates, not dynamic end-to-end measurements. The methodology (4 tasks, prompts, run schema, aggregation script) is documented externally and reproducible; community runs will revise these estimates.

## Who fits this hub, who does not

The pattern earns its keep in these profiles:

- A data scientist with an LLM agent in the R workflow (Claude Code, Codex, OpenCode, custom harness) that hits R analyses at least a few times a day.
- A pipeline that automates R analysis as part of a larger orchestrated process (bioinformatics, genomics, finance); the JSON contract makes the R step deterministic for the orchestrator.
- Instructors teaching R via an agent that demonstrates "how do I do X in R" with executable code and structured outputs.

The pattern adds friction or has no payoff in these cases:

- You write R by hand in RStudio with no agent in the loop. There is no token cost to reduce.
- You only use Python. The Python infrastructure skills (`cran_graph`, `cran_publisher`, `cran_workflow`, `autoresearch`) serve the R workflow; if you have no R, the hub does not serve you.
- You need microsecond latency for tight inner loops. The bridge spawns a fresh Rscript per call (~100 ms). For agentic invocation this is rounding error; for batched computation, use `rpy2` or another in-process binding.
- You already have a tailored agent-to-R integration that works. Switching only pays off if the uniform JSON contract gives you something you do not have today (auditability, easier handoff to other agents, multi-skill orchestration).

## What it contains

```
community-skills/
├── README.md                    <- this file
├── CONTRIBUTING.md              <- 5-step recipe to wrap a package
├── CHANGELOG.md                 <- per-release notes and Zenodo DOIs
├── CITATION.cff                 <- machine-readable citation
├── .zenodo.json                 <- Zenodo deposit metadata
├── pyproject.toml               <- pip install community-skills
├── docs/
│   ├── pattern.md               <- design rationale of the SKILL.md contract
│   ├── architecture.md          <- system diagram and data flow
│   ├── citation.md              <- BibTeX, APA, CFF, Zenodo
│   ├── adding_r_skill.md        <- worked tutorial: port an R package end-to-end
│   ├── graph_schema.md          <- cran_graph schema and comparison vs pak/renv/crandep
│   ├── optimize_examples.md     <- cran-graph optimize CLI worked examples
│   └── skill_generation.md      <- curated CRAN-skill generation pipeline
├── bridges/                     <- per-runtime Python adapters
│   ├── r.py                     <- subprocess + Rscript + JSON (canonical, all R skills)
│   └── python.py                <- subprocess + Python + JSON (internal infra skills only)
├── cran_graph/                  <- queryable global CRAN graph + install-set optimizer
│   ├── scrape.py                <- download and parse PACKAGES.gz and /Archive/
│   ├── deprecation.py           <- four-status heuristic classifier
│   ├── build.py                 <- NetworkX MultiDiGraph and SQLite roundtrip
│   ├── optimize.py              <- greedy solver with version-constraint validation
│   ├── viz.py                   <- layered PNG renderer (optional matplotlib)
│   └── cli.py                   <- cran-graph build / stats / optimize / plot entry points
├── cran_publisher/              <- R CMD check parser + categorizer + Gemma fix loop
│   ├── check.py                 <- subprocess wrapper around R CMD check
│   ├── error_parser.py          <- structured CheckSummary from log
│   ├── categorize.py            <- 15-category living taxonomy
│   ├── agents.py                <- Gemma prompt + structured proposal parser
│   ├── git_ops.py               <- minimal git helpers for attempt branches
│   ├── fix_loop.py              <- per-issue attempt loop with diversified prompts
│   ├── cost_tracker.py          <- token / dollar accounting (Gemma local: free)
│   └── report.py                <- plain-language-first Markdown report renderer
├── scripts/                     <- R-skill generation pipeline (cranlogs + tarball + Gemma)
│   ├── triage_top_cran.py       <- rank top-N by downloads, cross-reference snapshot, filter
│   ├── extract_package_metadata.py  <- parse DESCRIPTION + NAMESPACE + Rd from a tarball
│   ├── generate_skills_via_gemma.py <- generate SKILL.md drafts
│   ├── generate_invoke_r.py     <- generate invoke.R from staged SKILL.md + signatures
│   └── promote_all.py           <- promote staged drafts to skills/<pkg>/ after smoke
├── skills/                      <- gallery; one subdirectory per skill
│   ├── README.md                <- gallery index + per-skill hierarchy
│   ├── bgumbel/                 <- canonical R skill (worked example)
│   ├── cran_graph/              <- Python skill: graph build / stats / optimize / plot
│   ├── cran_publisher/          <- Python skill: CRAN check / fix loop / submit, plus r-universe register / status
│   ├── cran_workflow/           <- Python skill: composition of cran_graph + cran_publisher
│   ├── autoresearch/            <- Python skill: autonomous optimization loop (Phase 6 anchor)
│   ├── glue/, jsonlite/, ...    <- 105 R skills promoted from staging
│   └── _staging/                <- LLM-generated drafts awaiting human review (gitignored)
├── templates/
│   └── new_r_skill/             <- copy-paste scaffold for a new R skill
├── tests/                       <- pytest matrix; CI runs setup R + install + run
└── .github/
    ├── workflows/ci.yml         <- GitHub Actions: setup R, install bgumbel, pytest
    └── ISSUE_TEMPLATE/          <- new_skill, bug_report
```

The community-facing path is to read this `README.md`, then [`skills/README.md`](skills/README.md) for the gallery, then either consume an existing skill or follow [`docs/adding_r_skill.md`](docs/adding_r_skill.md) and [`CONTRIBUTING.md`](CONTRIBUTING.md) to wrap your own.

## How a skill is shaped

Each `skills/<name>/` directory contains:

- `SKILL.md`: a YAML front matter declaring the runtime (`r` or `python`) plus a body that lists each exposed function with input and output JSON schemas.
- `invoke.R` or `invoke.py`: a dispatcher in the package's native language. It reads one JSON object from stdin, routes on the `fn` field, calls the wrapped function, writes one JSON object to stdout.

Each `bridges/<runtime>.py` is a thin Python adapter that spawns the runtime, sends the JSON payload, and parses the response. `bridges/r.py` is the canonical bridge and handles every CRAN package wrapped by the hub. `bridges/python.py` exists to run the project's in-tree Python infrastructure skills (`cran_graph`, `cran_publisher`, `cran_workflow`, `autoresearch`); it is not a general-purpose bridge for arbitrary Python packages. Julia is intentionally out of scope.

```
+--------------+      JSON        +-----------+      stdin/stdout        +----------+
|   Agent      | ---------------> | bridge.<r>| -----------------------> | invoke.R |
| (Claude Code,|                  |  (Python) |       JSON               |   (R)    |
|  Codex, ...) | <--------------- |           | <----------------------- |          |
+--------------+      JSON        +-----------+                          +----------+
```

## How to install

Prerequisites: Python 3.10+, R installed and on `PATH` (only when you call an R-runtime skill), and the upstream package itself (for example, `install.packages("bgumbel")` for the bgumbel skill).

```bash
git clone https://github.com/pcbrom/community-skills
cd community-skills
pip install -e .
```

The install pulls in `networkx>=3.0` and `requests>=2.28` (used by `cran_graph` and the generation scripts). The bridge layer itself depends only on the Python standard library.

## How to use it

### Call a skill from Python (or any language that can run a subprocess)

```python
from bridges import invoke

result = invoke("bgumbel", {
    "fn":    "dbgumbel",
    "x":     [-1.0, 0.0, 1.0],
    "mu":    0.0,
    "sigma": 1.0,
    "delta": 0.5,
})
print(result)
# {'ok': True, 'fn': 'dbgumbel', 'result': [...]}
```

From inside an agent session, the same call is a single tool invocation. See [`docs/architecture.md`](docs/architecture.md) for the full diagram and [`docs/pattern.md`](docs/pattern.md) for the design rationale.

### Build and query the CRAN graph

```bash
cran-graph build  --output data/cran_snapshot_$(date -u +%Y-%m-%d).sqlite
cran-graph stats  data/cran_snapshot_$(date -u +%Y-%m-%d).sqlite
cran-graph optimize ggplot2 --snapshot data/cran_snapshot_$(date -u +%Y-%m-%d).sqlite
```

`cran-graph optimize` resolves the install closure for one or more targets, returns it in topological order, validates version constraints, and supports a strict-active mode that fails when any soft-deprecated or strong-deprecated package would enter the closure. Schema reference is in [`docs/graph_schema.md`](docs/graph_schema.md); eight worked examples are in [`docs/optimize_examples.md`](docs/optimize_examples.md).

### Run the skill-generation pipeline

```bash
# 1. Build (or refresh) the CRAN graph snapshot.
cran-graph build --output data/cran_snapshot_$(date -u +%Y-%m-%d).sqlite

# 2. Rank top-N by recent downloads, cross-reference, and filter.
python -m scripts.triage_top_cran \
    --snapshot data/cran_snapshot_$(date -u +%Y-%m-%d).sqlite \
    --top 200 \
    --output data/top_cran_curated.json

# 3. Generate SKILL.md drafts to the staging directory.
python -m scripts.generate_skills_via_gemma \
    --triage data/top_cran_curated.json \
    --output-dir skills/_staging \
    --limit 10
```

Each draft lands in `skills/_staging/<package>/SKILL.md` with a sibling `_meta.json` that records the raw metadata extracted from the tarball, so a reviewer can verify the LLM did not invent functions or links. Promotion from staging to `skills/<package>/` is an explicit human step. The full editorial contract enforced by the validator and the promotion checklist live in [`docs/skill_generation.md`](docs/skill_generation.md).

## Available skills

The gallery has 110 skills as of 2026-06-04.

### Core skills (curated, all-in)

| Skill | Runtime | Role | First release |
|---|---|---|---|
| [bgumbel](skills/bgumbel/) | R | canonical R reference; 7 functions over the bimodal Gumbel distribution | v0.1.0 |
| [cran_graph](skills/cran_graph/) | Python | global CRAN graph and install-set optimizer | v0.2.0 |
| [cran_publisher](skills/cran_publisher/) | Python | CRAN channel: `R CMD check` parser, categorizer, Gemma-driven fix loop, submission preflight and gated submit; r-universe channel: readiness preflight, `packages.json` register, build-status query | v0.2.0 |
| [cran_workflow](skills/cran_workflow/) | Python | composition of `cran_graph` plus `cran_publisher`: audit a CRAN release end-to-end | v0.2.0 |
| [autoresearch](skills/autoresearch/) | Python | autonomous optimization loop with a local LLM critic; Phase 6 anchor | v0.2.0 |

### CRAN top-100 (LLM-drafted, staging-then-promoted)

105 R skills drafted with Gemma 4 26b-fast and promoted after structural smoke validation. The first 90 came from the cranlogs top-100 of 2026-05-09; 15 more landed on 2026-06-04 as the curation queue driven by the harness sister package ([issue #1](https://github.com/pcbrom/community-skills/issues/1)): `gtsummary`, `survival`, `roxygen2`, `pkgdown`, `styler`, `lintr`, `marginaleffects`, `quarto`, `devtools`, `usethis`, `brms`, `lavaan`, `RefManageR`, `tinytable`, `rmarkdown`. Examples from the wider set: `dplyr`, `ggplot2`, `rlang`, `tibble`, `vctrs`, `purrr`, `stringr`, `cli`, `glue`, `Rcpp`. The full list and the audit results live at [`skills/README.md`](skills/README.md).

## Porting an R package to the hub (5 steps)

The bgumbel skill is the worked example; [`docs/adding_r_skill.md`](docs/adding_r_skill.md) walks the steps in detail.

1. **Pick the package and the surface.** Choose a permissive license (MIT, Apache 2, BSD, GPL-compatible). List the 3 to 15 functions an agent will plausibly call. Skills do not need to expose every public function of the upstream package.
2. **Copy the scaffold.** From the repo root: `cp -r templates/new_r_skill skills/<your-name>`.
3. **Fill `SKILL.md`.** Front matter declares `runtime: r`, `package`, `license`, `maintainer`. The body lists each exposed function with input and output JSON schemas plus a worked example.
4. **Adapt `invoke.R`.** Read one JSON object from stdin, route on the `fn` field, call the wrapped function, write one JSON object to stdout. On failure write `{"ok": false, "error": "..."}` and exit non-zero.
5. **Add a smoke test and open a PR.** Drop a file under `tests/test_skills/test_<your-name>.py`. The CI workflow installs the upstream package, runs your test, and gates the merge.

`bridges/r.py` is shared across all R skills; you do not write a new bridge for your skill.

## Running tests

```bash
pip install -e ".[dev]"
python -m pytest tests/ -v
```

Network-bound tests (full CRAN download, Ollama call) are skipped by default and gated behind `CRAN_GRAPH_NETWORK=1`. Per-skill smoke tests under `tests/test_skills/` are skipped automatically when the upstream R package is not installed locally; CI installs the relevant subset and runs them green. Current status: 182 passed, 128 skipped on 2026-05-11.

## Roadmap

| Version | Planned content |
|---|---|
| v0.1.0 (2026-05-06) | Pattern + R bridge + bgumbel skill. |
| v0.2.0+ | `cran_graph` + `cran_publisher` + `cran_workflow` (internal Python infra exposed as agent-callable skills) + the first wave of curated CRAN R skills generated through the staging pipeline; each promoted skill ships in its own minor release with its own Zenodo DOI. |
| ongoing | Each merged PR that adds an R skill ships in a minor release. The scope is R; Python and Julia external-package wrappers are out of scope (decision 2026-05-09). |

Acceptance criteria for new skills are in [CONTRIBUTING.md](CONTRIBUTING.md).

### Sister project: harness

A separate R package, `harness`, consumes this hub as a curated catalogue. It packages each professional R role (data scientist, statistician, ML engineer, package maintainer, paper author, performance engineer, and ten others) as a YAML harness that subsets the skills here, supplies a role-specific system prompt and folder convention, and launches the user's CLI coder of choice (claude, opencode, codex, aider, gemini-cli) in a Terminal tab. `harness` lives under `r-cs-packages/harness/` and ships from its own repository on its own CRAN cycle, with the same MIT licence as this hub. The skill-curation queue that feeds `harness` v0.1 is tracked in [issue #1](https://github.com/pcbrom/community-skills/issues/1).

## Genealogy

This hub continues a line of agent-tooling work by the maintainer:

- [autoresearch](https://github.com/pcbrom/autoresearch) (DOI [10.5281/zenodo.19772195](https://doi.org/10.5281/zenodo.19772195)) generalizes the autonomous research loop pattern released by [Andrej Karpathy](https://github.com/karpathy/autoresearch) as a Python package, with a JSON-Schema-constrained LLM critic.
- community-skills applies the *package-as-skill* pattern to the CRAN ecosystem, with the same emphasis on machine-readable contracts and subprocess-level isolation.

## Citation

If you use community-skills, please cite the version you used. The Zenodo DOI evolves with each release; consult [`CITATION.cff`](CITATION.cff) or [`docs/citation.md`](docs/citation.md).

### v0.2.0

Brom, P. C. (2026). community-skills: An R-focused hub of agent-callable skills for the CRAN ecosystem (v0.2.0) (0.2.0). Zenodo. https://doi.org/10.5281/zenodo.20543565

```bibtex
@software{brom2026community_skills_v020,
  author    = {Brom, Pedro Carvalho},
  title     = {community-skills: An R-focused hub of agent-callable skills for the CRAN ecosystem (v0.2.0)},
  year      = {2026},
  version   = {0.2.0},
  publisher = {Zenodo},
  doi       = {10.5281/zenodo.20543565},
  url       = {https://doi.org/10.5281/zenodo.20543565}
}
```

The concept DOI [`10.5281/zenodo.20543564`](https://doi.org/10.5281/zenodo.20543564) resolves to the latest published version and is the right anchor when the exact version is not the point.

## License

MIT, see [LICENSE](LICENSE).
