---
name: crayon
runtime: r
package: crayon
package_source: CRAN
package_url: https://r-lib.github.io/crayon/
package_version_pinned: ">=1.5.3"
license: MIT
maintainer: "Gábor Csárdi <csardi.gabor@gmail.com>"
---

# Skill: crayon

The crayon package provides functionality for colored terminal output on terminals supporting ANSI color and highlight codes. It supports automatic detection of ANSI color support and allows for the combination and nesting of colors and highlighting.

An agent should use this skill when tasks require the generation of formatted terminal text, the manipulation of ANSI-encoded strings, or the calculation of string properties while preserving color metadata.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("crayon")`.

## Functions exposed

### chr: Convert to character

**Input**

```json
{ "fn": "chr", "x": { "type": "string" } }
```

**Output**

```json
{ "ok": true, "fn": "chr", "result": { "type": "string" } }
```

### col_align: Align an ANSI colored string

**Input**

```json
{ "fn": "col_align", "string": { "type": "string" }, "width": { "type": "integer" }, "justify": { "type": "string", "enum": ["left", "center", "right"] } }
```

**Output**

```json
{ "ok": true, "fn": "col_align", "result": { "type": "string" } }
```

### col_nchar: Count characters in an ANSI colored string

**Input**

```json
{ "fn": "col_nchar", "string": { "type": "string" } }
```

**Output**

```json
{ "ok": true, "fn": "col_nchar", "result": { "type": "integer" } }
```

### col_strsplit: Split an ANSI colored string

**Input**

```json
{ "fn": "col_strsplit", "x": { "type": "string" }, "split": { "type": "string" } }
```

**Output**

```json
{ "ok": true, "fn": "col_strsplit", "result": { "type": "array", "items": { "type": "string" } } }
```

## When to invoke

* Formatting text output for terminal-based logs or user interfaces.
* Calculating the visible length of strings containing ANSI escape sequences.
* Splitting strings into substrings while maintaining the associated color and style metadata.
* Aligning colored text within fixed-width columns for tabular terminal displays.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "col_nchar", "string": "\u001b[31mred\u001b[39m"}' | Rscript --vanilla skills/crayon/invoke.R
```
