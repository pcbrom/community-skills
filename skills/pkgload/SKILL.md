---
name: pkgload
runtime: r
package: pkgload
package_source: CRAN
package_url: https://github.com/r-lib/pkgload
package_version_pinned: ">=1.5.2"
license: MIT
maintainer: "Lionel Henry <lionel@posit.co>"
---

# Skill: pkgload

The pkgload package simulates the process of installing and attaching an R package. It is used to facilitate rapid iteration during R package development by loading the package contents without a formal installation.

An agent should use this skill when it needs to load a local package for testing, run examples from an in-development package, or verify dependency versions within a development environment.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("pkgload")`.

## Functions exposed

### check_dep_version: Check that the version of an imported package satisfies requirements

**Input**

```json
{ "fn": "check_dep_version", "package": "string" }
```

**Output**

```json
{ "ok": true, "fn": "check_dep_version", "result": "boolean" }
```

### check_suggested: Check that the version of a suggested package satisfies requirements

**Input**

```json
{ "fn": "check_suggested", "package": "string" }
```

**Output**

```json
{ "ok": true, "fn": "check_suggested", "result": "boolean" }
```

### dev_example: Run examples for an in-development function

**Input**

```json
{ "fn": "dev_example", "function_name": "string" }
```

**

**Output**

```json
{ "ok": true, "fn": "dev_example", "result": "null" }
```

### dev_help: Search for source documentation for packages loaded with devtools

**Input**

```json
{ "fn": "dev_help", "topic": "string" }
```

**Output**

```json
{ "ok": true, "fn": "dev_help", "result": "null" }
```

### load_all: Load all files in a package directory

**Input**

```json
{ "fn": "load_all", "path": "string" }
```

**Output**

```json
{ "ok": true, "fn": "load_all", "result": "null" }
```

## When to invoke

- Verifying if a specific version of an imported dependency meets the requirements of a local package.
- Executing code examples from a package currently under development.
- Accessing documentation for functions in a package that has been loaded via load_all.
- Loading the contents of a local package directory to prepare for testing or debugging.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "dev_example", "function_name": "ggplot"}' | Rscript --vanilla skills/pkgload/invoke.R
```
