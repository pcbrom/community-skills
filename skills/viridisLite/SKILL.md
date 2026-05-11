---
name: viridisLite
runtime: r
package: viridisLite
package_source: CRAN
package_url: https://sjmgarnier.github.io/viridisLite/
package_version_pinned: ">=0.4.3"
license: MIT
maintainer: "Simon Garnier <garnier@njit.edu>"
---

# Skill: viridisLite

This package provides color maps designed to improve graph readability for readers with common forms of color blindness or color vision deficiency. The color maps are perceptually uniform in both regular form and when converted to black-and-white for printing.

An agent should use this skill when a task requires generating color palettes for plots, heatmaps, or data visualizations where accessibility and perceptual uniformity are required.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("viridisLite")`.

## Functions exposed

### `viridis`: Create a vector of equally spaced colors along a selected color map

**Input**

```json
{
  "fn": "viridis",
  "n": { "type": "integer", "description": "Number of colors to generate" },
  "option": { "type": "string", "description": "The color map option (e.g., 'magma', 'inferno', 'plasma', 'viridis', 'cividis', 'rocket', 'mako', 'turbo')" }
}
```

**Output**

```json
{ "ok": true, "fn": "viridis", "result": { "type": "array", "items": { "type": "string" }, "description": "Vector of hex color codes" } }
```

### `viridis.map`: Access RGB values of the color maps

**Input**

```json
{ "fn": "viridis.map" }
```

**Output**

```json
{ "ok": true, "fn": "viridis.map", "result": { "type": "object", "description": "Data set containing RGB values for included color maps" } }
```

## When to invoke

*   Generating hex code sequences for heatmaps or density plots where color blindness accessibility is a requirement.
*   Creating color palettes for continuous scales in R graphics.
*   Retrieving RGB component data for specific color maps like magma, inferno, or cividis.
*   Designing plots that must remain interpretable when printed in grayscale.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo 'list(n = 5, option = "viridis")' | Rscript --vanilla skills/viridisLite/invoke.R
```
