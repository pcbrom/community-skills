---
name: tzdb
runtime: r
package: tzdb
package_source: CRAN
package_url: https://tzdb.r-lib.org
package_version_pinned: ">=0.5.0"
license: MIT
maintainer: "Davis Vaughan <davis@posit.co>"
---

# Skill: tzdb

The tzdb package provides an up-to-date copy of the IANA Time Zone Database. It includes updates regarding time zone boundaries, UTC offsets, and daylight saving time rules. The package also provides a C++ interface for working with the 'date' library to facilitate date and date-time operations.

An agent should use this skill when tasks require verifying time zone names, checking the version of the time zone database, or locating the database file path on the local system.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("tzdb")`.

## Functions exposed

### `tzdb_names`: Returns time zone names found in the database

**Input**

```json
{ "fn": "tzdb_names" }
```

**Output**

```json
{ "ok": true, "fn": "tzdb_names", "result": { "type": "array", "items": { "type": "string" } } }
```

### `tzdb_path`: Retrieve the path to the time zone database

**Input**

```json
{ "fn": "tzdb_path", "text": { "type": "string" } }
```

**Output**

```json
{ "ok": true, "fn": "tzdb_path", "result": { "type": "string" } }
```

### `tzdb_version`: Returns the version of the time zone database

**Input**

```json
{ "fn": "tzdb_version" }
```

**Output**

```json
{ "ok": true, "fn": "tzdb_version", "result": { "type": "string" } }
```

### `tzdb_initialize`: Initialize tzdb for usage in other packages

**Input**

```json
{ "fn": "tzdb_initialize" }
```

**Output**

```json
{ "ok": true, "fn": "tzdb_initialize", "result": null }
```

## When to invoke

* Validating if a specific string is a valid IANA time zone name.
* Verifying the current version of the IANA Time Zone Database installed in the R environment.
* Locating the physical file path of the time zone database for system configuration tasks.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "tzdb_names"}' | Rscript --vanilla skills/tzdb/invoke.R
```
