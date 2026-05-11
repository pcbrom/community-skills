---
name: magrittr
runtime: r
package: magrittr
package_source: CRAN
package_url: https://magrittr.tidyverse.org
package_version_pinned: ">=2.0.5"
license: MIT
maintainer: "Lionel Henry <lionel@posit.co>"
---

# Skill: magrittr

The magrittr package provides a mechanism for chaining commands using the forward-pipe operator, `%>%`. This operator forwards a value or the result of an expression into the next function call or expression.

An agent should use this skill when it needs to construct or manipulate sequences of operations where the output of one function serves as the input to the next.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("magrittr")`.

## Functions exposed

### %>%

**Input**

```json
{ "fn": "%>%", "lhs": "any", "rhs": "expression" }
```

**Output**

```json
{ "ok": true, "fn": "%>%", "result": "any" }
```

### freduce

**Input**

```json
{ "fn": "freduce", "value": "any", "functions": "list" }
```

**Output**

```json
{ "ok": true, "fn": "freduce", "result": "any" }
```

### debug_pipe

**Input**

```json
{ "fn": "debug_pipe" }
```

**Output**

```json
{ "ok": true, "fn": "debug_pipe", "result": null }
```

### functions

**Input**

```json
{ "fn": "functions", "fseq": "fseq" }
```

**Output**

```json
{ "ok": true, "fn": "functions", "result": "list" }
```

## When to invoke

- When transforming a single data object through a series of sequential operations.
- When applying a list of functions to an initial value in a cumulative manner.
- When constructing pipelines where the right-hand side expression requires the left-hand side value as its first argument.
- When extracting a list of functions from a functional sequence for inspection.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "freduce", "value": 1, "functions": [{"x": "function(x) x + 1"}, {"x": "function(x) x * 2"}]}' | Rscript --vanilla skills/magrittr/invoke.R
```
