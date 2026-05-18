---
name: cran_publisher
runtime: python
package: cran_publisher
package_source: in-tree
package_url: https://github.com/pcbrom/community-skills
package_version_pinned: ">=0.1.0"
license: MIT
maintainer: "Pedro Carvalho Brom <pcbrom@gmail.com>"
---

# Skill: cran_publisher

Wraps the in-tree `cran_publisher` Python sub-package as an LLM-callable
skill. The agent invokes one of four contracts: run `R CMD check`
against an unpacked R package source tree; parse a check log into
structured issues; categorize the issues into a short living taxonomy;
or run a full automated fix loop that proposes minimal patches via a
local LLM, validates them through a fresh `R CMD check`, and merges
each accepted patch into a session branch via `git merge --no-ff`.

The fix loop is intended to be run by a human-supervised agent against
its own CRAN package. The merge always happens on a session branch;
the operator is expected to inspect the audit log and the diffs before
fast-forwarding the result onto a publishable branch.

## Prerequisites

- Python 3.10 or later available on `PATH`.
- R installed and on `PATH` (only when `fn` is `run_check` or
  `fix_session`).
- `git` on `PATH` (only when `fn` is `fix_session`).
- Ollama running locally with a `gemma4` model loaded (only when `fn`
  is `fix_session`).
- The community-skills repository checked out: the skill imports the
  in-tree `cran_publisher` Python package via PYTHONPATH.

## Functions exposed

The dispatcher selects on the `fn` field of the JSON payload.

### `run_check`: build the package, then run `R CMD check`

By default the source tree is first turned into a tarball with
`R CMD build` and the check runs against that tarball, which is what
CRAN itself does. This is required for any package whose `DESCRIPTION`
carries only `Authors@R`: the `Author` and `Maintainer` fields are
derived during the build, so a direct check of the unbuilt directory
would abort. Set `build_first` to `false` to check the directory in
place.

**Input**

```json
{
  "fn": "run_check",
  "package_dir": "string (filesystem path to the package source)",
  "flags": "array of strings (optional; R CMD check flags; default: ['--as-cran', '--no-manual', '--no-build-vignettes'])",
  "timeout": "number (optional; wall-clock seconds for the check; default: 600)",
  "build_first": "boolean (optional; default true; build a tarball before checking)",
  "build_flags": "array of strings (optional; R CMD build flags; default: ['--no-build-vignettes', '--no-manual'])",
  "build_timeout": "number (optional; wall-clock seconds for the build; default: 900)"
}
```

To exercise the vignettes, drop `--no-build-vignettes` from both
`flags` and `build_flags`. A compiled package, such as one with a Rust
or C++ component, needs a `timeout` and `build_timeout` large enough
for the full compilation.

**Output**

```json
{
  "ok": true,
  "fn": "run_check",
  "result": {
    "exit_code": "integer",
    "wall_clock_s": "number",
    "timed_out": "boolean",
    "stdout": "string (truncated to 16 KB)",
    "stderr": "string (truncated to 4 KB)"
  }
}
```

### `parse_log`: tokenize a check log into structured issues

**Input**

```json
{
  "fn": "parse_log",
  "stdout": "string (the stdout of R CMD check)"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "parse_log",
  "result": {
    "n_errors": "integer",
    "n_warnings": "integer",
    "n_notes": "integer",
    "issues": [
      {
        "verdict": "ERROR | WARNING | NOTE",
        "description": "string",
        "detail": "string"
      }
    ]
  }
}
```

### `categorize`: parse + classify in one call

**Input**

```json
{
  "fn": "categorize",
  "stdout": "string"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "categorize",
  "result": {
    "n_errors": "integer",
    "n_warnings": "integer",
    "n_notes": "integer",
    "by_category": "object (category -> count)",
    "items": [
      {
        "verdict": "string",
        "description": "string",
        "category": "string",
        "label": "string"
      }
    ]
  }
}
```

### `fix_session`: run the automated fix loop end-to-end

**Input**

```json
{
  "fn": "fix_session",
  "repo_root": "string (path to the git repo root)",
  "package_dir": "string (path to the package source; often equal to repo_root)",
  "audit_path": "string (where to append the JSONL audit; default: data/fix_session.jsonl)",
  "max_attempts_per_issue": "integer (optional; default 3)"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "fix_session",
  "result": {
    "run_branch": "string (the cran-publisher-run-<ts> branch holding accepted commits)",
    "n_attempts": "integer",
    "n_accepted": "integer",
    "attempts": [
      {
        "issue_description": "string",
        "issue_category": "string",
        "attempt_idx": "integer",
        "branch": "string",
        "accepted": "boolean",
        "reason": "string",
        "wall_clock_s": "number"
      }
    ]
  }
}
```

### `submission_preflight`: the submission readiness gate

