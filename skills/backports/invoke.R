#!/usr/bin/env Rscript
# backports skill dispatcher.
# Reads one JSON object from stdin, invokes the requested backports function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_backports <- requireNamespace("backports", quietly = TRUE)
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
      "The R package 'jsonlite' is required by the backports skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_backports) {
  emit_error(
    paste(
      "The R package 'backports' is required but is not installed.",
      "Run: install.packages('backports')."
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
  
  if (fn_name == "import") {
    pkgname <- as.character(require_field("pkgname", payload, fn_name))
    obj     <- if (is.null(payload$obj)) NULL else as.character(payload$obj)
    force   <- if (is.null(payload$force)) FALSE else isTRUE(payload$force)
    
    out <- backports::import(pkgname = pkgname, obj = obj, force = force)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "R_user_dir") {
    package <- as.character(require_field("package", payload, fn_name))
    out <- backports::R_user_dir(package = package)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "URLencode") {
    x <- as.character(require_field("x", payload, fn_name))
    repeated <- if (is.null(payload$repeated)) FALSE else isTRUE(payload$repeated)
    out <- backports::URLencode(x = x, repeated = repeated)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "anyNA") {
    x <- as.numeric(require_field("x", payload, fn_name))
    out <- backports::anyNA(x = x)
    emit_ok(as.logical(out), fn_name)
    
  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
