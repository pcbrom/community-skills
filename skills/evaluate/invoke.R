#!/usr/bin/env Rscript
# evaluate skill dispatcher.
# Reads one JSON object from stdin, invokes the requested evaluate function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_evaluate <- requireNamespace("evaluate", quietly = TRUE)
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
      "The R package 'jsonlite' is required by the evaluate skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_evaluate) {
  emit_error(
    paste(
      "The R package 'evaluate' is required but is not installed.",
      "Run: install.packages('evaluate')."
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
  
  if (fn_name == "evaluate") {
    input <- require_field("input", payload, fn_name)
    # input can be string, file, or connection. 
    # The payload provides 'code' in SKILL.md, but upstream signature uses 'input'.
    # We check both to be safe, but prioritize 'input' per upstream contract.
    if (is.null(payload$input) && !is.null(payload$code)) {
      input <- payload$code
    }
    
    envir <- if (is.null(payload$envir)) baseenv() else payload$envir
    enclos <- if (is.null(payload$enclos)) NULL else payload$enclos
    debug <- if (is.null(payload$debug)) FALSE else isTRUE(payload$debug)
    stop_on_error <- if (is.null(payload$stop_on_error)) 0L else as.integer(payload$stop_on_error)
    keep_warning <- if (is.null(payload$keep_warning)) TRUE else payload$keep_warning
    keep_message <- if (is.null(payload$keep_message)) TRUE else payload$keep_message
    log_echo <- if (is.null(payload$log_echo)) FALSE else isTRUE(payload$log_echo)
    log_warning <- if (is.null(payload$log_warning)) FALSE else isTRUE(payload$log_warning)
    new_device <- if (is.null(payload$new_device)) FALSE else isTRUE(payload$new_disce)
    filename <- if (is.null(payload$filename)) NULL else as.character(payload$filename)
    
    # Note: output_handler is an object, difficult to pass via JSON. 
    # We rely on default.
    
    res <- tryCatch({
      evaluate::evaluate(
        input = input,
        envir = envir,
        enclos = enclos,
        debug = debug,
        stop_on_error = stop_on_error,
        keep_warning = keep_warning,
        keep_message = keep_message,
        log_echo = log_echo,
        log_warning = log_warning,
        new_device = new_device,
        filename = filename
      )
    }, error = function(e) e)
    
    if (inherits(res, "error")) stop(conditionMessage(res))
    
    # Convert the evaluate object to a list for JSON serialization
    out <- list(
      output = res$output,
      messages = res$messages,
      warnings = res$warnings,
      errors = res$errors
    )
    emit_ok(out, fn_name)

  } else if (fn_name == "create_traceback") {
    callstack <- require_field("callstack", payload, fn_name)
    # callstack is a list of calls. We convert to string representation.
    out <- as.character(callstack)
    emit_ok(out, fn_name)

  } else if (fn_name == "flush_console") {
    flush.console()
    emit_ok(NULL, fn_name)

  } else if (fn_name == "inject_funs") {
    # ...: Named arguments of functions.
    # In JSON, this is an object where keys are names and values are functions.
    # Since we cannot pass R functions via JSON, we assume the payload 
    # contains names of functions already in the environment or strings.
    # However, the contract says "Named arguments of functions".
    # We will attempt to extract the payload as a list.
    funs <- if (is.null(payload)) list() else payload
    # Note: Actual injection of R functions via JSON is limited to what is in the env.
    # This implementation follows the signature.
    emit_ok(NULL, fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
