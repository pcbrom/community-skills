---
name: rlang
runtime: r
package: rlang
package_source: CRAN
package_url: https://rlang.r-lib.org
package_version_pinned: ">=1.2.0"
license: MIT
maintainer: "Lionel Henry <lionel@posit.co>"
---

# Skill: rlang

The rlang package provides a toolbox for working with base types, core R features such as the condition system, and tidy evaluation features. An agent should use this skill when tasks require low-level manipulation of R objects, custom error signaling with metadata, or precise argument validation.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("rlang")`.

## Functions exposed

### `abort`: Signal an error, warning, or message

**Input**

```json
{ "fn": "abort", "message": "string", "class": "string", "...": "object" }
```

**Output**

```json
{ "ok": true, "fn": "abort", "result": "null" }
```

### `are_na`: Test for missing values in a vector

**Input**

```json
{ "fn": "are_na", "x": "array" }
```

**Output**

```json
{ "ok": true, "fn": "are_na", "result": "boolean_array" }
```

### `arg_match`: Match an argument to a character vector

**Input**

```json
{ "fn": "arg_match", "arg": "string" }
```

**Output**

```json
{ "ok": true, "fn": "arg_match", "result": "string" }
```

### `arg_match0`: Match an argument to explicit values

**Input**

```json
{ "fn": "arg_match0", "arg": "string", "values": "array" }
```

**Output**

```json
{ "ok": true, "fn": "arg_match0", "result": "string" }
```

## When to invoke

* Validating that function arguments match a predefined set of allowed string values.
* Checking for the presence of `NA` values within numeric or character vectors.
* Creating custom error conditions that include specific metadata or error classes for downstream handling.
* Implementing precise argument matching where partial matches must be disallowed.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "are_na", "x": [1, 2, null]}' | Rscript --vanilla skills/rlang/invoke.R
```
