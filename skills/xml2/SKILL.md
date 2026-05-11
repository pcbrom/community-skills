---
name: xml2
runtime: r
package: xml2
package_source: CRAN
package_url: https://xml2.r-lib.org
package_version_pinned: ">=1.5.2"
license: MIT
maintainer: "Jeroen Ooms <jeroenooms@gmail.com>"
---

# Skill: xml2

The xml2 package provides bindings to libxml2 for processing XML data. It allows for parsing XML and HTML, navigating structures using XPath expressions, and performing XML schema validation.

An agent should use this skill when it needs to parse XML or HTML documents, extract specific elements or attributes from structured markup, or convert R list objects into XML format.

## Prerequisites

- R available on `PATH`.
- The package installed: `install.packages("xml2")`.

## Functions exposed

### read_xml: Read XML or HTML from a string or file

**Input**

```json
{ "fn": "read_xml", "xml": "string" }
```

**Output**

```json
{ "ok": true, "fn": "read_xml", "result": "xml_document" }
```

### read_html: Read HTML from a string, file, or URL

**Input**

```json
{ "fn": "read_html", "url": "string" }
```

**Output**

```json
{ "ok": true, "fn": "read_html", "result": "xml_document" }
```

### xml_find_first: Find the first node matching an XPath expression

**Input**

```json
{ "fn": "xml_find_first", "xml_node": "xml_document", "xpath": "string" }
```

**Output**

```json
{ "ok": true, "fn": "xml_find_first", "result": "xml_node" }
```

### xml_find_all: Find all nodes matching an XPath expression

**Input**

```json
{ "fn": "xml_find_all", "xml_node": "xml_document", "xpath": "string" }
```

**Output**

```json
{ "ok": true, "fn": "xml_find_all", "result": "xml_nodeset" }
```

### xml_text: Extract text content from an XML node

**Input**

```json
{ "fn": "xml_text", "xml_node": "xml_node" }
```

**Output**

```json
{ "ok": true, "fn": "xml_text", "result": "string" }
```

### xml_attr: Extract an attribute value from an XML node

**Input**

```json
{ "fn": "xml_attr", "xml_node": "xml_node", "attr": "string" }
```

**Output**

```json
{ "ok": true, "fn": "xml_attr", "result": "string" }
```

### as_list: Convert an XML node or document to an R list

**Input**

```json
{ "fn": "as_list", "xml_node": "xml_document" }
```

**Output**

```json
{ "ok": true, "fn": "as_list", "result": "list" }
```

### as_xml_document: Convert an R list to an XML document

**Input**

```json
{ "fn": "as_xml_document", "x": "list" }
```

**Output**

```json
{ "ok": true, "fn": "as_xml_document", "result": "xml_document" }
```

## When to invoke

- Extracting specific data points from web pages by parsing HTML via XPath.
- Converting nested R lists into valid XML files for data export.
- Parsing local XML files to retrieve node names, attributes, or text content.
- Validating XML documents against a schema.
- Scraping structured data from XML-based API responses.

## Error contract

```json
{ "ok": false, "fn": "<requested>", "error": "<human-readable message>" }
```

## Worked example

```bash
echo '{"fn": "read_xml", "xml": "<root><child id=\"1\">data</child></root>"}' | Rscript --vanilla skills/xml2/invoke.R
```
