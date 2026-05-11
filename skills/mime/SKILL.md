---
name: mime
runtime: r
package: mime
package_source: CRAN
package_url: https://github.com/yihui/mime
package_version_pinned: ">=0.13"
license: GPL
maintainer: "Yui Xie <xie@yihui.name>"
---

# Skill: mime

The mime package identifies MIME types from filenames by looking up extensions in a table derived from UNIX-type systems. An agent should use this skill when it needs to determine the media type of a file based on its extension or when processing multipart HTTP POST requests.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("mime")`.

## Functions exposed

### `guess_type`: Guess the MIME types from filenames

**Input**

```json
{
  "fn": "guess_type",
  "filenames": {
    "type": "array",
    "items": { "type": "string" }
  },
  "mime_extra": {
    "type": "object",
    "additionalProperties": { "type": "string" }
  },
  "unknown": { "type": "string" },
  "empty": { "type": "string" },
  "subtype": {
    "type": "array",
    "items": { "type": "string" }
  }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "guess_type",
  "result": {
    "type": "array",
    "items": { "type": "string" }
  }
}
```

### `mimemap`: Access the extension to MIME type mapping table

**Input**

```json
{
  "fn": "mimemap"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "mimemap",
  "result": {
    "type": "object",
    "additionalProperties": { "type": "string" }
  }
}
```

### `parse_multipart`: Parse multipart form data

**Input**

```json
{
  "fn": "parse_multipart",
  "env": {
    "type": "object",
    "description": "A Rook environment representing an HTTP POST request"
  }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "parse_multipart",
  "result": {
    "type": "object"
  }
}
```

## When to invoke

* Identifying the content type of files in a list of paths for web server configuration.
* Determining the correct `Content-Type` header for file uploads based on file extensions.
* Mapping specific file extensions to custom MIME types for non-standard file formats.
* Parsing incoming multipart/form-data from HTTP requests.

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
echo '{"fn": "guess_type", "filenames": ["test.html", "document.pdf", "script.R"]}' | Rscript --vanilla skills/mime/invoke.R
```
