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

### `run_check`: run `R CMD check` against a package source tree

**Input**

```json
{
  "fn": "run_check",
  "package_dir": "string (filesystem path to the package source)",
  "flags": "array of strings (optional; default: ['--as-cran', '--no-manual', '--no-build-vignettes'])",
  "timeout": "number (optional; wall-clock seconds; default: 600)"
}
```

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
