---
name: RefManageR
runtime: r
package: RefManageR
package_source: CRAN
package_url: https://github.com/ropensci/RefManageR/
package_version_pinned: ">=1.4.0"
license: GPL-2 | GPL-3 | BSD_3_clause + file LICENSE
maintainer: "Mathew W. McLean <mathew.w.mclean@gmail.com>"
---

# Skill: RefManageR

RefManageR provides tools for importing, manipulating, and managing BibTeX and BibLaTeX bibliographic references. It extends the standard bibentry class to support UTF-8 encoding, field-based searching, and various citation styles.

An agent should use this skill when tasks involve reading .bib files, retrieving bibliographic metadata via DOI or PubMed, or generating formatted citation lists for RMarkdown or RHTML documents.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("RefManageR")`.

## Functions exposed

### BibEntry: Create a bibliographic entry object

**Input**

```json
{
  "fn": "BibEntry",
  "bibtype": "string",
  "key": "string",
  "title": "string",
  "author": "string",
  "journaltitle": "string",
  "date": "string"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "BibEntry",
  "result": "BibEntry"
}
```

### Cite: Cite BibEntry objects in text

**Input**

```json
{
  "fn": "Cite",
  "bib": "BibEntry",
  "...",
  ".opts": {
    "cite.style": "string",
    "super": "boolean"
  }
}
```

**Output**

```json
{
  "ok": true,
  "fn": "Cite",
  "result": "string"
}
```

### GetBibEntryWithDOI: Lookup bibliography information using DOIs

**Input**

```json
{
  "fn": "GetBibEntryWith

DOI",
  "doi": "array of strings"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "GetBibEntryWithDOI",
  "result": "BibEntry"
}
```

### ReadBib: Read BibTeX files into R

**Input**

```json
{
  "fn": "ReadBib",
  "filename": "string"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "ReadBib",
  "result": "BibEntry"
}
```

### SearchBib: Search BibEntry objects by field

**Input**

```json
{
  "fn": "SearchBib",
  "bib": "BibEntry",
  "pattern": "string",
  "field": "string"
}
```

**Output**

```json
{
  "ok": true,
  "fn": "SearchBib",
  "result": "BibEntry"
}
```

## When to invoke

- When a task requires extracting metadata from a list of Digital Object Identifiers (DOIs).
- When an agent needs to parse and filter existing .bib files based on specific criteria like author names or publication years.
- When generating formatted bibliographies or citation strings for academic document preparation.
- When retrieving bibliographic records from external databases such as PubMed or CrossRef.

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
echo '{"fn": "GetBibEntryWithDOI", "doi": ["10.1016/j.iheduc.2003.11.004"]}' | Rscript --vanilla skills/RefManageR/invoke.R
```
