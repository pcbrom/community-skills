---
name: rstudioapi
runtime: r
package: rstudioapi
package_source: CRAN
package_url: https://rstudio.github.io/rstudioapi/
package_version_pinned: ">=0.18.0"
license: MIT
maintainer: "Kevin Ushey <kevin@rstudio.com>"
---

# Skill: rstudioapi

The rstudioapi package provides an interface to the RStudio IDE API. It allows for programmatic interaction with the RStudio environment, including managing editor themes, retrieving document information, and prompting the user for sensitive input.

An agent should use this skill when it needs to manipulate the RStudio interface, access the current active document, or interact with the user via RStudio-specific dialogs.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("rstudioapi")`.

## Functions exposed

### addTheme: Add a custom editor theme to RStudio

**Input**

```json
{ "fn": "addTheme", "theme": { "type": "string" } }
```

**Output**

```json
{ "ok": true, "fn": "addTheme", "result": { "type": "string" } }
```

### applyTheme: Apply an editor theme to RStudio

**Input**

```json
{ "fn": "applyTheme", "theme": { "type": "string" } }
```

**Output**

```json
{ "ok": true, "fn": "applyTheme", "result": { "type": "boolean" } }
```

### askForPassword: Ask the user for a password interactively

**Input**

```json
{ "fn": "askForPassword", "prompt": { "type": "string" } }
```

**Output**

```json
{ "ok": true, "fn": "askForPassword", "result": { "type": "string" } }
```

### askForSecret: Prompt user for secret

**Input**

```json
{ "fn": "askForSecret", "prompt": { "type": "string" } }
```

**Output**

```json
{ "ok": true, "fn": "askForSecret", "result": { "type": "string" } }
```

### isAvailable: Check if the RStudio API is available

**Input**

```json
{ "fn": "isAvailable", "args": {} }
```

**Output**

```json
{ "ok": true, "fn": "isAvailable", "result": { "type": "boolean" } }
```

## When to invoke

* Checking if the current execution environment is RStudio before attempting IDE-specific commands.
* Modifying the visual appearance of the RStudio editor by adding or applying themes.
* Requesting passwords or sensitive credentials from a user during an interactive session.
* Retrieving the path or content of the currently active document in the RStudio editor.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "isAvailable", "args": {}}' | Rscript --vanilla skills/rstudioapi/invoke.R
```
