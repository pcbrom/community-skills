---
name: styler
runtime: r
package: styler
package_source: CRAN
package_url: https://github.com/r-lib/styler
package_version_pinned: ">=1.11.0"
license: MIT
maintainer: "Lorenz Walthert <lorenz.walthert@icloud.com>"
---

# Skill: styler

The styler package provides non-invasive pretty-printing of R code. It reformats R code to follow consistent style guidelines without altering the underlying logic or the user's formatting intent.

An agent should use this skill when R code requires standardization, when cleaning up unformatted scripts, or when preparing R code for submission to repositories that enforce specific style guides.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("styler")`.

## Functions exposed

### style_text: Pretty-print R code from a character vector

**Input**

```json
{ "fn": "style_text", "text": "string" }
```

**Output**

```json
{ "ok": true, "fn": "style_text", "result": "string" }
```

### style_file: Pretty-print an R file

**Input**

```json
{ "fn": "style_file", "file": "string" }
```

**

**Output**

```json
{ "ok": true, "fn": "style_file", "result": "string" }
```

### style_pkg: Pretty-print all R files in a package directory

**Input**

```json
{ "fn": "style_pkg", "path": "string" }
```

**Output**

```json
{ "ok": true, "fn": "style_pkg", "result": "array" }
```

### cache_clear: Clear the styler cache

**Input**

```json
{ "fn": "cache_clear" }
```

**Output**

```json
{ "ok": true, "fn": "cache_clear", "result": null }
```

### compute_parse_data_nested: Obtain a nested parse table from a character vector

**Input**

```json
{ "fn": "compute_parse_data_nested", "text": "string" }
```

**Output**

```json
{ "ok": true, "fn": "compute_parse_data_nested", "result": "object" }
```

## When to invoke

* Standardizing R code snippets provided in text format to match tidyverse style conventions.
* Reformatting R script files to ensure consistent indentation and spacing before committing to version control.
* Cleaning up entire R package directories to ensure all files within the package adhere to a uniform style.
* Parsing R code into nested structures for programmatic analysis of code syntax.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "style_text", "text": "x <- 1;y<-2"}' | Rscript --vanilla skills/styler/invoke.R
```
