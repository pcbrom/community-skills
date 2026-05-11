#!/usr/bin/env Rscript
# later skill dispatcher.
# Reads one JSON object from stdin, invokes the requested later function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_later    <- requireNamespace("later",    quietly = TRUE)
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
      "The R package 'jsonlite' is required by the later skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_later) {
  emit_error(
    paste(
      "The R package 'later' is required but is not installed.",
      "Run: install.packages('later')."
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
  
  if (fn_name == "later") {
    func  <- require_field("func", payload, fn_name)
    delay <- as.numeric(require_field("delay", payload, fn_name))
    loop  <- if (is.null(payload$loop)) NULL else payload$loop
    
    # Note: later() returns NULL invisibly.
    out <- later::later(func = func, delay = delay, loop = loop)
    emit_ok(NULL, fn_name)
    
  } else if (fn_name == "later_fd") {
    func     <- require_field("func", payload, fn_name)
    readfds  <- as.integer(require_field("readfds", payload, fn_name))
    writefds <- as.integer(require_field("writefds", payload, fn_name))
    exceptfds <- as.integer(require_field("exceptfds", payload, fn_name))
    timeout  <- if (is.null(payload$timeout)) Inf else as.numeric(payload$timeout)
    loop     <- if (is.null(payload$loop)) NULL else payload$loop
    
    out <- later::later_fd(
      func = func, 
      readfds = readfds, 
      writefds = writefds, 
      exceptfds = exceptfds, 
      timeout = timeout, 
      loop = loop
    )
    emit_ok(NULL, fn_name)
    
  } else if (fn_name == "create_loop") {
    parent <- if (is.null(payload$parent)) NULL else payload$parent
    loop   <- require_field("loop", payload, fn_name)
    expr   <- require_field("expr", payload, fn_name)
    
    out <- later::create_loop(parent = parent, loop = loop, expr = expr)
    emit_ok(NULL, fn_name)
    
  } else if (fn_name == "loop_empty") {
    loop <- if (is.null(payload$loop)) NULL else payload$loop
    out <- later::loop_empty(loop = loop)
    emit_ok(as.logical(out), fn_name)
    
  } else if (fn_name == "run_now") {
    loop <- if (is.null(payload$loop)) NULL else payload$loop
    later::run_now(loop = loop)
    emit_ok(NULL, fn_name)
    
  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
