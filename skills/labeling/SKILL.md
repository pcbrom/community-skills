---
name: labeling
runtime: r
package: labeling
package_source: CRAN
package_url: https://cran.r-project.org/package=labeling
package_version_pinned: ">=0.4.3"
license: MIT
maintainer: "Nuno Sempere <nuno.semperelh@gmail.com>"
---

# Skill: labeling

The labeling package provides a collection of algorithms for axis labeling. It includes implementations of specific labeling strategies such as Heckbert's and Wilkinson's algorithms.

An agent should use this skill when a task requires calculating optimal tick label positions or formatting axis labels for plots.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("labeling")`.

## Functions exposed

### heckbert: Heckbert's labeling algorithm

**Input**

```json
{ "fn": "heckbert", "args": { "..." : "..." } }
```

**Output**

```json
{ "ok": true, "fn": "heckbert", "result": "array" }
```

### wilkinson: Wilkinson's labeling algorithm

**Input**

```json
{ "fn": "wilkinson", "args": { "..." : "..." } }
```

**Output**

```json
{ "ok": true, "fn": "wilkinson", "result": "array" }
```

### extended: An extension of Wilkinson's algorithm for position tick labels

**Input**

```json
{ "fn": "extended", "args": { "..." : "..." } }
```

**Output**

```json
{ "ok": true, "fn": "extended", "result": "array" }
```

### extended.figures: Generate figures from the extended algorithm

**Input**

```json
{ "fn": "extended.figures", "args": { "..." : "..." } }
```

**Output**

```json
{ "ok": true, "fn": "extended.figures", "result": "graphics_object" }
```

## When to invoke

- Determining optimal tick placement for numeric axes to prevent label overlap.
- Implementing optimization-based axis labeling for scientific plots.
- Generating specific figure types derived from the extended Wilkinson algorithm.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "heckbert", "args": {}}' | Rscript --vanilla skills/labeling/invoke.R
```
