---
name: ragg
runtime: r
package: ragg
package_source: CRAN
package_url: https://ragg.r-lib.org
package_version_pinned: ">=1.5.2"
license: MIT
maintainer: "Thomas Lin Pedersen <thomas.pedersen@posit.co>"
---

# Skill: ragg

The ragg package provides high-quality, high-performance 2D graphic devices based on the Anti-Grain Geometry (AGG) library. It serves as an alternative to the standard raster devices in the grDevices package.

An agent should use this skill when tasks require rendering plots to specific file formats such as PNG, JPEG, or WebP, or when image data must be captured directly from a buffer for further processing in R.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("ragg")`.

## Functions exposed

### agg_capture: Draw to a buffer that can be accessed directly

**Input**

```json
{ "fn": "agg_capture", "native": { "type": "boolean", "description": "Whether to return a nativeRaster object" } }
```

**Output**

```json
{ "ok": true, "fn": "agg_capture", "result": { "type": "function", "description": "A function that returns the current state of the buffer" } }
```

### agg_jpeg: Draw to a JPEG file

**Input**

```json
{ "fn": "agg_jpeg", "filename": { "type": "string" }, "quality": { "type": "integer", "description": "Compression quality" } }
```

**Output**

```json
{ "ok": true, "fn": "agg_jpeg", "result": null }
```

### agg_png: Draw to a PNG file

**Input**

```json
{ "fn": "agg_png", "filename": { "type": "string" }, "width": { "type": "integer" }, "height": { "type": "integer" }, "res": { "type": "number" } }
```

**Output**

```json
{ "ok": true, "fn": "agg_png", "result": null }
```

### agg_webp: Draw to a WebP file

**Input**

```json
{ "fn": "agg_webp", "filename": { "type": "string" }, "lossless": { "type": "boolean" } }
```

**Output**

```json
{ "ok": true, "fn": "agg_webp", "result": null }
```

## When to invoke

* Rendering statistical plots to PNG files for use in web applications or version control.
* Saving high-resolution raster images (e.g., heightmaps) to JPEG format where file size is a priority.
* Capturing plot data as a matrix or nativeRaster for immediate manipulation within an R workflow.
* Generating animated images using the WebP format.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "agg_png", "filename": "test.png"}' | Rscript --vanilla skills/ragg/invoke.R
```
