---
name: bslib
runtime: r
package: bslib
package_source: CRAN
package_url: https://rstudio.github.io/bslib/
package_version_pinned: ">=0.10.0"
license: MIT
maintainer: "Carson Sievert <carson@posit.co>"
---

# Skill: bslib

The bslib package provides tools for custom CSS styling of Shiny and R Markdown applications using Bootstrap Sass. It enables the creation of custom Bootstrap themes, management of Bootstrap 3, 4, and 5 dependencies, and the implementation of advanced UI components like accordions and task buttons.

An agent should use this skill when tasks involve modifying the visual appearance of a Shiny application, creating custom Bootstrap themes, or implementing specific UI layouts such as sidebars, cards, or vertically collapsing accordions.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("bslib")`.

## Functions exposed

### `accordion`: Create a vertically collapsing accordion

**Input**

```json
{
  "fn": "accordion",
  "...,": "...",
  "open": {
    "type": "string",
    "description": "Specifies which panels are open by default"
  },
  "id": {
    "type": "string",
    "description": "The ID for the accordion to allow programmatic updates"
  }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "accordion",
  "result": "htmltools::tag"
}
```

### `bs_theme`: Create a new Bootstrap theme

**Input**

```json
{
  "fn": "bs_theme",
  "bg": {
    "type": "string",
    "description": "Background color"
  },
  "fg": {
    "type": "string",
    "description": "Foreground color"
  },
  "primary": {
    "type": "string",
    "description": "Primary color"
  },
  "base_font": {
    "type": "string",
    "description": "Base font family"
  }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "bs_theme",
  "result": "bslib::bs_theme"
}
```

### `layout_columns`: Create a column-based layout

**Input**

```json
{
  "fn": "layout_columns",
  "...",
  "col_widths": {
    "type": "integer",
    "description": "Width of columns"
  }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "layout_columns",
  "result": "htmltools::tag"
}
```

### `as_fill_carrier`: Coerce elements to fill behavior

**Input**

```json
{
  "fn": "as_fill_carrier",
  "...",
  "tag": {
    "type": "htmltools::tag"
  }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "as_fill_carrier",
  "result": "htmltools::tag"
}
```

## When to invoke

- When a task requires changing the color palette, fonts, or CSS variables of a Shiny application.
- When a task requires organizing UI elements into collapsible sections using an accordion.
- When a task requires implementing a responsive grid layout using columns.
- When a task requires ensuring that specific UI elements (like `uiOutput`) expand to fill their parent containers.
- When a task requires binding an `ExtendedTask` to a button to manage busy states in a Shiny UI.

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
echo 'Rscript --vanilla -e "print(bslib::bs_theme(bg = \"#FFFFFF\", fg = \"#000000\"))"' | Rscript --vanilla skills/bslib/invoke.R
```
