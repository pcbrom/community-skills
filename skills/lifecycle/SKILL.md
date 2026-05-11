---
name: lifecycle
runtime: r
package: lifecycle
package_source: CRAN
package_url: https://lifecycle.r-lib.org/
package_version_pinned: ">=1.0.5"
license: MIT
maintainer: "Lionel Henry <lionel@posit.co>"
---

# Skill: lifecycle

The lifecycle package provides tools to manage the life cycle of R package functions. It enables developers to implement shared conventions for deprecation, documentation badges, and user-friendly warnings.

An agent should use this skill when modifying R package code to implement deprecation logic, signal changes in function status, or generate documentation badges for experimental or superseded features.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("lifecycle")`.

## Functions exposed

### `badge`: Embed a lifecycle badge in documentation

**Input**

```json
{ "fn": "badge", "status": { "type": "string", "enum": ["experimental", "deprecated", "superseded"] } }
```

**Output**

```json
{ "ok": true, "fn": "badge", "result": { "type": "string" } }
```

### `deprecate_warn`: Deprecate functions or arguments with warnings

**Input**

```json
{ "fn": "deprecate_warn", "when": { "type": "string" }, "what": { "type": "string" }, "details": { "type": ["string", "array"] }, "replacement": { "type": ["string", "null"] } }
```

**Output**

```json
{ "ok": true, "fn": "deprecate_warn", "result": { "type": "null" } }
```

### `deprecate_stop`: Deprecate functions or arguments with errors

**Input**

```json
{ "fn": "deprecate_stop", "when": { "type": "string" }, "what": { "type": "string" }, "details": { "type": ["string", "array"] }, "replacement": { "type": ["string", "null"] } }
```

**Output**

```json
{ "ok": true, "fn": "deprecate_stop", "result": { "type": "null" } }
```

### `expect_deprecated`: Test if an expression produces lifecycle warnings

**Input**

```json
{ "fn": "expect_deprecated", "expr": { "type": "string" } }
```

**Output**

```json
{ "ok": true, "fn": "expect_deprecated", "result": { "type": "boolean" } }
```

## When to invoke

*   When updating R package source code to transition a function from active to deprecated status.
*   When implementing logic to handle renamed or superseded arguments in function signatures.
*   When writing unit tests to verify that deprecated features still trigger the correct lifecycle warnings.
*   When generating Roxygen2 documentation strings that require visual indicators for experimental features.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo 'list(fn="badge", status="deprecated")' | Rscript --vanilla skills/lifecycle/invoke.R
```
