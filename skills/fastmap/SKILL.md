---
name: fastmap
runtime: r
package: fastmap
package_source: CRAN
package_url: https://r-lib.github.io/fastmap/
package_version_pinned: ">=1.2.0"
license: MIT
maintainer: "Winston Chang <winston@posit.co>"
---

# Skill: fastmap

The fastmap package provides efficient implementations of data structures, specifically a key-value store, a stack, and a queue. It uses C++ to implement the map, which prevents the memory leakage associated with R's global symbol table when using environments as key-value stores with many unique keys.

An agent should use this skill when tasks require managing large sets of string-based keys or implementing FIFO (first-in, first-out) and LIFO (last-in, first-out) data structures without increasing the R symbol table size.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("fastmap")`.

## Functions exposed

### fastmap: Create a key-value store

**Input**

```json
{ "fn": "fastmap", "missing_..." : "any" }
```

**Output**

```json
{ "ok": true, "fn": "fastmap", "result": "object" }
```

### fastqueue: Create a queue

**Input**

```json
{ "fn": "fastqueue" }
```

**Output**

```json
{ "ok": true, "fn": "fastqueue", "result": "object" }
```

### faststack: Create a stack

**Input**

```json
{ "fn": "faststack" }
```

**Output**

```json
{ "ok": true, "fn": "faststack", "result": "object" }
```

### is.key_missing: Check if an object represents a missing key

**Input**

```json
{ "fn": "is.key_missing", "x": "any" }
```

**Output**

```json
{ "ok": true, "fn": "is.key_missing", "result": "boolean" }
```

## When to invoke

*   When storing large numbers of unique string keys to avoid memory leaks in the R global symbol table.
*   When implementing a FIFO buffer using a circular list structure.
*   When implementing a LIFO buffer for tracking nested operations or state.
*   When a task requires a high-performance key-value lookup where keys are strings and values are arbitrary R objects.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo 'list(fn="fastmap")' | Rscript --vanilla skills/fastmap/invoke.R
```
