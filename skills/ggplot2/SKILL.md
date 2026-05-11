---
name: ggplot2
runtime: r
package: ggplot2
package_source: CRAN
package_url: https://ggplot2.tidyverse.org
package_version_pinned: ">=4.0.3"
license: MIT
maintainer: "Thomas Lin Pedersen <thomas.pedersen@posit.co>"
---

# Skill: ggplot2

ggplot2 is a system for declaratively creating graphics based on the Grammar of Graphics. The user provides data, maps variables to aesthetics, and specifies graphical primitives.

An agent should use this skill when a task requires generating plots from structured data, such as scatter plots, bar charts, or density plots, by defining mappings between data columns and visual properties.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("ggplot2")`.

## Functions exposed

### geom_point: Add a layer of points to a plot

**Input**

```json
{
  "fn": "geom_point",
  "mapping": { "type": "object", "description": "Aesthetic mappings" },
  "data": { "type": "object", "description": "The dataset" },
  "size": { "type": "number", "description": "Size of points" },
  "color": { "type": "string", "description": "Color of points" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "geom_point",
  "result": { "type": "object", "description": "A ggplot2 layer object" }
}
```

### geom_line: Add a layer of lines to a plot

**Input**

```json
{
  "fn": "geom_line",
  "mapping": { "type": "object", "description": "Aesthetic mappings" },
  "data": { "type": "object", "description": "The dataset" },
  "linewidth": { "type": "number", "description": "Width of lines" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "geom_line",
  "result": { "type": "object", "description": "A ggplot2 layer object" }
}
```

### geom_bar: Add a layer of bar charts to a plot

**Input**

```json
{
  "fn": "geom_bar",
  "mapping": { "type": "object", "description": "Aesthetic mappings" },
  "data": { "type": "object", "description": "The dataset" },
  "stat": { "type": "string", "description": "Statistical transformation" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "geom_bar",
  "result": { "type": "object", "description": "A ggplot2 layer object" }
}
```

### facet_wrap: Split a plot into multiple panels

**Input**

```json
{
  "fn": "facet_wrap",
  "formula": { "type": "string", "description": "Formula for faceting" },
  "nrow": { "type": "integer", "description": "Number of rows" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "facet_wrap",
  "result": { "type": "object", "description": "A Facet object" }
}
```

## When to invoke

- Creating scatter plots to examine the relationship between two continuous variables in a dataframe.
- Generating bar charts to visualize the frequency of categorical variables.
- Producing line graphs to track changes in a variable over a continuous axis.
- Splitting a single visualization into multiple sub-panels based on a categorical grouping variable.

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
echo '{"fn": "geom_point", "data": {"x": [1, 2, 3], "y": [4, 5, 6]}, "mapping": {"x": "x", "y": "y"}}' | Rscript --vanilla skills/ggplot2/invoke.R
```
