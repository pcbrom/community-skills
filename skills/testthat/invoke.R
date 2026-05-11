#!/usr/bin/env Rscript
# testthat skill dispatcher.
# Reads one JSON object from stdin, invokes the requested testthat function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_testthat <- requireNamespace("testthat",  quietly = TRUE)
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
      "The R package 'jsonlite' is required by the testthat skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_testthat) {
  emit_error(
    paste(
      "The R package 'testthat' is required but is not installed.",
      "Run: install.packages('testthat')."
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
  
  if (fn_name == "CheckReporter") {
    reporter <- require_field("reporter", payload, fn_name)
    # CheckReporter has no arguments in upstream signature
    out <- testthat::CheckReporter(reporter = reporter)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "DebugReporter") {
    reporter <- require_field("reporter", payload, fn_name)
    out <- testthat::DebugReporter(reporter = reporter)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "FailReporter") {
    reporter <- require_field("reporter", payload, fn_name)
    out <- testthat::FailReporter(reporter = reporter)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "JunitReporter") {
    reporter <- require_field("reporter", payload, fn_name)
    out <- testthat::JunitReporter(reporter = reporter)
    emit_ok(as.character(out), fn_name)
    
  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
