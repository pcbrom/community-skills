---
name: sys
runtime: r
package: sys
package_source: CRAN
package_url: https://jeroen.r-universe.dev/sys
package_version_pinned: ">=3.4.3"
license: MIT
maintainer: "Jeroen Ooms <jeroenooms@gmail.com>"
---

# Skill: sys

The sys package provides tools for executing system commands from R with fine control over process behavior. It serves as a replacement for base R system functions, offering capabilities for managing background tasks, handling timeouts, and streaming input/output streams.

An agent should use this skill when it needs to execute shell commands, run R scripts as external processes, or manage long-running system tasks that require monitoring or interruption.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("sys")`.

## Functions exposed

### exec_wait: Execute a command and wait for completion

**Input**

```json
{
  "fn": "exec_wait",
  "command": "string",
  "args": "array of strings",
  "stdout": "boolean",
  "stderr": "boolean",
  "timeout": "number"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "exec_wait",
  "result": {
    "status": "integer",
    "stdout": "string or null",
    "stderr": "string or null"
  }
}
```

### exec_internal: Execute a command and capture output streams

**Input**

```json
{
  "fn": "exec_internal",
  "command": "string",
  "args": "array of strings",
  "stdin": "string or file path"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "exec_internal",
  "result": {
    "status": "integer",
    "stdout": "raw vector",
    "stderr": "raw vector"
  }
}
```

### r_wait: Execute an R command via Rscript

**Input**

```json
{
  "fn": "r_wait",
  "args": "array of strings",
  "std_in": "string or file path"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "r_wait",
  "result": {
    "status": "integer"
  }
}
```

### as_text: Convert raw vectors to text

**Input**

```json
{
  "fn": "as_text",
  "raw_vector": "array of integers"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "as_text",
  "result": "string"
}
```

## When to invoke

* Executing system-level utilities such as `ping`, `git`, or `curl` to verify network connectivity or repository states.
* Running R scripts as independent processes to prevent memory leakage in the main session.
* Automating shell-based file manipulations or system configuration checks.
* Processing binary stream outputs from system commands into readable text formats.

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
echo '{"fn": "exec_wait", "command": "date", "args": []}' | Rscript --vanilla skills/sys/invoke.R
```
