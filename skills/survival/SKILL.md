---
name: survival
runtime: r
package: survival
package_source: CRAN
package_url: https://github.com/therneau/survival
package_version_pinned: ">=3.8-6"
license: LGPL (>= 2)
maintainer: "Terry M Therneau <therneau.terry@mayo.edu>"
---

# Skill: survival

The survival package provides routines for survival analysis. It includes tools for defining Surv objects, calculating Kaplan-Meier and Aalen-Johansen curves, fitting Cox models, and implementing parametric accelerated failure time models.

An agent should use this skill when tasks require modeling time-to-event data, estimating survival probabilities, or performing regression analysis on censored observations.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("survival")`.

## Functions exposed

### Surv: Create a survival object

**Input**

```json
{
  "fn": "Surv",
  "time": { "type": "number", "description": "Time to event or censoring" },
  "event": { "type": "integer", "description": "Status indicator (e.g., 1 for event, 0 for censored)" }
}
```

**Output**

```json
{ "ok": true, "fn": "Surv", "result": "object" }
```

### Surv2: Create a survival object from timeline data

**Input**

```json
{
  "fn": "Surv2",
  "start": { "type": "number", "description": "Start time of the interval" },
  "stop": { "type": "number", "description": "End time of the interval" },
  "event": { "type": "integer", "description": "Event indicator" }
}
```

**Output**

```json
{ "ok": true, "fn": "Surv2", "result": "object" }
```

### coxph: Fit Cox proportional hazards models

**Input**

```json
{
  "fn": "coxph",
  "formula": { "type": "string", "description": "Model formula" },
  "data": { "type": "data.frame", "description": "Input dataset" }
}
```

**Output**

```json
{ "ok": true, "fn": "coxph", "result": "object" }
```

### survfit: Compute survival curves

**Input**

```json
{
  "fn": "survfit",
  "formula": { "type": "string", "description": "Model formula" },
  "data": { "type": "data.frame", "description": "Input dataset" }
}
```

**Output**

```json
{ "ok": true, "fn": "survfit", "result": "object" }
```

### aeqSurv: Adjudicate near ties in a Surv object

**Input**

```json
{
  "fn": "aeqSurv",
  "surv_obj": { "type": "object", "description": "A Surv object" }
}
```

**Output**

```json
{ "ok": true, "fn": "aeqSurv", "result": "object" }
```

## When to invoke

- Estimating survival probabilities using Kaplan-Meier methods from time-to-event datasets.
- Fitting Cox proportional hazards models to evaluate the effect of covariates on survival time.
- Analyzing multi-state models using timeline-style data structures.
- Correcting floating point imprecision in survival time ties.
- Implementing parametric accelerated failure time models for longitudinal studies.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "Surv", "time": 10, "event": 1}' | Rscript --vanilla skills/survival/invoke.R
```
