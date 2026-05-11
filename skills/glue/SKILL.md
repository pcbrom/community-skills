---
name: glue
runtime: r
package: glue
package_source: CRAN
package_url: https://glue.tidyverse.org/
package_version_pinned: ">=1.8.1"
license: MIT
maintainer: "Jennifer Bryan <jenny@posit.co>"
---

# Skill: glue

The glue package provides an implementation of interpreted string literals. It allows for string interpolation by evaluating R expressions enclosed in braces within a character string.

An agent should use this skill when it needs to construct complex strings, format output messages with variable values, or generate SQL queries using dynamic parameters.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("glue")`.

## Functions exposed

### `glue`: Format and interpolate a string

**Input**

```json
{
  "fn": "glue",
  "..." : "string",
  "...": "..."
}
```

**Output**

```json
{
  "ok": true,
  "fn": "glue",
  "result": "string"
}
```

### `as_glue`: Coerce object to glue

**Input**

```json
{
  "fn": "as_glue",
  "x": "object"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "as_glue",
  "result": "glue_object"
}
```

### `glue_col`: Construct strings with color

**Input**

```json
{
  "fn": "glue_col",
  "..." : "string",
  "...": "..."
}
```

**Output**

```json
{
  "ok": true,
  "fn": "glue_col",
  "result": "string"
}
```

### `glue_collapse`: Collapse a character vector

**Input**

```json
{
  "fn": "glue_collapse",
  "x": "character_vector",
  "sep": "string",
  "last": "string"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "glue_collapse",
  "result": "string"
}
```

## When to invoke

* Constructing human readable notification messages containing numeric or date variables.
* Generating SQL statements where table names or column names are provided as dynamic arguments.
* Formatting multi-line strings by concatenating fragments while trimming leading and trailing whitespace.
* Creating colored terminal output for logs using crayon-compatible syntax.
* Collapsing lists of identifiers into a single comma-separated string for use in SQL IN clauses.

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
echo '{"fn": "glue", "args": {"name": "Fred", "age": 50}}' | Rscript --vanilla skills/glue/invoke.R
```
