---
name: fs
runtime: r
package: fs
package_source: CRAN
package_url: https://fs.r-lib.org
package_version_pinned: ">=2.1.0"
license: MIT
maintainer: "Jeroen Ooms <jeroenooms@gmail.com>"
---

# Skill: fs

The `fs` package provides a cross-platform interface to file system operations using the `libuv` C library. It allows for manipulation of files and directories, path manipulation, and querying file metadata.

An agent should use this skill when tasks require inspecting directory contents, managing file permissions, creating or deleting files, or performing path transformations.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("fs")`.

## Functions exposed

### `dir_ls`: List files in a directory

**Input**

```json
{
  "fn": "dir_ls",
  "path": { "type": "string" },
  "type": { "type": "string", "enum": ["undirected", "directory", "file", "link"] },
  "glob": { "type": "string" },
  "recurse": { "type": "boolean" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "dir_ls",
  "result": { "type": "array", "items": { "type": "string" } }
}
```

### `dir_info`: Retrieve detailed information about directory contents

**Input**

```json
{
  "fn": "dir_info",
  "path": { "type": "string" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "dir_info",
  "result": { "type": "object" }
}
```

### `file_access`: Query for existence and access permissions

**Input**

```json
{
  "fn": "file_access",
  "x": { "type": "string" },
  "mode": { "type": "string", "enum": ["exists", "read", "write", "execute"] }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "file_access",
  "result": { "type": "boolean" }
}
```

### `file_chmod`: Change file permissions

**Input**

```json
{
  "fn": "file_chmod",
  "path": { "type": "string" },
  "mode": { "type": "string" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "file_chmod",
  "result": { "type": "null" }
}
```

### `path_abs`: Convert a path to an absolute path

**Input**

```json
{
  "fn": "path_abs",
  "path": { "type": "string" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "path_abs",
  "result": { "type": "string" }
}
```

## When to invoke

* Identifying all files matching a specific extension within a directory tree.
* Verifying if a specific file exists and is writable before attempting a write operation.
* Retrieating file metadata such as size, modification time, or permissions for a list of paths.
* Converting relative file paths into absolute paths for unambiguous file referencing.
* Modifying file system permissions to restrict or grant access to specific users or groups.

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
echo '{"fn": "dir_ls", "path": ".", "glob": "*.R"}' | Rscript --vanilla skills/fs/invoke.R
```
