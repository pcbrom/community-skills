---
name: progress
runtime: r
package: progress
package_source: CRAN
package_url: https://github.com/r-lib/progress#readme
package_version_pinned: ">=1.2.3"
license: MIT
maintainer: "Gábor Csárdi <csardi.gabor@gmail.com>"
---

# Skill: progress

The progress package provides configurable progress bars for terminal environments, including Emacs, ESS, RStudio, Windows Rgui, and macOS R.app. It allows for the display of percentage completion, elapsed time, and estimated time of arrival.

An agent should use this skill when managing long-running loops or iterative processes where tracking completion status and time estimates is required.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("progress")`.

## Functions exposed

### progress_bar: Create a new progress bar object

**Input**

```json
{
  "fn": "progress_bar$new",
  "total": { "type": "integer" },
  "format": { "type": "string" },
  "clear": { "type": "boolean" },
  "width": { "type": "integer" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "progress_bar$new",
  "result": "R6 object"
}
```

### tick: Update the progress bar by one increment

**Input**

```json
{
  "fn": "tick",
  "delta": { "type": "integer" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "tick",
  "result": null
}
```

## When to invoke

*   When executing iterative loops where the total number of iterations is known.
*   When monitoring the progress of file downloads or data transfers.
*   When tracking the completion of large-scale simulations or computations.
*   When providing visual feedback for long-running data processing tasks in a terminal.

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
echo '{"fn": "progress_bar$new", "total": 100, "format": "[:bar] :percent"}' | Rscript --vanilla skills/progress/invoke.R
```
