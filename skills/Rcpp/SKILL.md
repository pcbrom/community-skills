---
name: Rcpp
runtime: r
package: Rcpp
package_source: CRAN
package_url: https://www.rcpp.org, https://dirk.eddelbuettel.com/code/rcpp.html, https://github.com/RcppCore/Rcpp
package_version_pinned: ">=1.1.1-1.1"
license: GPL (>= 2)
maintainer: "Dirk Eddelbuettel <edd@debian.org>"
---

# Skill: Rcpp

Rcpp provides R functions and C++ classes for the integration of R and C++. It allows for the mapping of R data types to C++ equivalents, facilitating the use of third-party libraries and the development of new C++ code within the R environment.

An agent should use this skill when tasks require compiling C++ code within an R session, creating new R packages that utilize C++ source files, or interfacing with C++ modules and classes.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("Rcpp")`.

## Functions exposed

### cppFunction: Compile and evaluate C++ code

**Input**

```json
{ "fn": "cppFunction", "code": "string" }
```

**Output**

```json
{ "ok": true, "fn": "cppFunction", "result": "function" }
```

### sourceCpp: Compile and source a C++ file

**Input**

```json
{ "fn": "sourceCpp", "file": "string" }
```

**Output**

```json
{ "ok": true, "fn": "sourceCpp", "result": "NULL" }
```

### Rcpp.package.skeleton: Create a new R package skeleton

**Input**

```json
{ "fn": "Rcpp.package.skeleton", "name": "string", "attributes": "boolean", "module": "boolean" }
```

**Output**

```json
{ "ok": true, "fn": "Rcpp.package.skeleton", "result": "character" }
```

### Module: Retrieve an Rcpp module

**Input**

```json
{ "fn": "Module", "module_name": "string" }
```

**Output**

```json
{ "ok": true, "fn": "Module", "result": "module" }
```

### populate: Populate a namespace or environment with module content

**Input**

```json
{ "fn": "populate", "module": "string", "env": "environment" }
```

**Output**

```json
{ "ok": true, "fn": "populate", "result": "NULL" }
```

## When to invoke

*   When a task requires the compilation of C++ source code into an R function via a string input.
*   When an agent needs to automate the creation of a new R package structure that includes C++ integration.
*   When a task involves loading and interacting with C++ modules or classes within an existing R session.
*   When an agent must interface R data types with C++ objects for performance-oriented computations.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "cppFunction", "code": "int add(int x, int y) { return x + y; }"}' | Rscript --vanilla skills/Rcpp/invoke.R
```
