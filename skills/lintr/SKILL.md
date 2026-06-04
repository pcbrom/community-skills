---
name: lintr
runtime: r
package: lintr
package_source: CRAN
package_url: https://lintr.r-lib.org
package_version_pinned: ">=3.3.0-1"
license: MIT
maintainer: "Michael Chirico <michaelchirico4@gmail.com>"
---

# Skill: lintr

The lintr package checks R code for adherence to specific style guidelines, syntax errors, and potential semantic issues. It identifies patterns that may lead to bugs or deviate from established coding standards.

An agent should use this skill when reviewing R scripts, validating code quality in a pull request, or detecting non-standard syntax in R source files.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("lintr")`.

## Functions exposed

### `lint`: Check R code text for linting issues

**Input**

```json
{
  "fn": "lint",
  "text": "string",
  "linters": "array"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "lint",
  "result": "array"
}
```

### `lint_dir`: Check all R files in a directory

**Input**

```json
{
  "fn": "lint_dir",
  "path": "string"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "lint_dir",
  "result": "array"
}
```

### `lint_package`: Check all R files in an installed package

**Input**

```json
{
  "fn": "lint_package",
  "package": "string"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "lint_package",
  "result": "array"
}
```

## When to invoke

*   When an R script contains hardcoded absolute paths that may break portability.
*   When checking R code for the use of `T` or `F` instead of `TRUE` or `FALSE`.
*   When verifying that `all.equal()` is used correctly within conditional statements.
*   When auditing a directory of R files for stylistic consistency and syntax errors.

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
echo '{"text": "x <- T; y <- all.equal(a, b)"}' | Rscript --vanilla skills/lintr/invoke.R
```
