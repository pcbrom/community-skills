#!/usr/bin/env Rscript
# commonmark skill dispatcher.
# Reads one JSON object from stdin, invokes the requested commonmark function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_commonmark <- requireNamespace("commonmark", quietly = TRUE)
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
      "The R package 'jsonlite' is required by the commonmark skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_commonmark) {
  emit_error(
    paste(
      "The R package 'commonmark' is required but is not installed.",
      "Run: install.packages('commonmark')."
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
    emit_error(sprintf("Field `%s` is required for fn=%s.", name, fn_name))
  }
  payload[[name]]
}

dispatch <- function(payload) {
  fn_name <- payload$fn
  
  if (fn_name == "markdown_html" || 
      fn_name == "markdown_latex" || 
      fn_name == "markdown_xml" || 
      fn_name == "markdown_text") {
    
    # All these functions share the same core argument structure from the Rd
    text <- as.character(require_field("text", payload, fn_name))
    
    # Optional arguments
    hardbreaks <- if (is.null(payload$hardbreaks)) NULL else as.logical(payload$hardbreaks)
    smart      <- if (is.null(payload$smart))      NULL else as.logical(payload$smart)
    normalize  <- if (is.null(payload$normalize))  NULL else as.logical(payload$normalize)
    sourcepos  <- if (is.null(payload$sourcepos))  NULL else as.logical(payload$sourcepos)
    footnotes  <- if (is.null(payload$footnotes))  NULL else as.logical(payload$footnotes)
    extensions <- if (is.null(payload$extensions)) NULL else as.character(payload$extensions)
    width      <- if (is.null(payload$width))      NULL else as.numeric(payload$width)

    # Build argument list for the specific function
    args <- list(text = text)
    if (!is.null(hardbreaks)) args$hardbreaks <- hardbreaks
    if (!is.null(smart))      args$smart      <- smart
    if (!is.null(normalize))  args$normalize  <- normalize
    if (!is.null(sourcepos))  args$sourcepos  <- sourcepos
    if (!is.null(footnotes))  args$footnotes  <- footnotes
    if (!is.null(extensions)) args$extensions <- extensions
    if (!is.null(width))      args$width      <- width

    # Route to the specific function
    func <- switch(fn_name,
      "markdown_html"  = commonmark::markdown_html,
      "markdown_latex" = commonmark::markdown_latex,
      "markdown_xml"   = commonmark::markdown_xml,
      "markdown_text"  = commonmark::markdown_text
    )
    
    out <- do.call(func, args)
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "list_extensions") {
    out <- commonmark::list_extensions()
    emit_ok(as.character(out), fn_name)
    
  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
