---
name: brms
runtime: r
package: brms
package_source: CRAN
package_url: https://github.com/paul-buerkner/brms
package_version_pinned: ">=2.23.0"
license: GPL-2
maintainer: "Paul-Christian Bürkner <paul.buerkner@gmail.com>"
---

# Skill: brms

This package fits Bayesian generalized (non-)linear multivariate multilevel models using Stan. It supports a wide range of distributions and link functions, including linear, count, survival, and zero-inflated models.

An agent should use this skill when a task requires Bayesian inference, multilevel modeling, or the estimation of complex regression models with non-standard error structures.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("brms")`.

## Functions exposed

### `brm`: Fit Bayesian regression models

**Input**

```json
{
  "fn": "brm",
  "formula": "string",
  "data": "data.frame",
  "family": "string",
  "prior": "list",
  "cores": "integer",
  "chains": "integer"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "brm",
  "result": "brmsfit"
}
```

### `add_criterion`: Add model fit criteria to model objects

**Input**

```json
{
  "fn": "add_criterion",
  "fit": "brmsfit",
  "criteria": "array"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "add_criterion",
  "result": "brmsfit"
}
```

### `R2D2`: Set up R2D2(M2) priors

**Input**

```json
{
  "fn": "R2D2",
  "mean_R2": "number",
  "prec_R2": "number",
  "main": "boolean"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "R2D2",
  "result": "list"
}
```

## When to invoke

- Estimating multilevel models where observations are nested within groups.
- Fitting regression models with non-Gaussian response variables, such as count data or survival times.
- Implementing distributional regression where parameters of the response distribution are predicted.
- Comparing models using information criteria such as LOO or WAIC.
- Applying specific prior knowledge through flexible prior specifications.

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
echo '{"fn": "brm", "formula": "y ~ x", "data": {"y": [1, 2, 3], "x": [1, 2, 3]}, "family": "gaussian"}' | Rscript --vanilla skills/brms/invoke.R
```
