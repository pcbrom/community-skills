---
name: evaluate
runtime: r
package: evaluate
package_source: CRAN
package_url: https://evaluate.r-lib.org/
package_version_pinned: ">=1.0.5"
license: MIT
maintainer: "Hadley Wickham <hadley@posit.co>"
---

# Skill: evaluate

The evaluate package provides tools to parse and evaluate R code while capturing all side effects. It recreates the behavior of the R command line by capturing messages, warnings, errors, and output in the order they occur.

An agent should use this skill when it needs to execute R code strings and capture the full context of the execution, including interleaved console output and graphics device states, rather than just the final returned value.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("evaluate")`.

## Functions exposed

### evaluate: Evaluate input and return all details of evaluation

**Input**

```json
{ "fn": "evaluate", "code": { "type": "array", "items": { "type": "string" } } }
```

**Output**

```json
{ "ok": true, "fn": "evaluate", "result": { "type": "object" } }
```

### create_traceback: Generate a traceback from a list of calls

**Input**

```json
{ "fn": "create_traceback", "calls": { "type": "array", "items": { "type": "object" } } }
```

**Output**

```json
{ "ok": true, "fn": "create_traceback", "result": { "type": "string" } }
```

### inject_funs: Inject functions into the environment of evaluate

**Input**

```json
{ "fn": "inject_funs", "funs": { "type": "object" } }
```

**Output**

```json
{ "ok": true, "fn": "inject_funs", "result": { "type": "NULL" } }
```

## When to invoke

*   Executing a sequence of R expressions where the order of printed output, warnings, and errors must be preserved.
*   Testing R code snippets to verify that specific messages or warnings are triggered during execution.
*   Simulating R console behavior for automated code verification tasks.
*   Intercepting system calls during code evaluation by replacing functions within the evaluation environment.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "evaluate", "code": ["1 + 1", "print(\"hello\")"]}' | Rscript --vanilla skills/evaluate/invoke.R
```
