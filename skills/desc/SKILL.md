---
name: desc
runtime: r
package: desc
package_source: CRAN
package_url: https://desc.r-lib.org/
package_version_pinned: ">=1.4.3"
license: MIT + file LICENSE
maintainer: "Gábor Csárdi <csardi.gabor@gmail.com>"
---

# Skill: desc

The `desc` package provides tools to read, write, create, and manipulate R package DESCRIPTION files. It is designed for workflows that require programmatic modification of package metadata.

An agent should use this skill when tasks involve automating the creation of new R packages, updating package dependencies, or modifying author and maintainer information within an existing DESCRIPTION file.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("desc")`.

## Functions exposed

### `desc_get`: Retrieve a field value from a DESCRIPTION file

**Input**

```json
{ "fn": "desc_get", "path": "string", "field": "string" }
```

**Output**

```json
{ "ok": true, "fn": "desc_get", "result": "string" }
```

### `desc_set`: Set a field value in a DESCRIPTION file

**Input**

```json
{ "fn": "desc_set", "path": "string", "field": "string", "value": "string" }
```

**Output**

```json
{ "ok": true, "fn": "desc_set", "result": "boolean" }
```

### `desc_add_dep`: Add a dependency to a DESCRIPTION file

**Input**

```json
{ "fn": "desc_add_dep", "path": "string", "package": "string", "type": "string" }
```

**Output**

```json
{ "ok": true, "fn": "desc_add_dep", "result": "boolean" }
```

### `desc_set_version`: Update the package version

**Input**

```json
{ "fn": "desc_set_version", "path": "string", "version": "string" }
```

**Output**

```json
{ "ok": true, "fn": "desc_set_version", "result": "boolean" }
```

### `check_field`: Perform syntactical check of a field

**Input**

```json
{ "fn": "check_field", "path": "string", "field": "string" }
```

**Output**

```json
{ "ok": true, "fn": "check_field", "result": "boolean" }
```

## When to invoke

- Modifying the `Imports`, `Depends`, or `Suggests` fields to add or remove R packages.
- Updating the `Version` field during automated release workflows.
- Programmatically changing the `Maintainer` or `Author` fields in a package metadata file.
- Validating that specific fields in a DESCRIPTION file adhere to required syntax.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "desc_get", "path": "DESCRIPTION", "field": "Package"}' | Rscript --vanilla skills/desc/invoke.R
```
