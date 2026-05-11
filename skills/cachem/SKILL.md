---
name: cachem
runtime: r
package: cachem
package_source: CRAN
package_url: https://cachem.r-lib.org/
package_version_pinned: ">=1.1.0"
license: MIT
maintainer: "Winston Chang <winston@posit.co>"
---

# Skill: cachem

The cachem package provides key-value stores with automatic pruning capabilities. It allows for the creation of memory or disk-based caches that maintain specific constraints regarding total size, object age, or the number of objects.

An agent should use this skill when managing computational resources, specifically when implementing mechanisms to store expensive-to-compute results while preventing memory exhaustion or disk overflow.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("cachem")`.

## Functions exposed

### cache_disk: Create a disk cache object

**Input**

```json
{
  "fn": "cache_disk",
  "path": { "type": "string" },
  "max_size": { "type": "number" },
  "max_age": { "type": "number" },
  "max_n": { "type": "integer" },
  "evict": { "type": "string" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "cache_disk",
  "result": { "type": "object" }
}
```

### cache_mem: Create a memory cache object

**Input**

```json
{
  "fn": "cache_mem",
  "max_size": { "type": "number" },
  "max_age": { "type": "number" },
  "max_n": { "type": "integer" },
  "evict": { "type": "string" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "cache_mem",
  "result": { "type": "object" }
}
```

### cache_layered: Compose cache objects into a layered cache

**Input**

```json
{
  "fn": "cache_layered",
  "..." : { "type": "array", "items": { "type": "object" } }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "cache_layered",
  "result": { "type": "object" }
}
```

### key_missing: Check if a key is absent from a cache

**Input**

```json
{
  "fn": "key_missing",
  "cache": { "type": "object" },
  "key": { "type": "string" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "key_missing",
  "result": { "type": "boolean" }
}
```

## When to invoke

* Implementing memoization for functions that perform heavy data transformations or large-scale simulations.
* Managing local storage for large datasets where disk space must be capped at a specific threshold.
* Creating multi-tier caching strategies, such as checking a fast memory cache before querying a larger disk cache.
* Preventing memory leaks in long-running R processes by enforcing maximum object age or count.

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
echo '{"fn": "cache_mem", "max_size": 1048576}' | Rscript --vanilla skills/cachem/invoke.R
```