`R CMD check` answers "does the package check clean". It does not answer
"is this release ready to submit". This function makes the policy checks
the check omits and returns one structured verdict: required `DESCRIPTION`
fields, a release version that is not a development version, a `NEWS`
entry for the version, a populated `cran-comments.md`, the `LICENSE` file,
the last check result, and the built tarball.

It deliberately stops at the verdict. It does not upload anything. The
submission itself, and the confirmation e-mail CRAN sends to the
maintainer, stay with the maintainer by design: that e-mail is the
accountability gate for publishing under a person's name, and removing it
would be removing a deliberate human checkpoint, not adding a feature.

**Input**

```json
{
  "fn": "submission_preflight",
  "package_dir": "string (filesystem path to the package source)",
  "tarball": "string (optional; path to a built source tarball)",
  "check_stdout": "string (optional; stdout of a prior R CMD check; when given, errors and warnings block, and so does a 'CPU time N times elapsed' note, since CRAN's incoming pretest archives a submission that uses more than two cores)"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "submission_preflight",
  "result": {
    "package": "string",
    "version": "string",
    "ready": "boolean (true only when every blocking gate passes)",
    "gates": [
      {
        "name": "string",
        "passed": "boolean or null (null means undetermined)",
        "blocking": "boolean",
        "detail": "string"
      }
    ],
    "blocking_failures": "array of strings (names of the blocking gates that failed)",
    "handoff": "array of strings (the remaining manual steps when ready)"
  }
}
```

Pass `check_stdout` from a clean-environment check, such as win-builder,
rather than a local check whose warnings may be environment artifacts.

### `submit`: the gated CRAN upload

Uploads the package to CRAN through `devtools::submit_cran()`, behind two
gates: the `submission_preflight` must pass, and the caller must pass
`confirm=true`. With `confirm` unset the call is a dry run that reports the
preflight and the command it would run, and uploads nothing.

It stops at the upload. The confirmation e-mail CRAN sends to the
maintainer is never touched: clicking that link is the maintainer's act,
the accountability gate for publishing under a person's name. A skill that
clicked it would be removing a deliberate human checkpoint.

**Input**

```json
{
  "fn": "submit",
  "package_dir": "string (filesystem path to the package source)",
  "confirm": "boolean (the upload runs only when this is exactly true; otherwise the call is a dry run)",
  "check_stdout": "string (optional; stdout of a prior R CMD check, passed to the preflight)",
  "tarball": "string (optional; path to a built source tarball)",
  "timeout": "number (optional; wall-clock seconds for devtools::submit_cran(), which rebuilds the package; default 1800)"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "submit",
  "result": {
    "package": "string",
    "version": "string",
    "uploaded": "boolean (true only when the upload ran and returned success)",
    "dry_run": "boolean (true when confirm was not set)",
    "preflight_ready": "boolean",
    "reason": "string",
    "rscript_exit_code": "integer or null",
    "output": "string (devtools::submit_cran() output, truncated)",
    "next_step": "string"
  }
}
```

After a real upload the submission is still not complete: CRAN e-mails the
maintainer a confirmation link, and clicking it is the maintainer's step,
not the skill's.

## When to invoke

- The agent has a CRAN package source tree on disk and wants the
  current `R CMD check` verdict as a structured object instead of a
  log to parse by hand.
- The agent has an existing check log (perhaps from CI) and wants to
  ask "which issues are blockers?" without rerunning the check.
- The agent wants the issues grouped by kind (missing documentation,
  undefined globals, URL check, license, ...) for prioritization.
- The agent is supervising a CRAN release cycle and wants to attempt
  automated fixes for the easy classes of issue while keeping a clear
  audit trail and a human gate before submission.
- The agent has a package that checks clean and wants the structured
  "is this release ready to submit" verdict before handing off to the
  maintainer for the submission itself.
- The maintainer has decided to submit and wants the upload run behind
  the preflight and confirm gates, stopping at the CRAN confirmation
  e-mail, which stays the maintainer's to click.

## Error contract

Any failure inside the dispatcher returns:

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

Examples: missing required field (`package_dir` for `run_check`),
package directory has no `DESCRIPTION`, R is not installed, Ollama
unreachable, the run repository has uncommitted changes, the proposal
contained an out-of-tree path. The fix-loop function always commits
its accepted patches; failed attempts are reverted via
`git reset --hard` so the run branch only carries clean history.

## Worked examples

```bash
# Parse a check log captured earlier:
cat my_check.log | python3 -c "
import json, sys
payload = {'fn': 'parse_log', 'stdout': open('my_check.log').read()}
print(json.dumps(payload))
" | python3 skills/cran_publisher/invoke.py

# End-to-end fix session against a checked-out CRAN package:
echo '{
  "fn": "fix_session",
  "repo_root": "/path/to/your/cran/package",
  "package_dir": "/path/to/your/cran/package",
  "audit_path": "data/fix_session.jsonl",
  "max_attempts_per_issue": 3
}' | python3 skills/cran_publisher/invoke.py
```
