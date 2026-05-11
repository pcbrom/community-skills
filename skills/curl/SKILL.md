---
name: curl
runtime: r
package: curl
package_source: CRAN
package_url: https://jeroen.r-universe.dev/curl
package_version_pinned: ">=7.1.0"
license: MIT + file LICENSE
maintainer: "Jeroen Ooms <jeroenooms@gmail.com>"
---

# Skill: curl

This package provides bindings to libcurl for performing configurable HTTP and FTP requests. It allows for processing responses in memory, on disk, or via streaming interfaces.

An agent should use this skill when it needs to perform low-level network operations, such as downloading files, encoding URL components, or managing HTTP handles.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("curl")`.

## Functions exposed

### `curl`: Create a connection interface for URLs

**Input**

```json
{ "fn": "curl", "url": "string", "mode": "string" }
```

**Output**

```json
{ "ok": true, "fn": "curl", "result": "connection_object" }
```

### `curl_download`: Download a file to a specific disk location

**Input**

```json
{ "fn": "curl_download", "url": "string", "destfile": "string" }
```

**Output**

```json
{ "ok": true, "fn": "curl_download", "result": "string" }
```

### `curl_escape`: Encode special characters for use in URLs

**Input**

```json
{ "fn": "curl_escape", "string": "string" }
```

**Output**

```json
{ "ok": true, "fn": "curl_escape", "result": "string" }
```

### `curl_version`: Retrieve libcurl version information

**Input**

```json
{ "fn": "curl_version" }
```

**Output**

```json
{ "ok": true, "fn": "curl_version", "result": "object" }
```

## When to invoke

* Downloading large datasets or files from HTTP, HTTPS, or FTP sources to the local file system.
* Encoding strings containing non-ASCII characters or special symbols for safe inclusion in URL query parameters.
* Implementing custom HTTP request logic, such as handling specific compression types like gzip or deflate.
* Verifying network connectivity or checking the version of the underlying libcurl library.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "curl_escape", "string": "foo = bar + 5"}' | Rscript --vanilla skills/curl/invoke.R
```
