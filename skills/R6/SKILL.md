---
name: R6
runtime: r
package: R6
package_source: CRAN
package_url: https://r6.r-lib.org
package_version_pinned: ">=2.6.1"
license: MIT
maintainer: "Winston Chang <winston@posit.co>"
---

# Skill: R6

The R6 package provides a mechanism for creating classes with reference semantics in R. It allows for the definition of objects with public and private members and supports inheritance.

An agent should use this skill when tasks require the implementation of object-oriented programming structures, the management of mutable state, or the creation of encapsulated data containers that do not follow R's standard copy-on-modify semantics.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("R6")`.

## Functions exposed

### R6Class: Create an R6 reference object generator

**Input**

```json
{
  "fn": "R6Class",
  "classname": "string",
  "public": "object",
  "private": "object",
  "inherit": "string"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "R6Class",
  "result": "object"
}
```

### is.R6: Check if an object is an R6 class generator or object

**Input**

```json
{
  "fn": "is.R6",
  "x": "any"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "is.R6",
  "result": "boolean"
}
```

### is.R6Class: Check if an object is an R6 class generator

**Input**

```json
{
  "fn": "is.R6Class",
  "x": "any"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "is.R6Class",
  "result": "boolean"
}
```

### as.list: Convert an R6 object to a list of public members

**Input**

```json
{
  "fn": "as.list",
  "x": "object"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "as.list",
  "result": "object"
}
```

## When to invoke

*   Defining custom data structures that require mutable state, such as queues, stacks, or linked lists.
*   Implementing complex algorithms where maintaining a single, updated instance of an object is more efficient than passing copies.
*   Creating encapsulated systems where internal logic and data must be hidden from the global environment.
*   Building hierarchical class structures that utilize inheritance across different R packages.

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
echo '{"fn": "is.R6", "x": "NULL"}' | Rscript --vanilla skills/R6/invoke.R
```
