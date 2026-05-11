---
name: lubridate
runtime: r
package: lubridate
package_source: CRAN
package_url: https://lubridate.tidyverse.org
package_version_pinned: ">=1.9.5"
license: MIT
maintainer: "Vitalie Spinu <spinuvit@gmail.com>"
---

# Skill: lubridate

The lubridate package provides functions for working with date-times and time-spans. It enables fast parsing of date-time data, extraction and updating of date-time components such as years, months, days, hours, minutes, and seconds, and algebraic manipulation of date-time and time-span objects.

An agent should use this skill when tasks involve parsing unstructured date strings, calculating differences between time intervals, or manipulating specific components of a timestamp.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("lubridate")`.

## Functions exposed

### am: Determine if a date-time occurs in the AM period

**Input**

```json
{ "fn": "am", "x": "string or POSIXct" }
```

**Output**

```json
{ "ok": true, "fn": "am", "result": "boolean" }
```

### as.duration: Convert objects to a duration

**Input**

```json
{ "fn": "as.duration", "x": "Interval, Period, or numeric" }
```

**Output**

```json
{ "ok": true, "fn": "as.duration", "result": "Duration" }
```

### as.interval: Convert objects to an interval

**Input**

```json
{ "fn": "as.interval", "x": "difftime, Duration, Period, or numeric", "origin": "POSIXct" }
```

**Output**

```json
{ "ok": true, "fn": "as.interval", "result": "Interval" }
```

### as.period: Convert objects to a period

**Input**

```json
{ "fn": "as.period", "x": "Interval, Duration, difftime, or numeric", "unit": "string" }
```

**Output**

```json
{ "ok": true, "fn": "as.period", "result": "Period" }
```

## When to invoke

- Converting numeric values or strings representing seconds into structured duration objects.
- Calculating the elapsed time between two specific timestamps as an interval.
- Extracting the day, month, or year from a date-time object for temporal grouping.
- Determining if a specific timestamp falls within the morning (AM) or afternoon (PM) period.
- Transforming time-spans into human-readable periods with specified units like days or hours.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "am", "x": "2012-03-26 08:00:00"}' | Rscript --vanilla skills/lubridate/invoke.R
```
