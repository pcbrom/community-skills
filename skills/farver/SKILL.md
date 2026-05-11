---
name: farver
runtime: r
package: farver
package_source: CRAN
package_url: https://farver.data-imaginist.com
package_version_pinned: ">=2.1.2"
license: MIT
maintainer: "Thomas Lin Pedersen <thomas.pedersen@posit.co>"
---

# Skill: farver

The farver package provides high performance functions for colour space manipulation. It implements colour space conversions and comparisons using C++ to achieve higher speeds than the grDevices package.

An agent should use this skill when tasks involve converting colour representations between different spaces, calculating perceptual distances between colours, or decoding hex-string colour values into numerical formats.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("farver")`.

## Functions exposed

### `decode_colour`: Decode RGB hex-strings into colour values

**Input**

```json
{
  "fn": "decode_colour",
  "colours": { "type": "array", "items": { "type": "string" } },
  "alpha": { "type": "boolean" },
  "to": { "type": "string" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "decode_colour",
  "result": { "type": "array", "items": { "type": "array", "items": { "type": "number" } } }
}
```

### `convert_colour`: Convert between colour spaces

**Input**

```json
{
  "fn": "convert_colour",
  "from": { "type": "string" },
  "to": { "type": "string" },
  "colour": { "type": "array", "items": { "type": "array", "items": { "type": "number" } } },
  "white_from": { "type": "string" },
  "white_to": { "type": "string" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "convert_colour",
  "result": { "type": "array", "items": { "type": "array", "items": { "type": "number" } } }
}
```

### `compare_colour`: Calculate the distance between colours

**Input**

```json
{
  "fn": "compare_colour",
  "colour1": { "type": "array", "items": { "type": "number" } },
  "colour2": { "type": "array", "items": { "type": "number" } },
  "from_space": { "type": "string" },
  "to_space": { "type": "string" },
  "method": { "type": "string" }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "compare_colour",
  "result": { "type": "number" }
}
```

### `as_white_ref`: Convert value to tristimulus values normalised to Y=100

**Input**

```json
{
  "fn": "as_white_ref",
  "x": { "type": ["string", "array"] }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "as_white_ref",
  "result": { "type": "array", "items": { "type": "number" } }
}
```

## When to invoke

* Converting a list of hex-encoded colour strings into numerical LUV, LAB, or LCH coordinates.
* Calculating the perceptual difference between two sets of colours using the CIE2000 algorithm.
* Transforming colour data from one illuminant reference to another, such as D65 to F10.
* Comparing colour similarity across different colour spaces by first converting them to a common representation.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "decode_colour", "colours": ["#43e1f6", "steelblue"], "to": "lch"}' | Rscript --vanilla skills/farver/invoke.R
```
