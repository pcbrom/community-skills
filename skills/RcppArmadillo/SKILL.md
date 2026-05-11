---
name: RcppArmadillo
runtime: r
package: RcppArmadillo
package_source: CRAN
package_url: https://github.com/RcppCore/RcppArmadillo, https://dirk.eddelbuettel.com/code/rcpp.armadillo.html
package_version_pinned: ">=15.2.6-1"
license: GPL (>= 2)
maintainer: "Dirk Eddelbuettel <edd@debian.org>"
---

# Skill: RcppArmadillo

RcppArmadillo provides an interface between R and the Armadillo C++ library for templated linear algebra. It enables high-level syntax for operations on vectors, matrices, and cubes, supporting dense and sparse structures.

An agent should use this skill when tasks require efficient linear model fitting, matrix decompositions, or the creation of new R packages that utilize C++ Armadillo features.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("RcppArmadillo")`.

## Functions exposed

### `fastLm`: Estimates a linear model using the Armadillo solve function

**Input**

```json
{
  "fn": "fastLm",
  "formula": "string",
  "data": "object"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "fastLm",
  "result": "object"
}
```

### `fastLmPure`: Bare-bones linear model fitting using direct matrices

**Input**

```json
{
  "fn": "fastLmPure",
  "x": "matrix",
  "y": "vector"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "fastLmPure",
  "result": "object"
}
```

### `armadillo_version`: Reports the version of the Armadillo library

**Input**

```json
{
  "fn": "armadillo_version"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "armadillo_version",
  "result": "string"
}
```

### `RcppArmadillo.package.skeleton`: Automates creation of a new R package skeleton

**Input**

```json
{
  "fn": "RcppArmadillo.package.skeleton",
  "package_name": "string"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "RcppArmadillo.package.skeleton",
  "result": "null"
}
```

## When to invoke

- Performing linear regression on large datasets where speed is a priority.
- Fitting linear models using direct matrix inputs without R formula overhead.
- Verifying the installed version of the Armadillo C++ library.
- Generating boilerplate code for new R packages that require C++ integration via Armadillo.
- Managing parallelization settings for OpenMP-enabled operations.

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
echo '{"fn": "armadillo_version"}' | Rscript --vanilla skills/RcppArmadillo/invoke.R
```
