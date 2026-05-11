---
name: rappdirs
runtime: r
package: rappdirs
package_source: CRAN
package_url: https://cran.r-project.org/package=rappdirs
package_version_pinned: ">=0.3.4"
license: MIT
maintainer: "Hadley Wickham <hadley@posit.co>"
---

# Skill: rappdirs

The rappdirs package provides a method to determine standard directory paths on a user's computer for saving data, caches, and logs. It follows platform-specific conventions for Windows, macOS, and Linux.

An agent should use this skill when a task requires identifying appropriate filesystem locations for persistent application state, such as storing downloaded datasets, caching computation results, or writing log files.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("rappdirs")`.

## Functions exposed

### app_dir: Create an object containing multiple application directory paths

**Input**

```json
{ "fn": "app_dir", "appname": "string", "appauthor": "string" }
```

**Output**

```json
{ "ok": true, "fn": "app_dir", "result": { "cache": "string", "log": "string", "data": "string", "config": "string", "site_data": "string", "site_config": "string" } }
```

### user_cache_dir: Get the path to the user cache directory

**Input**

```json
{ "fn": "user_cache_dir", "appname": "string" }
```

**Output**

```json
{ "ok": true, "fn": "user_cache_dir", "result": "string" }
```

### user_data_dir: Get the path to the user data directory

**Input**

```json
{ "fn": "user_data_dir", "appname": "string" }
```

**Output**

```json
{ "ok": true, "fn": "user_data_dir", "result": "string" }
```

### user_config_dir: Get the path to the user configuration directory

**Input**

```json
{ "fn": "user_config_dir", "appname": "string", "roaming": "boolean", "os": "string" }
```

**Output**

```json
{ "ok": true, "fn": "user_config_dir", "result": "string" }
```

### site_data_dir: Get the path to the shared site data directory

**Input**

```json
{ "fn": "site_data_dir", "appname": "string" }
```

**Output**

```json
{ "ok": true, "fn": "site_data_dir", "result": "string" }
```

## When to invoke

* Identifying a directory to store large downloaded files that should not be part of a version control system.
* Locating a directory for writing runtime logs during a long-running computation.
* Determining where to save user-specific configuration settings or preferences.
* Finding a shared directory for data that must be accessible to all users on a multi-user Linux system.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "user_cache_dir", "appname": "my_app"}' | Rscript --vanilla skills/rappdirs/invoke.R
```
