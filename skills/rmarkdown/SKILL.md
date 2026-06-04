---
name: rmarkdown
runtime: r
package: rmarkdown
package_source: CRAN
package_url: https://github.com/rstudio/rmarkdown
package_version_pinned: ">=2.31"
license: GPL-3
maintainer: "Yihui Xie <xie@yihui.name>"
---

# Skill: rmarkdown

The rmarkdown package provides functionality to convert R Markdown documents into various output formats. An agent should use this skill when a task requires transforming R Markdown (.Rmd) files into HTML, PDF, Word, or presentation formats.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("rmarkdown")`.

## Functions exposed

### render: Render an R Markdown document to a specified format

**Input**

```json
{
  "fn": "render",
  "input": "string",
  "output_format": "string"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "render",
  "result": "string"
}
```

### all_output_formats: Determine all output formats for a document

**Input**

```json
{
  "fn": "all_output_formats",
  "input": "string"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "all_output_formats",
  "result": {
    "type": "array",
    "items": { "type": "string" }
  }
}
```

### available_templates: List available R Markdown templates

**Input**

```json
{
  "fn": "available_templates",
  "package": "string"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "available_templates",
  "result": {
    "type": "array",
    "items": { "type": "string" }
  }
}
```

### beamer_presentation: Create a Beamer presentation format object

**Input**

```json
{
  "fn": "beamer_presentation",
  "incremental": "boolean"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "beamer_presentation",
  "result": "object"
}
```

## When to invoke

* Converting an existing .Rmd file into a PDF document for report generation.
* Generating HTML presentations from R Markdown source code.
* Identifying all possible output formats supported by a specific R Markdown file.
* Listing available document templates within a specific R package to initialize new document drafts.

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
echo '{"fn": "all_output_formats", "input": "test.Rmd"}' | Rscript --vanilla skills/rmarkdown/invoke.R
```
