---
name: tinytable
runtime: r
package: tinytable
package_source: CRAN
package_url: https://vincentarelbundock.github.io/tinytable/
package_version_pinned: ">=0.16.0"
license: GPL (>= 3)
maintainer: "Vincent Arel-Bundock <vincent.arel-bundock@umontreal.ca>"
---

# Skill: tinytable

This package provides a mechanism to create highly customized tables in various formats, including HTML, LaTeX, Markdown, Word, PNG, PDF, and Typst. It allows for the conversion of data frames into formatted table objects with specific styling, grouping, and numeric formatting.

An agent should use this skill when a task requires the generation of formatted tabular representations of data for reports, documents, or visual displays.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("tinytable")`.

## Functions exposed

### `tt`: Convert data frame to tinytable

**Input**

```json
{ "fn": "tt", "x": { "type": "object", "description": "A data frame or data.table to convert" } }
```

**Output**

```json
{ "ok": true, "fn": "tt", "result": "tinytable_object" }
```

### `format_tt`: Format columns of a tinytable

**Input**

```json
{
  "fn": "format_tt",
  "x": "tinytable_object",
  "j": { "type": ["string", "integer"], "description": "Column index or name" },
  "digits": { "type": "integer", "description": "Number of significant digits" },
  "num_fmt": { "type": "string", "description": "Formatting style such as decimal or significant_cell" },
  "num_mark_dec": { "type": "string", "description": "Decimal separator" },
  "num_mark_big": { "type": "string", "description": "Thousands separator" }
}
```

**Output**

```json
{ "ok": true, "fn": "format_tt", "result": "tinytable_object" }
```

### `group_tt`: Add spanning labels to rows or columns

**Input**

```json
{
  "fn": "group_tt",
  "x": "tinytable_object",
  "i": { "type": ["vector", "list"], "description": "Row grouping labels" },
  "j": { "type": ["list"], "description": "Column grouping labels" }
}
```

**Output**

```json
{ "ok": true, "fn": "group_tt", "result": "tinytable_object" }
```

### `format_vector`: Format a numeric or date vector

**Input**

```json
{
  "fn": "format_vector",
  "x": { "type": ["numeric", "Date", "logical"], "description": "The vector to format" },
  "digits": { "type": "integer" },
  "date": { "type": "string", "description": "Date format string" },
  "bool": { "type": "function", "description": "Function to transform logical values" }
}
```

**Output**

```json
{ "ok": true, "fn": "format_vector", "result": "character_vector" }
```

## When to invoke

* Converting a data frame into a Markdown table for documentation.
* Applying specific decimal precision or thousand separators to numeric columns in a table.
* Adding spanning headers to group rows or columns in a table for hierarchical data presentation.
* Formatting date vectors into human-readable strings for report generation.
* Generating LaTeX code for tables using the tabularray package.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo 'list(fn="tt", x=data.frame(a=c(1,2), b=c(3,4)))' | Rscript --vanilla skills/tinytable/invoke.R
```
