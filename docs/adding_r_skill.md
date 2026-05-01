# Adding an R skill, end to end

This walkthrough takes you from "I have an R package I want an agent to call"
to "the skill is in the hub, CI is green, my PR is ready to merge". The
bgumbel skill (`skills/bgumbel/`) is the reference implementation; this
document explains every choice you will face when porting your own.

## Before you start

You need:

- An R package on CRAN or GitHub with a permissive license (MIT, BSD, Apache 2,
  or GPL-compatible). Check the `LICENSE` file of the upstream repo.
- A clear idea of which functions an agent might want to call. Three to
  fifteen functions is typical; do not try to expose the entire surface.
- R installed locally with the package working interactively. If
  `install.packages("<your-package>")` and a quick demo do not work in your
  shell, the skill will not work either.

## Step 1: pick the surface

Open an R session and answer:

- Which functions return decisions or quantities an agent would actually
  use? (`fit`, `predict`, `summarize`, sampling functions, density/CDF, etc.)
- Which return objects too complex to serialize (e.g. closures, S4 with
  environments)? Skip those, or expose only their numeric fields.
- Which functions modify global state (`options()`, random seed)? Either
  document the seed convention in `SKILL.md` or expose `seed` as a payload
  field. The bgumbel skill takes `seed` for `rbgumbel`.

Write down the function list. It becomes the body of `SKILL.md`.

## Step 2: copy the scaffold

From the repo root:

```bash
cp -r templates/new_r_skill skills/<your-name>
mv skills/<your-name>/SKILL.md.template      skills/<your-name>/SKILL.md
mv skills/<your-name>/invoke.R.template      skills/<your-name>/invoke.R
mv skills/<your-name>/README.md.template     skills/<your-name>/README.md
chmod +x skills/<your-name>/invoke.R
```

Use the upstream package's CRAN name in lowercase, e.g.
`skills/forecast/`, `skills/lme4/`. Keep one skill per package.

## Step 3: fill SKILL.md

Front matter (between the `---` markers at the top) declares metadata the
hub uses to route and cite:

```yaml
---
name: <your-name>
runtime: r
package: <upstream-r-package-name>
package_source: CRAN          # or GitHub
package_url: https://github.com/<owner>/<repo>
package_version_pinned: ">=X.Y.Z"
license: <MIT|BSD|GPL-3|Apache-2.0>
maintainer: "<Your Name> <you@example.com>"
---
```

Body documents each function with the same template:

````markdown
### `<function_name>` — one-line summary

**Input**

```json
{
  "fn": "<function_name>",
  "<arg>": <type or schema>
}
```

**Output**

```json
{ "ok": true, "fn": "<function_name>", "result": <type> }
```
````

Be explicit about types: `number`, `integer`, `boolean`, `[number, ...]`
(JSON array of numbers), `string`. If a field is optional, say so and give
the default.

## Step 4: adapt invoke.R

The dispatcher is the only piece of code you write. Its job:

1. Load `jsonlite` and the upstream package, with helpful error messages
   if either is missing.
2. Read JSON from stdin.
3. Read `payload$fn` and dispatch to one R function per branch.
4. Return `{"ok": true, "fn": ..., "result": ...}` on success.
5. Return `{"ok": false, "error": "..."}` and `quit(status = 1)` on failure.

Use the bgumbel `invoke.R` as a reference. The pattern is mechanical:

```r
} else if (fn_name == "<your_function>") {
  arg1 <- as.numeric(require_field("<arg1>", payload, fn_name))
  arg2 <- as.numeric(require_field("<arg2>", payload, fn_name))
  out <- <upstream_pkg>::<your_function>(arg1, arg2)
  emit_ok(as.numeric(out), fn_name)
}
```

The helper functions `emit_ok`, `emit_error`, and `require_field` live at the
top of the dispatcher and are shared across all skills. You can keep them
inline (as bgumbel does) or refactor into a sourced helper file later.

### Type marshalling tips

- R returns `NULL` for some operations. `jsonlite::toJSON` serializes
  `NULL` as `null`, which Python parses as `None`. That round-trip is fine.
- Dates are ambiguous; if your function returns dates, decide whether to
  return ISO strings or numeric epoch seconds and document it in `SKILL.md`.
- For named lists, prefer flat objects with explicit keys; nested lists
  serialize cleanly but make schemas larger.

## Step 5: add a smoke test

Create `tests/test_skills/test_<your-name>.py`:

```python
import shutil
import pytest

from bridges import invoke


@pytest.mark.skipif(shutil.which("Rscript") is None, reason="R not installed")
def test_<your_name>_<function_name>_smoke():
    result = invoke("<your-name>", {
        "fn": "<function_name>",
        # ... minimal valid arguments
    })
    assert result["ok"] is True, result
    assert result["fn"] == "<function_name>"
    # Optionally: assert structural properties of result["result"]
```

The test must pass on a fresh CI runner where R has just been installed.
Avoid asserting exact floating-point values; use bounds or tolerances.

## Step 6: run locally

```bash
# From the repo root
pip install -e .
python -m pytest tests/test_skills/test_<your-name>.py -v
```

If the test passes, run the dispatcher manually too:

```bash
echo '{"fn": "<function_name>", ...}' \
  | Rscript --vanilla skills/<your-name>/invoke.R
```

## Step 7: open the PR

Commit message convention:

```
skills: add <your-name> wrapping <upstream-package>

Exposes <list of fn names>. References <link to upstream paper if any>.
```

The CI workflow installs the upstream package and runs the full pytest
matrix. Once green, the maintainer reviews and merges. You are now part
of the hub; thanks for contributing.

## Common pitfalls

- **Mismatched argument names.** R uses snake_case and dot.case
  inconsistently. Always pass arguments by name in `invoke.R`, not by
  position.
- **Side-effecting plotting functions.** If the wrapped function plots,
  wrap the call in `withr::with_pdf(NULL, ...)` or redirect to a file
  the agent can read. Plotting to stdout breaks the JSON contract.
- **Long-running fits.** If a function may exceed 60 seconds (default
  bridge timeout), document it in `SKILL.md` and let the caller pass
  `timeout` to `bridges.invoke`.
- **R's `factor` type.** Convert to `as.character` before serializing,
  or document that the result will be a labelled string vector.
