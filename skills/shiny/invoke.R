#!/usr/bin/env Rscript
# shiny skill dispatcher.
# Reads one JSON object from stdin, invokes the requested shiny function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output (e.g. package banners) to stderr so the only
# thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_shiny    <- requireNamespace("shiny",    quietly = TRUE)
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
      "The R package 'jsonlite' is required by the shiny skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_shiny) {
  emit_error(
    paste(
      "The R package 'shiny' is required but is not installed.",
      "Run: install.packages('shiny')."
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
  if (fn_name == "ExtendedTask") {
    expr <- require_field("expr", payload, fn_name)
    # expr is expected to be a function or a string representing a function
    out <- tryCatch({
      if (is.character(expr)) eval(parse(text = expr)) else expr
    }, error = function(e) stop(conditionMessage(e)))
    emit_ok(out, fn_name)
  } else if (fn_name == "MockShinySession") {
    args <- require_field("args", payload, fn_name)
    # args is a list of arguments for the constructor
    out <- tryCatch({
      do.call(shiny::MockShinySession, args)
    }, error = function(e) stop(conditionMessage(e)))
    emit_ok(out, fn_name)
  } else if (fn_name == "NS") {
    namespace <- as.character(require_field("namespace", payload, fn_name))
    id <- if (is.null(payload$id)) NULL else as.character(payload$id)
    out <- shiny::NS(namespace = namespace, id = id)
    emit_ok(out, fn_name)
  } else if (fn_name == "Progress") {
    session <- require_field("session", payload, fn_name)
    min_val <- as.numeric(require_field("min", payload, fn_name))
    max_val <- as.numeric(require_field("max", payload, fn_name))
    out <- shiny::Progress$new(session = session, min = min_val, max = max_val)
    emit_ok(out, fn_name)
  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
