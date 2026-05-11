---
name: readr
runtime: r
package: readr
package_source: CRAN
package_url: https://readr.tidyverse.org
package_version_pinned: ">=2.2.0"
license: MIT + file LICENSE
maintainer: "Jennifer Bryan <jenny@posit.co>"
---

# Skill: readr

The readr package provides methods for reading rectangular text data, including CSV, TSV, and fixed-width formats. It is designed to parse various data types found in unstructured environments and provides mechanisms to handle unexpected changes in data structure.

An agent should use this skill when it needs to ingest delimited text files or fixed-width files into an R environment for processing.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("readr")`.

## Functions exposed

### read_csv: Read a comma-separated values file

**Input**

```json
{ "fn": "read_csv", "file": "string" }
```

**Output**

```json
{ "ok": true, "fn": "read_csv", "result": "array" }
```

### read_tsv: Read a tab-separated values file

**Input**

```json
{ "fn": "read_tsv", "file": "string" }
```

**Output**

```json
{ "ok": true, "fn": "read_tsv", "result": "array" }
```

### read_delim: Read a delimited text file with a custom delimiter

**Input**

```json
{ "fn": "read_delim", "file": "string", "delim": "string" }
```

**Output**

```json
{ "ok": true, "fn": "read_delim", "result": "array" }
```

### read_fwf: Read a fixed-width format file

**Input**

```json
{ "fn": "read_fwf", "file": "string", "col_positions": "string" }
```

**Output**

```json
{ "ok": true, "fn": "read_fwf", "result": "array" }
```

### cols: Create column specification

**Input**

```json
{ "fn": "cols", "spec": "object" }
```

**Output**

```json
{ "ok": true, "fn": "cols", "result": "object" }
```

## When to invoke

* Loading comma-separated files for tabular data processing.
* Parsing tab-separated files from web-based data exports.
* Reading files with custom delimiters, such as semicolons or pipes.
* Processing fixed-width text files where column boundaries are defined by character positions.
* Defining specific data types for columns to ensure consistent parsing of numeric or date strings.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "read_csv", "file": "data.csv"}' | Rscript --vanilla skills/readr/invoke.R
```
