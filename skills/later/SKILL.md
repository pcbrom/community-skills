---
name: later
runtime: r
package: later
package_source: CRAN
package_url: https://later.r-lib.org
package_version_pinned: ">=1.4.8"
license: MIT
maintainer: "Charlie Gao <charlie.gao@posit.co>"
---

# Skill: later

The later package provides utilities for scheduling R or C functions to execute after a specified period or when specific system events occur. It manages tasks within an event loop, allowing functions to run after the current R execution stack has emptied.

An agent should use this skill when it needs to manage asynchronous task scheduling, implement delayed execution of R code, or monitor file descriptor readiness within an event loop.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("later")`.

## Functions exposed

### `later`: Schedule an R function or formula to run after a specified period

**Input**

```json
{
  "fn": "later",
  "x": "function or formula",
  "delay": "number (seconds)"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "later",
  "result": "null"
}
```

### `later_fd`: Schedule a function to run when file descriptors are ready

**Input**

```json
{
  "fn": "later_fd",
  "f": "function",
  "fds": "array of integers",
  "timeout": "number (seconds)"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "later_fd",
  "result": "null"
}
```

### `loop_empty`: Check if the event loop contains no scheduled callbacks

**Input**

```json
{
  "fn": "loop_empty"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "loop_empty",
  "result": "boolean"
}
```

### `run_now`: Execute all currently pending tasks in the event loop

**Input**

```json
{
  "fn": "run_now"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "run_now",
  "result": "null"
}
```

## When to invoke

*   When a task requires execution after a specific time delay, such as a delayed retry of a network request.
*   When monitoring system-level events, such as checking if a file descriptor is ready for reading or writing.
*   When managing private event loops to isolate asynchronous operations from the global R execution state.
*   When verifying if any background processes or scheduled callbacks remain in the queue.

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
echo '{"fn": "later", "x": "function() { print(\"delayed\") }", "delay": 1}' | Rscript --vanilla skills/later/invoke.R
```
