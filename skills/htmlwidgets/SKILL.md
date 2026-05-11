---
name: htmlwidgets
runtime: r
package: htmlwidgets
package_source: CRAN
package_url: https://github.com/ramnathv/htmlwidgets
package_version_pinned: ">=1.6.4"
license: MIT
maintainer: "Carson Sievert <carson@posit.co>"
---

# Skill: htmlwidgets

The htmlwidgets package provides a framework for creating HTML widgets that render in the R console, R Markdown documents, and Shiny web applications. An agent should use this skill when it needs to programmatically generate, manipulate, or save interactive web-based visualizations and components within an R environment.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("htmlwidgets")`.

## Functions exposed

### JS: Mark character strings as literal JavaScript code

**Input**

```json
{ "fn": "JS", "x": { "type": "array", "items": { "type": "string" } } }
```

**Output**

```json
{ "ok": true, "fn": "JS", "result": { "type": "string" } }
```

### createWidget: Create an HTML widget

**Input**

```json
{ "fn": "createWidget", "x": { "type": "object" }, "width": { "type": "number" }, "height": { "type": "number" } }
```

**Output**

```json
{ "ok": true, "fn": "createWidget", "result": { "type": "object" } }
```

### getDependency: Get js and css dependencies for a htmlwidget

**Input**

```json
{ "fn": "getDependency", "x": { "type": "object" } }
```

**Output**

```json
{ "ok": true, "fn": "getDependency", "result": { "type": "array", "items": { "type": "object" } } }
```

### saveWidget: Save a widget to an HTML file

**Input**

```json
{ "fn": "saveWidget", "x": { "type": "object" }, "file": { "type": "string" }, "selfcontained": { "type": "boolean" } }
```

**Output**

```json
{ "ok": true, "fn": "saveWidget", "result": { "type": "boolean" } }
```

## When to invoke

- When a task requires converting R data structures into interactive JavaScript-based components.
- When an agent needs to inject raw JavaScript logic into a widget configuration.
- When a task involves exporting an interactive R widget as a standalone, self-contained HTML file.
- When an agent must identify the specific JavaScript or CSS dependencies required to render a particular widget.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo 'list(x = JS("1 + 1"))' | Rscript --vanilla skills/htmlwidgets/invoke.R
```
