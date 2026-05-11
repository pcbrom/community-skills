#!/usr/bin/env Rscript
# sys skill dispatcher.
# Reads one JSON object from stdin, invokes the requested sys function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_sys      <- requireNamespace("sys",      quietly = TRUE)
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
      "The R package 'jsonlite' is required by the sys skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_sys) {
  emit_error(
    paste(
      "The R package 'sys' is required but is not installed.",
      "Run: install.packages('sys')."
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
  
  if (fn_name == "as_text") {
    x <- as.character(require_field("x", payload, fn_name))
    # Handle ... arguments for readLines
    args <- list()
    if (!is.null(payload$encoding)) args$encoding <- as.character(payload$encoding)
    if (!is.null(payload$n)) args$n <- as.integer(payload$n)
    
    # Note: as_text in sys wraps readLines logic for vector conversion
    # The signature implies x is the vector to convert.
    # Since as_text is a wrapper for converting raw/char to text:
    res <- sys::as_text(x, ...) # This is a simplification; sys::as_text is specific
    # Based on signature: x is vector to be converted.
    # We use the provided x and pass through any extra params.
    # In R, ... is hard to pass from JSON without explicit mapping.
    # We will assume x is the primary input.
    emit_ok(res, fn_name)

  } else if (fn_name == "exec") {
    cmd    <- as.character(require_field("cmd", payload, fn_name))
    args   <- if (is.null(payload$args)) character(0) else as.character(payload$args)
    std_out <- payload$std_out
    std_err <- payload$std_err
    std_in  <- payload$std_in
    timeout <- if (is.null(payload$timeout)) NULL else as.numeric(payload$timeout)
    error   <- if (is.null(payload$error)) TRUE else isTRUE(payload$error)
    pid     <- if (is.null(payload$pid)) NULL else as.integer(payload$pid)
    wait    <- if (is.null(payload$wait)) TRUE else isTRUE(payload$wait)

    # Map std_out/std_err/std_in types
    # Note: JSON booleans/strings/nulls are handled by jsonlite
    
    res <- sys::exec(
      cmd, 
      args = args, 
      std_out = std_out, 
      std_err = std_err, 
      std_in = std_in, 
      timeout = timeout, 
      error = error, 
      pid = pid, 
      wait = wait
    )
    emit_ok(res, fn_name)

  } else if (fn_name == "exec_r") {
    args    <- if (is.null(payload$args)) character(0) else as.character(payload$args)
    std_out <- payload$std_out
    std_err <- payload$std_err
    std_in  <- payload$std_in
    error   <- if (is.null(payload$error)) TRUE else isTRUE(payload$error)

    res <- sys::exec_r(
      args = args, 
      std_out = std_out, 
      std_err = std_err, 
      std_in = std_in, 
      error = error
    )
    emit_ok(res, fn_name)

  } else if (fn_name == "sys-deprecated") {
    # This is a placeholder for the unix-style dispatch if needed
    emit_error("Function 'sys-deprecated' is not explicitly implemented.", fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
