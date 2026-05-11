---
name: sass
runtime: r
package: sass
package_source: CRAN
package_url: https://rstudio.github.io/sass/
package_version_pinned: ">=0.4.10"
license: MIT
maintainer: "Carson Sievert <carson@rstudio.com>"
---

# Skill: sass

The sass package provides an SCSS compiler powered by the LibSass library. It allows for the generation of dynamic style sheets using variables, inheritance, and functions within the Sass CSS extension language.

An agent should use this skill when tasks require compiling SCSS or Sass syntax into standard CSS, managing web font imports via Google Fonts, or constructing complex style sheets from multiple R objects or files.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("sass")`.

## Functions exposed

### `as_sass`: Convert an R object into Sass code

**Input**

```json
{
  "fn": "as_sass",
  "input": {
    "oneOf": [
      { "type": "string" },
      { "type": "array", "items": { "oneOf": [{ "type": "string" }, { "type": "object" }] } }
    ]
  }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "as_sass",
  "result": { "type": "string" }
}
```

### `font_google`: Helpers for importing web fonts

**Input**

```json
{
  "fn": "font_google",
  "family": { "type": "string" },
  "wght": { "type": "string" },
  "local": { "type": "boolean" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "font_google",
  "result": { "type": "object" }
}
```

### `sass`: Compile Sass to CSS

**Input**

```json
{
  "fn": "sass",
  "input": { "type": "string" },
  "options": { "type": "object" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "sass",
  "result": { "type": "string" }
}
```

### `output_template`: Generate an intelligent temporary output file

**Input**

```json
{
  "fn": "output_template",
  "basename": { "type": "string" },
  "dirname": { "type": "string" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "output_template",
  "result": { "type": "string" }
}
```

## When to invoke

- Converting SCSS syntax strings or lists of R objects into valid CSS strings.
- Generating CSS `@font-face` rules or Google Font import links for web development.
- Compiling Sass files that utilize variables, mixins, or nested rules into a single CSS output.
- Managing temporary CSS file creation that requires compatibility with Sass cache settings.

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
echo '{"fn": "as_sass", "input": ["body { color: blue; }"]}' | Rscript --vanilla skills/sass/invoke.R
```
