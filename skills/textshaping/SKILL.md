---
name: textshaping
runtime: r
package: textshaping
package_source: CRAN
package_url: https://github.com/r-lib/textshaping
package_version_pinned: ">=1.0.5"
license: MIT
maintainer: "Thomas Lin Pedersen <thomas.pedersen@posit.co>"
---

# Skill: textshaping

This package provides bindings to the HarfBuzz and Fribidi libraries. It enables text shaping, which includes font fallbacks, bidirectional script support, and word wrapping. It is used for calculating glyph positions and managing complex text layouts in R graphics.

An agent should use this skill when tasks require calculating precise glyph positions, determining text width, retrieving OpenType features from fonts, or generating placeholder text in specific scripts for testing layout rendering.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("textshaping")`.

## Functions exposed

### `get_font_features`: Retrieve available OpenType feature tags for fonts

**Input**

```json
{
  "fn": "get_font_features",
  "family": {
    "type": "string",
    "description": "The name of the font family"
  }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "get_font_features",
  "result": {
    "type": "array",
    "items": { "type": "string" }
  }
}
```

### `lorem_text`: Generate filler text in various scripts

**Input**

```json
{
  "fn": "lorem_text",
  "script": {
    "type": "string",
    "description": "The script type, such as 'hangul' or 'arabic'"
  },
  "n": {
    "type": "integer",
    "description": "Number of paragraphs to generate"
  }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "lorem_text",
  "result": { "type": "string" }
}
```

### `lorem_bidi`: Generate bidirectional gibberish text

**Input**

```json
{
  "fn": "lorem_bidi"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "lorem_bidi",
  "result": { "type": "string" }
}
```

### `shape_text`: Calculate glyph positions and layout metrics

**Input**

```json
{
  "fn": "shape_text",
  "text": { "type": "string" },
  "max_width": { "type": "number" },
  "indent": { "type": "number" },
  "id": { "type": "array", "items": { "type": "integer" } },
  "size": { "type": "array", "items": { "type": "number" } }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "shape_text",
  "result": { "type": "object" }
}
```

### `plot_shape`: Preview calculated text layout

**Input**

```json
{
  "fn": "plot_shape",
  "shape": { "type": "object", "description": "The output from shape_text" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "plot_shape",
  "result": { "type": "boolean" }
}
```

## When to invoke

* Determining the available OpenType features for a specific font family.
* Generating multi-script placeholder text for testing graphical device rendering.
* Calculating precise glyph positions and line breaks for strings containing bidirectional text or complex scripts.
* Verifying text layout calculations through visual previews of shaped text metrics.

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
echo '{"fn": "lorem_text", "script": "hangul", "n": 1}' | Rscript --vanilla skills/textshaping/invoke.R
```
