---
name: base64enc
runtime: r
package: base64enc
package_source: CRAN
package_url: https://www.rforge.net/base64enc
package_version_pinned: ">=0.1-6"
license: GPL-2 | GPL-3
maintainer: "Simon Urbanek <Simon.Urbanek@r-project.org>"
---

# Skill: base64enc

The base64enc package provides tools for handling base64 encoding and decoding. It allows for the conversion of raw vectors, files, or connections into base64 encoded strings and vice versa.

An agent should use this skill when it needs to transform binary data into a text-based format for transmission, or when it needs to reconstruct binary files from base64 encoded strings.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("base64enc")`.

## Functions exposed

### base64encode: Encode data into base64 encoding

**Input**

```json
{ "fn": "base64encode", "x": "array", "width": "integer", "sep": "string" }
```

**Output**

```json
{ "ok": true, "fn": "base64encode", "result": "string" }
```

### base64decode: Decode a base64-encoded string into binary data

**Input**

```json
{ "fn": "base64decode", "input": "string", "output": "null" }
```

**Output**

```json
{ "ok": true, "fn": "base64decode", "result": "array" }
```

### dataURI: Create a data URI string

**Input**

```json
{ "fn": "dataURI", "x": "array", "encoding": "string", "mime": "string", "file": "string" }
```

**Output**

```json
{ "ok": true, "fn": "dataURI", "result": "string" }
```

### checkUTF8: Check the validity of a byte stream as UTF8

**Input**

```json
{ "fn": "checkUTF8", "x": "array" }
```

**Output**

```json
{ "ok": true, "fn": "checkUTF8", "result": "boolean" }
```

## When to invoke

* Converting raw byte vectors into ASCII strings for inclusion in JSON or XML payloads.
* Reconstructing image files or other binary assets from base64 encoded text.
* Generating data URIs for embedding small images or assets directly into HTML or CSS.
* Verifying if a specific raw vector contains valid UTF-8 encoded characters.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "base64encode", "x": [1, 2, 3]}' | Rscript --vanilla skills/base64enc/invoke.R
```
