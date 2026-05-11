---
name: jsonlite
runtime: r
package: jsonlite
package_source: CRAN
package_url: https://jeroen.r-universe.dev/jsonlite
package_version_pinned: ">=2.0.0"
license: MIT
maintainer: "Jeroen Ooms <jeroenooms@gmail.com>"
---

# Skill: jsonlite

The jsonlite package provides a parser and generator for JSON data, optimized for statistical data and web interactions. It enables the conversion of JSON strings into R objects and vice versa, supporting complex structures such as nested data frames.

An agent should use this skill when it needs to parse JSON responses from web APIs, transform R objects into JSON format for transmission, or manipulate the structure of JSON data through flattening, prettifying, or minifying.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("jsonlite")`.

## Functions exposed

### fromJSON: Convert JSON data to R objects

**Input**

```json
{ "fn": "fromJSON", "x": "string" }
```

**Output**

```json
{ "ok": true, "fn": "fromJSON", "result": "object" }
```

### toJSON: Convert R objects to JSON data

**Input**

```json
{ "fn": "toJSON", "x": "object" }
```

**

```json
{ "ok": true, "fn": "toJSON", "result": "string" }
```

### flatten: Flatten nested data frames into a 2D tabular structure

**Input**

```json
{ "fn": "flatten", "x": "data.frame" }
```

**Output**

```json
{ "ok": true, "fn": "flatten", "result": "data.frame" }
```

### prettify: Add indentation to a JSON string

**Input**

```json
{ "fn": "prettify", "x": "string" }
```

**Output**

```json
{ "ok": true, "fn": "prettify", "result": "string" }
```

### minify: Remove all indentation and whitespace from a JSON string

**Input**

```json
{ "fn": "minify", "x": "string" }
```

**Output**

```json
{ "ok": true, "fn": "minify", "result": "string" }
```

### rbind_pages: Combine a list of data frames into a single data frame

**Input**

```json
{ "fn": "rbind_pages", "x": "list" }
```

**Output**

```json
{ "ok": true, "fn": "rbind_pages", "result": "data.frame" }
```

## When to invoke

* Converting raw JSON strings from HTTP responses into R lists or data frames for processing.
* Transforming R data frames into JSON format for API payloads or file storage.
* Simplifying deeply nested JSON structures into flat, two-dimensional tables for tabular analysis.
* Reformatting JSON strings to improve human readability via indentation.
* Compressing JSON strings by removing whitespace for minimized network bandwidth usage.
* Merging multiple data frames retrieved from paginated API endpoints into a single dataset.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"name": "test", "value": 123}' | Rscript --vanilla skills/jsonlite/invoke.R
```
