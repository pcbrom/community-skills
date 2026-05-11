---
name: xfun
runtime: r
package: xfun
package_source: CRAN
package_url: https://github.com/yihui/xfun
package_version_pinned: ">=0.57"
license: MIT
maintainer: "Yihui Xie <xie@yihui.name>"
---

# Skill: xfun

The xfun package provides miscellaneous utility functions used across various R packages. It contains tools for file manipulation, string processing, system command execution, and HTML generation.

An agent should use this skill when tasks require executing R commands via the system shell, generating HTML-compatible identifiers from strings, or running R functions within a fresh R session to ensure environment isolation.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("xfun")`.

## Functions exposed

### Rscript: Run Rscript or R CMD commands

**Input**

```json
{ "fn": "Rscript", "args": { "type": "array", "items": { "type": "string" } } }
```

**Output**

```json
{ "ok": true, "fn": "Rscript", "result": { "type": "string" } }
```

### Rscript_call: Call a function in a new R session

**Input**

```json
{ "fn": "Rscript_call", "func": { "type": "string" }, "args": { "type": "array", "items": { "type": "any" } }, "options": { "type": "array", "items": { "type": "string" }, "default": [] } }
```

**Output**

```json
{ "ok": true, "fn": "Rscript_call", "result": { "type": "any" } }
```

### alnum_id: Generate ID strings for HTML elements

**Input**

```json
{ "fn": "alnum_id", "x": { "type": "array", "items": { "type": "string" } }, "pattern": { "type": "string", "default": "[^[:alnum:]]+" } }
```

**Output**

```json
{ "ok": true, "fn": "alnum_id", "result": { "type": "array", "items": { "type": "string" } } }
```

### attr2: Obtain an attribute without partial matching

**Input**

```json
{ "fn": "attr2", "x": { "type": "any" }, "name": { "type": "string" } }
```

**Output**

```json
{ "ok": true, "fn": "attr2", "result": { "type": "any" } }
```

## When to invoke

* Executing shell-level R commands such as `R CMD build` or `Rscript -e`.
* Running specific R functions in a clean environment to prevent side effects from the current global environment.
* Creating sanitized, alphanumeric strings for use as HTML element IDs from raw text or HTML fragments.
* Retrieving object attributes where exact name matching is required to avoid errors from partial matching.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo 'list(fn="Rscript", args=c("-e", "print(\"hello\")"))' | Rscript --vanilla skills/xfun/invoke.R
```
