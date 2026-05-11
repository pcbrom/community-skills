---
name: backports
runtime: r
package: backports
package_source: CRAN
package_url: https://github.com/r-lib/backports
package_version_pinned: ">=1.5.1"
license: GPL-2 | GPL-3
maintainer: "Michel Lang <michellang@gmail.com>"
---

# Skill: backports

The backports package provides reimplementations of functions introduced or changed in R since version 3.0.0. It allows for compatibility across different R installations by providing backported versions of specific functions.

An agent should use this skill when writing or maintaining R packages that require compatibility with R versions older than 3.0.0, or when specifically needing to ensure consistent behavior of functions like anyNA, URLencode, or R_user_dir across varying R environments.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("backports")`.

## Functions exposed

### import: Import backported functions into a package namespace

**Input**

```json
{
  "fn": "import",
  "pkgname": "string",
  "functions": {
    "type": "array",
    "items": { "type": "string" },
    "description": "Specific functions to import"
  },
  "force": {
    "type": "boolean",
    "description": "Whether to force import specific functions"
  }
}
```

**Output**

```json
{ "ok": true, "fn": "import", "result": "null" }
```

### anyNA: Check if any element of a logical vector is NA

**Input**

```json
{
  "fn": "anyNA",
  "x": {
    "type": "array",
    "items": { "type": ["numeric", "character", "logical"] }
  }
}
```

**Output**

```json
{ "ok": true, "fn": "anyNA", "result": "boolean" }
```

### URLencode: Encode a URL string

**Input**

```json
{
  "fn": "URLencode",
  "x": { "type": "string" },
  "repeated": { "type": "boolean" }
}
```

**Output**

```json
{ "ok": true, "fn": "URLencode", "result": "string" }
```

### R_user_dir: Determine the user directory for a given package

**Input**

```json
{
  "fn": "R_user_dir",
  "package": { "type": "string" }
}
```

**Output**

```json
{ "ok": true, "fn": "R_user_dir", "result": "string" }
```

## When to invoke

*   When developing R packages that must support R versions prior to 3.0.0.
*   When a task requires checking for NA values in vectors using the backported anyNA implementation.
*   When performing URL encoding where the repeated argument behavior must be consistent across R versions older than 3.2.0.
*   When managing user directories for packages in environments with R versions older than 4.0.0.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "anyNA", "x": [1, 2, null]}' | Rscript --vanilla skills/backports/invoke.R
```
