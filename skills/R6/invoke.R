#!/usr/bin/env Rscript
# R6 skill dispatcher.
# Reads one JSON object from stdin, invokes the requested R6 function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_R6       <- requireNamespace("R6",       quietly = TRUE)
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
      "The R package 'jsonlite' is required by the R6 skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_R6) {
  emit_error(
    paste(
      "The R package 'R6' is required but is not installed.",
      "Run: install.packages('R6')."
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
  
  if (fn_name == "R6Class") {
    classname <- as.character(require_field("classname", payload, fn_name))
    public    <- if (is.null(payload$public)) NULL else payload$public
    private   <- if (is.null(payload$private)) NULL else payload$private
    active    <- if (is.null(payload$active)) NULL else payload$active
    inherit   <- if (is.null(payload$inherit)) NULL else payload$as.character(payload$inherit)
    lock_objects <- if (is.null(payload$lock_objects)) NULL else as.logical(payload$lock_objects)
    class     <- if (is.null(payload$class)) NULL else as.logical(payload$class)
    portable  <- if (is.null(payload$portable)) NULL else as.logical(payload$portable)
    lock_class <- if (is.null(payload$lock_class)) NULL else as.logical(payload$lock_class)
    cloneable <- if (is.null(payload$cloneable)) NULL else as.logical(payload$cloneable)
    parent_env <- if (is.null(payload$parent_env)) NULL else payload$parent_env

    # R6Class constructor arguments
    res <- R6::R6Class(
      classname = classname,
      public = public,
      private = private,
      active = active,
      inherit = inherit,
      lock_objects = lock_objects,
      class = class,
      portable = portable,
      lock_class = lock_class,
      cloneable = cloneable,
      parent_env = parent_env
    )
    emit_ok(res, fn_name)

  } else if (fn_name == "is.R6") {
    x <- require_field("x", payload, fn_name)
    out <- is.R6(x)
    emit_ok(as.logical(out), fn_name)

  } else if (fn_name == "is.R6Class") {
    x <- require_field("x", payload, fn_name)
    out <- is.R6Class(x)
    emit_ok(as.logical(out), fn_name)

  } else if (fn_name == "as.list.R6") {
    x <- require_field("x", payload, fn_name)
    out <- as.list.R6(x)
    emit_ok(out, fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
