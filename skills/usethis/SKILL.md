---
name: usethis
runtime: r
package: usethis
package_source: CRAN
package_url: https://usethis.r-lib.org
package_version_pinned: ">=3.2.1"
license: MIT
maintainer: "Jennifer Bryan <jenny@posit.co>"
---

# Skill: usethis

The usethis package automates R package and project setup tasks. It provides programmatic interfaces for configuring unit testing, test coverage, continuous integration, Git, GitHub, licenses, and RStudio projects.

An agent should invoke this skill when a task requires initializing a new R package, cloning a repository from GitHub into a local project, or modifying configuration files such as .Rprofile or .gitignore.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("usethis")`.

## Functions exposed

### `create_from_github`: Create a project from a GitHub repository

**Input**

```json
{ "fn": "create_from_github", "repo_spec": "string" }
```

**Output**

```json
{ "ok": true, "fn": "create_from_github", "result": "string" }
```

### `create_package`: Create a new R package

**Input**

```json
{ "fn": "create_package", "path": "string" }
```

**Output**

```json
{ "ok": true, "fn": "create_package", "result": "boolean" }
```

### `edit_file`: Open or create a file for editing

**Input**

```json
{ "fn": "edit_file", "file": "string" }
```

**Output**

```json
{ "ok": true, "fn": "edit_file", "result": "null" }
```

### `git_protocol`: Check or set the default Git protocol

**Input**

```json
{ "fn": "git_protocol", "protocol": "string" }
```

**Output**

```json
{ "ok": true, "fn": "git_protocol", "result": "string" }
```

## When to invoke

* Initializing a new R package structure from a local directory path.
* Cloning an existing GitHub repository to a local machine using a URL or owner/repo specification.
* Modifying R environment configurations, such as .Renviron or .Rprofile.
* Setting the Git transport protocol between HTTPS and SSH for new remote configurations.
* Creating or updating project-specific configuration files like .gitignore.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "create_from_github", "repo_spec": "r-lib/usethis"}' | Rscript --vanilla skills/usethis/invoke.R
```
