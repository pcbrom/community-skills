---
name: stringi
runtime: r
package: stringi
package_source: CRAN
package_url: https://stringi.gagolewski.com/
package_version_pinned: ">=1.8.7"
license: file LICENSE
maintainer: "Marek Gagolewski <marek@gagolewski.com>"
---

# Skill: stringi

stringi provides character string, text, and natural language processing tools. It supports pattern searching using Java-like regular expressions and the Unicode collation algorithm, random string generation, case mapping, string transliteration, concatenation, sorting, padding, wrapping, and Unicode normalization.

The package is used for tasks involving complex text manipulation, Unicode-aware string comparisons, pattern counting, text boundary detection, and date-time arithmetic.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("stringi")`.

## Functions exposed

### `stri_compare`: Compare strings with or without collation

**Input**

```json
{
  "fn": "stri_compare",
  "x": "string",
  "y": "string",
  "locale": "string"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "stri_compare",
  "result": "integer"
}
```

### `stri_count`: Count the number of pattern occurrences

**Input**

```json
{
  "fn": "stri_count",
  "x": "string",
  "pattern": "string",
  "fixed": "boolean"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "stri_count",
  "result": "integer"
}
```

### `stri_count_boundaries`: Count the number of text boundaries

**Input**

```json
{
  "fn": "stri_count_boundaries",
  "x": "string",
  "type": "string"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "stri_count_boundaries",
  "result": "integer"
}
```

### `stri_datetime_add`: Modify a date-time object by adding time units

**Input**

```json
{
  "fn": "stri_datetime_add",
  "x": "string",
  "num": "numeric",
  "units": "string"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "stri_datetime_add",
  "result": "string"
}
```

## When to invoke

* Identifying the number of words, sentences, or characters in a text block.
* Counting specific substrings or regex patterns within a corpus.
* Performing locale-specific string comparisons, such as checking lexicographic order in Polish or Slovak.
* Calculating new timestamps by adding or subtracting years, months, or days from existing date-time strings.
* Detecting occurrences of Unicode character classes, such as whitespace or letter categories.

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
echo '{"fn": "stri_count", "x": "Lorem ipsum dolor sit amet", "pattern": "dolor", "fixed": true}' | Rscript --vanilla skills/stringi/invoke.R
```
