---
name: gtable
runtime: r
package: gtable
package_source: CRAN
package_url: https://gtable.r-lib.org
package_version_pinned: ">=0.3.6"
license: MIT
maintainer: "Thomas Lin Pedersen <thomas.pedersen@posit.co>"
---

# Skill: gtable

The gtable package provides tools for managing tables of grobs (graphical objects). It defines a gtable class that specifies a grid, a list of grobs, and their placement within that grid.

This skill is used when an agent needs to programmatically construct complex graphical layouts, arrange multiple plots in a grid, or manipulate the structure of existing grob tables by adding rows, columns, or specific graphical elements.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("gtable")`.

## Functions exposed

### `gtable`: Create a new grob table

**Input**

```json
{
  "fn": "gtable",
  "widths": "array of grid units",
  "heights": "array of grid units"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "gtable",
  "result": "gtable object"
}
```

### `gtable_add_grob`: Add a single grob to a table

**Input**

```json
{
  "fn": "gtable_add_grob",
  "x": "gtable object",
  "grob": "grid grob object",
  "t": "integer row index",
  "l": "integer column index",
  "b": "integer row index (optional)",
  "r": "integer column index (optional)"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "gtable_add_grob",
  "result": "gtable object"
}
```

### `gtable_add_cols`: Add new columns to a gtable

**Input**

```json
{
  "fn": "gtable_add_cols",
  "x": "gtable object",
  "widths": "array of grid units",
  "after": "integer index (optional)"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "gtable_add_cols",
  "result": "gtable object"
}
```

### `as.gtable`: Convert an object to a gtable

**Input**

```json
{
  "fn": "as.gtable",
  "x": "object to convert"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "as.gtable",
  "result": "gtable object"
}
```

## When to invoke

*   When a task requires arranging multiple separate plots into a single coordinated grid layout.
*   When an agent needs to expand an existing graphical table by inserting new columns or rows at specific indices.
*   When a task involves placing specific graphical elements, such as rectangles or text, into specific cells of a grid.
*   When a task requires manipulating the spanning properties of grobs across multiple rows or columns.

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
echo '{"fn": "gtable", "widths": [1, 1], "heights": [1, 1]}' | Rscript --vanilla skills/gtable/invoke.R
```
