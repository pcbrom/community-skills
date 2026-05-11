#!/usr/bin/env Rscript
# base64enc skill dispatcher.
# Reads one JSON object from stdin, invokes the requested base64enc function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_base64enc <- requireNamespace("base64enc", quietly = TRUE)
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
      "The R package 'jsonlite' is required by the base64enc skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_base64enc) {
  emit_error(
    paste(
      "The R package 'base64enc' is required but is not installed.",
      "Run: install.packages('base64enc')."
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
  
  if (fn_name == "base64encode") {
    # Upstream: what, linewidth, newline, output, file
    # Note: SKILL.md uses 'x' but upstream uses 'what'
    what <- if (is.null(payload$what)) payload$x else payload$what
    if (is.null(what)) emit_error("Field `what` (or `x`) is required.", fn_name)
    
    # Coerce input
    if (is.numeric(what)) what <- as.raw(as.integer(what))
    if (is.character(what) && length(what) > 1) what <- paste(what, collapse = "\n")
    
    args <- list(what = what)
    if (!is.null(payload$linewidth)) args$linewidth <- as.integer(payload$linewidth)
    if (!is.null(payload$newline)) args$newline <- as.character(payload$newline)
    if (!is.null(payload$output)) args$output <- payload$output
    if (!is.null(payload$file)) args$file <- as.character(payload$file)
    
    res <- tryCatch(do.call(base64enc::base64encode, args), error = function(e) e)
    if (inherits(res, "error")) emit_error(conditionMessage(res), fn_name)
    emit_ok(as.character(res), fn_name)

  } else if (fn_name == "base64decode") {
    # Upstream: what, linewidth, newline, output, file, strict
    what <- if (is.null(payload$what)) payload$input else payload$what
    if (is.null(what)) emit_error("Field `what` (or `input`) is required.", fn_name)
    
    args <- list(what = what)
    if (!is.null(payload$linewidth)) args$linewidth <- as.integer(payload$linewidth)
    if (!is.null(payload$newline)) args$newline <- as.character(payload$newline)
    if (!is.null(payload$output)) args$output <- payload$output
    if (!is.null(payload$file)) args$file <- as.character(payload$file)
    if (!is.null(payload$strict)) args$strict <- as.logical(payload$strict)
    
    res <- tryCatch(do.call(base64enc::base64decode, args), error = function(e) e)
    if (inherits(res, "error")) emit_error(condition, fn_name)
    # Convert raw to numeric array for JSON compatibility
    emit_ok(as.numeric(as.integer(res)), fn_name)

  } else if (fn_name == "dataURI") {
    # Upstream: data, mime, encoding, file
    data_val <- if (is.null(payload$data)) payload$x else payload$data
    if (is.null(data_val) && is.null(payload$file)) {
      emit_error("Either `data` (or `x`) or `file` must be provided.", fn_name)
    }
    
    args <- list()
    if (!is.null(data_val)) {
      if (is.numeric(data_val)) data_val <- as.raw(as.integer(data_val))
      args$data <- data_val
    }
    if (!is.null(payload$mime)) args$mime <- as.character(payload$mime)
    if (!is.null(payload$encoding)) {
      args$encoding <- payload$encoding
      if (args$encoding == "base64") args$encoding <- "base64" else args$encoding <- NULL
    }
    if (!is.null(payload$file)) args$file <- as.character(payload$file)
    
    res <- tryCatch(do.call(base64enc::dataURI, args), error = function(e) e)
    if (inherits(res, "error")) emit_error(conditionMessage(res), fn_name)
    emit_ok(as.character(res), fn_name)

  } else if (fn_name == "checkUTF8") {
    # Upstream: what, quiet, charlen, min.char
    what <- if (is.null(payload$what)) payload$x else payload$what
    if (is.null(what)) emit_error("Field `what` (or `x`) is required.", fn_name)
    if (is.numeric(what)) what <- as.raw(as.integer(what))
    
    args <- list(what = what)
    if (!is.null(payload$quiet)) args$quiet <- as.logical(payload$quiet)
    if (!is.null(payload$charlen)) args$charlen <- as.logical(payload$charlen)
    if (!is.null(payload$min.char)) args$min.char <- as.integer(payload$min.char)
    
    res <- tryCatch(do.call(base64enc::checkUTF8, args), error = function(e) e)
    if (inherits(res, "error")) emit_error(conditionMessage(res), fn_name)
    emit_ok(as.logical(res), fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
