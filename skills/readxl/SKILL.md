---
name: readxl
runtime: r
package: readxl
package_source: CRAN
package_url: https://readxl.tidyverse.org
package_version_pinned: ">=1.4.5"
license: MIT
maintainer: "Jennifer Bryan <jenny@posit.co>"
---

# Skill: readxl

The readxl package imports Excel files into R. It supports the .xls format via the libxls C library and the .xlsx format via the RapidXML C++ library. The package operates on Windows, Mac, and Linux without external dependencies.

An agent should use this skill when it needs to extract data from Excel spreadsheets for downstream processing or analysis.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("readxl")`.

## Functions exposed

### `read_excel`: Read xls and xlsx files

**Input**

```json
{
  "fn": "read_excel",
  "path": "string",
  "sheet": "string|number",
  "skip": "integer",
  "col_names": "boolean",
  "col_types": "string|array",
  "n_max": "integer"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "read_excel",
  "result": "array"
}
```

### `excel_sheets`: List all sheets in an excel spreadsheet

**Input**

```json
{
  "fn": "excel_sheets",
  "path": "string"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "excel_sheets",
  "result": "array"
}
```

### `excel_format`: Determine file format

**Input**

```json
{
  "fn": "excel_format",
  "guess": "boolean"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "excel_format",
  "result": "string"
}
```

### `readxl_example`: Get path to readxl example

**Input**

```json
{
  "fn": "readxl_example",
  "name": "string"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "readxl_example",
  "result": "string"
}
```

## When to invoke

- When a task requires reading data from a file with a .xls or .xlsx extension.
- When an agent needs to identify the names of all worksheets within a workbook to iterate through them.
- When an agent needs to verify if a specific file follows the Excel file format based on extension or magic number.
- When an agent needs to access built-in example datasets for testing purposes.

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
echo '{"fn": "read_excel", "path": "path/to/file.xlsx", "sheet": 1}' | Rscript --vanilla skills/readxl/invoke.R
```
