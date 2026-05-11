---
name: yaml
runtime: r
package: yaml
package_source: CRAN
package_url: https://yaml.r-lib.org
package_version_pinned: ">=2.3.12"
license: BSD_3_clause
maintainer: "Hadley Wickham <hadley@posit.co>"
---

# Skill: yaml

This package implements the LibYAML parser and emitter for R. It provides functionality to convert R objects into YAML strings and to parse YAML documents into R objects.

An agent should use this skill when it needs to serialize R data structures into a YAML format for configuration files or when it needs to parse YAML-formatted text or files into R objects for processing.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("yaml")`.

## Functions exposed

### as.yaml: Convert an R object into a YAML string

**Input**

```json
{ "fn": "as.yaml", "x": "object", "indent": "integer", "omap": "boolean" }
```

**Output**

```json
{ "ok": true, "fn": "as.yaml", "result": "string" }
```

### read_yaml: Read a YAML document

**Input**

```json
{ "fn": "read_yaml", "file": "string" }
```

**Output**

```json
{ "ok": true, "fn": "read_yaml", "result": "object" }
```

### write_yaml: Write a YAML representation to a file

**Input**

```json
{ "fn": "write_yaml", "x": "object", "file": "string" }
```

**Output**

```json
{ "ok": true, "fn": "write_yaml", "result": "null" }
```

### yaml.load: Parse a YAML string

**Input**

```json
{ "fn": "yaml.load", "text": "string" }
```

**Output**

```json
{ "ok": true, "fn": "yaml.load", "result": "object" }
```

## When to invoke

* Converting R lists or data frames into YAML-formatted strings for storage or transmission.
* Parsing YAML configuration files into R lists for use in automated workflows.
* Transforming YAML-formatted text input into R-native data structures.
* Generating YAML files from R objects to be used as input for other software systems.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "as.yaml", "x": {"a": 1, "b": [2, 3]}}' | Rscript --vanilla skills/yaml/invoke.R
```
