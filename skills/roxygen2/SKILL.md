---
name: roxygen2
runtime: r
package: roxygen2
package_source: CRAN
package_url: https://roxygen2.r-lib.org/
package_version_pinned: ">=8.0.0"
license: MIT + file LICENSE
maintainer: "Hadley Wickham <hadley@posit.co>"
---

# Skill: roxygen2

roxygen2 generates Rd documentation, NAMESPACE files, and collation fields from specially formatted comments within R code. This package automates the production of package metadata and documentation files by parsing in-line comments.

An agent should use this skill when tasks involve automating R package documentation, managing NAMESPACE exports, or parsing roclet files.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("roxygen2")`.

## Functions exposed

### `roxygenize`: Generate documentation and NAMESPACE from package source

**Input**

```json
{ "fn": "roxygenize", "package": "string" }
```

**Output**

```json
{ "ok": true, "fn": "roxygenize", "result": "string" }
```

### `namespace_roclet`: Automate NAMESPACE file production

**Input**

```json
{ "fn": "namespace_roclet", "package": "string" }
```

**Output**

```json
{ "ok": true, "fn": "namespace_roclet", "result": "boolean" }
```

### `is_s3_generic`: Determine if a function is an S3 generic

**Input**

```json
{ "fn": "is_s3_generic", "name": "string" }
```

**Output**

```json
{ "ok": true, "fn": "is_s3_generic", "result": "boolean" }
```

### `escape_examples`: Escape Rd examples for documentation

**Input**

```json
{ "fn": "escape_examples", "text": "string" }
```

**Output**

```json
{ "ok": true, "fn": "escape_examples", "result": "string" }
```

## When to invoke

* Automating the creation of `NAMESPACE` files based on `@export` and `@import` tags in R source files.
* Generating `.Rd` documentation files from in-line R comments.
* Verifying if specific function names correspond to S3 generics or S3 methods.
* Formatting R code examples to comply with Rd escaping rules for documentation.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "is_s3_generic", "name": "print"}' | Rscript --vanilla skills/roxygen2/invoke.R
```
