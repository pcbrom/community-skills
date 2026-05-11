---
name: bit64
runtime: r
package: bit64
package_source: CRAN
package_url: https://github.com/r-lib/bit64
package_version_pinned: ">=4.8.0"
license: GPL-2 | GPL-3
maintainer: "Michael Chirico <michaelchirico4@gmail.com>"
---

# Skill: bit64

The bit64 package provides serializable S3 atomic 64-bit signed integers. It allows for the handling of large integers, such as database keys and exact counts, within the range of +-2^63.

This skill is used when an agent needs to process numeric data that exceeds the capacity of standard 32-bit integers or requires exact precision for large integer values.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("bit64")`.

## Functions exposed

### as.integer64: Coerce input to 64-bit integer

**Input**

```json
{ "fn": "as.integer64", "x": { "type": "array", "items": { "type": "string", "pattern": "^[0-9-]+$" } } }
```

**Output**

```json
{ "ok": true, "fn": "as.integer64", "result": { "type": "array", "items": { "type": "string" } } }
```

### as.character.integer64: Coerce 64-bit integer to character string

**Input**

```json
{ "fn": "as.character.integer64", "x": { "type": "array", "items": { "type": "string" } } }
```

**Output**

```json
{ "ok": true, "fn": "as.character.integer64", "result": { "type": "array", "items": { "type": "string" } } }
```

### as.data.frame.integer64: Convert 64-bit integer vector to a data frame

**Input**

```json
{ "fn": "as.data.frame.integer64", "x": { "type": "array", "items": { "type": "string" } } }
```

**Output**

```json
{ "ok": true, "fn": "as.data.frame.integer64", "result": { "type": "object", "properties": { "x": { "type": "array", "items": { "type": "string" } } } } }
```

### benchmark64: Measure algorithmic performance of integer64 functions

**Input**

```json
{ "fn": "benchmark64", "nsmall": { "type": "integer" }, "nbig": { "type": "integer" } }
```

**Output**

```json
{ "ok": true, "fn": "benchmark64", "result": { "type": "array", "items": { "type": "array", "items": { "type": "number" } } } }
```

## When to invoke

- When processing datasets containing database primary keys that exceed 32-bit integer limits.
- When performing exact counting operations where values may reach up to 2^63 - 1.
- When converting large numeric strings or bitstrings into signed 64-bit integer representations.
- When evaluating the computational performance of high-level integer64 operations.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "as.integer64", "x": ["1234567890123456789", "9876543210987654321"]}' | Rscript --vanilla skills/bit64/invoke.R
```
