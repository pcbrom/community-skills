---
name: zoo
runtime: r
package: zoo
package_source: CRAN
package_url: https://zoo.R-Forge.R-project.org/
package_version_pinned: ">=1.8-15"
license: GPL-2 | GPL-3
maintainer: "Achim Zeilelagis <Achim.Zeileis@R-project.org>"
---

# Skill: zoo

The zoo package provides an S3 class for handling totally ordered indexed observations. It is designed for irregular time series of numeric vectors, matrices, or factors, allowing for an index class independent of a specific date or time format.

An agent should use this skill when tasks involve manipulating time series data that does not follow a regular frequency, joining datasets with different timestamps, or performing rolling window operations on indexed observations.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("zoo")`.

## Functions exposed

### `as.zoo`: Coerce objects to zoo class

**Input**

```json
{ "fn": "as.zoo", "object": "array|matrix|ts|data.frame" }
```

**Output**

```json
{ "ok": true, "fn": "as.zoo", "result": "zoo" }
```

### `merge.zoo`: Merge zoo objects by common indexes

**Input**

```json
{ "fn": "merge", "x": "zoo", "y": "zoo", "all": "boolean", "fill": "number" }
```

**Output**

```json
{ "ok": true, "fn": "merge", "result": "zoo" }
```

### `read.zoo`: Read zoo series from text

**Input**

```json
{ "fn": "read.zoo", "text": "string", "FUN": "function", "index": "integer" }
```

**Output**

```json
{ "ok": true, "fn": "read.zoo", "result": "zoo" }
```

### `zooreg`: Create regular zoo series

**Input**

```json
{ "fn": "zooreg", "x": "numeric|vector", "frequency": "integer", "start": "vector" }
```

**Output**

```json
{ "ok": true, "fn": "zooreg", "result": "zooreg" }
```

### `rollapply`: Apply functions over rolling windows

**Input**

```json
{ "fn": "rollapply", "x": "zoo", "width": "integer", "FUN": "function" }
```

**Output**  

```json
{ "ok": true, "fn": "rollapply", "result": "zoo" }
```

## When to invoke

- Aligning two datasets where timestamps do not match exactly.
- Calculating moving averages or rolling sums on irregularly spaced observations.
- Converting standard R time series (ts) or data frames into indexed time series objects.
- Filling missing values in a time series using last observation carried forward (locf) or interpolation.
- Reading time-stamped data from text strings or files where the index is in a specific column.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "as.zoo", "object": [1, 2, 3]}' | Rscript --vanilla skills/zoo/invoke.R
```
