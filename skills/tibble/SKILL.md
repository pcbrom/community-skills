---
name: tibble
runtime: r
package: tibble
package_source: CRAN
package_url: https://tibble.tidyverse.org/
package_version_pinned: ">=3.3.1"
license: MIT
maintainer: "Kirill Müller <kirill@cynkra.com>"
---

# Skill: tibble

The tibble package provides the `tbl_df` class, which is a modern version of the data frame. It features stricter checking and improved formatting for better data inspection.

An agent should use this skill when tasks involve converting matrices or lists into structured data frames, adding new columns or rows to existing datasets, or formatting character vectors for display.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("tibble")`.

## Functions exposed

### `as_tibble`: Coerce objects to tibbles

**Input**

```json
{
  "fn": "as_tibble",
  "x": "matrix, data.frame, or list"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "as_tibble",
  "result": "tibble"
}
```

### `add_column`: Add columns to a data frame

**Input**

```json
{
  "fn": "add_column",
  "x": "tibble",
  "...",
  ".before": "string (optional)"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "add_column",
  "result": "tibble"
}
```

### `add_row`: Add rows to a data frame

**Input**

```json
{
  "fn": "add_row",
  "x": "tibble",
  "...": "values for new rows",
  ".before": "integer (optional)"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "add_row",
  "result": "tibble"
}
```

### `char`: Format a character vector

**Input**

```json
{
  "fn": "char",
  "x": "character vector",
  "min_chars": "number (optional)",
  "shorten": "string (optional)"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "char",
  "result": "character vector"
}
```

## When to invoke

* Converting a numeric matrix or a list of vectors into a structured table for inspection.
* Appending new observations to an existing dataset.
* Inserting new variables into a table at specific positions.
* Controlling the truncation and abbreviation of long strings in character columns.

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
echo '{"fn": "as_tibble", "x": [[1, 2], [3, 4]]}' | Rscript --vanilla skills/tibble/invoke.R
```
