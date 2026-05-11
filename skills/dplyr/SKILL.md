---
name: dplyr
runtime: r
package: dplyr
package_source: CRAN
package_url: https://dplyr.tidyverse.org
package_version_pinned: ">=1.2.1"
license: MIT
maintainer: "Hadley Wickham <hadley@posit.co>"
---

# Skill: dplyr

dplyr provides a grammar of data manipulation for data frame objects. It allows for consistent operations on data in memory or out of memory.

An agent should use this skill when tasks require transforming, filtering, reordering, or aggregating tabular data structures.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.lag("dplyr")`.

## Functions exposed

### `arrange`: Order rows using column values

**Input**

```json
{
  "fn": "arrange",
  ".data": "data.frame",
  "desc": "boolean",
  ".by_group": "boolean"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "arrange",
  "result": "data.frame"
}
```

### `across`: Apply a function across multiple columns

**Input**

```json
{
  "fn": "across",
  ".data": "data.frame",
  "cols": "selection_spec",
  "functions": "list"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "across",
  "result": "data.frame"
}
```

### `count`: Count the number of observations

**Input**

```json
{
  "fn": "count",
  ".data": "data.frame",
  "sort": "boolean"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "count",
  "result": "data.frame"
}
```

### `distinct`: Retain only unique rows

**Input**

```json
{
  "fn": "distinct",
  ".data": "data.frame",
  ".keep_all": "boolean"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "distinct",
  "result": "data.frame"
}
```

## When to invoke

- Sorting datasets by specific numeric or categorical columns.
- Calculating summary statistics across multiple columns simultaneously.
- Identifying unique entries or removing duplicate rows from a dataset.
- Aggregating frequency counts for categorical variables.
- Reordering data based on descending or ascending values.

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
echo '{"fn": "arrange", ".data": {"mpg": [21, 22, 20], "cyl": [6, 4, 6]}, "desc": true}' | Rscript --vanilla skills/dplyr/invoke.R
```
