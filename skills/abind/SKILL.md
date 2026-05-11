---
name: abind
runtime: r
package: abind
package_source: CRAN
package_url: https://cran.r-project.org/package=abind
package_version_pinned: ">=1.4-8"
license: MIT
maintainer: "Tony Plate <tplate@acm.org>"
---

# Skill: abind

The abind package provides tools to combine multidimensional arrays, vectors, and matrices into a single array. It generalizes the functionality of cbind and rbind to higher-dimensional tensors.

An agent should use this skill when tasks require concatenating arrays along specific dimensions, subsetting multidimensional objects using arbitrary indices, or reducing the dimensionality of tensors.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("abind")`.

## Functions exposed

### abind: Combine multidimensional arrays

**Input**

```json
{
  "fn": "abind",
  "x": "array or list of arrays",
  "along": "integer or float representing the dimension to bind along"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "abind",
  "result": "array"
}
```

### asub: Arbitrary subsetting of array-like objects

**Input**

```json
{
  "fn": "asub",
  "x": "array-like object",
  "indices": "list of indices for each dimension"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "asub",
  "result": "array"
}
```

### adrop: Drop dimensions of an array object

**Input**

```json
{
  "fn": "adrop",
  "x": "array-like object",
  "drop": "integer or vector of dimensions to drop"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "adrop",
  "result": "array"
}
```

### acorn: Return a corner of an array object

**Input**

```json
{
  "fn": "acorn",
  "x": "array-like object",
  "n": "integer representing number of slices"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "acorn",
  "result": "array"
}
```

## When to invoke

* Concatenating multiple matrices or tensors along a new or existing dimension.
* Extracting specific slices from a high-dimensional tensor using non-standard index patterns.
* Removing specific dimensions from an array after a subsetting operation.
* Inspecting small sub-sections of large multidimensional arrays.

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
echo '{"fn": "abind", "x": [[1,2],[3,4]], "along": 1}' | Rscript --vanilla skills/abind/invoke.R
```
