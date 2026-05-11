---
name: vroom
runtime: r
package: vroom
package_source: CRAN
package_url: https://vroom.tidyverse.org
package_version_pinned: ">=1.7.1"
license: MIT
maintainer: "Jennifer Bryan <jenny@posit.co>"
---

# Skill: vroom

The vroom package provides high-speed reading and writing of rectangular text data, including CSV, TSV, and fixed-width formats. It utilizes an initial indexing step and lazy reading to minimize memory usage by only reading data when accessed.

The package is used when an agent needs to ingest large delimited text files or write structured data to disk efficiently.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("vroom")`.

## Functions exposed

### vroom: Read rectangular text data

**Input**

```json
{
  "fn": "vroom",
  "file": "string",
  "delim": "string",
  "col_types": "string or list"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "vroom",
  "result": "tibble"
}
```

### vroom_write: Write rectangular text data to disk

**Input**

```json
{
  "fn": "vroom_write",
  "x": "data.frame",
  "file": "string",
  "delim": "string"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "vroom_write",
  "result": "null"
}
```

### cols: Create column specification

**Input**

```json
{
  "fn": "cols",
  "..." : "list of column specifications"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "cols",
  "result": "col_spec"
}
```

### gen_tbl: Generate a random tibble

**Input**

```json
{
  "fn": "gen_tbl",
  "nrow": "integer",
  "ncol": "integer",
  "col_types": "string"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "gen_tbl",
  "result": "tibble"
}
```

## When to invoke

- Loading large CSV or TSV files where memory efficiency is required.
- Writing data frames to disk in delimited text formats.
- Defining specific data types for columns during file ingestion to prevent parsing errors.
- Generating synthetic datasets for testing or benchmarking purposes.

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
echo '{"file": "data.csv", "delim": ","}' | Rscript --vanilla skills/vroom/invoke.R
```
