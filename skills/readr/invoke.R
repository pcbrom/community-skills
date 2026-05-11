#!/usr/bin/env Rscript
# readr skill dispatcher.
# Reads one JSON object from stdin, invokes the requested readr function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_readr    <- requireNamespace("readr",    quietly = TRUE)
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
      "The R package 'jsonlite' is required by the readr skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_readr) {
  emit_error(
    paste(
      "The R package 'readr' is required but is not installed.",
      "Run: install.packages('readr')."
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
  
  if (fn_name == "read_csv") {
    file <- as.character(require_field("file", payload, fn_name))
    out <- tryCatch(readr::read_csv(file = file), error = function(e) e)
    if (inherits(out, "error")) {
      emit_error(conditionMessage(out), fn_name)
    } else {
      emit_ok(out, fn_name)
    }
    
  } else if (fn_name == "read_tsv") {
    file <- as.character(require_field("file", payload, fn_name))
    out <- tryCatch(readr::read_tsv(file = file), error = function(e) e)
    if (inherits(out, "error")) {
      emit_error(conditionMessage(out), fn_name)
    } else {
      emit_ok(out, fn_name)
    }
    
  } else if (fn_name == "read_delim") {
    file  <- as.character(require_field("file", payload, fn_name))
    delim <- as.character(require_field("delim", payload, fn_name))
    out   <- tryCatch(readr::read_delim(file = file, delim = delim), error = function(e) e)
    if (inherits(out, "error")) {
      emit_error(conditionMessage(out), fn_name)
    } else {
      emit_ok(out, fn_name)
    }
    
  } else if (fn_name == "read_fwf") {
    file          <- as.character(require_field("file", payload, fn_name))
    col_positions <- as.character(require_field("col_positions", payload, fn_name))
    out           <- tryCatch(readr::read_fwf(file = file, col_positions = col_positions), error = function(e) e)
    if (inherits(out, "error")) {
      emit_error(conditionMessage(out), fn_name)
    } else {
      emit_ok(out, fn_name)
    }
    
  } else if (fn_name == "cols") {
    # Note: '...' is not directly accessible in a JSON payload as a named list of args.
    # We treat the 'spec' field as the collection of column definitions.
    spec_data <- require_field("spec", payload, fn_name)
    # In R, 'cols' uses dots. We map the 'spec' object keys to the dots.
    # Since we cannot easily reconstruct the ... call from a JSON object without 
    # knowing the names, we assume 'spec' contains the named arguments.
    out <- tryCatch(readr::cols(.default = spec_data), error = function(e) e)
    if (inherits(out, "error")) {
      emit_error(conditionMessage(out), fn_name)
    } else {
      emit_ok(out, fn_name)
    }
    
  } else if (fn_name == "as.col_spec") {
    x <- require_field("x", payload, fn_name)
    out <- tryCatch(readr::as_col_spec(x), error = function(e) e)
    if (inherits(out, "error")) {
      emit_error(conditionMessage(out), fn_name)
    } else {
      emit_ok(out, fn_name)
    }
    
  } else if (fn_name == "clipboard") {
    out <- tryCatch(readr::clipboard(), error = function(e) e)
    if (inherits(out, "error")) {
      emit_error(condition_message(out), fn_name)
    } else {
      emit_ok(out, fn_name)
    }
    
  } else if (fn_name == "col_skip") {
    # col_skip is an internal helper, but we expose it if requested.
    # It typically takes a vector of indices.
    indices <- as.integer(require_field("indices", payload, fn_name))
    out <- tryCatch(readr::col_skip(indices), error = function(e) e)
    if (inherits(out, "error")) {
      emit_error(conditionMessage(out), fn_name)
    } else {
      emit_ok(out, fn_name)
    }
    
  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
