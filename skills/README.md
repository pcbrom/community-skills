# Skills index

Each subdirectory of `skills/` is a self-contained, agent-callable wrapping of one upstream package. The structure is identical across runtimes so an agent can navigate any skill without prior knowledge of the wrapped package.

## Hierarchy of a single skill

```
skills/<skill-name>/
├── SKILL.md      # machine-readable contract (front matter + per-function schemas)
├── invoke.R      # R dispatcher when runtime: r
├── invoke.py     # Python dispatcher when runtime: python
├── README.md     # human-friendly usage from shell, Python, and inside an agent (optional)
└── CITATION.md   # how to cite both the upstream package and this hub release (optional)
```

The bridge (`bridges/<runtime>.py`) is shared across all skills of the same runtime; you do not write a new bridge per skill. The project supports two runtimes: `r` (canonical for CRAN packages) and `python` (in-tree infrastructure skills only). Julia is out of scope (decision 2026-05-09).

## Available skills (promoted)

Gallery size as of 2026-05-11: **94 skills**.

### Core skills (5)

| Skill | Runtime | Role | First release |
|---|---|---|---|
| [bgumbel](bgumbel/) | R | canonical R reference; 7 functions over the bimodal Gumbel distribution. Wraps [pcbrom/bgumbel](https://github.com/pcbrom/bgumbel) (CRAN, ~48K downloads, 10 citing papers) | v0.1.0 |
| [cran_graph](cran_graph/) | Python | `build_snapshot`, `stats`, `optimize`, `plot_closure` over the in-tree `cran_graph` sub-package | v0.2.0 |
| [cran_publisher](cran_publisher/) | Python | `run_check`, `parse_log`, `categorize`, `fix_session` over the in-tree `cran_publisher` sub-package | v0.2.0 |
| [cran_workflow](cran_workflow/) | Python | `audit_release`, `fix_and_report`; composes `cran_graph` and `cran_publisher` | v0.2.0 |
| [autoresearch](autoresearch/) | Python | `init`, `run`, `critic`, `analyze`, `audit`, `state` over [pcbrom/autoresearch](https://github.com/pcbrom/autoresearch) ([DOI 10.5281/zenodo.19772195](https://doi.org/10.5281/zenodo.19772195), Trabalho do Dr. Brom); Phase 6 instrumental anchor | v0.2.0 |

### CRAN top-100 R skills (89)

89 R skills drafted with Gemma 4 26b-fast from the cranlogs top-100 of the last month (2026-05-09) and promoted after passing a structural smoke screen described in [`docs/skill_generation.md`](../docs/skill_generation.md). Two of these (`glue`, `jsonlite`) carry hand-written semantic smoke tests on top of the structural check; the other 87 ship the structural stub only and are flagged for per-skill review before any user-visible release. A stratified audit on 2026-05-11 (random sample of 15 from the 28 installed-locally subset, seed 11) returned 15 / 15 structurally valid, 0 functional fails (`data/audit_stratified_2026-05-11.json`).

**Full list:** `abind, askpass, backports, base64enc, bgumbel, bit, bit64, broom, bslib, cachem, callr, cli, commonmark, cpp11, crayon, curl, data.table, DBI, desc, digest, dplyr, evaluate, farver, fastmap, fontawesome, fs, generics, ggplot2, glue, gtable, highr, hms, htmltools, htmlwidgets, httr, isoband, jsonlite, knitr, labeling, later, lifecycle, lme4, lubridate, magrittr, mime, openssl, pillar, pkgbuild, pkgload, prettyunits, processx, progress, promises, ps, purrr, R6, ragg, rappdirs, Rcpp, RcppArmadillo, RcppEigen, readr, readxl, rlang, rprojroot, rstudioapi, S7, sass, scales, shiny, stringi, stringr, sys, systemfonts, testthat, textshaping, tibble, tidyr, tidyselect, timechange, tinytex, tzdb, utf8, vctrs, viridisLite, vroom, withr, xfun, xml2, yaml, zoo`. One package (`rmarkdown`) failed to produce a parse-clean dispatcher across 4 generation attempts and remains in `_staging/` pending manual review.

The list above grows by community contribution. Open an issue with the [`new_skill` template](../.github/ISSUE_TEMPLATE/new_skill.yml) to propose a wrap.

## Staging (LLM-generated drafts awaiting human review)

The `_staging/` directory holds SKILL.md drafts produced by the curated CRAN-skill generation pipeline (cranlogs ranking + tarball metadata + Gemma 4 26b-fast via Ollama, documented in [`docs/skill_generation.md`](../docs/skill_generation.md)). The directory is gitignored: drafts must pass human review and gain a hand-written `invoke.R` before promotion to a top-level entry in this gallery.

Staging snapshot (2026-05-09): 91 drafts covering essentially the full top-100 most-downloaded CRAN packages of the last month (the cranlogs API caps the response at 100 entries; 91 of those survived the deprecation and existing-skill filters, plus a single `car` failed validation after retries). Validator-clean (frontmatter, required sections, no em-dash, no forbidden terms). Average generation time 7.8 seconds per skill on Gemma 4 26b-fast running locally via Ollama, zero monetary cost. Examples in staging include `rlang`, `cli`, `vctrs`, `ggplot2`, `lifecycle`, `dplyr`, `Rcpp`, `magrittr`, `glue`, `R6`, `tibble`, `fs`, `withr`, `cpp11`, `jsonlite`, `S7`, `pillar`, `purrr`, `scales`, `curl`, `rmarkdown`, `stringr`, `xfun`, `bslib`, `utf8`, `generics`, `tidyr`, `gtable`, `viridisLite`, `isoband`, `knitr`, `sass`, `crayon`, `digest`, `httr`, `htmltools`, `RcppEigen`, `data.table`, `shiny`, `later`, and so on.

## Adding your own R skill (5 steps)

The project's scope is R. The 5-step recipe below targets a CRAN package; details and the worked example live in [`docs/adding_r_skill.md`](../docs/adding_r_skill.md).

1. **Choose a package.** Permissive license (MIT, Apache 2, BSD, GPL-compatible), small surface (3-15 functions), and a real use case for an agent.
2. **Copy the scaffold.** From the repo root: `cp -r templates/new_r_skill skills/<your-name>`.
3. **Fill `SKILL.md`.** Declare `runtime: r` in the front matter. Document each function with input and output JSON schemas. Use the bgumbel skill as the reference style.
4. **Adapt `invoke.R`.** Read JSON from stdin, dispatch on the `fn` field, write JSON to stdout. Errors must return `{"ok": false, "error": "..."}` with a non-zero exit status so the bridge can surface them cleanly.
5. **Add a smoke test.** Drop a file under `tests/test_skills/test_<your-name>.py`. The CI workflow runs it on every push and PR.

Open a pull request. The maintainer reviews; CI must be green to merge.

## Contract checklist before opening a PR

- [ ] `SKILL.md` declares `runtime: r`, `package`, `package_source`, `license`, `maintainer` in the front matter.
- [ ] Every exposed function has input and output schemas in the body.
- [ ] `invoke.R` handles missing fields, invalid types, and upstream errors gracefully.
- [ ] (Optional) `README.md` covers shell + Python + agent usage with at least one runnable example.
- [ ] (Optional) `CITATION.md` credits the upstream package authors and links the canonical paper or release.
- [ ] `tests/test_skills/test_<your-name>.py` exercises at least one nontrivial input/output pair.
- [ ] CI is green.
