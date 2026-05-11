---
name: pkgbuild
runtime: r
package: pkgbuild
package_source: CRAN
package_url: https://github.com/r-lib/pkgbuild
package_version_pinned: ">=1.4.8"
license: MIT + file LICENSE
maintainer: "Gábor Csárdi <csardi.gabor@gmail.com>"
---

# Skill: pkgbuild

The pkgbuild package provides functions to locate compilers and build tools required for R package construction. It manages the configuration of the PATH environment variable to ensure R can access necessary development tools.

An agent should use this skill when it needs to verify the presence of build tools, compile C/C++ code, or create package binaries from source directories.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("pkgbuild")`.

## Functions exposed

### build: Build a package from a source directory

**Input**

```json
{ "fn": "build", "path": "string", "binary": "boolean" }
```

**Output**

```json
{ "ok": true, "fn": "build", "result": "string" }
```

### check_build_tools: Check if build tools are available

**Input**

```json
{ "fn": "check_build_tools" }
```

**Output**

```json
{ "ok": true, "fn": "check_build_tools", "result": "boolean" }
```

### compile_dll: Compile a shared library from source

**Input**

```json
{ "fn": "compile_dll", "path": "string" }
```

**Output**

```json
{ "ok": true, "fn": "compile_dll", "result": "boolean" }
```

### compiler_flags: Retrieve compiler flags

**Input**

```json
{ "fn": "compiler_flags", "debug": "boolean" }
```

**Output**

```json
{ "ok": true, "fn": "compiler_flags", "result": "character vector" }
```

## When to invoke

* Verifying if a system has the necessary compilers and Rtools installed to compile C++ or C code.
* Creating a `.tar.gz` or platform-specific binary (e.g., `.zip`) from a local package directory.
* Checking if specific compiler flags like `-Wall` and `-pedantic` are active during a build process.
* Cleaning compiled objects from a package `src` directory before a new build.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "check_build_tools"}' | Rscript --vanilla skills/pkgbuild/invoke.R
```
