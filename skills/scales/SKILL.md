---
name: scales
runtime: r
package: scales
package_source: CRAN
package_url: https://scales.r-lib.org
package_version_pinned: ">=1.4.0"
license: MIT
maintainer: "Thomas Lin Pedersen <thomas.pedersen@posit.co>"
---

# Skill: scales

The scales package provides functions for mapping data to graphical aesthetics. It includes methods for determining axis breaks, generating labels, and managing color palettes for plots and legends.

An agent should use this skill when tasks involve preparing numeric or categorical data for visualization, such as calculating axis intervals, formatting currency or scientific notation, or adjusting color transparency.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("scales")`.

## Functions exposed

### alpha: Modify colour transparency

**Input**

```json
{
  "fn": "alpha",
  "colour": { "type": "string" },
  "alpha": { "type": "number" }
}
```

**Output**

```json
{ "ok": true, "fn": "alpha", "result": { "type": "string" } }
```

### breaks_extended: Automatic breaks for numeric axes

**Input**

```json
{
  "fn": "breaks_extended",
  "n": { "type": "integer" }
}
```

**Output**

```json
{ "ok": true, "fn": "breaks_extended", "result": { "type": "array", "items": { "type": "number" } } }
```

### breaks_exp: Breaks for exponentially transformed data

**Input**

```json
{
  "fn": "breaks_exp",
  "n": { "type": "integer" }
}
```

**Output**

```json
{ "ok": true, "fn": "breaks_exp", "result": { "type": "array", "items": { "type": "number" } } }
```

### comma: Format numbers with commas

**Input**

```json
{
  "fn": "comma",
  "x": { "type": "number" }
}
```

**Output**

```json
{ "ok": true, "fn": "comma", "result": { "type": "string" } }
```

## When to invoke

*   Calculating appropriate axis tick marks for numeric ranges using Wilkinson's algorithm.
*   Formatting numeric vectors into human-readable strings, such as adding commas or currency symbols.
*   Adjusting the alpha channel of hex color strings for transparency in layered plots.
*   Determining break positions for data subject to exponential transformations.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "alpha", "colour": "red", "alpha": 0.5}' | Rscript --vanilla skills/scales/invoke.R
```
