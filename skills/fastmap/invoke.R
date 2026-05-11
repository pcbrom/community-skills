#!/usr/bin/env Rscript
# fastmap skill dispatcher.
# Reads one JSON object from stdin, invokes the requested fastmap function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_fastmap  <- requireNamespace("fastmap",  quietly = TRUE)
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
      "The R package 'jsonlite' is required by the fastmap skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_fastmap) {
  emit_error(
    paste(
      "The R package 'fastmap' is required but is not installed.",
      "Run: install.packages('fastmap')."
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
  if (fn_name == "fastmap") {
    missing_default <- if (is.null(payload$missing_default)) NULL else payload$missing_default
    out <- fastmap::fastmap(missing_default = missing_default)
    emit_ok(out, fn_name)
  } else if (fn_name == "fastqueue") {
    init <- if (is.null(payload$init)) NULL else as.integer(payload$init)
    missing_default <- if (is.null(payload$missing_default)) NULL else payload$missing_default
    out <- fastmap::fastqueue(init = init, missing_default = missing_default)
    emit_ok(out, fn_name)
  } else if (fn_name == "faststack") {
    init <- if (is.null(payload$init)) NULL else as.integer(payload$init)
    missing_default <- if (is.null(payload$missing_default)) NULL else payload$missing_default
    out <- fastmap::faststack(init = init, missing_default = missing_default)
    emit_ok(out, fn_name)
  } else if (fn_name == "is.key_missing") {
    x <- payload$x
    out <- fastmap::is.key_missing(x = x)
    emit_ok(as.logical(out), fn_name)
  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
