---
name: purrr
runtime: r
package: purrr
package_source: CRAN
package_url: https://purrr.tidyverse.org/
package_version_pinned: ">=1.2.2"
license: MIT
maintainer: "Hadley Wickham <hadley@posit.co>"
---

# Skill: purrr

This package provides a functional programming toolkit for R. It enables the application of functions across collections, the manipulation of lists, and the creation of specialized accessor functions.

An agent should use this skill when tasks involve iterating over lists or vectors with specific functional logic, transforming nested data structures, or constructing complex mapping functions.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("purrr")`.

## Functions exposed

### `accumulate`: Sequentially apply a 2-argument function to elements of a vector

**Input**

```json
{
  "fn": "accumulate",
  "x": "array",
  "f": "function",
  ".dir": "string"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "accumulate",
  "result": "array"
}
```

### `as_mapper`: Convert an object into a mapper function

**Input**

```json
{
  "fn": "as_mapper",
  "x": "array"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "as_mapper",
  "result": "function"
}
```

### `attr_getter`: Create an attribute getter function

**Input**

```json
{
  "fn": "attr_getter",
  "name": "string"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "attr_getter",
  "result": "function"
}
```

### `pluck`: Extract a deeply nested element from a list

**Input**

```json
{
  "fn": "pluck",
  "x": "array",
  "args": "array"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "pluck",
  "result": "any"
}
```

## When to invoke

- When a task requires calculating running totals or intermediate states of a vector reduction.
- When an agent needs to transform a list of strings or indices into a functional accessor for nested lists.
- When extracting specific metadata or attributes from objects within a collection.
- When navigating deeply nested list structures using a sequence of keys or indices.

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
echo '{"fn": "accumulate", "x": "[1, 2, 3, 4, 5]", "f": "plus"}' | Rscript --vanilla skills/purrr/invoke.R
```
