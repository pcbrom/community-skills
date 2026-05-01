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

## Available skills

| Skill | Runtime | Wraps | Functions exposed | Status |
|---|---|---|---|---|
| [bgumbel](bgumbel/) | R | [pcbrom/bgumbel](https://github.com/pcbrom/bgumbel) (CRAN, ~48K downloads, 10 citing papers) | 7 (density, CDF, quantile, samples, two moments, MLE) | v0.1.0 |

The list above grows by community contribution. Open an issue with the [`new_skill` template](../.github/ISSUE_TEMPLATE/new_skill.yml) to propose a wrap.

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
