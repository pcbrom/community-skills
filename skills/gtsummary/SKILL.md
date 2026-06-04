---
name: gtsummary
runtime: r
package: gtsummary
package_source: CRAN
package_url: https://github.com/ddsjoberg/gtsummary
package_version_pinned: ">=2.5.1"
license: MIT
maintainer: "Daniel D. Sjoberg <danield.sjoberg@gmail.com>"
---

# Skill: gtsummary

The gtsummary package creates presentation-ready tables that summarize datasets and regression models. It is used to generate formatted summaries of descriptive statistics, such as means and proportions, and to present results from regression models, including logistic regression and Cox proportional hazards regression.

An agent should invoke this skill when a task requires the generation of formatted statistical tables from data frames or model objects, specifically for summarizing variable distributions or displaying regression coefficients with associated statistics.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("gtsummary")`.

## Functions exposed

### `tbl_summary`: Summarize data frames

**Input**

```json
{
  "fn": "tbl_summary",
  "x": { "type": "data.frame" },
  "include": { "type": "array", "items": { "type": "string" } },
  "statistic": { "type": "object" },
  "missing": { "type": "string" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "tbl_summary",
  "result": { "type": "gtsummary_object" }
}
```

### `tbl_regression`: Summarize regression models

**Input**

```json
{
  "fn": "tbl_regression",
  "x": { "type": "model_object" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "tbl_regression",
  "result": { "type": "gtsummary_object" }
}
```

### `add_ci`: Add confidence interval column

**Input**

```json
{
  "fn": "add_ci",
  "x": { "type": "gtsummary_object" },
  "pattern": { "type": "string" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "add_ci",
  "result": { "type": "gtsummary_object" }
}
```

### `add_global_p`: Add global p-values for model covariates

**Input**

```json
{
  "fn": "add_global_p",
  "x": { "type": "gtsummary_object" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "add_global_p",
  "result": { "type": "gtsummary_object" }
}
```

### `add_difference`: Add difference statistics between groups

**Input**

```json
{
  "fn": "add_difference",
  "x": { "type": "gtsummary_object" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "add_difference",
  "result": { "type": "gtsummary_object" }
}
```

## When to invoke

* Generating descriptive statistics tables for clinical or experimental datasets.
* Formatting regression model outputs, such as odds ratios or hazard ratios, into publication-ready tables.
* Adding statistical comparisons, such as p-values or confidence intervals, to existing summary tables.
* Summarizing categorical and continuous variables with specific formatting for means, medians, or proportions.

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
echo '{"fn": "tbl_summary", "x": "trial", "include": ["age", "response"]}' | Rscript --vanilla skills/gtsummary/invoke.R
```
