---
name: quarto
runtime: r
package: quarto
package_source: CRAN
package_url: https://github.com/quarto-dev/quarto-r
package_version_pinned: ">=1.5.1"
license: MIT
maintainer: "Christophe Dervieux <cderv@posit.co>"
---

# Skill: quarto

This package provides an R interface to the Quarto Markdown publishing system. It allows for the conversion of R Markdown documents and Jupyter notebooks into various output formats.

An agent should use this skill when tasks involve rendering documents, managing Quarto projects, migrating bookdown cross-references to Quarto syntax, or preparing R scripts for knitr spin processing.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("quarto")`.

## Functions exposed

### add_spin_preamble: Add spin preamble to an R script

**Input**

```json
{
  "fn": "add_spin_preamble",
  "file": "string",
  "title": "string",
  "preamble": "object"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "add_spin_preamble",
  "result": "boolean"
}
```

### check_newer_version: Check for newer version of Quarto

**Input**

```json
{
  "fn": "check_newer_version",
  "version": "string",
  "verbose": "boolean"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "check_newer_version",
  "result": "boolean"
}
```

### detect_bookdown_crossrefs: Identify bookdown cross-references for migration

**Input**

```json
{
  "fn": "detect_bookdown_crossrefs",
  "file": "string",
  "verbose": "boolean"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "detect_bookdown_crossrefs",
  "result": "list"
}
```

### find_project_root: Find the root of a Quarto project

**Input**

```json
{
  "fn": "find_project_root",
  "path": "string"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "find_project_root",
  "result": "string"
}
```

### quarto_render: Render a Quarto document

**Input**

```json
{
  "fn": "quarto_render",
  "input": "string",
  "output_format": "string",
  "params": "object"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "quarto_render",
  "result": "boolean"
}
```

## When to invoke

- Converting existing R Markdown (.Rmd) or Jupyter (.ipynb) files into HTML, PDF, or Word documents.
- Scanning a directory of legacy bookdown files to identify syntax that requires updates for Quarto compatibility.
- Automating the creation of YAML metadata headers for R scripts intended for use with knitr::spin.
- Locating the configuration root of a Quarto project to resolve relative file paths during document generation.
- Verifying the presence of the Quarto binary and checking for available updates in a deployment environment.

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
echo '{"fn": "quarto_render", "input": "analysis.qmd"}' | Rscript --vanilla skills/quarto/invoke.R
```
