---
name: pillar
runtime: r
package: pillar
package_source: CRAN
package_url: https://pillar.r-lib.org/
package_version_pinned: ">=1.11.1"
license: MIT
maintainer: "Kirill Müller <kirill@cynkra.com>"
---

# Skill: pillar

The pillar package provides generics for formatting columns of data using the full range of colors available in modern terminals. It includes tools for aligning strings, formatting character vectors, and managing tabular displays.

An agent should use this skill when tasks require the visual formatting of data structures, such as aligning text within vectors or preparing data for tabular display in a terminal environment.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("pillar")`.

## Functions exposed

### align: Align strings within a character vector

**Input**

```json
{
  "fn": "align",
  "x": {
    "type": "array",
    "items": { "type": "string" }
  },
  "align": { "type": "string", "enum": ["left", "right", "center"] }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "align",
  "result": {
    "type": "array",
    "items": { "type": "string" }
  }
}
```

### char: Format a character vector

**Input**

```json
{
  "fn": "char",
  "x": {
    "type": "array",
    "items": { "type": "string" }
  }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "char",
  "result": {
    "type": "array",
    "items": { "type": "string" }
  }
}
```

### colonnade: Format multiple vectors in a tabular display

**Input**

```json
{
  "fn": "colonnade",
  "x": {
    "type": "array",
    "items": {
      "type": "array",
      "items": { "type": "string" }
    }
  },
  "width": { "type": "integer" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "colonnade",
  "result": { "type": "string" }
}
```

## When to invoke

* Formatting character vectors for consistent alignment in terminal outputs.
* Organizing multiple data vectors into a wrapped, tabular layout for constrained display widths.
* Implementing custom formatting logic for data type subclasses.

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
echo '{"fn": "align", "x": ["abc", "de"], "align": "right"}' | Rscript --vanilla skills/pillar/invoke.R
```
