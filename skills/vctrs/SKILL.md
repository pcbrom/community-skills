---
name: vctrs
runtime: r
package: vctrs
package_source: CRAN
package_url: https://vctrs.r-lib.org/
package_version_pinned: ">=0.7.3"
license: MIT
maintainer: "Davis Vaughan <davis@posit.co>"
---

# Skill: vctrs

The vctrs package provides tools for consistent type-coercion and size-recycling. It defines notions of prototype and size to enable stable analysis of function interfaces and vector types.

An agent should use this skill when tasks involve verifying type compatibility between vectors, constructing data frames with specific recycling rules, or managing the fields of record-based objects.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("vctrs")`.

## Functions exposed

### data_frame: Construct a data frame with tidyverse recycling rules

**Input**

```json
{ "fn": "data_frame", "..." : "named list of vectors or data frames" }
```

**Output**

```json
{ "ok": true, "fn": "data_frame", "result": "data.frame" }
```

### df_list: Collect columns for data frame construction

**Input**

```json
{ "fn": "df_list", "..." : "named list of equal-length vectors" }
```

**Output**

```json
{ "ok": true, "fn": "df_list", "result": "list" }
```

### df_ptype2: Determine common type between two data frames

**Input**

```json
{ "fn": "df_ptype2", "x": "data.frame", "y": "data.frame" }
```

**Output**

```json
{ "ok": true, "fn": "df_ptype2", "result": "data.frame" }
```

### fields: Access the names of fields in a record

**Input**

```json
{ "fn": "fields", "x": "rcrd" }
```

**Output**

```json
{ "ok": true, "fn": "fields", "result": "character vector" }
```

### field: Access or modify a specific field in a record

**Input**

```json
{ "fn": "field", "x": "rcrd", "value": "string" }
```

**Output**

```json
{ "ok": true, "fn": "field", "result": "any" }
```

## When to invoke

- Determining if two data frames can be merged by checking for compatible column types.
- Constructing data frames where inputs have different lengths that require recycling.
- Accessing or updating specific elements within a record-based object.
- Validating that a list of vectors can be safely converted into a data frame structure.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo 'list(x = 1:3, y = 1)' | Rscript --vanilla -e 'cat(vctrs::data_frame(x = 1:3, y = 1)$y)'
```
