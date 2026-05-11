---
name: cran_workflow
runtime: python
package: cran_workflow
package_source: in-tree (composition)
package_url: https://github.com/pcbrom/community-skills
package_version_pinned: ">=0.1.0"
license: MIT
maintainer: "Pedro Carvalho Brom <pcbrom@gmail.com>"
---

# Skill: cran_workflow

Higher-order skill that composes `cran_graph` and `cran_publisher`
behind one JSON contract. The agent supplies the path to a CRAN
package source tree on disk, and the workflow runs a small playbook
that mirrors how a human maintainer would prepare a release:

1. Open the local CRAN snapshot.
2. Resolve the install closure of the package; report the deprecation
   status of every transitive dependency.
3. Run `R CMD check` against the source tree, parse the log, classify
   each issue.
4. Optionally hand the issue set to the Phase 5.3 Gemma-only fix loop
   (`run_full_session`) and produce the structured Markdown report.

The canonical case study is `bgumbel`. The workflow does not submit to
CRAN; the submit gate is Phase 5.4 and stays human-supervised.

## Prerequisites

- Python 3.10+ on `PATH`.
- A `cran_graph` SQLite snapshot (build with `cran-graph build`).
- R on `PATH` (only when `fn` is `audit_release` or
  `fix_and_report`).
- `git` on `PATH` (only when `fn` is `fix_and_report`).
- Ollama running locally with a Gemma model (only when `fn` is
  `fix_and_report`).

## Functions exposed

### `audit_release`: pre-release dependency and check audit (read-only)

Resolves the install closure of the package, then runs `R CMD check`
on its source tree, then categorizes each issue. No git operations,
no LLM calls. Useful as a one-call "where do I stand?" query.

**Input**

```json
{
  "fn": "audit_release",
  "snapshot": "string (path to cran_graph SQLite snapshot)",
  "package_name": "string (the package name as it appears in the snapshot)",
  "package_dir": "string (path to the unpacked source tree)",
  "strict_active": "boolean (optional; default false; flag soft/strong-deprecated deps as conflicts)",
  "r_version": "string (optional; checked against `Depends: R (op X)` edges)"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "audit_release",
  "result": {
    "closure": {
      "install_set": "array of strings",
      "install_count": "integer",
      "by_status": "object",
      "warnings": "array",
      "conflicts": "array"
    },
    "check": {
      "exit_code": "integer",
      "n_errors": "integer",
      "n_warnings": "integer",
      "n_notes": "integer",
      "by_category": "object",
      "issues": "array of {verdict, category, description}"
    },
    "passes_cran": "boolean (no ERROR and no WARNING)"
  }
}
```

### `fix_and_report`: run the Phase 5.3 Gemma-only fix loop + render the report

Calls `cran_publisher.run_full_session` and returns both the session
summary and the rendered Markdown report. Writes the report to disk
when `report_path` is supplied.

**Input**

```json
{
  "fn": "fix_and_report",
  "repo_root": "string (path to the git work tree)",
  "package_dir": "string (path to the package source; often equal to repo_root)",
  "package_name": "string (display name used in the report)",
  "audit_path": "string (where to append the JSONL audit; default data/fix_session.jsonl)",
  "report_path": "string (optional; where to write the rendered report.md)",
  "max_attempts_per_issue": "integer (optional; default 5)",
  "soft_wall_clock_s": "number (optional; default 180)",
  "hard_wall_clock_s": "number (optional; default 600)"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "fix_and_report",
  "result": {
    "run_branch": "string",
    "n_attempts": "integer",
    "n_accepted": "integer",
    "soft_cap_hit": "boolean",
    "hard_cap_hit": "boolean",
    "report_markdown": "string (the rendered report, truncated to 16 KB)",
    "report_path": "string or null"
  }
}
```

## When to invoke

- An agent is preparing a CRAN release on behalf of a maintainer and
  needs the "where do I stand?" view before deciding whether to spend
  wall-clock on the fix loop.
- An agent has decided to invest the fix loop budget and wants the
  whole pipeline (loop + report) in one JSON round-trip.
- Documentation or training material needs a worked example combining
  cran_graph (graph-side) and cran_publisher (publish-side); the
  workflow is the canonical bridge.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

Examples: required field missing; snapshot not present; `R CMD check`
fails to spawn; the repo has uncommitted changes; the package is
absent from the snapshot.

## Worked example (bgumbel)

```bash
# Step 1: audit the release.
echo '{
  "fn": "audit_release",
  "snapshot": "data/cran_snapshot_2026-05-09.sqlite",
  "package_name": "bgumbel",
  "package_dir": "cran_graph_extra/bgumbel"
}' | python3 skills/cran_workflow/invoke.py

# Step 2 (after the audit confirms blockers): run the fix loop and render the report.
echo '{
  "fn": "fix_and_report",
  "repo_root": "cran_graph_extra/bgumbel",
  "package_dir": "cran_graph_extra/bgumbel",
  "package_name": "bgumbel",
  "audit_path": "data/fix_session_bgumbel.jsonl",
  "report_path": "data/report_bgumbel.md",
  "max_attempts_per_issue": 5
}' | python3 skills/cran_workflow/invoke.py
```
