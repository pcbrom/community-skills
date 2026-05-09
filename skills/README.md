# Skills index

Each subdirectory of `skills/` is a self-contained, agent-callable wrapping of one upstream package. The structure is identical across runtimes so an agent can navigate any skill without prior knowledge of the wrapped package.

## Hierarchy of a single skill

```
skills/<skill-name>/
├── SKILL.md      # machine-readable contract (front matter + per-function schemas)
├── invoke.<ext>  # native-language dispatcher (R: invoke.R, Python: invoke.py, Julia: invoke.jl)
├── invoke.py     # optional Python wrapper that re-exports via the bridge
├── README.md     # human-friendly usage from shell, Python, and inside an agent
└── CITATION.md   # how to cite both the upstream package and this hub release
```

The bridge (`bridges/<runtime>.py`) is shared across all skills of the same runtime; you do not write a new bridge per skill.

## Available skills (promoted)

| Skill | Runtime | Wraps | Functions exposed | Status |
|---|---|---|---|---|
| [bgumbel](bgumbel/) | R | [pcbrom/bgumbel](https://github.com/pcbrom/bgumbel) (CRAN, ~48K downloads, 10 citing papers) | 7 (density, CDF, quantile, samples, two moments, MLE) | v0.1.0 |

The list above grows by community contribution. Open an issue with the [`new_skill` template](../.github/ISSUE_TEMPLATE/new_skill.yml) to propose a wrap.

## Staging (LLM-generated drafts awaiting human review)

The `_staging/` directory holds SKILL.md drafts produced by the curated CRAN-skill generation pipeline (cranlogs ranking + tarball metadata + Gemma 4 26b-fast via Ollama, documented in [`docs/skill_generation.md`](../docs/skill_generation.md)). The directory is gitignored: drafts must pass human review and gain a hand-written `invoke.R` before promotion to a top-level entry in this gallery.

Staging snapshot (2026-05-09): 91 drafts covering essentially the full top-100 most-downloaded CRAN packages of the last month (the cranlogs API caps the response at 100 entries; 91 of those survived the deprecation and existing-skill filters, plus a single `car` failed validation after retries). Validator-clean (frontmatter, required sections, no em-dash, no forbidden terms). Average generation time 7.8 seconds per skill on Gemma 4 26b-fast running locally via Ollama, zero monetary cost. Examples in staging include `rlang`, `cli`, `vctrs`, `ggplot2`, `lifecycle`, `dplyr`, `Rcpp`, `magrittr`, `glue`, `R6`, `tibble`, `fs`, `withr`, `cpp11`, `jsonlite`, `S7`, `pillar`, `purrr`, `scales`, `curl`, `rmarkdown`, `stringr`, `xfun`, `bslib`, `utf8`, `generics`, `tidyr`, `gtable`, `viridisLite`, `isoband`, `knitr`, `sass`, `crayon`, `digest`, `httr`, `htmltools`, `RcppEigen`, `data.table`, `shiny`, `later`, and so on.

## Adding your own example (5 steps)

The same recipe works for any upstream package whose runtime is already supported (today: R; Python and Julia bridges are placeholders open for community contribution).

1. **Choose a package.** Pick something with a permissive license, a small surface (3-15 functions), and a real use case for an agent.
2. **Copy the scaffold.** From the repo root: `cp -r templates/new_r_skill skills/<your-name>` (use `new_python_skill` or `new_julia_skill` once those bridges land).
3. **Fill `SKILL.md`.** Declare `runtime` in the front matter. Document each function with input and output JSON schemas. Use the bgumbel skill as the reference style.
4. **Adapt `invoke.<ext>`.** Read JSON from stdin, dispatch on the `fn` field, write JSON to stdout. Errors must return `{"ok": false, "error": "..."}` with a non-zero exit status so the bridge can surface them cleanly.
5. **Add a smoke test.** Drop a file under `tests/test_skills/test_<your-name>.py`. The CI workflow runs it on every push and PR.

Open a pull request. The maintainer reviews; CI must be green to merge.

## Contract checklist before opening a PR

- [ ] `SKILL.md` declares `runtime`, `package`, `package_source`, `license`, `maintainer` in the front matter.
- [ ] Every exposed function has input and output schemas in the body.
- [ ] `invoke.<ext>` handles missing fields, invalid types, and upstream errors gracefully.
- [ ] `README.md` covers shell + Python + agent usage with at least one runnable example.
- [ ] `CITATION.md` credits the upstream package authors and links the canonical paper or release.
- [ ] `tests/test_skills/test_<your-name>.py` exercises at least one nontrivial input/output pair.
- [ ] CI is green.
