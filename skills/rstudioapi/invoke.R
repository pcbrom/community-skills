#!/usr/bin/env Rscript
# rstudioapi skill dispatcher.
# Reads one JSON object from stdin, invokes the requested rstudioapi function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_rstudioapi <- requireNamespace("rstudioapi", quietly = TRUE)
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
      "The R package 'jsonlite' is required by the rstudioapi skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_rstudioapi) {
  emit_error(
    paste(
      "The R package 'rstudioapi' is required but is not installed.",
      "Run: install.packages('rstudioapi')."
    )
  )
}

stdin_text <- paste(readLines("stdin", warn = FALSE), collapse = "\and")
# Note: Using a small hack for stdin reading if readLines fails on empty
if (length(stdin_text) == 0 || !nzchar(stdin_text)) {
  # Check if stdin is actually empty
  stdin_text <- tryCatch(paste(readLines("stdin", warn = FALSE), collapse = "\n"), error = function(e) "")
}

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
  
  if (fn_name == "addTheme") {
    themePath <- as.character(require_field("themePath", payload, fn_name))
    apply     <- if (is.null(payload$apply)) FALSE else isTRUE(payload$apply)
    force     <- if (is.null(payload$force)) FALSE else isTRUE(payload$force)
    globally  <- if (is.null(payload$globally)) FALSE else isTRUE(payload$globally)
    
    res <- tryCatch({
      rstudioapi::addTheme(themePath = themePath, apply = apply, force = force, globally = globally)
      # addTheme returns NULL or error; if apply was TRUE, the side effect happens.
      # We return the path as a confirmation of the operation.
      themePath
    }, error = function(e) e)
    
    if (inherits(res, "error")) stop(conditionMessage(res))
    emit_ok(as.character(res), fn_name)

  } else if (fn_name == "applyTheme") {
    name <- as.character(require_field("name", payload, fn_name))
    res <- tryCatch({
      rstudioapi::applyTheme(name = name)
    }, error = function(e) e)
    
    if (inherits(res, "error")) stop(conditionMessage(res))
    emit_ok(as.logical(res), fn_name)

  } else if (fn_name == "askForPassword") {
    prompt <- as.character(require_field("prompt", payload, fn_name))
    res <- tryCatch({
      rstudioapi::askForPassword(prompt = prompt)
    }, error = function(e) e)
    
    if (inherits(res, "error")) stop(conditionMessage(res))
    emit_ok(as.character(res), fn_name)

  } else if (fn_name == "askForSecret") {
    name    <- as.character(require_field("name", payload, fn_name))
    message <- as.character(require_field("message", payload, fn_name))
    title   <- as.character(require_field("title", payload, fn_name))
    res <- tryCatch({
      rstudioapi::askForSecret(name = name, message = message, title = title)
    }, error = function(e) e)
    
    if (inherits(res, "error")) stop(conditionMessage(res))
    emit_ok(as.character(res), fn_name)

  } else if (fn_name == "isAvailable") {
    res <- rstudioapi::isAvailable()
    emit_ok(as.logical(res), fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  # Re-fetch fn_name from payload if possible for the error report
  fn_err <- if (!is.null(payload$fn)) payload$fn else NA_character_
  emit_error(conditionMessage(err), fn_err)
}
