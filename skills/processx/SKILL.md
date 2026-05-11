---
name: processx
runtime: r
package: processx
package_source: CRAN
package_url: https://processx.r-lib.org
package_version_pinned: ">=3.9.0"
license: MIT
maintainer: "Gábor Csárdi <csardi.gabor@gmail.com>"
---

# Skill: processx

The processx package provides tools to execute and control system processes in the background. It allows for monitoring background processes, waiting for completion, retrieving exit statuses, and terminating processes.

The skill is triggered when an agent needs to run external system commands, manage a sequence of piped processes, or monitor the standard output and error streams of non-blocking connections.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("processx")`.

## Functions exposed

### run: Execute a command and wait for it to finish

**Input**

```json
{
  "fn": "run",
  "command": { "type": "string" },
  "args": { "type": "array", "items": { "type": "string" } },
  "error_on_status": { "type": "boolean" },
  "stdout": { "type": "string" },
  "stderr": { "type": "string" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "run",
  "result": {
    "status": { "type": "integer" },
    "stdout": { "type": "string" },
    "stderr": { "type": "string" }
  }
}
```

### pipeline: Create a sequence of connected processes

**Input**

```json
{
  "fn": "pipeline",
  "commands": {
    "type": "array",
    "items": {
      "type": "array",
      "items": { "type": "string" }
    }
  },
  "stdin": { "type": "string" },
  "stdout": { "type": "string" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "pipeline",
  "result": {
    "type": "object",
    "description": "A handle to the pipeline object"
  }
}
```

### base64_decode: Decode a base64 encoded string

**Input**

```json
{
  "fn": "base64_decode",
  "input": { "type": "string" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "base64_decode",
  "result": { "type": "string" }
}
```

## When to invoke

- Running shell commands or external binaries to perform file transformations.
- Constructing Unix-style pipelines where the output of one command serves as the input to another.
- Decoding data encoded in base64 format.
- Monitoring the execution status and error streams of background system tasks.

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
echo '{"fn": "run", "command": "ls", "args": ["-l"]}' | Rscript --vanilla skills/processx/invoke.R
```
