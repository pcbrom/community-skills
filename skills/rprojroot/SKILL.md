---
name: rprojroot
runtime: r
package: rprojroot
package_source: CRAN
package_url: https://rprojroot.r-lib.org/
package_version_pinned: ">=2.1.1"
license: MIT + file LICENSE
maintainer: "Kirill Müller <kirill@cynkra.com>"
---

# Skill: rprojroot

This package provides tools for identifying the root directory of a project hierarchy. It allows for locating a directory based on specific criteria, such as the presence of a particular file or a specific file pattern.

An agent should use this skill when it needs to resolve absolute paths to files within a project structure, regardless of the current working directory.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("rprojroot")`.

## Functions exposed

### find_root: Find the root of a directory hierarchy

**Input**

```json
{ "fn": "find_root", "criterion": "object" }
```

**Output**

```json
{ "ok": true, "fn": "find_root", "result": "string" }
```

### find_root_file: Find a file path relative to the project root

**Input**

```json
{ "fn": "find_root_file", "path_components": "array" }
```

**Output**

```json
{ "ok": true, "fn": "find_root_file", "result": "string" }
```

### is_r_package: Check if a directory is an R package

**Input**

```json
{ "fn": "is_r_package", "path": "string" }
```

**Output**

```json
{ "ok": true, "fn": "is_r_package", "result": "boolean" }
```

### has_file: Check for the existence of a file pattern

**Input**

```json
{ "fn": "has_file", "file": "string", "contents": "string" }
```

**Output**

```json
{ "ok": true, "fn": "has_file", "result": "object" }
```

## When to invoke

* Locating a `DESCRIPTION` file to identify the base of an R package.
* Resolving paths to test files within a `tests/testthat` directory relative to the project root.
* Determining if the current working directory is part of a Git, RStudio, or Quarto project.
* Finding a specific configuration file by searching upwards through the directory tree.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "find_root_file", "path_components": ["tests", "testthat.R"]}' | Rscript --vanilla skills/rprojroot/invoke.R
```
