---
name: data.table
runtime: r
package: data.table
package_source: CRAN
package_url: https://r-datatable.com
package_version_pinned: ">=1.18.4"
license: MPL-2.0
maintainer: "Tyson Barrett <t.barrett88@gmail.com>"
---

# Skill: data.table

The data.table package provides an extension of the data.frame class for high-performance data manipulation. It enables fast aggregation of large datasets, efficient ordered joins, and memory-efficient modification of columns by reference.

An agent should use this skill when tasks involve processing large-scale datasets in memory, performing complex joins, or executing high-speed file I/O operations on character-separated-value files.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("data.table")`.

## Functions exposed

### data.table: Create or convert to a data.table object

**Input**

```json
{ "fn": "data.table", "..." : "..." }
```

**Output**

```json
{ "ok": true, "fn": "data.table", "result": "data.table" }
```

### fread: Fast reading of files

**Input**

```json
{ "fn": "fread", "file": "string" }
```

**Output**

```json
{ "ok": true, "fn": "fread", "result": "data.table" }
```

### fwrite: Fast writing of files

**Input**

```json
{ "fn": "fwrite", "x": "data.table", "file": "string" }
```

**Output**

```json
{ "ok": true, "fn": "fwrite", "result": "boolean" }
```

### setkey: Sort and set key for fast joins and grouping

**Input**

```json
{ "fn": "setkey", "x": "data.table", "order": "character vector" }
```

**Output**

```json
{ "ok": true, "fn": "setkey", "result": "null" }
```

### tables: Summarize metadata of all data.tables in memory

**Input**

```json
{ "fn": "tables", "env": "environment" }
```

**Output**

```json
{ "ok": true, "fn": "tables", "result": "data.table" }
```

### copy: Create a deep copy of an object

**Input**

```json
{ "fn": "copy", "x": "object" }
```

**Output**

```json
{ "ok": true, "fn": "copy", "result": "object" }
```

## When to invoke

- Reading large CSV files where standard R read functions are slow.
- Performing joins between datasets using shared keys.
- Aggregating large datasets by specific groups.
- Modifying columns in a dataset without creating full object copies.
- Sorting datasets to optimize subsequent binary searches or grouping operations.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "data.table", "x": "a=1:5, b=letters[1:5]"}' | Rscript --vanilla skills/data.table/invoke.R
```
