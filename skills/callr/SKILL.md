---
name: callr
runtime: r
package: callr
package_source: CRAN
package_url: https://callr.r-lib.org
package_version_pinned: ">=3.7.6"
license: MIT
maintainer: "Gábor Csárdi <csardi.gabor@gmail.com>"
---

# Skill: callr

The callr package allows for the execution of R code within a separate R process. This prevents computations from affecting the state of the current R session.

An agent should use this skill when it needs to run R code in a clean environment, execute long-running tasks in the background, or perform computations that require isolation from the primary session.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("callr")`.

## Functions exposed

### r: Evaluate an expression in another R session

**Input**

```json
{ "fn": "r", "expr": "function" }
```

**Output**

```json
{ "ok": true, "fn": "r", "result": "any" }
```

### r_bg: Evaluate an expression in another R session in the background

**Input**

```json
{ "fn": "r_bg", "expr": "function" }
```

**Output**

```json
{ "ok": true, "fn": "r_bg", "result": "callr_process" }
```

### default_repos: Get default value for the repos option

**Input**

```json
{ "fn": "default_repos" }
```

**Output**

```json
{ "ok": true, "fn": "default_repos", "result": "character vector" }
```

## When to invoke

* Running R code that requires a clean environment free from existing workspace variables or loaded packages.
* Executing R functions that are computationally intensive and should run in a background process to avoid blocking the main session.
* Testing R code in an environment that ignores system or user profiles.
* Performing tasks that require specific environment variable configurations, such as setting R_BROWSER or R_PDFVIEWER.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "r", "expr": "function() { 1 + 1 }"}' | Rscript --vanilla skills/callr/invoke.R
```
