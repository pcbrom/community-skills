---
name: utf8
runtime: r
package: utf8
package_source: CRAN
package_url: https://krlmlr.github.io/utf8/
package_version_pinned: ">=1.2.6"
license: Apache-2.0
maintainer: "Kirill Müller <kirill@cynkra.com>"
---

# Skill: utf8

This package provides tools for processing and printing UTF-8 encoded international text. It enables users to validate, normalize, encode, and format Unicode characters for correct display.

An agent should use this skill when tasks involve handling character encoding errors, verifying the validity of UTF-8 strings, or formatting text for consistent terminal output.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("utf8")`.

## Functions exposed

### as_utf8: Convert character objects to valid UTF-8

**Input**

```json
{
  "fn": "as_utf8",
  "x": { "type": "array", "items": { "type": "string" } },
  "normalize": { "type": "boolean" }
}
```

**Output**

```json
{ "ok": true, "fn": "as_utf8", "result": { "type": "array", "items": { "type": "string" } } }
```

### utf8_valid: Test for valid UTF-8 strings

**Input**

```json
{
  "fn": "utf8_valid",
  "x": { "type": "array", "items": { "type": "string" } }
}
```

**Output**

```json
{ "ok": true, "fn": "utf8_valid", "result": { "type": "array", "items": { "type": "boolean" } } }
```

### utf8_encode: Escape strings for UTF-8 printing

**Input**

```json
{
  "fn": "utf8_encode",
  "x": { "type": "array", "items": { "type": "string" } },
  "escapes": { "type": "string" }
}
```

**Output**

```json
{ "ok": true, "fn": "utf8_encode", "result": { "type": "array", "items": { "type": "string" } } }
```

### utf8_format: Format character objects for display

**Input**

```json
{
  "fn": "utf8_format",
  "x": { "type": "array", "items": { "type": "string" } },
  "chars": { "type": "integer" },
  "justify": { "type": "string", "enum": ["left", "right", "centre"] },
  "width": { "type": "integer" }
}
```

**Output**

```json
{ "ok": true, "fn": "utf8_format", "result": { "type": "array", "items": { "type": "string" } } }
```

## When to invoke

- Verifying if a character vector contains sequences that violate UTF-8 encoding standards.
- Converting text from legacy encodings, such as Latin-1, into valid UTF-8.
- Normalizing Unicode strings to Unicode composed normal form (NFC).
- Preparing text strings for terminal display by escaping special characters or adjusting string width.
- Checking if the current output connection supports ANSI escape sequences or UTF-8.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "utf8_valid", "x": ["fa\u00E7ile", "fa\xE7ile"]}' | Rscript --vanilla skills/utf8/invoke.R
```
