---
name: shiny
runtime: r
package: shiny
package_source: CRAN
package_url: https://shiny.posit.co/
package_version_pinned: ">=1.13.0"
license: MIT
maintainer: "Carson Sievert <carson@posit.co>"
---

# Skill: shiny

Shiny is a web application framework for R. It enables the creation of interactive web applications through automatic reactive binding between inputs and outputs.

An agent should use this skill when tasks involve constructing user interfaces, managing reactive computations, or simulating Shiny session environments for testing purposes.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("shiny")`.

## Functions exposed

### ExtendedTask: Manage background computations

**Input**

```json
{
  "fn": "ExtendedTask",
  "expr": "function"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "ExtendedTask",
  "result": "object"
}
```

### MockShinySession: Simulate a Shiny session for testing

**Input**

```json
{
  "fn": "MockShinySession",
  "args": "list"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "MockShinySession",
  "result": "object"
}
```

### NS: Create namespaced IDs for modules

**Input**

```json
{
  "fn": "NS",
  "ns": "string",
  "id": "string"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "NS",
  "result": "string"
}
```

### Progress: Report computation progress via object-oriented API

**Input**

```json
{
  "fn": "Progress",
  "session": "object",
  "min": "number",
  "max": "number"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "Progress",
  "result": "object"
}
```

## When to invoke

- Creating interactive web interfaces that require reactive bindings between user inputs and R-based outputs.
- Implementing background processing for long-running computations to prevent session blocking.
- Developing unit tests for Shiny modules by simulating session behavior and input states.
- Implementing progress bars and status indicators for iterative computational tasks.

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
echo '{"fn": "NS", "ns": "module_id", "id": "input_id"}' | Rscript --vanilla skills/shiny/invoke.R
```
