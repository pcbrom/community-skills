---
name: S7
runtime: r
package: S7
package_source: CRAN
package_url: https://rconsortium.github.io/S7/
package_version_pinned: ">=0.2.2"
license: MIT + file LICENSE
maintainer: "Hadley Wickham <hadley@posit.co>"
---

# Skill: S7

S7 provides an object oriented programming system for R, designed as a successor to the S3 and S4 systems. It enables the definition of formal classes, generics, and methods, and supports a limited form of multiple dispatch.

An agent should use this skill when tasks require the construction of formal class hierarchies, the implementation of method dispatch logic, or the management of object properties within an R environment.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("S7")`.

## Functions exposed

### S7_class: Retrieve the S7 class of an object

**Input**

```json
{ "fn": "S7_class", "x": "object" }
```

**Output**

```json
{ "ok": true, "fn": "S7_class", "result": "S7_class" }
```

### S7_data: Get or set the underlying base data of an S7 object

**Input**

```json
{ "fn": "S7_data", "x": "S7_object" }
```

**Output**

```json
{ "ok": true, "fn": "S7_data", "result": "any" }
```

### S7_inherits: Check if an object inherits from a specific S7 class

**Input**

```json
{ "fn": "S7_inherits", "x": "S7_object", "class": "S7_class" }
```

**Output**

```json
{ "ok": true, "fn": "S7_inherits", "result": "boolean" }
```

### S4_register: Register an S7 class with the S4 system

**Input**

```json
{ "fn": "S4_register", "class": "S7_class" }
```

**Output**

```json
{ "ok": true, "fn": "S4_register", "result": "NULL" }
```

## When to invoke

* Defining new class hierarchies with formal specifications for complex data structures.
* Implementing method dispatch logic for custom object types.
* Verifying class inheritance relationships between existing objects and class definitions.
* Extracting or modifying the underlying primitive data from an S7 object.
* Integrating S7 classes with existing S4 generic functions.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "S7_class", "x": "S7_object"}' | Rscript --vanilla skills/S7/invoke.R
```
