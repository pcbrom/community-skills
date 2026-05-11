---
name: prettyunits
runtime: r
package: prettyunits
package_source: CRAN
package_url: https://github.com/r-lib/prettyunits
package_version_pinned: ">=1.2.0"
license: MIT
maintainer: "Gabor Csardi <csardi.gabor@gmail.com>"
---

# Skill: prettyunits

The prettyunits package provides functions for converting raw numeric values, time intervals, and color codes into human readable strings. An agent should use this skill when raw data such as byte counts, milliseconds, or p-values require formatting for display in reports or user interfaces.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("prettyunits")`.

## Functions exposed

### pretty_bytes: Format bytes into a human readable string

**Input**

```json
{ "fn": "pretty_bytes", "x": "number", "style": "string" }
```

**Output**

```json
{ "ok": true, "fn": "pretty_bytes", "result": "string" }
```

### pretty_color: Convert color definitions to names

**Input**

```json
{ "fn": "pretty_color", "x": "string" }
```

**Output**

```json
{ "ok": true, "fn": "pretty_color", "result": "string" }
```

### pretty_dt: Format time intervals

**Input**

```json
{ "fn": "pretty_dt", "x": "difftime" }
```

**Output**

```json
{ "ok": true, "fn": "pretty_dt", "result": "string" }
```

### pretty_ms: Format milliseconds into a human readable string

**Input**

```json
{ "fn": "pretty_ms", "x": "number", "compact": "boolean" }
```

**Output**

```json
{ "ok": true, "fn": "pretty_ms", "result": "string" }
```

### pretty_p_value: Format p-values for readability

**Input**

```json
{ "fn": "pretty_p_value", "x": "number" }
```

**Output**

```json
{ "ok": true, "fn": "pretty_p_value", "result": "string" }
```

## When to invoke

- Converting large integer byte counts into units such as kB, MB, or GB.
- Transforming raw millisecond values into readable durations.
- Converting hexadecimal or RGB color strings into standard color names.
- Formatting scientific notation p-values into readable strings like "<0.0001".
- Converting difftime objects into strings containing days, hours, minutes, and seconds.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo 'list(fn="pretty_bytes", x=1337)' | Rscript --vanilla skills/prettyunits/invoke.R
```
