---
name: fontawesome
runtime: r
package: fontawesome
package_source: CRAN
package_url: https://github.com/rstudio/fontawesome, https://rstudio.github.io/fontawesome/
package_version_pinned: ">=0.5.3"
license: MIT + file LICENSE
maintainer: "Richard Iannone <rich@posit.co>"
---

# Skill: fontawesome

The fontawesome package provides tools to insert Font Awesome icons into R Markdown documents and Shiny applications. It enables the generation of icons as SVG tags, HTML dependency objects, or HTML `<i>` tags.

An agent should use this skill when a task requires generating visual icons for web-based reports, creating HTML-based UI components in Shiny, or retrieving metadata regarding available icon names and versions.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("fontawesome")`.

## Functions exposed

### `fa`: Generate Font Awesome icons as SVGs

**Input**

```json
{ "fn": "fa", "name": "string", "style": "string" }
```

**Output**

```json
{ "ok": true, "fn": "fa", "result": "string" }
```

### `fa_i`: Generate a Font Awesome `<i>` tag

**Input**

```json
{ "fn": "fa_i", "name": "string" }
```

**Output**

```json
{ "ok": true, "fn": "fa_i", "result": "string" }
```

### `fa_html_dependency`: Use a Font Awesome `html_dependency`

**Input**

```json
{ "fn": "fa_html_dependency" }
```

**Output**

```json
{ "ok": true, "fn": "fa_html_dependency", "result": "object" }
```

### `fa_metadata`: Get metadata on the included Font Awesome assets

**Input**

```json
{ "fn": "fa_metadata" }
```

**Output**

```json
{ "ok": true, "fn": "fa_metadata", "result": "object" }
```

### `fa_png`: Export Font Awesome icons as PNG images

**Input**

```json
{ "fn": "fa_png", "name": "string", "filename": "string" }
```

**Output**

```json
{ "ok": true, "name": "string", "result": "string" }
```

## When to invoke

- Generating SVG-based icons for inline use within R Markdown documents.
- Creating `<i>` tags for legacy Shiny applications using `shiny::icon()`.
- Adding HTML dependencies to a Shiny or R Markdown context to support icon rendering.
- Retrieving a list of available icon names or version information for programmatic icon selection.
- Converting vector-based icons into PNG raster graphics for non-HTML environments.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "fa", "name": "r-project"}' | Rscript --vanilla skills/fontawesome/invoke.R
```
