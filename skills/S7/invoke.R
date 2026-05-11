#!/usr/bin/env Rscript
# S7 skill dispatcher.
# Reads one JSON object from stdin, invokes the requested S7 function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_S7       <- requireNamespace("S7",       quietly = TRUE)
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
      "The R package 'jsonlite' is required by the S7 skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_S7) {
  emit_error(
    paste(
      "The R package 'S7' is required but is not installed.",
      "Run: install.packages('S7')."
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
  
  if (fn_name == "S4_register") {
    class_obj <- require_field("class", payload, fn_name)
    env_val   <- if (is.null(payload$env)) NULL else as.environment(payload$env)
    
    out <- S7::S4_register(class = class_obj, env = env_val)
    emit_ok(out, fn_name)

  } else if (fn_name == "S7_class") {
    object <- require_field("object", payload, fn_name)
    out <- S7::S7_class(object = object)
    emit_ok(out, fn_name)

  } else if (fn_name == "S7_data") {
    object <- require_field("object", payload, fn_name)
    check  <- if (is.null(payload$check)) NULL else isTRUE(payload$check)
    value  <- if (is.null(payload$value)) NULL else payload$value
    
    out <- S7::S7_data(object = object, check = check, value = value)
    emit_ok(out, fn_name)

  } else if (fn_name == "S7_inherits") {
    x      <- require_field("x", payload, fn_name)
    class_ <- require_field("class", payload, fn_name)
    arg    <- if (is.null(payload$arg)) NULL else as.character(payload$arg)
    
    out <- S7::S7_inherits(x = x, class = class_, arg = arg)
    emit_ok(out, fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
