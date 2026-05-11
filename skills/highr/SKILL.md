---
name: highr
runtime: r
package: highr
package_source: CRAN
package_url: https://github.com/yihui/highr
package_version_pinned: ">=0.12"
license: GPL
maintainer: "Yihlam Xie <xie@yihui.name>"
---

# Skill: highr

The highr package provides syntax highlighting for R source code. It generates formatted output in LaTeX and HTML formats.

The package can be used to transform raw R code strings into structured markup for document generation.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("highr")`.

## Functions exposed

### hi_andre: A wrapper to Andre Simon's Highlight

**Input**

```json
{
  "fn": "hi_andre",
  "code": "string",
  "language": "string",
  "format": "string"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "hi_andre",
  "result": "string"
}
```

### hi_html: Syntax highlight R code for HTML output

**Input**

```json
{
  "fn": "hi_html",
  "code": "string or array of strings"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "hi_html",
  "result": "string"
}
```

### hi_latex: Syntax highlight R code for LaTeX output

**Input**

```json
{
  "fn": "hi_latex",
  "code": "string or array of strings"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "hi_latex",
  "result": "string"
}
```

### hilight: Syntax highlight an R code fragment

**Input**

```json
{
  "fn": "hilight",
  "code": "string or array of strings"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "hilight",
  "result": "string"
}
```

## When to invoke

- Converting R code snippets into HTML for web-based documentation.
- Generating LaTeX markup for R code blocks in scientific papers.
- Applying syntax highlighting to non-R languages such as C via the hi_andre interface.
- Transforming raw R strings into tokenized markup for custom document styles.

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
echo '{"fn": "hi_html", "code": "x <- 1 # comment"}' | Rscript --vanilla skills/highr/invoke.R
```
