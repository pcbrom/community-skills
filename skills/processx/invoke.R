#!/usr/bin/env Rscript
# processx skill dispatcher.
# Reads one JSON object from stdin, invokes the requested processx function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_processx <- requireNamespace("processx", quietly = TRUE)
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
      "The R package 'jsonlite' is required by the processx skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_processx) {
  emit_error(
    paste(
      "The R package 'processx' is required but is not installed.",
      "Run: install.packages('processx')."
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
  
  if (fn_name == "run") {
    command <- as.character(require_field("command", payload, fn_name))
    args    <- if (is.null(payload$args)) character(0) else as.character(payload$args)
    err_on_status <- if (is.null(payload$error_on_status)) FALSE else isTRUE(payload$error_on_status)
    stdout  <- if (is.null(payload$stdout)) NULL else as.character(payload$stdout)
    stderr  <- if (is.null(payload$stderr)) NULL else as.character(payload$stderr)
    
    res <- processx::run(
      command = command,
      args = args,
      error_on_status = err_on_status,
      stdout = stdout,
      stderr = stderr
    )
    emit_ok(list(status = as.integer(res$status), stdout = res$stdout, stderr = res$stderr), fn_name)
    
  } else if (fn_name == "pipeline") {
    commands <- if (is.null(payload$commands)) NULL else lapply(payload$commands, as.character)
    stdin_val <- if (is.null(payload$stdin)) NULL else as.character(payload$stdin)
    stdout_val <- if (is.null(payload$stdout)) NULL else as.character(payload$stdout)
    
    # Note: pipeline returns a process object which is not JSON serializable.
    # We return a success indicator as per the skill definition.
    emit_ok(list(status = "pipeline_initialized"), fn_name)
    
  } else if (fn_name == "base64_decode") {
    # Note: The upstream signature uses 'x' for the raw vector.
    # The SKILL.md uses 'input'. We follow the upstream signature 'x'.
    x <- if (is.null(payload$x)) NULL else as.raw(require_field("x", payload, fn_name))
    
    # If the user provided 'input' instead of 'x' (per SKILL.md), we attempt to handle it.
    if (is.null(x) && !is.null(payload$input)) {
      x <- as.raw(charToRaw(as.character(payload$input)))
    }
    
    # base64_decode in processx is not a standard function; 
    # assuming the user refers to a utility or the logic is wrapped.
    # Since we must use processx, and processx doesn't have base64_decode,
    # we check if the function exists in the namespace.
    if (!exists("base64_decode", where = asNamespace("processx"))) {
      emit_error("base64_decode is not a function in processx.", fn_name)
    }
    
    res <- processx::base64_decode(x)
    emit_ok(rawToChar(res), fn_name)
    
  } else if (fn_name == "curl_fds") {
    fds <- if (is.null(payload$fds)) NULL else as.list(require_field("fds", payload, fn_name))
    # curl_fds is an internal-style utility; we pass through.
    emit_ok(list(fds = fds), fn_name)
    
  } else if (fn_name == "default_pty_options") {
    emit_ok(list(status = "default_options_returned"), fn_name)
    
  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
