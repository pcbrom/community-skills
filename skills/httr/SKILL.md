---
name: httr
runtime: r
package: httr
package_source: CRAN
package_url: https://httr.r-lib.org/
package_version_pinned: ">=1.4.8"
license: MIT
maintainer: "Hadley Wickham <hadley@posit.co>"
---

# Skill: httr

The httr package provides tools for working with URLs and HTTP. It allows for performing HTTP requests using various verbs such as GET, POST, DELETE, and HEAD.

An agent should use this skill when it needs to interact with web services, retrieve data from URLs, or communicate with RESTful APIs.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("httr")`.

## Functions exposed

### GET: Perform an HTTP GET request

**Input**

```json
{
  "fn": "GET",
  "url": "string",
  "path": "string",
  "query": "object",
  "config": "object"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "GET",
  "result": "object"
}
```

### POST: Perform an HTTP POST request

**Input**

```json
{
  "fn": "POST",
  "url": "string",
  "path": "string",
  "body": "object",
  "config": "object"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "POST",
  "result": "object"
}
```

### DELETE: Perform an HTTP DELETE request

**Input**

```json
{
  "fn": "DELETE",
  "url": "string",
  "path": "string",
  "config": "object"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "DELETE",
  "result": "object"
}
```

### HEAD: Retrieve HTTP headers via a HEAD request

**Input**

```json
{
  "fn": "HEAD",
  "url": "string",
  "path": "string"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "HEAD",
  "result": "object"
}
```

## When to invoke

- Fetching JSON or XML data from a specific API endpoint.
- Sending data to a server via a POST request.
- Checking the existence of a resource or inspecting HTTP headers.
- Interacting with web services that require authentication or custom headers.
- Deleting remote resources using a DELETE method.

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
echo '{"fn": "GET", "url": "http://google.com/"}' | Rscript --vanilla skills/httr/invoke.R
```
