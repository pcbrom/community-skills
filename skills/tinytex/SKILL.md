---
name: tinytex
runtime: r
package: tinytex
package_source: CRAN
package_url: https://github.com/rstudio/tinytex
package_version_pinned: ">=0.59"
license: MIT
maintainer: "Yihui Xie <xie@yihui.name>"
---

# Skill: tinytex

This package provides helper functions to install, maintain, and compile LaTeX documents using the TinyTeX distribution. It allows for the automated installation of missing LaTeX packages and the management of the TeX Live distribution.

An agent should use this skill when it needs to generate PDF documents from LaTeX source, verify the presence of specific LaTeX packages, or manage a lightweight LaTeX installation on a system.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("tinytex")`.

## Functions exposed

### check_installed: Check if certain LaTeX packages are installed

**Input**

```json
{ "fn": "check_installed", "package": "string" }
```

**Output**

```json
{ "ok": true, "fn": "check_installed", "result": "boolean" }
```

### install_tinytex: Install TinyTeX distribution

**Input**

```json
{ "fn": "install_tinytex" }
```

**Output**

```json
{ "ok": true, "fn": "install_tinytex", "result": "boolean" }
```

### is_tinytex: Check if the current LaTeX installation is TinyTeX

**Input**

```json
{ "fn": "is_tinytex" }
```

**Output**

```json
{ "ok": true, "fn": "is_tinytex", "result": "boolean" }
```

### pdflatex: Compile a LaTeX document using pdflatex

**Input**

```json
{ "fn": "pdflatex", "file": "string" }
```

**Output**

```json
{ "ok": true, "fn": "pdflatex", "result": "boolean" }
```

### tlmgr_install: Install a LaTeX package via tlmgr

**Input**

```json
{ "fn": "tlmgr_install", "package": "string" }
```

**Output**

```json
{ "ok": true, "fn": "tlmgr_install", "result": "boolean" }
```

## When to invoke

- When a LaTeX compilation error indicates a missing `.sty` or `.cls` file.
- When a task requires converting `.tex` source files into `.pdf` format.
- When verifying if a lightweight LaTeX environment is available on the current system.
- When automating the setup of a TeX Live environment for reproducible document generation.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "is_tinytex"}' | Rscript --vanilla skills/tinytex/invoke.R
```
