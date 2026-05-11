---
name: RcppEigen
runtime: r
package: RcppEigen
package_source: CRAN
package_url: https://github.com/RcppCore/RcppEigen, https://dirk.eddelbuettel.com/code/rcpp.eigen.html
package_version_pinned: ">=0.3.4.0.2"
license: GPL (>= 2)
maintainer: "Dirk Eddelbuettel <edd@debian.org>"
---

# Skill: RcppEigen

RcppEigen provides integration between R and the Eigen C++ template library for linear algebra. It enables the use of Eigen for operations involving matrices, vectors, numerical solvers, and decompositions for dense and sparse matrices.

An agent should use this skill when tasks require high-performance linear algebra computations, such as fitting linear models via Eigen-based methods or generating C++ package skeletons for Eigen integration.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("RcppEigen")`.

## Functions exposed

### `fastLm`: Estimate a linear model using Eigen-based methods

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

### `fastLmPure`: Bare-bones linear model fitting using model matrix and response

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

### `RcppEigen.package.skeleton`: Create a skeleton for a new RcppEigen package

**Input**

```json
{
  "fn": "RcppEigen.package.skeleton",
  "package_name": "string"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "RcppEigen.package.skeleton",
  "result": "null"
}
```

## When to invoke

- Performing linear regression where performance benefits from Eigen-based solvers are required.
- Fitting linear models using a model matrix and response vector directly without R formula overhead.
- Automating the setup of new R package structures that require RcppEigen headers.

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
echo 'Rscript --vanilla -e "library(RcppEigen); print(fastLm(y ~ x, data=data.frame(x=1:5, y=2:6)))"' | Rscript --vanilla skills/RcppEigen/invoke.R
```
