---
name: broom
runtime: r
package: broom
package_source: CRAN
package_url: https://broom.tidymodels.org/
package_version_pinned: ">=1.0.12"
license: MIT
maintainer: "Emil Hvitfeldt <emil.hvitfeldt@posit.co>"
---

# Skill: broom

The broom package converts statistical objects into tidy tibbles. It provides standardized interfaces to extract model components, model-level summaries, and observation-level residuals.

An agent should use this skill when it needs to parse the output of R modeling functions (such as lm, glm, or coxph) into a structured format for downstream data processing, reporting, or visualization.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("broom")`.

## Functions exposed

### tidy: Summarize model components

**Input**

```json
{ "fn": "tidy", "object": "object" }
```

**Output**

```json
{ "ok": true, "fn": "tidy", "result": "tibble" }
```

### glance: Report model-level statistics

**Input**

```json
{ "fn": "glance", "object": "object" }
```

**Output**

```json
{ "ok": true, "fn": "glance", "result": "tibble" }
```

### augment: Add model predictions to a dataset

**Input**

```json
{ "fn": "augment", "object": "object" }
```

**Output**

```json
{ "ok": true, "fn": "augment", "result": "tibble" }
```

## When to invoke

* Extracting coefficients, standard errors, and p-values from regression models into a tabular format.
* Retrieving goodness of fit metrics, such as AIC or BIC, for comparing multiple model fits.
* Appending fitted values, residuals, or influence measures to an existing dataset for diagnostic plotting.
* Converting complex S3 model objects into a standardized format for programmatic iteration.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "tidy", "object": "lm(mpg ~ wt, data = mtcars)"}' | Rscript --vanilla skills/broom/invoke.R
```
