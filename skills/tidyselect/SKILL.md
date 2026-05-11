---
name: tidyselect
runtime: r
package: tidyselect
package_source: CRAN
package_url: https://cran.r-project.org/package=tidyselect
package_version_pinned: ">=1.2.1"
license: MIT + file LICENSE
maintainer: "Lionel Henry <lionel@posit.co>"
---

# Skill: tidyselect

tidyselect provides a backend for selection functions within the tidyverse. It enables the implementation of consistent selection interfaces, allowing for the identification and manipulation of columns in data frames using specific predicates and character vectors.

An agent should use this skill when tasks involve identifying specific columns in a data frame based on patterns, names, or positions, or when reordering and renaming columns according to tidyselect syntax.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("tidyselect")`.

## Functions exposed

### `all_of`: Select variables from character vectors strictly

**Input**

```json
{ "fn": "all_of", "x": "array of strings" }
```

**Output**

```json
{ "ok": true, "fn": "all_of", "result": "array of strings" }
```

### `any_of`: Select variables from character vectors without error on missing values

**Input**

```json
{ "fn": "any_of", "x": "array of strings" }
```

**Output**

```json
{ "ok": true, "fn": "any_of", "result": "array of strings" }
```

### `contains`: Select columns containing a specific string

**Input**

```json
{ "fn": "contains", "contains": "string" }
```

**Output**

```json
{ "ok": true, "fn": "contains", "result": "string" }
```

### `starts_with`: Select columns starting with a specific string

**Input**

```json
{ "name": "starts_with", "prefix": "string" }
```

**Output**

```json
{ "ok": true, "fn": "starts_with", "result": "string" }
```

### `ends_with`: Select columns ending with a specific string

**Input**

```json
{ "name": "ends_with", "suffix": "string" }
```

**Output**

```json
{ "ok": true, "fn": "ends_with", "result": "string" }
```

### `everything`: Select all available variables

**Input**

```json
{ "fn": "everything" }
```

**Output**

```json
{ "ok": true, "fn": "everything", "result": "all columns" }
```

## When to invoke

* Identifying columns in a data frame that match a specific substring pattern.
* Selecting a subset of columns using a predefined character vector where all elements must exist.
* Selecting a subset of columns using a character vector where some elements may be absent from the data frame.
* Filtering columns based on their starting or ending character sequences.
* Reordering columns in a data frame by moving specific selections to positions before or after other columns.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "all_of", "x": ["mpg", "cyl"]}' | Rscript --vanilla skills/tidyselect/invoke.R
```
