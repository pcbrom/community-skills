#!/usr/bin/env Rscript
# rlang skill dispatcher.
# Reads one JSON object from stdin, invokes the requested rlang function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_rlang    <- requireNamespace("rlang",    quietly = TRUE)
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
      "The R package 'jsonlite' is required by the rlang skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_rlang) {
  emit_error(
    paste(
      "The R package 'rlang' is required but is not installed.",
      "Run: install.packages('rlang')."
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
  
  if (fn_name == "abort") {
    message <- as.character(require_field("message", payload, fn_name))
    
    # Extract optional arguments from the payload
    # Note: '...' in JSON is represented by the extra keys in the payload
    args <- list(message = message)
    
    # Map specific known arguments from the upstream signature
    if (!is.null(payload$class)) args$class <- as.character(payload$class)
    if (!is.null(payload$call)) args$call <- payload$call
    if (!is.null(payload$body)) args$body <- payload$body
    if (!is.null(payload$footer)) args$footer <- payload$footer
    if (!is.null(payload$trace)) args$trace <- payload$trace
    if (!is.null(payload$parent)) args$parent <- payload$parent
    if (!is.null(payload$use_cli_format)) args$use_cli_format <- as.logical(payload$use_cli_format)
    if (!is.null(payload$.inherit)) args$.inherit <- as.logical(payload$.inherit)
    if (!is.null(payload$.internal)) args$.internal <- as.logical(payload$.internal)
    if (!is.null(payload$.file)) args$.file <- as.character(payload$.file)
    if (!is.null(payload$.frame)) args$.frame <- payload$.frame
    if (!is.null(payload$.trace_bottom)) args$.trace_bottom <- payload$.trace_bottom
    if (!is.null(payload$.subclass)) args$.subclass <- payload$.subclass
    if (!is.null(payload$.frequency)) args$.frequency <- as.character(payload$.frequency)
    if (!is.null(payload$.frequency_id)) args$.frequency_id <- as.character(payload$.frequency_id)
    if (!is.null(payload$id)) args$id <- as.character(payload$id)

    # We use do.call to pass the constructed list as arguments
    # rlang::abort is a function call that signals a condition
    tryCatch({
      do.call(rlang::abort, args)
      emit_ok(NULL, fn_name)
    }, error = function(e) {
      # If abort succeeds, it usually stops execution, but if it's caught:
      emit_error(conditionMessage(e), fn_name)
    })

  } else if (fn_name == "are_na") {
    x <- as.numeric(require_field("x", payload, fn_name))
    out <- is.na(x)
    emit_ok(as.numeric(out), fn_name)

  } else if (fn_name == "arg_match") {
    arg <- as.character(require_field("arg", payload, fn_name))
    values <- as.character(require_field("values", payload, fn_name))
    
    # Handle optional arguments
    error_arg <- if (!is.null(payload$error_arg)) as.character(payload$error_arg) else NULL
    error_call <- if (!is.null(payload$error_call)) payload$error_call else NULL
    arg_nm <- if (!is.null(payload$arg_nm)) as.character(payload$arg_nm) else NULL
    multiple <- if (!is.null(payload$multiple)) as.logical(payload$multiple) else NULL

    # Construct argument list for rlang::arg_match
    args <- list(arg = arg, values = values)
    if (!is.null(error_arg)) args$error_arg <- error_arg
    if (!is.null(error_call)) args$error_call <- error_call
    if (!is.null(arg_nm)) args$arg_nm <- arg_nm
    if (!is.null(multiple)) args$multiple <- multiple
    
    out <- do.call(rlang::arg_match, args)
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "arg_match0") {
    arg <- as.character(require_field("arg", payload, fn_name))
    values <- as.character(require_field("values", payload, fn_name))
    
    # arg_match0 is not in the provided signature list but is in SKILL.md
    # We follow the pattern of the provided signatures.
    out <- rlang::arg_match0(arg, values)
    emit_ok(as.character(out), fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
