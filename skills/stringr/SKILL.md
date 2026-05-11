---
name: stringr
runtime: r
package: stringr
package_source: CRAN
package_url: https://cran.r-project.org/package=stringr
package_version_pinned: ">=1.6.0"
license: MIT
maintainer: "Hadley Wickham <hadley@posit.co>"
---

# Skill: stringr

The stringr package provides a consistent set of wrappers for common string operations. It is built upon the stringi package to provide a simplified interface for manipulating character vectors.

An agent should use this skill when tasks require pattern matching, string transformation, text extraction, or character encoding adjustments within R.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("stringr")`.

## Functions exposed

### str_c: Join multiple strings into one string

**Input**

```json
{
  "fn": "str_c",
  "...",: { "type": "array", "items": { "type": "string" } },
  "sep": { "type": "string" },
  "collapse": { "type": "string" }
}
```

**Output**

```json
{ "ok": true, "fn": "str_c", "result": { "type": "string" } }
```

### str_count: Count number of matches

**Input**

```json
{
  "fn": "str_count",
  "string": { "type": "array", "items": { "type": "string" } },
  "pattern": { "type": "string" }
}
```

**Output**

```json
{ "ok": true, "fn": "str_count", "result": { "type": "array", "items": { "type": "integer" } } }
```

### str_detect: Logical testing for pattern matches

**Input**

```json
{
  "fn": "str_detect",
  "string": { "type": "array", "items": { "type": "string" } },
  "pattern": { "type": "string" }
}
```

**Output**

```json
{ "ok": true, "fn": "str_detect", "result": { "type": "array", "items": { "type": "boolean" } } }
```

### str_replace_all: Replace all occurrences of a pattern

**Input**

```json
{
  "fn": "str_replace_all",
  "string": { "type": "array", "items": { "type": "string" } },
  "pattern": { "type": "string" },
  "replacement": { "type": "string" }
}
```

**Output**

```json
{ "ok": true, "fn": "str_replace_all", "result": { "type": "array", "items": { "type": "string" } } }
```

### str_sub: Extract substrings

**Input**

```json
{
  "fn": "str_sub",
  "string": { "type": "array", "items": { "type": "string" } },
  "start": { "type": "integer" },
  "end": { "type": "integer" }
}
```

**Output**

```json
{ "ok": true, "fn": "str_sub", "result": { "type": "array", "items": { "type": "string" } } }
```

### invert_match: Switch location of matches to location of non-matches

**Input**

```json
{
  "fn": "invert_match",
  "location": { "type": "array", "items": { "type": "array", "items": { "type": "integer" } } }
}
```

**Output**

```json
{ "ok": true, "fn": "invert_match", "result": { "type": "array", "items": { "type": "array", "items": { "type": "integer" } } } }
```

## When to invoke

* Identifying specific substrings or patterns within a vector of text.
* Counting the frequency of specific characters or regex patterns in a dataset.
* Cleaning text by removing, replacing, or padding specific characters.
* Splitting single strings into multiple components based on delimiters.
- Converting text between different character encodings.
- Extracting specific segments of a string based on index positions.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "str_count", "string": ["apple", "banana"], "pattern": "a"}' | Rscript --vanilla skills/stringr/invoke.R
```
