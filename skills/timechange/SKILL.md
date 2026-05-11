---
name: timechange
runtime: r
package: timechange
package_source: CRAN
package_url: https://github.com/vspinu/timechange/
package_version_pinned: ">=0.4.0"
license: GPL (>= 3)
maintainer: "Vitalie Spinu <spinuvit@gmail.com>"
---

# Skill: timechange

The timechange package provides routines for the manipulation of date-time objects. It accounts for time-zones and daylight saving time transitions. The package includes utilities for updating date-time components, modifying time-zones, rounding date-times, and performing period addition or subtraction.

An agent should use this skill when tasks involve adjusting timestamps, calculating new dates after adding months or years, rounding timestamps to specific intervals, or extracting specific components like year or month from a date-time object.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("timechange")`.

## Functions exposed

### `time_add`: Add periods to date-time objects

**Input**

```json
{
  "fn": "time_add",
  "x": "POSIXct or POSIXlt",
  "year": "integer",
  "month": "integer",
  "day": "integer",
  "hour": "integer",
  "minute": "integer",
  "second": "integer",
  "roll_month": "string",
  "roll_dst": "string"
}
```

**Output**

```json
{ "ok": true, "fn": "time_add", "result": "POSIXct" }
```

### `time_get`: Get components of a date-time object

**Input**

```json
{
  "fn": "time_get",
  "x": "POSIXct or POSIXlt"
}
```

**Output**

```json
{ "ok": true, "fn": "time_get", "result": "list" }
```

### `time_round`: Round date-time objects to a unit or multiple

**Input**

```json
{
  "fn": "time_round",
  "x": "POSIXct or POSIXlt",
  "unit": "string"
}
```

**Output**

```json
{ "ok": true, "fn": "time_round", "result": "POSIXct" }
```

### `time_update`: Update components of a date-time object

**Input**

```json
{
  "fn": "time_update",
  "x": "POSIXct or POSIXlt",
  "year": "integer",
  "month": "integer",
  "mday": "integer",
  "hour": "integer",
  "minute": "integer",
  "second": "integer",
  "tz": "string",
  "roll_month": "string",
  "exact": "boolean"
}
```

**Output**

```json
{ "ok": true, "fn": "time_update", "result": "POSIXct" }
```

## When to invoke

* Calculating a future or past date by adding a specific number of months or years to an existing timestamp.
* Rounding timestamps to the nearest hour, day, or minute for temporal aggregation.
* Extracting the day, month, or year from a timestamp to use in a report or database query.
* Modifying the time-zone of a timestamp while maintaining the correct local time.
* Adjusting a date-time object to a specific day of the month while handling invalid dates via rolling logic.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "time_add", "x": "2000-01-31 01:02:03", "month": 1, "roll_month": "postday"}' | Rscript --vanilla skills/timechange/invoke.R
```
