#!/usr/bin/env Rscript
# bit64 skill dispatcher.
# Reads one JSON object from stdin, invokes the requested bit64 function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_bit64    <- requireNamespace("bit64",    quietly = TRUE)
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
      "The R package 'jsonlite' is required by the bit64 skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_bit64) {
  emit_error(
    paste(
      "The R package 'bit64' is required but is not installed.",
      "Run: install.packages('bit64')."
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
  
  if (fn_name == "as.character.integer64") {
    x <- as.character(require_field("x", payload, fn_name))
    # Note: ... and other args are passed via NextMethod in the upstream, 
    # but we only handle the explicit contract here.
    out <- bit64::as.character.integer64(x)
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "as.data.frame.integer64") {
    x <- as.character(require_field("x", payload, fn_name))
    # Convert input strings to integer64 first to respect the class requirement
    x_64 <- bit64::as.integer64(x)
    row_names <- if (!is.null(payload$row.names)) as.character(payload$row.names) else NULL
    
    # The function signature for as.data.frame.integer64 removes the class 
    # before calling as.data.frame, so we simulate the logic.
    df <- as.data.frame(x_64)
    if (!is.null(row_names)) rownames(df) <- row_names
    
    # Return as a list/object structure compatible with JSON
    emit_ok(list(x = as.character(x_64)), fn_name)

  } else if (fn_name == "as.integer64.character") {
    x <- as.character(require_field("x", payload, fn_name))
    keep_names <- if (is.null(payload$keep.names)) FALSE else isTRUE(payload$keep.names)
    # We use the character vector directly; bit64 handles the conversion.
    out <- bit64::as.integer64(x)
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "benchmark64") {
    nsmall <- as.integer(require_field("nsmall", payload, fn_name))
    nbig   <- as.integer(require_field("nbig",   payload, fn_name))
    what   <- as.character(require_field("what",  payload, fn_name))
    
    # Handle optional parameters
    uniorder <- if (is.null(payload$uniorder)) NULL else as.character(payload$uniorder)
    taborder <- if (is.null(payload$taborder)) NULL else as.character(payload$taborder)
    plot_flag <- if (is.null(payload$plot)) TRUE else isTRUE(payload$plot)
    
    # benchmark64 is a complex function; we execute the core logic.
    # Since we cannot easily pass R functions via JSON, we assume 'what' 
    # contains names of functions to benchmark.
    # For the purpose of this dispatcher, we execute the benchmark.
    res <- bit64::benchmark64(
      nsmall = nsmall, 
      nbig = nbig, 
      what = what,
      uniorder = uniorder,
      taborder = taborder,
      plot = plot_flag
    )
    emit_ok(as.numeric(res), fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
