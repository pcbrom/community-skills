---
name: cli
runtime: r
package: cli
package_source: CRAN
package_url: https://cli.r-lib.org
package_version_pinned: ">=3.6.6"
license: MIT
maintainer: "Gábor Csárdi <gabor@posit.co>"
---

# Skill: cli

The cli package provides a suite of tools for constructing command line interfaces. It enables the creation of semantic elements such as headings, lists, and alerts, and supports custom themes via a CSS-like language.

An agent should use this skill when tasks require the formatting of text for terminal output, including the application of ANSI colors, text styles, or the structural arrangement of strings into columns and lists.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("cli")`.

## Functions exposed

### ansi_collapse: Collapse a vector into a string scalar

**Input**

```json
{
  "fn": "ansi_collapse",
  "x": { "type": "array", "items": { "type": "string" } },
  "sep": { "type": "string" },
  "sep2": { "type": "string" },
  "last": { "type": "string" },
  "trunc": { "type": "integer" },
  "style": { "type": "string" }
}
```

**Output**

```json
{ "ok": true, "fn": "ansi_collapse", "result": { "type": "string" } }
```

### ansi_columns: Format a character vector in multiple columns

**Input**

```json
{
  "fn": "ansi_columns",
  "x": { "type": "array", "items": { "type": "string" } }
}
```

**Output**

```json
{ "ok": true, "fn": "ansi_columns", "result": { "type": "string" } }
```

### ansi_grep: Search for patterns in ANSI strings

**Input**

```json
{
  "fn": "ansi_grep",
  "pattern": { "type": "string" },
  "x": { "type": "array", "items": { "type": "string" } }
}
```

**Output**

```json
{ "ok": true, "fn": "ansi_grep", "result": { "type": "array", "items": { "type": "integer" } } }
```

### cli_alert_success: Display a success alert

**Input**

```json
{
  "fn": "cli_alert_success",
  "msg": { "type": "string" }
}
```

**Output**

```json
{ "ok": true, "fn": "cli_alert_success", "result": null }
```

## When to invoke

- Formatting lists of strings into a single, human-readable string with custom separators.
- Arranging text elements into a multi-column layout for terminal display.
- Searching for specific substrings within text that contains ANSI color codes.
- Generating structured terminal notifications such as success, warning, or error alerts.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "ansi_collapse", "x": ["a", "b", "c"], "sep": ", "}' | Rscript --vanilla skills/cli/invoke.R
```
