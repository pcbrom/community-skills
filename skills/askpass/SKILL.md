---
name: askpass
runtime: r
package: askpass
package_source: CRAN
package_url: https://r-lib.r-universe.dev/askpass
package_version_pinned: ">=1.2.1"
license: MIT
maintainer: "Jero/Ooms <jeroenooms@gmail.com>"
---

# Skill: askpass

The askpass package provides cross-platform utilities for prompting users for credentials or passphrases. It is used to facilitate authentication with servers or to access protected keys.

The package supports direct password entry within R or indirect entry as a backend for SSH or Git via environment variables.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("askpass")`.

## Functions exposed

### `askpass`: Prompt the user for a password

**Input**

```json
{ "fn": "askpass", "prompt": "string" }
```

**Output**

```json
{ "ok": true, "fn": "askpass", "result": "string" }
```

### `ssh_askpass`: Retrieve the path to the native executable

**Input**

```json
{ "fn": "ssh_askpass" }
```

**Output**

```json
{ "ok": true, "fn": "ssh_askpass", "result": "string" }
```

## When to invoke

- When a task requires user input for a password or passphrase to authenticate with a remote server.
- When an automated process needs to access a protected cryptographic key.
- When configuring environment variables like SSH_ASKPASS or GIT_ASKPASS for Git or SSH operations.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "askpass", "prompt": "Enter password"}' | Rscript --vanilla skills/askpass/invoke.R
```
