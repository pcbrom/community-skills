#!/usr/bin/env Rscript
# quarto skill dispatcher.
# Reads one JSON object from stdin, invokes the requested quarto function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_quarto   <- requireNamespace("quarto",   quietly = TRUE)
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
      "The R package 'jsonlite' is required by the quarto skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_quarto) {
  emit_error(
    paste(
      "The R package 'quarto' is required but is not installed.",
      "Run: install.packages('quarto')."
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
  if (fn_name == "add_spin_preamble") {
    script  <- as.character(require_field("script", payload, fn_name))
    title   <- if (is.null(payload$title)) NULL else as.character(payload$title)
    preamble <- if (is.null(payload$preamble)) NULL else payload$preamble
    quiet   <- if (is.null(payload$quiet)) TRUE else as.logical(payload$quiet)
    
    out <- quarto::add_spin_preamble(script = script, title = title, 
                                     preamble = preamble, quiet = quiet)
    emit_ok(as.logical(out), fn_name)
  } else if (fn_name == "check_newer_version") {
    version <- if (is.null(payload$version)) NULL else as.character(payload$version)
    verbose <- if (is.null(payload$verbose)) TRUE else as.logical(payload$verbose)
    
    out <- quarto::check_newer_version(version = version, verbose = verbose)
    emit_ok(as.logical(out), fn_name)
  } else if (fn_name == "detect_bookdown_crossrefs") {
    path    <- if (is.null(payload$path)) "." else as.character(payload$path)
    verbose <- if (is.null(payload$verbose)) FALSE else as.logical(payload$verbose)
    
    out <- quarto::detect_bookdown_crossrefs(path = path, verbose = verbose)
    emit_ok(out, fn_name)
  } else if (fn_name == "find_project_root") {
    path <- if (is.null(payload$path)) "." else as.character(payload$path)
    
    out <- quarto::find_project_root(path = path)
    emit_ok(as.character(out), fn_name)
  } else if (fn_name == "quarto_render") {
    input        <- as.character(require_field("input", payload, fn_name))
    output_format <- if (is.null(payload$output_format)) NULL else as.character(payload$output_format)
    params        <- if (is.null(payload$params)) NULL else payload$params
    
    out <- quarto::quarto_render(input = input, output_format = output_format, params = params)
    emit_ok(as.logical(out), fn_name)
  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
