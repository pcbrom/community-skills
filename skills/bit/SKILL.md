---
name: bit
runtime: r
package: bit
package_source: CRAN
package_url: https://github.com/r-lib/bit
package_version_pinned: ">=4.6.0"
license: GPL-2 | GPL-3
maintainer: "Michael Chirico <MichaelChirico4@gmail.com>"
---

# Skill: bit

The bit package provides classes and methods for memory-efficient boolean selections. It includes implementations for boolean and skewed boolean vectors, fast boolean methods, and efficient set operations on sorted and unsorted integer sets.

An agent should use this skill when tasks involve large-scale logical operations, memory-constrained boolean vector manipulation, or high-performance set intersections and differences.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("bit")`.

## Functions exposed

### as.bit: Coerce input to a bit vector

**Input**

```json
{ "fn": "as.bit", "x": "array" }
```

**Output**

```json
{ "ok": true, "fn": "as.bit", "result": "bit" }
```

### as.bitwhich: Coerce input to a bitwhich vector

**Input**

```json
{ "fn": "as.bitwhich", "x": "array" }
```

**Output**

```json
{ "ok": true, "fn": "as.bitwhich", "result": "bitwhich" }
```

### as.booltype: Coerce input to a specific boolean type

**Input**

```json
{ "fn": "as.booltype", "x": "array", "type": "string" }
```

**Output**

```json
{ "ok": true, "fn": "as.booltype", "result": "booltype" }
```

### as.ri: Coerce input to a run-length encoded (ri) format

**Input**

```json
{ "fn": "as.ri", "x": "array" }
```

**Output**

```json
{ "ok": true, "fn": "as.ri", "result": "ri" }
```

## When to invoke

* Performing set operations such as intersection, union, or symmetric difference on large integer datasets.
* Managing memory-intensive logical vectors by converting them to compressed bit or bitwhich formats.
* Executing fast sorting or unique identification of integer sequences.
* Processing data using run-length encoding (ri) for compressed storage of repetitive boolean patterns.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "as.bit", "x": [0, 1, 0, 1]}' | Rscript --vanilla skills/bit/invoke.R
```
