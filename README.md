# community-skills

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![CI](https://github.com/pcbrom/community-skills/actions/workflows/ci.yml/badge.svg)](https://github.com/pcbrom/community-skills/actions/workflows/ci.yml)
[![Skills: 1](https://img.shields.io/badge/skills-1-blue.svg)](skills/)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.0000000.svg)](https://doi.org/10.5281/zenodo.0000000)

A community hub that exposes packages from any language ecosystem (R, Python, Julia, Stata, ...) as machine-readable skills that LLM agents can invoke autonomously.

## What problem does it solve

A modern R package such as [bgumbel](https://github.com/pcbrom/bgumbel) (+48k CRAN downloads, ten papers cite it) is documented for human readers via roxygen comments and PDF manuals. To call it from a Claude Code, Codex, or OpenCode session, you still write a per-package glue layer by hand: parse a prompt, set up a subprocess, marshal arguments, parse output. Multiply this by every R, Python, or Julia package an agent might want, and the integration overhead becomes the bottleneck.

community-skills documents a single pattern that turns any package into an agent-callable skill, and it ships canonical implementations so you can start invoking them today.

## How it works

Each `skills/<name>/` directory ships:

- `SKILL.md` — a machine-readable contract that declares the skill's runtime (`r`, `python`, `julia`, ...) and lists each exposed function with input and output JSON schemas.
- `invoke.<ext>` — the dispatcher in the package's native language. It reads a JSON object from stdin, routes on the `fn` field, calls the wrapped function, writes a JSON object to stdout.
- `invoke.py` — an optional Python wrapper that re-exports the skill via the appropriate bridge.

Each `bridges/<runtime>.py` is a thin Python adapter that spawns the runtime, sends the JSON payload, and parses the response. Today, `bridges/r.py` is implemented; `bridges/python.py` and `bridges/julia.py` are placeholders that raise `NotImplementedError` and link to the issue tracker for community contribution.

Any agent harness that can run a subprocess and exchange JSON works. There is no IDE-specific dependency.

```
+--------------+      JSON        +-----------+      stdin/stdout        +----------+
|   Agent      | ---------------> | bridge.<r>| -----------------------> | invoke.R |
| (Claude Code,|                  |  (Python) |       JSON               |   (R)    |
|  Codex, ...) | <--------------- |           | <----------------------- |          |
+--------------+      JSON        +-----------+                          +----------+
```

## Repository hierarchy at a glance

```
community-skills/
├── README.md                    <- you are here (community entry point)
├── CONTRIBUTING.md              <- 5-step porting recipe
├── CHANGELOG.md                 <- per-release Zenodo DOI
├── CITATION.cff                 <- machine-readable citation
├── .zenodo.json                 <- Zenodo metadata
├── pyproject.toml               <- pip install community-skills
├── docs/
│   ├── pattern.md               <- design rationale
│   ├── architecture.md          <- system diagram + data flow
│   ├── citation.md              <- BibTeX, APA, CFF, Zenodo
│   └── adding_r_skill.md        <- worked tutorial: port an R package end-to-end
├── bridges/                     <- one Python adapter per runtime (shared by all skills)
│   ├── r.py                     <- subprocess + Rscript + JSON   (implemented)
│   ├── python.py                <- placeholder                   (community PR welcome)
│   └── julia.py                 <- placeholder                   (community PR welcome)
├── skills/                      <- gallery; one subdirectory per wrapped package
│   ├── README.md                <- gallery index + per-skill hierarchy
│   └── bgumbel/                 <- worked example, R runtime
│       ├── SKILL.md             <- runtime + per-function input/output schemas
│       ├── invoke.R             <- dispatcher (reads stdin, writes stdout)
│       ├── invoke.py            <- optional Python wrapper
│       ├── README.md            <- human-friendly usage
│       └── CITATION.md          <- credit upstream + this release
├── templates/
│   ├── new_r_skill/             <- copy-paste scaffold for a new R skill
│   ├── new_python_skill/        <- placeholder
│   └── new_julia_skill/         <- placeholder
├── tests/                       <- pytest matrix; CI runs setup R + install + run
└── .github/
    ├── workflows/ci.yml         <- GitHub Actions: setup R, install bgumbel, pytest
    └── ISSUE_TEMPLATE/          <- `new_skill`, `bug_report`
```

The community-facing path is: read this `README.md`, then [`skills/README.md`](skills/README.md) to see the gallery, then either consume an existing skill or follow [`docs/adding_r_skill.md`](docs/adding_r_skill.md) (or [`CONTRIBUTING.md`](CONTRIBUTING.md)) to wrap your own.

## Available skills

| Skill | Runtime | Wraps | Functions | First release |
|---|---|---|---|---|
| [bgumbel](skills/bgumbel/) | R | [bgumbel](https://github.com/pcbrom/bgumbel) (CRAN, ~48K downloads, 10 citing papers) | `dbgumbel`, `pbgumbel`, `qbgumbel`, `rbgumbel`, `m1bgumbel`, `m2bgumbel`, `mlebgumbel` | v0.1.0 |

More skills land as the community contributes. The full list with status flags is at [`skills/README.md`](skills/README.md).

## Porting a package to agentic coding (5 steps)

The recipe below is the same regardless of the upstream package's language. The bgumbel skill is the worked example; [`docs/adding_r_skill.md`](docs/adding_r_skill.md) walks the steps in detail.

1. **Pick the package and the surface.** Choose a permissive license (MIT, Apache 2, BSD, GPL-compatible). List the 3-15 functions an agent will plausibly call. Skills do not need to expose every public function of the upstream package.
2. **Copy the scaffold.** From the repo root: `cp -r templates/new_r_skill skills/<your-name>` (or `new_python_skill`, `new_julia_skill` when those bridges land).
3. **Fill `SKILL.md`.** Front matter declares `runtime`, `package`, `license`, `maintainer`. Body lists each exposed function with input and output JSON schemas plus a worked example.
4. **Adapt `invoke.<ext>`.** Read one JSON object from stdin, route on the `fn` field, call the wrapped function, write one JSON object to stdout. On failure write `{"ok": false, "error": "..."}` and exit non-zero.
5. **Add a smoke test and open a PR.** Drop a file under `tests/test_skills/test_<your-name>.py`. The CI workflow installs the upstream package, runs your test, and gates the merge.

The `bridges/<runtime>.py` adapter is **shared across all skills** of the same runtime; you do not write a new one for your skill.

## Quick start

Prerequisites: Python 3.10+, R installed and on `PATH`, and the package being wrapped (`install.packages("bgumbel")` for the bgumbel skill).

```bash
git clone https://github.com/pcbrom/community-skills
cd community-skills
pip install -e .

python3 -c "
from bridges import invoke
result = invoke('bgumbel', {
    'fn': 'dbgumbel',
    'x': [-1.0, 0.0, 1.0],
    'mu1': -1.0,
    'mu2': 1.0,
    'delta': 0.5,
})
print(result)
"
# {'ok': True, 'fn': 'dbgumbel', 'result': [...]}
```

From inside an agent session, the same call is a single tool invocation. See [`docs/architecture.md`](docs/architecture.md) for the full diagram and [`docs/pattern.md`](docs/pattern.md) for the design rationale.

## Roadmap

| Version | Planned content |
|---|---|
| v0.1.0 (2026-05-13) | Pattern + R bridge + bgumbel skill. |
| v0.2.0+ | Second skill chosen by community demand (likely Python via subprocess + venv, or Julia). |
| ongoing | Each merged PR that adds a skill or bridge ships in a minor release with its own Zenodo DOI. |

Acceptance criteria for new skills are listed in [CONTRIBUTING.md](CONTRIBUTING.md).

## Genealogy

This hub continues a line of agent-tooling work by the maintainer:

- [autoresearch](https://github.com/pcbrom/autoresearch) (DOI [10.5281/zenodo.19772195](https://doi.org/10.5281/zenodo.19772195)) generalizes the autonomous research loop pattern released by [Andrej Karpathy](https://github.com/karpathy/autoresearch) as a Python package, with a JSON-Schema-constrained LLM critic.
- community-skills generalizes the *package-as-skill* pattern across language ecosystems, with the same emphasis on machine-readable contracts and subprocess-level isolation.

## Citation

If you use community-skills, please cite the version you used. The Zenodo DOI evolves with each release; consult [`CITATION.cff`](CITATION.cff) or [`docs/citation.md`](docs/citation.md).

## License

MIT, see [LICENSE](LICENSE).
