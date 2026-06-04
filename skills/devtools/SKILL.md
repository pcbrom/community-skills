---
name: devtools
runtime: r
package: devtools
package_source: CRAN
package_url: https://devtools.r-lib.org/
package_version_pinned: ">=2.5.2"
license: MIT
maintainer: "Jennifer Bryan <jenny@posit.co>"
---

# Skill: devtools

The devtools package provides a collection of tools for R package development. An agent should use this skill when tasks involve building, checking, documenting, or installing R packages from local directories or remote repositories.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("devtools")`.

## Functions exposed

### build: Convert a package source directory into a bundled file

**Input**

```json
{ "fn": "build", "binary": false, "path": "string" }
```

**Output**

```json
{ "ok": true, "fn": "build", "result": "string" }
```

### check: Check a package for errors and compliance

**Input**

```json
{ "fn": "check", "path": "string" }
```

**Output**

```json
{ "ok": true, "fn": "check", "result": "string" }
```

### document: Generate documentation from roxygen2 comments

**Input**

```json
{ "fn": "document", "path": "string" }
```

**Output**

```json
{ "ok": true, "fn": "document", "result": "boolean" }
```

### install: Install a package from a specified source

**Input**

```json
{ "fn": "install", "package": "string", "repos": "string" }
```

**Output**

```json
{ "ok": true, "fn": "install", "result": "boolean" }
```

### load_all: Load a package for development

**Input**

```json
{ "fn": "load_all", "path": "string" }
```

**Output**

```json
{ "ok": true, "fn": "load_all", "result": "boolean" }
```

## When to invoke

*   Converting a local R package directory into a `.tar.gz` or `.zip` archive for distribution.
*   Verifying package integrity and compliance with CRAN standards using the check function.
*   Updating `.Rd` files in the `man/` directory based on updated Roxygen2 comments in the source code.
*   Installing R packages from GitHub, GitLab, or local file paths.
*   Loading a package's namespace and functions into the current session for testing purposes.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "build", "binary": false}' | Rscript --vanilla skills/devtools/invoke.R
```
