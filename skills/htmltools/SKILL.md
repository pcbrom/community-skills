---
name: htmltools
runtime: r
package: htmltools
package_source: CRAN
package_url: https://github.com/rstudio/htmltools
package_version_pinned: ">=0.5.9"
license: GPL (>= 2)
maintainer: "Carson Sievert <carson@posit.co>"
---

# Skill: htmltools

The htmltools package provides tools for HTML generation and output. It allows for the programmatic construction of HTML elements and the management of HTML dependencies.

An agent should use this skill when tasks require the creation of HTML markup, the manipulation of HTML tags, or the preparation of HTML documents for browser rendering.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("htmltools")`.

## Functions exposed

### HTML: Mark characters as HTML to prevent escaping

**Input**

```json
{ "fn": "HTML", "x": "string" }
```

**Output**

```json
{ "ok": true, "fn": "HTML", "result": "string" }
```

### as.tags: Convert arbitrary values to tags

**Input**

```json
{ "fn": "as.tags", "x": "any" }
```

**Output**

```json
{ "ok": true, "fn": "as.tags", "result": "string" }
```

### bindFillRole: Allow tags to intelligently fill their container

**Input**

```json
{ "fn": "bindFillRole", "x": "any", "container": "boolean", "item": "boolean", ".cssSelector": "string" }
```

**Output**

```json
{ "ok": true, "fn": "bindFillRole", "result": "any" }
```

### browsable: Make an HTML object browsable

**Input**

```json
{ "fn": "browsable", "x": "any" }
```

**Output**

```json
{ "ok": true, "fn": "browsable", "result": "any" }
```

## When to invoke

* Generating HTML markup from string inputs or R objects.
* Constructing nested HTML structures using tag functions.
* Managing CSS or JavaScript dependencies within an HTML document.
* Converting raw text into HTML-safe objects to prevent unintended character escaping.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo 'list(fn="HTML", x="<b>bold</b>")' | Rscript --vanilla skills/htmltools/invoke.R
```
