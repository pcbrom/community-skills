---
name: lavaan
runtime: r
package: lavaan
package_source: CRAN
package_url: https://cran.r-project.org/package=lavaan
package_version_pinned: ">=0.6-21"
license: GPL (>= 2)
maintainer: "Yves Rosseel <Yves.Rosseel@UGent.be>"
---

# Skill: lavaan

The lavaan package provides tools to fit various latent variable models. This includes confirmatory factor analysis, structural equation modeling, and latent growth curve models.

An agent should use this skill when a task requires estimating relationships between observed and latent variables, testing measurement models, or analyzing longitudinal data through growth curves.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("lavaan")`.

## Functions exposed

### `lavaan`: Fit a latent variable model

**Input**

```json
{
  "fn": "lavaan",
  "model": "string",
  "data": "data.frame"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "lavaan",
  "result": "lavaan.fit"
}
```

### `cfa`: Fit Confirmatory Factor Analysis models

**Input**

```json
{
  "fn": "cfa",
  "model": "string",
  "data": "data.frame"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "cfa",
  "result": "lavaan.fit"
}
```

### `sem`: Fit Structural Equation Models

**Input**

```json
{
  "fn": "sem",
  "model": "string",
  "data": "data.frame"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "sem",
  "result": "lavaan.fit"
}
```

### `growth`: Fit Growth Curve models

**Input**

```json
{
  "fn": "growth",
  "model": "string",
  "data": "data.frame"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "growth",
  "result": "lavaan.fit"
}
```

## When to invoke

- When the task involves testing a pre-specified measurement model where observed indicators load onto latent factors.
- When the task requires estimating paths between latent constructs in a structural equation model.
- When the task involves analyzing trajectories of change over multiple time points using growth curve modeling.
- When the input data contains observed variables and the goal is to quantify the underlying latent structure.

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
echo '{"fn": "cfa", "model": "visual =~ x1 + x2 + x3", "data": "HolzingerSwineford1939"}' | Rscript --vanilla skills/lavaan/invoke.R
```
