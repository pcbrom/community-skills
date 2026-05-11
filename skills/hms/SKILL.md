---
name: hms
runtime: r
package: hms
package_source: CRAN
package_url: https://hms.tidyverse.org/
package_version_pinned: ">=1.1.4"
license: MIT
maintainer: "Kirill Müller <kirill@cynkra.com>"
---

# Skill: hms

The hms package implements an S3 class for storing and formatting time-of-day values. It uses the difftime class as a base and maintains seconds as the unit for numeric coercion.

An agent should use this skill when tasks involve parsing time strings, constructing time-of-day objects from numeric components, or rounding time values to specific intervals.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("hms")`.

## Functions exposed

### hms: Construct hms objects from time components

**Input**

```json
{ "fn": "hms", "seconds": "number", "minutes": "number", "hours": "number", "day": "number" }
```

**Output**

```json
{ "ok": true, "fn": "hms", "result": "hms" }
```

### parse_hms: Convert character strings to hms objects

**Input**

```json
{ "fn": "parse_hms", "x": "string" }
```

**Output**

```json
{ "ok": true, "fn": "parse_hms", "result": "hms" }
```

### round_hms: Round hms objects to a multiple or digits

**Input**

```json
{ "fn": "round_hms", "x": "hms", "digits": "number" }
```

**Output**

```json
{ "ok": true, "fn": "round_hms", "result": "hms" }
```

### as_hms: Convert various data types to hms

**Input**

```json
{ "fn": "as_hms", "x": "string|numeric|POSIXct" }
```

**Output**

```json
{ "ok": true, "fn": "as_hms", "result": "hms" }
```

## When to invoke

- Converting character vectors in the format "HH:MM:SS" into time-of-day objects.
- Creating time objects from separate numeric vectors representing hours, minutes, and seconds.
- Rounding time-of-day values to the nearest minute, second, or decimal fraction of a second.
- Casting numeric durations or POSIXct timestamps into the hms class for use in data frames.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "parse_hms", "x": "12:34:56"}' | Rscript --vanilla skills/hms/invoke.R
```
