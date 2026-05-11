---
name: systemfonts
runtime: r
package: systemfonts
package_source: CRAN
package_url: https://github.com/r-lib/systemfonts
package_version_pinned: ">=1.3.2"
license: MIT + file LICENSE
maintainer: "Thomas Lin Pedersen <thomas.pedersen@posit.co>"
---

# Skill: systemfonts

The systemfonts package provides native access to the font catalogue of the host operating system. It allows for the identification of installed font files on Windows, macOS, and Linux.

An agent should use this skill when tasks require locating font files, determining font properties, or managing font substitution for specific character sets.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("systemfonts")`.

## Functions exposed

### `add_fonts`: Add local font files to the search path

**Input**

```json
{ "fn": "add_fonts", "fontfile": "string" }
```

**Output**

```json
{ "ok": true, "fn": "add_fonts", "result": "null" }
```

### `as_font_weight`: Convert weight names to numeric values

**Input**

```json
{ "fn": "as_font_weight", "weights": ["string"] }
```

**Output**

```json
{ "ok": true, "fn": "as_font_weight", "result": ["number"] }
```

### `as_font_width`: Convert width names to numeric values

**Input**

```json
{ "fn": "as_font_width", "widths": ["string"] }
```

**Output**

```json
{ "ok": true, "fn": "as_font_width", "result": ["number"] }
```

### `font_fallback`: Get the fallback font for a given string

**Input**

```json
{ "fn": "font_fallback", "string": "string" }
```

**Output**

```json
{ "ok": true, "fn": "font_fallback", "result": "string" }
```

### `font_feature`: Define OpenType font feature settings

**Input**
Note: This function uses named arguments for specific features and 4-letter tags for others.

```json
{ "fn": "font_feature", "features": "object" }
```

**Output**

```json
{ "ok": true, "fn": "font_feature", "result": "object" }
```

## When to invoke

* Identifying the file path of a specific font family installed on the local system.
* Calculating a substitute font for strings containing Unicode characters or emojis not present in a primary font.
* Converting human readable font weight names like "bold" or "light" into numeric values for programmatic styling.
* Configuring OpenType typographic features such as tabular numbers or stylistic sets for text rendering.
: Sideloading specific font files into the R session without system-wide installation.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "font_fallback", "string": "\U0001f604"}' | Rscript --vanilla skills/systemfonts/invoke.R
```
