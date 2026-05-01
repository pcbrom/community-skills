# Contributing to community-skills

Thanks for considering a contribution. This hub grows by accumulating skills from the community: each new skill makes more packages reachable to LLM agents (Claude Code, Codex, OpenCode, and any tool that can spawn a subprocess and exchange JSON).

## Scope

A community-skills entry wraps an existing package from a programming-language ecosystem (R, Python, Julia, Stata, ...) so that an agent can invoke its functions without writing custom glue. The hub is intentionally **agent-agnostic**: contributions must not depend on the internals of any particular IDE or harness.

## Adding a new skill (5 steps)

The recipe below targets an R package. Python and Julia bridges are placeholders today; PRs that implement either bridge are also welcome.

1. **Pick a package**. It must have a permissive license (MIT, BSD, Apache 2, GPL-compatible) and a small, well-defined surface (3-15 functions). Open an [`new_skill` issue](.github/ISSUE_TEMPLATE/new_skill.yml) first if you want to discuss the choice.
2. **Copy the scaffold**. From the repo root: `cp -r templates/new_r_skill skills/<your-skill-name>`. Replace `your-skill-name` with the package's CRAN name in lowercase.
3. **Fill `SKILL.md`**. Declare `runtime: r`. List each function you wrap with: a one-line description, a JSON schema for inputs, a JSON schema for outputs, and a worked example. The `skills/bgumbel/SKILL.md` file is the reference.
4. **Adapt `invoke.R`**. The script reads a JSON object from stdin, dispatches on the `fn` field, calls the package function, and writes a JSON object to stdout. Handle errors by writing `{"ok": false, "error": "..."}` and exiting with status 1.
5. **Add a smoke test**. Drop a file under `tests/test_skills/test_<your-skill-name>.py` mirroring `tests/test_skills/test_bgumbel.py`. The test should call the bridge end-to-end and check at least one nontrivial input/output pair.

Open a pull request. CI runs setup R, installs the wrapped package, and executes pytest. Once it is green, the maintainer reviews and merges.

## Adding a new bridge

Implementing the Python or Julia bridge follows the same pattern as `bridges/r.py`:

- Read JSON from stdin.
- Spawn the runtime's interpreter in a subprocess (Python, Julia).
- The interpreter reads JSON, dispatches on `fn`, calls the wrapped function, writes JSON to stdout.
- Capture stderr and exit codes; surface failures through `{"ok": false, "error": "..."}`.

Open a `new_bridge` discussion issue first so the API stays consistent across runtimes.

## Style and conventions

- Match the existing file structure under `skills/<name>/` and `bridges/<runtime>.py`.
- One function = one entry in `SKILL.md`. Keep schemas minimal; do not invent fields the wrapped function does not accept.
- Errors must be human-legible. If R is missing, the R bridge already returns a clear message; new bridges must do the same.
- License of every contribution must be MIT-compatible. Wrapping a GPL package is allowed when the wrapper is MIT and the GPL package is invoked at arm's length via subprocess.

## Citation

Each release receives a Zenodo DOI. When citing community-skills in academic work, use the DOI of the version you used. See `CITATION.cff` and `docs/citation.md`.
