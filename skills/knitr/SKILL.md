---
name: knitr
runtime: r
package: knitr
package_source: CRAN
package_url: https://yihui.org/knitr/
package_version_pinned: ">=1.51"
license: GPL
maintainer: "Yihui Xie <xie@yihui.name>"
---

# Skill: knitr

knitr provides a general-purpose tool for dynamic report generation in R using Literate Programming techniques. It allows for the execution of code chunks within a document to produce integrated text and output.

An agent should use this skill when it needs to transform R code or Sweave documents into formatted reports such as HTML, PDF, or Markdown.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("knitr")`.

## Functions exposed

### knit: Execute a knitr document

**Input**

```json
{ "fn": "knit", "filename": "string" }
```

**Output**

```json
{ "ok": true, "fn": "knit", "result": "string" }
```

### knit2pdf: Render a document to PDF

**Input**

```json
{ "fn": "knit2pdf", "filename": "string" }
```

**Output**

```json
{ "ok": true, "fn": "knit2pdf", "result": "string" }
```

### knit2html: Render a document to HTML

**Input**

```json
{ "fn": "knit2html", "filename": "string" }
```

**Output**

```json
{ "ok": true, "fn": "knit2html", "result": "string" }
```

### Sweave2knitr: Convert Sweave documents to knitr format

**Input**

```json
{ "fn": "Sweave2knitr", "text": "string", "output": "string" }
```

**Output**

```json
{ "ok": true, "fn": "Sweave2knitr", "result": "string" }
```

### all_labels: Retrieve all chunk labels from a document

**Input**

```json
{ "fn": "all_labels", "conditions": "string" }
```

**Output**

```json
{ "ok": true, "fn": "all_labels", "result": "array of strings" }
```

## When to invoke

* Converting legacy .Rnw (Sweave) files into modern .knitr compatible formats.
* Generating automated HTML reports from R Markdown or knitr source files.
* Producing PDF documentation containing integrated R code execution results.
* Extracting specific code chunk labels from a document for targeted processing.
* Transforming raw R output into formatted tables using kable.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "knit", "filename": "test.Rnw"}' | Rscript --vanilla skills/knitr/invoke.R
```
