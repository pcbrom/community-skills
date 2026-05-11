#!/usr/bin/env Rscript
# bit skill dispatcher.
# Reads one JSON object from stdin, invokes the requested bit function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_bit      <- requireNamespace("bit",      quietly = TRUE)
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
      "The R package 'jsonlite' is required by the bit skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_bit) {
  emit_error(
    paste(
      "The R package 'bit' is required but is not installed.",
      "Run: install.packages('bit')."
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
  
  if (fn_name == "as.bit") {
    x <- as.numeric(require_field("x", payload, fn_name))
    # Handle length argument if provided
    args <- list(x = x)
    if (!is.null(payload$length)) args$length <- as.integer(payload$length)
    
    out <- do.call(bit::as.bit, args)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "as.bitwhich") {
    x <- as.numeric(require_field("x", payload, fn_name))
    args <- list(x = x)
    if (!is.null(payload$maxindex)) args$maxindex <- as.integer(payload$maxindex)
    if (!is.null(payload$poslength)) args$poslength <- as.integer(payload$poslength)
    if (!is.null(payload$range)) args$range <- as.numeric(payload$range)
    
    out <- do.call(bit::as.bitwhich, args)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "as.booltype") {
    x <- as.numeric(require_field("x", payload, fn_name))
    booltype <- if (is.null(payload$booltype)) NULL else as.character(payload$booltype)
    
    args <- list(x = x)
    if (!is.null(booltype)) args$booltype <- booltype
    
    out <- do.call(bit::as.booltype, args)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "as.ri") {
    x <- as.numeric(require_field("x", payload, fn_name))
    args <- list(x = x)
    
    out <- do.call(bit::as.ri, args)
    emit_ok(out, fn_name)
    
  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
