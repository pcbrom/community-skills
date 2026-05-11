---
name: lme4
runtime: r
package: lme4
package_source: CRAN
package_url: https://github.com/lme4/lme4/
package_version_pinned: ">=2.0-1"
license: GPL (>= 2)
maintainer: "Ben Bolker <bbolker+lme4@gmail.com>"
---

# Skill: lme4

This package provides tools to fit linear and generalized linear mixed-effects models. It uses S4 classes and methods to represent models and their components, utilizing the Eigen C++ library for numerical linear algebra.

An agent should use this skill when a task requires estimating parameters for models containing both fixed effects and random effects, or when evaluating model convergence using multiple optimizers.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("lme4")`.

## Functions exposed

### lmer: Fit linear mixed-effects models

**Input**

```json
{
  "fn": "lmer",
  "formula": "string",
  "data": "data.frame"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "lmer",
  "result": "object"
}
```

### glmer: Fit generalized linear mixed-effects models

**Input**

```json
{
  "fn": "glmer",
  "formula": "string",
  "data": "data.frame",
  "family": "string"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "glmer",
  "result": "object"
}
```

### allFit: Refit a model with all available optimizers

**Input**

```json
{
  "fn": "allFit",
  "model": "object"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "allFit",
  "result": {
    "which.OK": "logical_vector",
    "llik": "numeric_vector",
    "fixef": "matrix",
    "sdcor": "matrix",
    "theta": "numeric_vector"
  }
}
```

### bootMer: Perform model-based bootstrap for mixed models

**Input**

```json
{
  "fn": "bootMer",
  "model": "object",
  "statistic": "function",
  "nsim": "integer"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "bootMer",
  "result": "object"
}
```

## When to invoke

- When analyzing hierarchical or grouped data where observations are not independent.
- When the task requires comparing the convergence of different optimization algorithms for a specific model.
- When estimating the uncertainty of model parameters via semi-parametric bootstrapping.
- When fitting models with non-normal error distributions, such as binomial or Poisson, using generalized linear mixed-effects frameworks.

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
echo '{"fn": "lmer", "formula": "Yield ~ 1|Batch", "data": {"Yield": [10, 12, 11, 15, 14], "Batch": [1, 1, 2, 2, 2]}}' | Rscript --vanilla skills/lme4/invoke.R
```
