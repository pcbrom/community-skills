---
name: isoband
runtime: r
package: isoband
package_source: CRAN
package_url: https://isoband.r-lib.org
package_version_pinned: ">=0.3.0"
license: MIT
maintainer: "Thomas Lin Pedersen <thomas.pedersen@posit.co>"
---

# Skill: isoband

This package provides a C++ implementation for generating contour lines (isolines) and contour polygons (isobands) from regularly spaced grids containing elevation data. It is used for processing grid-based datasets to extract geometric boundaries at specific intervals.

An agent should use this skill when tasked with converting a 2D matrix of values into vector-based contour geometries or when calculating area-based polygons from elevation grids.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("isoband")`.

## Functions exposed

### `isobands`: Generate contour polygons from an elevation grid

**Input**

```json
{
  "fn": "isobands",
  "x": { "type": "array", "items": { "type": "number" }, "description": "X coordinates of the grid" },
  "y": { "type": "array", "items": { "type": "number" }, "description": "Y coordinates of the grid" },
  "z": { "type": "array", "items": { "type": "array", "items": { "type": "number" } }, "description": "Matrix of elevation values" },
  "levels": { "type": "array", "items": { "type": "number" }, "description": "Threshold levels for bands" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "isobands",
  "result": {
    "type": "array",
    "items": {
      "type": "object",
      "properties": {
        "x": { "type": "array", "items": { "type": "number" } },
        "y": { "type": "array", "items": { "type": "number" } },
        "id": { "type": "array", "items": { "type": "integer" } }
      }
    }
  }
}
```

### `isolines`: Generate contour lines from an elevation grid

**Input**

```json
{
  "fn": "isolines",
  "x": { "type": "array", "items": { "type": "number" } },
  "y": { "type": "array", "items": { "type": "number" } },
  "z": { "type": "array", "items": { "type": "array", "items": { "type": "number" } } },
  "levels": { "type": "array", "items": { "type": "number" } }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "isolines",
  "result": {
    "type": "array",
    "items": {
      "type": "object",
      "properties": {
        "x": { "type": "array", "items": { "type": "number" } },
        "y": { "type": "array", "items": { "type": "number" } },
        "id": { "type": "array", "items": { "type": "integer" } }
      }
    }
  }
}
```

### `iso_to_sfg`: Convert isolines or isobands to sf geometry objects

**Input**

```json
{
  "fn": "iso_to_sfg",
  "object": { "type": "object", "description": "An object of class isobands or isolines" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "iso_to_sfg",
  "result": { "type": "object", "description": "An sf geometry collection (sfg) object" }
}
```

### `clip_lines`: Clip lines to avoid intersection with bounding boxes

**Input**

```json
{
  "fn": "clip_lines",
  "lines": { "type": "object", "description": "Line segments to be clipped" },
  "boxes": { "type": "array", "items": { "type": "object" }, "description": "Set of boxes to avoid" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "clip_lines",
  "result": { "type": "object", "description": "Clipped line segments" }
}
```

## When to invoke

* Converting a 2D numeric matrix representing topography into vector polygons for GIS software.
* Extracting specific contour level paths from a regular spatial grid.
* Removing line segments from contour plots that overlap with text labels or other geometric annotations.
* Transforming grid-based elevation data into `sf` (simple features) objects for spatial analysis.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "isolines", "x": [1, 2, 3], "y": [3, 2, 1], "z": [[0, 1, 0], [1, 2, 1], [0, 1, 0]], "levels": [0.5, 1.5]}' | Rscript --vanilla skills/isoband/invoke.R
```
