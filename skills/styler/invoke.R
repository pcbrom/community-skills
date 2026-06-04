#!/usr/bin/env Rscript
# styler skill dispatcher.
# Reads one JSON object from stdin, invokes the requested styler function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_styler   <- requireNamespace("styler",   quietly = TRUE)
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
      "The R package 'jsonlite' is required by the styler skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_styler) {
  emit_error(
    paste(
      "The R package 'styler' is required but is not installed.",
      "Run: install.packages('styler')."
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
  
  if (fn_name == "style_text") {
    text <- as.character(require_field("text", payload, fn_name))
    out <- styler::style_text(text = text)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "style_file") {
    file <- as.character(require_field("file", payload, fn_name))
    out <- styler::style_file(file = file)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "style_pkg") {
    path <- as.character(require_field("path", payload, fn_name))
    out <- styler::style_pkg(path = path)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "cache_activate") {
    cache_name <- if (is.null(payload$cache_name)) NULL else as.character(payload$cache_name)
    verbose <- if (is.null(payload$verbose)) TRUE else as.logical(payload$verbose)
    out <- styler::cache_activate(cache_name = cache_name, verbose = verbose)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "cache_clear") {
    cache_name <- if (is.null(payload$cache_name)) NULL else as.character(payload$cache_name)
    ask <- if (is.null(payload$ask)) FALSE else as.logical(payload$ask)
    out <- styler::cache_clear(cache_name = cache_name, ask = ask)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "cache_info") {
    cache_name <- if (is.null(payload$cache_name)) NULL else as.character(payload$cache_name)
    format <- if (is.null(payload$format)) "lucid" else as.character(payload$format)
    out <- styler::cache_info(cache_name = cache_name, format = format)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "compute_parse_data_nested") {
    text <- as.character(require_field("text", payload, fn_name))
    transformers <- if (is.null(payload$transformers)) NULL else payload$transformers
    more_specs <- if (is.null(payload$more_specs)) NULL else payload$more_specs
    out <- styler::compute_parse_data_nested(text = text, transformers = transformers, more_specs = more_specs)
    emit_ok(out, fn_name)
    
  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
