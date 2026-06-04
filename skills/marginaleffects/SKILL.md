---
name: marginaleffects
runtime: r
package: marginaleffects
package_source: CRAN
package_url: https://marginaleffects.com/
package_version_pinned: ">=0.32.0"
license: GPL (>= 3)
maintainer: "Vincent Arel-Bundock <vincent.arel-bundock@umontreal.ca>"
---

# Skill: marginaleffects

The marginaleffects package computes predictions, comparisons, slopes, marginal means, and hypothesis tests for over 100 classes of statistical and machine learning models in R. It allows for the calculation of uncertainty estimates using the delta method, bootstrapping, or simulation-based inference.

An agent should use this skill when a task requires interpreting model coefficients through marginal effects, calculating risk ratios or odds ratios, or generating data grids for counterfactual predictions.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("marginaleffects")`.

## Functions exposed

### avg_comparisons: Compute average marginal comparisons

**Input**

```json
{
  "fn": "avg_comparisons",
  "model": "object",
  "variables": "list",
  "type": "string",
  "newdata": "object"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "avg_comparisons",
  "result": "data.frame"
}
```

### comparisons: Compute unit-level comparisons

**Input**

```json
{
  "fn": "comparisons",
  "model": "object",
  "variables": "list",
  "newdata": "object"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "comparisons",
  "result": "data.frame"
}
```

### datagrid: Generate a data grid of specified values

**Input**

```json
{
  "fn": "datagrid",
  "model": "object",
  "newdata": "data.frame",
  "variables": "list"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "datagrid",
  "result": "data.frame"
}
```

### predictions: Compute predicted values

**Input**

```json
{
  "fn": "predictions",
  "model": "object",
  "newdata": "object"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "predictions",
  "result": "data.frame"
}
```

### slopes: Compute marginal slopes

**Input**

```json
{
  "fn": "slopes",
  "model": "object",
  "newdata": "object"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "slopes",
  "result": "data.frame"
}
```

## When to invoke

* Calculating risk ratios, odds ratios, or differences in predicted probabilities from GLM outputs.
* Computing average marginal effects for categorical regressors at specific levels.
* Generating counterfactual scenarios by evaluating model predictions at specific values of a predictor.
* Estimating the slope of a continuous variable at the mean or at observed values of other covariates.
* Performing hypothesis tests on non-linear combinations of model parameters.

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
echo '{"fn": "avg_comparisons", "model": "mod", "variables": {"cyl": "reference"}}' | Rscript --vanilla skills/marginaleffects/invoke.R
```
