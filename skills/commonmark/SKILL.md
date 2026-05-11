---
name: commonmark
runtime: r
package: commonmark
package_source: CRAN
package_url: https://docs.ropensci.org/commonmark/
package_version_pinned: ">=2.0.0"
license: BSD_2_clause
maintainer: "Jeroen Ooms <jeroenooms@gmail.com>"
---

# Skill: commonmark

This package provides high performance rendering of CommonMark and GitHub Flavored Markdown (GFM) using the cmark reference implementation. It enables the conversion of markdown text into HTML, LaTeX, groff man, and XML formats.

An agent should use this skill when it needs to transform markdown syntax into structured document formats or extract the markdown parse tree as XML.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("commonmark")`.

## Functions exposed

### markdown_html: Convert markdown to HTML

**Input**

```json
{ "fn": "markdown_html", "markdown": "string" }
```

**Output**

```json
{ "ok": true, "fn": "markdown_html", "result": "string" }
```

### markdown_latex: Convert markdown to LaTeX

**Input**

```json
{ "fn": "markdown_latex", "markdown": "string" }
```

**Output**

```json
{ "ok": true, "fn": "markdown_latex", "result": "string" }
```

### markdown_xml: Convert markdown to XML parse tree

**Input**

```json
{ "fn": "markdown_xml", "markdown": "string" }
```

**Output**

```json
{ "ok": true, "fn": "markdown_xml", "result": "string" }
```

### markdown_text: Convert markdown to plain text

**Input**

```json
{ "fn": "markdown_text", "markdown": "string" }
```

**Output**

```json
{ "ok": true, "fn": "markdown_text", "result": "string" }
```

### list_extensions: List available GitHub Flavored Markdown extensions

**Input**

```json
{ "fn": "list_extensions" }
```

**Output**

```json
{ "ok": true, "fn": "list_extensions", "result": "array" }
```

## When to invoke

* Converting markdown documentation into HTML for web display.
* Transforming markdown content into LaTeX for scientific publication.
* Extracting the structural hierarchy of a markdown document via XML parsing.
* Stripping markdown syntax to obtain plain text from a document.
* Verifying the availability of GFM extensions like tables or strikethrough in the current environment.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "markdown_html", "markdown": "# Hello\n**World**"}' | Rscript --vanilla skills/commonmark/invoke.R
```
