---
name: withr
runtime: r
package: withr
package_source: CRAN
package_url: https://withr.r-lib.org
package_version_pinned: ">=3.0.2"
license: MIT
maintainer: "Lionel Henry <lionel@posit.co>"
---

# Skill: withr

The withr package provides functions to run code with temporarily modified global state. It allows for the safe management of side effects by ensuring that changes to the environment, file system, or R options are reverted after a specific block of code executes.

An agent should use this skill when a task requires modifying global R settings, directory paths, or system environment variables for a single operation without affecting the subsequent execution context.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("withr")`.

## Functions exposed

### defer: Defer evaluation of an expression to a parent frame

**Input**

```json
{ "fn": "defer", "expr": "string" }
```

**Output**

```json
{ "ok": true, "fn": "defer", "result": null }
```

### local_dir: Temporarily change the working directory

**Input**

```json
{ "fn": "local_dir", "path": "string" }
```

**Output**

```json
{ "ok": true, "fn": "local_dir", "result": null }
```

### local_envvar: Temporarily set an environment variable

**Input**

```json
{ "fn": "local_envvar", "name": "string", "value": "string" }
```

**Output**

```json
{ "ok": true, "fn": "local_envvar", "result": null }
```

### local_options: Temporarily modify R options

**Input**

```json
{ "fn": "local_options", "options": "object" }
```

**Output**

```json
{ "ok": true, "fn": "local_options", "result": null }
```

### local_seed: Temporarily set the random number generator seed

**Input**

```json
{ "fn": "local_seed", "seed": "integer" }
```

**Output**

```json
{ "ok": true, "fn": "local_seed", "result": null }
```

## When to invoke

- When a script must read or write files in a specific directory without changing the global working directory for the entire session.
- When an analysis requires specific R options, such as `stringsAsFactors`, to be active only during a single function call.
- When setting environment variables, such as API keys or library paths, that should not persist after the current task completes.
- When performing simulations that require a fixed seed for reproducibility within a specific block of code.
- When managing temporary files that must be deleted automatically when a function exits.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "local_envvar", "name": "TEST_VAR", "value": "active"}' | Rscript --vanilla skills/withr/invoke.R
```
