---
name: testthat
runtime: r
package: testthat
package_source: CRAN
package_url: https://testthat.r-lib.org
package_version_pinned: ">=3.3.2"
license: MIT + file LICENSE
maintainer: "Hadley Wickham <hadley@posit.co>"
---

# Skill: testthat

testthat is a testing framework for R designed to facilitate unit testing within an R workflow. It provides tools to verify that R code behaves as expected by defining expectations and reporters.

An agent should use this skill when it needs to verify the correctness of R functions, validate code logic against specific inputs, or automate the checking of R package integrity.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("testthat")`.

## Functions exposed

### CheckReporter: Report results for R CMD check

**Input**

```json
{ "fn": "CheckReporter", "reporter": "object" }
```

**Output**

```json
{ "ok": true, "fn": "CheckReporter", "result": "object" }
```

### DebugReporter: Interactively debug failing tests

**Input**

```json
{ "fn": "DebugReporter", "reporter": "object" }
```

**Output**

```json
{ "ok": true, "fn": "DebugReporter", "result": "object" }
```

### FailReporter: Fail if any tests fail

**Input**

```json
{ "fn": "FailReporter", "reporter": "object" }
```

**Output**

```json
{ "ok": true, "fn": "FailReporter", "result": "object" }
```

### JunitReporter: Report results in jUnit XML format

**Input**

```json
{ "fn": "JunitReporter", "reporter": "object" }
```

**Output**

```json
{ "ok": true, "fn": "JunitReporter", "result": "object" }
```

## When to invoke

- Verifying that a specific R function returns the expected data type or value given a set of inputs.
- Checking if an R function correctly handles error conditions or warnings.
- Automating the validation of R package components during a continuous integration process.
- Comparing the output of an R function against a known reference value or file.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "expect_equal", "actual": 10, "expected": 10}' | Rscript --vanilla skills/testthat/invoke.R
```
