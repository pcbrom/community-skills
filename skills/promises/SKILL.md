---
name: promises
runtime: r
package: promises
package_source: CRAN
package_url: https://rstudio.github.io/promises/
package_version_pinned: ">=1.5.0"
license: MIT
maintainer: "Barret Schloerke <barret@posit.co>"
---

# Skill: promises

The promises package provides abstractions for asynchronous programming in R. It allows a single R process to orchestrate multiple background tasks without blocking the main session.

An agent should use this skill when it needs to manage concurrent operations, handle tasks that resolve at a later time, or implement non-blocking workflows involving background workers.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.anc("promises")`.

## Functions exposed

### promise: Create a new promise object

**Input**

```json
{
  "fn": "promise",
  "expr": "function(resolve, reject)"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "promise",
  "result": "promise"
}
```

### then: Chain operations to a promise

**Input**

```json
{
  "fn": "then",
  "p": "promise",
  "onFulfilled": "function",
  "onRejected": "function"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "then",
  "result": "promise"
}
```

### is.promise: Check if an object is a promise

**Input**

```json
{
  "fn": "is.promise",
  "x": "any"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "is.promise",
  "result": "boolean"
}
```

### hybrid_then: Execute handlers synchronously or asynchronously

**Input**

```json
{
  "fn": "hybrid_then",
  "x": "any",
  "on_success": "function",
  "on_failure": "function"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "hybrid_then",
  "result": "any"
}
```

### future_promise_queue: Execute work using a future queue

**Input**

```json
{
  "fn": "future_promise_queue",
  "expr": "expression"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "future_promise_queue",
  "result": "promise"
}
```

## When to invoke

- When an agent must initiate a long-running computation and continue executing other R commands.
- When managing a queue of background tasks to prevent blocking the main R session when workers are unavailable.
- When processing data streams where the arrival of results is non-deterministic.
- When implementing error handling logic that must apply to both synchronous and asynchronous data types.

## Error contract

```json
{
  "ok": false,
  "fn": "<requested>",
  "error": "<human-readable message>"
}
```

## Worked example

```bash
echo '{"fn": "is.promise", "x": null}' | Rscript --vanilla skills/promises/invoke.R
```
