---
name: generics
runtime: r
package: generics
package_source: CRAN
package_url: https://generics.r-lib.org
package_version_pinned: ">=0.1.4"
license: MIT
maintainer: "Hadley Wickham <hadley@posit.co>"
---

# Skill: generics

The generics package provides several S3 generic functions that are not included in base R methods, specifically those related to model fitting. This package reduces dependency conflicts by providing standardized interfaces for common operations.

An agent should use this skill when it needs to perform standardized operations on model objects, such as calculating accuracy, augmenting datasets with model predictions, or computing statistics using S3 dispatch.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("generics")`.

## Functions exposed

### `accuracy`: Returns range of summary measures of the forecast accuracy

**Input**

```json
{ "fn": "accuracy", "object": "object" }
```

**Output**

```json
{ "ok": true, "fn": "accuracy", "result": "object" }
```

### `augment`: Augment data with information from an object

**Input**

```json
{ "fn": "augment", "data": "data.frame", "object": "object" }
```

**Output**

```json
{ "ok": true, "fn": "augment", "result": "data.frame" }
```

### `calculate`: Calculate statistics

**Input**

```json
{ "fn": "calculate", "object": "object", "..." : "..." }
```

**Output**

```json
{ "ok": true, "fn": "calculate", "result": "numeric" }
```

### `compile`: Finalizes or completes an object

**Input**

```json
{ "fn": "compile", "object": "object" }
```

**Output**

```json
{ "ok": true, "fn": "compile", "result": "object" }
```

## When to invoke

- When evaluating the performance of a fitted model using forecast accuracy metrics.
- When adding model-derived predictions or residuals to an existing dataset.
- When performing statistical computations that require S3 method dispatch for specific object classes.
- When finalizing model objects for downstream processing.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "accuracy", "object": null}' | Rscript --vanilla skills/generics/invoke.R
```
