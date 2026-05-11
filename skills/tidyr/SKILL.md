---
name: tidyr
runtime: r
package: tidyr
package_source: CRAN
package_url: https://cran.r-project.org/package=tidyr
package_version_pinned: ">=1.3.2"
license: MIT
maintainer: "Hadley Wickham <hadley@posit.co>"
---

# Skill: tidyr

tidyr provides tools to create tidy data, where each column represents a variable, each row represents an observation, and each cell contains a single value. The package facilitates changing the shape of datasets through pivoting, managing hierarchies via nesting and unnesting, and rectangling nested lists into data frames.

The skill is triggered when a task requires reshaping wide-format data to long-format, expanding datasets to include missing combinations, or cleaning string columns by extracting specific values.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("tidyr")`.

## Functions exposed

### pivot_longer

**Input**

```json
{
  "fn": "pivot_longer",
  "data": "data.frame",
  "cols": "string",
  "names_to": "string",
  "values_to": "string"
}
```

**Output**

```json
{ "ok": true, "fn": "pivot_longer", "result": "data.frame" }
```

### pivot_wider

**Input**

```json
{
  "fn": "pivot_wider",
  "data": "data.frame",
  "names_from": "string",
  "values_from": "string"
}
```

**Output**

```json
{ "ok": and, "fn": "pivot_wider", "result": "data.frame" }
```

### complete

**Input**

```json
{
  "fn": "complete",
  "data": "data.frame",
  "..." : "string"
}
```

**Output**

```json
{ "ok": true, "fn": "complete", "result": "data.frame" }
```

### drop_na

**Input**

```json
{
  "fn": "drop_na",
  "data": "data.frame",
  "...": "string"
}
```

**Output**

```json
{ "ok": true, "fn": "drop_na", "result": "data.frame" }
```

### unnest

**Input**

```json
{
  "fn": "unnest",
  "data": "data.frame",
  "cols": "string"
}
```

**Output**

```json
{ "ok": true, "fn": "unnest", "result": "data.frame" }
```

## When to invoke

* Transforming datasets where column headers represent values of a single variable (e.g., converting columns "2021", "2022", "2023" into a single "year" column).
* Expanding a dataset to ensure all possible combinations of observed factors are present, filling missing entries with NA.
* Removing observations that contain missing values in specific columns.
* Flattening datasets containing list-columns or nested data frames into a rectangular format.
* Extracting substrings or patterns from a single character column into multiple distinct columns.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "drop_na", "data": {"x": [1, 2, null], "y": ["a", null, "b"]}, "x": "x"}' | Rscript --vanilla skills/tidyr/invoke.R
```
