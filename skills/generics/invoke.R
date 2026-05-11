#!/usr/bin/env Rscript
# generics skill dispatcher.
# Reads one JSON object from stdin, invokes the requested generics function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_generics <- requireNamespace("generics", quietly = TRUE)
})

emit_error <- function(message_text, fn_name = NA_character_, code = 1L) {
  payload <- list(ok = FALSE, error = unname(message_text))
  if (!is.na(fn_name)) payload$fn <- fn_name
  sink(NULL, type = "output")  # restore stdout before writing the final JSON
  if (ok_jsonlite) {
    cat(jsonlite::toJSON(payload, auto_unbox = TRUE, na = "null"))
  } else {
    cat(sprintf('{"ok":false,"error":%s}',
                shQuote(message, type = "cmd")))
  }
  cat("\n")
  quit(status = code, save = "no")
}

if (!ok_jsonlite) {
  emit_error(
    paste(
      "The R package 'jsonlite' is required by the generics skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_generics) {
  emit_error(
    paste(
      "The R package 'generics' is required but is not installed.",
      "Run: install.packages('generics')."
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
  
  if (fn_name == "accuracy") {
    object <- require_field("object", payload, fn_name)
    # Pass remaining arguments via ...
    args <- payload[setdiff(names(payload), c("fn", "object"))]
    out <- generics::accuracy(object = object, ...)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "augment") {
    x <- require_field("x", payload, fn_name)
    # Note: Upstream signature uses x, but SKILL.md mentions data. 
    # We follow the UPSTREAM SIGNATURES block: x is the key.
    args <- payload[setdiff(names(payload), c("fn", "x"))]
    out <- generics::augment(x = x, ...)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "calculate") {
    x <- require_field("x", payload, fn_name)
    args <- payload[setdiff(names(payload), c("fn", "x"))]
    out <- generics::calculate(x = x, ...)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "compile") {
    object <- require_field("object", payload, fn_name)
    args <- payload[setdiff(names(payload), c("fn", "object"))]
    out <- generics::compile(object = object, ...)
    emit_ok(out, fn_name)
    
  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

# Wrapper for dispatch to handle errors from the wrapped functions
err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
