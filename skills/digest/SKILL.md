---
name: digest
runtime: r
package: digest
package_source: CRAN
package_url: https://github.com/eddelbuettel/digest
package_version_pinned: ">=0.6.39"
license: GPL (>= 2)
maintainer: "Dirk Eddelbuettel <edd@debian.org>"
---

# Skill: digest

This package provides functions to create compact hash digests of R objects and files using various algorithms, including md5, sha-1, sha-256, and crc32. It also supports the creation of hash-based message authentication codes (HMAC) and AES block cipher objects.

An agent should use this skill when it needs to verify data integrity, generate unique identifiers for R objects, or perform feature hashing on strings.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("digest")`.

## Functions exposed

### `digest`: Create hash function digests for arbitrary R objects or files

**Input**

```json
{
  "fn": "digest",
  "x": "any",
  "algo": "string",
  "serialize": "boolean"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "digest",
  "result": "string"
}
```

### `digest2int`: Hash arbitrary string to integer

**Input**

```json
{
  "fn": "digest2int",
  "x": "string",
  "seed": "integer"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "digest2int",
  "result": "integer"
}
```

### `sha1`: Calculate a SHA1 hash of an object

**Input**

```json
{
  "fn": "sha1",
  "x": "any"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "sha1",
  "result": "string"
}
```

### `hmac`: Create hash-based message authentication code

**Input**

```json
{
  "fn": "hmac",
  "key": "any",
  "object": "any",
  "algo": "string"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "hmac",
  "result": "string"
}
```

## When to invoke

* Generating a unique fingerprint for an R data frame to detect changes in datasets.
* Converting a text string into a deterministic integer for use in randomized experiments or feature hashing.
* Verifying the integrity of a file or object by comparing its current hash against a known value.
* Creating a message authentication code to ensure the authenticity of a data payload.

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
echo '{"fn": "digest", "x": "test_string", "algo": "md5", "serialize": false}' | Rscript --vanilla skills/digest/invoke.R
```
