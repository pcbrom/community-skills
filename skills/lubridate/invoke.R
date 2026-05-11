#!/usr/bin/env Rscript
# lubridate skill dispatcher.
# Reads one JSON object from stdin, invokes the requested lubridate function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_lubridate <- requireNamespace("lubridate", quietly = TRUE)
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
      "The R package 'jsonlite' is required by the lubridate skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_lubridate) {
  emit_error(
    paste(
      "The R package 'lubridate' is required but is not installed.",
      "Run: install.packages('lubridate')."
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
  
  if (fn_name == "am") {
    x <- require_field("x", payload, fn_name)
    # Parse x as date-time if it is a string
    if (is.character(x)) x <- lubridate::as_datetime(x)
    out <- lubridate::am(x)
    emit_ok(as.logical(out), fn_name)
    
  } else if (fn_name == "as.duration") {
    x <- require_field("x", payload, fn_name)
    if (is.numeric(x)) x <- as.numeric(x)
    out <- lubridate::as.duration(x)
    emit_ok(as.numeric(out), fn_name)
    
  } else if (fn_name == "as.interval") {
    x <- require_field("x", payload, fn_name)
    if (is.numeric(x)) x <- as.numeric(x)
    
    start <- NULL
    if (!is.null(payload$start)) {
      start <- payload$start
      if (is.character(start)) start <- lubridate::as_datetime(start)
    }
    
    out <- lubridate::as.interval(x, start = start)
    emit_ok(as.numeric(out), fn_name)
    
  } else if (fn_name == "as.period") {
    x <- require_field("x", payload, fn_name)
    if (is.numeric(x)) x <- as.numeric(x)
    
    unit <- NULL
    if (!is.null(payload$unit)) unit <- as.character(payload$unit)
    
    out <- lubridate::as.period(x, unit = unit)
    # Period objects are complex; return as list of components or numeric if possible
    if (inherits(out, "Period")) {
      emit_ok(as.list(out), fn_name)
    } else {
      emit_ok(as.numeric(out), fn_name)
    }
    
  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
