---
name: pkgdown
runtime: r
package: pkgdown
package_source: CRAN
package_url: https://pkgdown.r-lib.org/
package_version_pinned: ">=2.2.0"
license: MIT + file LICENSE
maintainer: "Hadley Wickham <hadley@posit.co>"
---

# Skill: pkgdown

The pkgdown package generates static HTML documentation websites from R package source code. It converts documentation, vignettes, and README files into a navigable web format.

An agent should use this skill when a task requires converting an existing R package into a hosted website, generating favicons from a package logo, or rendering R Markdown vignettes into HTML articles.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("pkgdown")`.

## Functions exposed

### as_pkgdown: Generate pkgdown data structure

**Input**

```json
{ "fn": "as_pkgdown", "package": "string" }
```

**Output**

```json
{ "ok": true, "fn": "as_pkgdown", "result": "object" }
```

### build_articles: Build articles section

**Input**

```json
{ "fn": "build_articles", "pkg": "string" }
```

**Output**

```json
{ "ok": true, "fn": "build_articles", "result": "boolean" }
```

### build_favicons: Initialise favicons from package logo

**Input**

```json
{ "fn": "build_favicons", "pkg": "string" }
```

**Output**

```json
{ "ok": true, "fn": "build_favicons", "result": "boolean" }
```

### build_home: Build home section

**Input**

```json
{ "fn": "build_home", "pkg": "string" }
```

**Output**

```json
{ "ok": true, "fn": "build_home", "result": "boolean" }
```

### build_site: Build the entire website

**Input**

```json
{ "fn": "build_site", "pkg": "string" }
```

**Output**

```json
{ "ok": true, "fn": "build_site", "result": "boolean" }
```

## When to invoke

- Converting an R package directory into a structured HTML website.
- Rendering R Markdown files located in the vignettes directory into HTML articles.
- Generating a set of web-ready favicons from an existing SVG or PNG package logo.
- Rebuilding the home page, authors page, and license page from package metadata.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "build_site", "pkg": "/path/to/package"}' | Rscript --vanilla skills/pkgdown/invoke.R
```
