---
name: ps
runtime: r
package: ps
package_source: CRAN
package_url: https://github.com/r-lib/ps
package_version_pinned: ">=1.9.3"
license: MIT
maintainer: "Gábor Csárdi <csardi.gabor@gmail.com>"
---

# Skill: ps

The ps package provides an interface to list, query, and manipulate system processes across Windows, Linux, and macOS. An agent should use this skill when it needs to inspect the current process table, monitor system resource usage, or manage running applications and their child processes.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("ps")`.

## Functions exposed

### ps: Retrieve the current process table

**Input**

```json
{ "fn": "ps", "args": {} }
```

**Output**

```json
{ "ok": true, "fn": "ps", "result": { "type": "array", "items": { "type": "object" } } }
```

### ps_pids: List all active process IDs

**Input**

```json
{ "fn": "ps_pids", "args": {} }
```

**Output**

```json
{ "ok": true, "fn": "ps_pids", "result": { "type": "array", "items": { "type": "integer" } } }
```

### ps_name: Get the name of a specific process

**Input**

```json
{ "fn": "ps_name", "pid": { "type": "integer" } }
```

**Output**

```json
{ "ok": true, "fn": "ps_name", "result": { "type": "string" } }
```

### ps_cpu_count: Get the number of CPUs available

**Input**

```json
{ "fn": "ps_cpu_count", "args": {} }
```

**Output**

```json
{ "ok": true, "fn": "ps_cpu_count", "result": { "type": "integer" } }
```

### ps_memory_info: Get memory usage details for a process

**Input**

```json
{ "fn": "ps_memory_info", "pid": { "type": "integer" } }
```

**Output**

```json
{ "ok": true, "fn": "ps_memory_info", "result": { "type": "object" } }
```

## When to invoke

- Identifying the PID of a specific running application by name.
- Monitoring system-wide CPU or memory consumption.
- Checking for the existence of a specific process before executing a command.
- Inspecting the process tree to find parent or child processes.
- Retrieating system-level information such as OS type or CPU count.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "ps_pids", "args": {}}' | Rscript --vanilla skills/ps/invoke.R
```
