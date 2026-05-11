#!/usr/bin/env Rscript
# xml2 skill dispatcher.
# Reads one JSON object from stdin, invokes the requested xml2 function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_xml2     <- requireNamespace("xml2",     quietly = TRUE)
})

emit_error <- function(message_text, fn_name = NA_character_, code = 1L) {
  payload <- list(ok = FALSE, error = unname(message_text))
  if (!is.na(fn_name)) payload$fn <- fn_name
  sink(NULL, type = "output")  # restore stdout before writing the final JSON
  if (ok_jsonlite) {
    cat(jsonlite::toJSON(payload, auto_unbox = TRUE, na = "null"))
  } else {
    cat(sprintf('{"ok":false,"error":%s}',
                shQuote(message_text, type = "cmd")))
  }
  cat("\n")
  quit(status = code, save = "no")
}

if (!ok_jsonlite) {
  emit_error(
    paste(
      "The R package 'jsonlite' is required by the xml2 skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_xml2) {
  emit_error(
    paste(
      "The R package 'xml2' is required but is not installed.",
      "Run: install.packages('xml2')."
    )
  )
}

stdin_text <- paste(readLines("stdin", warn = FALSE), collapse = "\n")
if (!nzchar(stdin_text)) {
  emit_error("No JSON payload received on stdin.")
}

payload <- tryCatch(
  jsonlite::fromJSON(stdin_text, simplifyVector = TRUE),
  error = function(e) emit_error(paste0("Invalid JSON on stdin: ", conditionMessage(e)))
)

fn_name <- payload$fn
if (is.null(fn_name) || !nzchar(fn_name)) {
  emit_error("Field `fn` is required.")
}

emit_ok <- function(result, fn_name) {
  sink(NULL, type = "output")  # restore stdout before writing the final JSON
  cat(jsonlite::toJSON(
    list(ok = TRUE, fn = unname(fn_name), result = result),
    auto_unbox = TRUE, na = "null", digits = 12
  ))
  cat("\n")
}

require_field <- function(name, payload, fn_name) {
  if (is.null(payload[[name]])) {
    emit_error(sprintf("Field `%s` is required for fn=%s.", name, fn_name), fn_name)
  }
  payload[[name]]
}

dispatch <- function(payload) {
  fn_name <- payload$fn
  
  if (fn_name == "as_list") {
    x <- require_field("x", payload, fn_name)
    ns <- if (is.null(payload$ns)) NULL else as.character(payload$ns)
    out <- xml2::as_list(x, ns = ns)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "as_xml_document") {
    x <- require_field("x", payload, fn_name)
    out <- xml2::as_xml_document(x)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "download_xml") {
    url    <- as.character(require_field("url", payload, fn_name))
    file   <- as.character(require_field("file", payload, fn_name))
    quiet  <- if (is.null(payload$quiet)) TRUE else isTRUE(payload$quiet)
    mode   <- if (is.null(payload$mode)) "w" else as.character(payload$mode)
    handle <- if (is.null(payload$handle)) NULL else payload$handle
    
    # Note: handle is an external pointer, cannot be easily passed via JSON.
    # We proceed with standard download.
    xml2::download_xml(url = url, file = file, quiet = quiet, mode = mode)
    emit_ok(TRUE, fn_name)
    
  } else if (fn_name == "read_xml") {
    x <- require_field("x", payload, fn_name)
    encoding   <- if (is.null(payload$encoding)) NULL else as.character(payload$encoding)
    as_html    <- if (is.null(payload$as_html)) FALSE else isTRUE(payload$as_html)
    options    <- if (is.null(payload$options)) 0L else as.integer(payload$options)
    base_url   <- if (is.null(payload$base_url)) NULL else as.character(payload$base_url)
    n          <- if (is.null(payload$n)) NULL else as.integer(payload$n)
    verbose    <- if (is.null(payload$verbose)) FALSE else isTRUE(payload$verbose)
    
    out <- xml2::read_xml(
      x = x, 
      encoding = encoding, 
      as_html = as_html, 
      options = options, 
      base_url = base_url, 
      n = n, 
      verbose = verbose
    )
    emit_ok(out, fn_name)
    
  } else if (fn_name == "read_html") {
    # read_html is a wrapper for read_xml with as_html = TRUE
    url <- as.character(require_field("url", payload, fn_name))
    out <- xml2::read_html(url)
    emit_ok(out, fn_name)
    
  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
