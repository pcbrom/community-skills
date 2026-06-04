#!/usr/bin/env Rscript
# roxygen2 skill dispatcher.
# Reads one JSON object from stdin, invokes the requested roxygen2 function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_roxygen2 <- requireNamespace("roxygen2",  quietly = TRUE)
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
      "The R package 'jsonlite' is required by the roxygen2 skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_roxygen2) {
  emit_error(
    paste(
      "The R package 'roxygen2' is required but is not installed.",
      "Run: install.packages('roxygen2')."
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
  if (fn_name == "escape_examples") {
    text <- as.character(require_field("text", payload, fn_name))
    out <- roxygen2::escape_examples(text = text)
    emit_ok(as.character(out), fn_name)
  } else if (fn_name == "is_s3_generic") {
    name <- as.character(require_field("name", payload, fn_name))
    env  <- if (is.null(payload$env)) baseenv() else as.environment(payload$env)
    out <- roxygen2::is_s3_generic(name = name, env = env)
    emit_ok(as.logical(out), fn_name)
  } else if (fn_name == "load_options")
    {
    base_path <- as.character(require_field("base_path", payload, fn_name))
    key       <- as.character(require_field("key",       payload, fn_name))
    default   <- if (is.null(payload$default)) NULL else payload$default
    out <- roxygen2::load_options(base_path = base_path, key = key, default = default)
    emit_ok(out, fn_name)
  } else if (fn_name == "namespace_roclet") {
    package <- as.character(require_field("package", payload, fn_name))
    out <- roxygen2::namespace_roclet(package = package)
    emit_ok(as.logical(out), fn_name)
  } else if (fn_name == "roxygenize") {
    package <- as.character(require_field("package", payload, fn_name))
    out <- roxygen2::roxygenize(package = package)
    emit_ok(as.character(out), fn_name)
  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
