---
name: DBI
runtime: r
package: DBI
package_source: CRAN
package_url: https://dbi.r-dbi.org
package_version_pinned: ">=1.3.0"
license: LGPL (>= 2.1)
maintainer: "Kirill Müller <kirill@cynkra.com>"
---

# Skill: DBI

DBI provides a database interface definition for communication between R and relational database management systems. It defines a standard set of classes and methods for interacting with various R/DBMS implementations.

An agent should use this skill when it needs to execute SQL queries, manage database tables, or transfer data between R data frames and a relational database.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("DBI")`.

## Functions exposed

### dbConnect: Establish a connection to a database

**Input**

```json
{ "fn": "dbConnect", "drv": "object", "..." : "..." }
```

**Output**

```json
{ "ok": true, "fn": "dbConnect", "result": "object" }
```

### dbGetQuery: Execute a query and return a data frame

**Input**

```json
{ "fn": "dbGetQuery", "con": "object", "statement": "string" }
```

**Output**

```json
{ "ok": true, "fn": "dbGetQuery", "result": "data.frame" }
```

### dbExecute: Execute a statement and return the number of rows affected

**Input**

```json
{ "fn": "dbExecute", "con": "object", "statement": "string" }
```

**Output**

```json
{ "ok": true, "fn": "dbExecute", "result": "integer" }
```

### dbWriteTable: Write a data frame to a database table

**Input**

```json
{ "fn": "dbWriteTable", "con": "object", "name": "string", "value": "data.frame" }
```

**Output**

```json
{ "ok": true, "fn": "dbWriteTable", "result": "boolean" }
```

### dbAppendTable: Insert rows into an existing table

**Input**

```json
{ "fn": "dbAppendTable", "con": "object", "name": "string", "value": "data.frame" }
```

**Output**

```json
{ "ok": true, "fn": "dbAppendTable", "result": "boolean" }
```

### dbListTables: List all tables in the database

**Input**

```json
{ "fn": "dbListTables", "con": "object" }
```

**Output**

```json
{ "ok": true, "fn": "dbListTables", "result": "character vector" }
```

## When to invoke

- Retrieving specific subsets of data from a relational database using SQL SELECT statements.
- Creating new tables in a database based on existing R data frames.
- Appending new observations to an existing database table.
- Checking for the existence of specific tables or columns within a database schema.
- Executing DDL statements such as CREATE TABLE or DROP TABLE.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "dbListTables", "con": "connection_object"}' | Rscript --vanilla skills/DBI/invoke.R
```
