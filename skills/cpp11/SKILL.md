---
name: cpp11
runtime: r
package: cpp11
package_source: CRAN
package_url: https://cpp11.r-lib.org
package_version_pinned: ">=0.5.5"
license: MIT
maintainer: "Davis Vaughan <davis@posit.co>"
---

# Skill: cpp11

The cpp11 package provides a header-only C++11 interface to the R C interface. It is designed to be safe against C++ exceptions and long jumps from the C API, while supporting interaction with ALTREP vectors.

An agent should use this skill when tasks require compiling C++ code, evaluating C++ expressions, or managing C++ dependencies within an R environment.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("cpp11")`.

## Functions exposed

### cpp_eval: Evaluate a single C++ expression

**Input**

```json
{ "fn": "cpp_eval", "code": "string" }
```

**Output**

```json
{ "ok": true, "fn": "cpp_eval", "result": "any" }
```

### cpp_source: Compile and load C++ files

**Input**

```json
{ "fn": "cpp_source", "code": "string" }
```

**Output**

```json
{ "ok": true, "fn": "cpp_source", "result": "null" }
```

### cpp_function: Compile and load a single function

**Input**

```json
{ "fn": "cpp_function", "code": "string" }
```

**Output**

```json
{ "ok": true, "fn": "cpp_function", "result": "null" }
```

### cpp_register: Generate wrappers for registered C++ functions

**Input**

```json
{ "fn": "cpp_register", "dir": "string" }
```

**Output**

```json
{ "ok": true, "fn": "cpp_register", "result": "null" }
```

### cpp_vendor: Vendor cpp11 headers into a directory

**Input**

```json
{ "fn": "cpp_vendor", "dir": "string" }
```

**Output**

```json
{ "ok": true, "fn": "cpp_vendor", "result": "null" }
```

## When to invoke

- When a task requires executing C++ logic directly within an R session.
- When a task involves compiling C++ source code strings into callable R functions.
- When a task requires generating C++ wrappers for functions decorated with the cpp11 register attribute.
- When a task requires creating a local copy of cpp11 headers for dependency management.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "cpp_eval", "code": "1 + 1"}' | Rscript --vanilla skills/cpp11/invoke.R
```
