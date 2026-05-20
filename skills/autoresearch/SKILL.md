---
name: autoresearch
runtime: python
package: autoresearch
package_source: PyPI / source
package_url: https://github.com/pcbrom/autoresearch
package_version_pinned: ">=0.1.0"
license: MIT
maintainer: "Pedro Carvalho Brom <pcbrom@gmail.com>"
---

# Skill: autoresearch

Wraps the autoresearch package (DOI [10.5281/zenodo.19772195](https://doi.org/10.5281/zenodo.19772195)) as an LLM-callable skill. autoresearch generalizes Karpathy's autonomous-optimization loop as a Python library: a runner that mutates a single file, executes an experiment, extracts a metric, and either advances or resets the git head, plus a JSON-schema-constrained LLM critic that proposes the next change. The skill exposes the six single-shot CLI subcommands; the long-running `loop` and the interactive `wizard` are out of scope because they violate the JSON-in / JSON-out contract.

This skill is the instrumental anchor of Phase 6 of the cran-graph sprint: the same `propose-validate-iterate` loop becomes the motor of `forks/glmnet-fast/` and `forks/survival-fast/` optimization with the equivalence harness gating each iteration.

## Prerequisites

- Python 3.10 or later available on `PATH`.
- `autoresearch` installed (`pip install autoresearch` or editable install of the source). The `autoresearch` CLI binary must be on `PATH`.
- For `critic` and `loop` (the latter not exposed here), Ollama running locally with a Gemma model loaded, configured via the project's `config.yaml`.

## Functions exposed

The dispatcher selects on the `fn` field of the JSON payload. Each function invokes the corresponding `autoresearch <subcommand>` and returns the subprocess outcome plus the captured stdout / stderr (truncated).

### `init`: scaffold a new project from a problem.yaml

**Input**

```json
{
  "fn": "init",
  "problem": "string (path to the problem.yaml)",
  "target": "string (path to the directory where the project will be scaffolded)",
  "tag": "string (optional; short label appended to the project name)"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "init",
  "result": {
    "exit_code": "integer",
    "stdout": "string",
    "stderr": "string"
  }
}
```

### `run`: run one experiment iteration

**Input**

```json
{
  "fn": "run",
  "problem": "string (optional; path to the problem.yaml of the active project)"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "run",
  "result": {
    "exit_code": "integer",
    "stdout": "string",
    "stderr": "string"
  }
}
```

### `critic`: ask the LLM critic for one proposal

**Input**

```json
{
  "fn": "critic",
  "problem": "string (optional; path to problem.yaml)",
  "dry_run": "boolean (optional; default false; skip the network round-trip)"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "critic",
  "result": {
    "exit_code": "integer",
    "stdout": "string (the proposal JSON or a dry-run message)",
    "stderr": "string"
  }
}
```

### `analyze`: summarize the results.tsv of the active project

**Input**

```json
{
  "fn": "analyze",
  "project": "string (optional; path to project directory)",
  "problem": "string (optional; path to problem.yaml)",
  "lower_is_better": "boolean (optional; default true)"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "analyze",
  "result": {
    "exit_code": "integer",
    "stdout": "string",
    "stderr": "string"
  }
}
```

### `audit`: render the consolidated AUDIT_LOG of the active project

**Input**

```json
{
  "fn": "audit",
  "problem": "string (optional)",
  "out_md": "string (optional; default AUDIT_LOG.md)",
  "out_json": "string (optional; default AUDIT_LOG.json)"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "audit",
  "result": {
    "exit_code": "integer",
    "stdout": "string",
    "stderr": "string"
  }
}
```

### `state`: regenerate the STATE.md snapshot

**Input**

```json
{
  "fn": "state",
  "problem": "string (optional)",
  "force": "boolean (optional; default false; rebuilds even if state is recent)"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "state",
  "result": {
    "exit_code": "integer",
    "stdout": "string",
    "stderr": "string"
  }
}
```

## When to invoke

- The agent is setting up a new optimization project and wants to scaffold from a `problem.yaml` template.
- The agent supervises an iterative optimization run and wants to dispatch one experiment iteration per turn rather than block on the long-running loop.
- The agent needs a fresh proposal from the local LLM critic for analyst review.
- The agent ingests the project's `results.tsv` or `AUDIT_LOG.md` and wants the canonical summary instead of parsing the file by hand.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

Examples: required field missing (`problem`/`target` for `init`); `autoresearch` binary not on `PATH`; the subprocess exited non-zero (`stdout` / `stderr` attached for diagnosis); the project directory does not exist.

## Worked example

```bash
echo '{"fn": "critic", "dry_run": true}' | python3 skills/autoresearch/invoke.py
```
