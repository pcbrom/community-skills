#!/usr/bin/env Rscript
# pkgdown skill dispatcher.
# Reads one JSON object from stdin, invokes the requested pkgdown function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_pkgdown  <- requireNamespace("pkgdown",  quietly = TRUE)
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
      "The R package 'jsonlite' is required by the pkgdown skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_pkgdown) {
  emit_error(
    paste(
      "The R package 'pkgdown' is required but is not installed.",
      "Run: install.packages('pkgdown')."
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
  if (fn_name == "as_pkgdown") {
    pkg <- as.character(require_field("pkg", payload, fn_name))
    override <- payload$override
    out <- pkgdown::as_pkgdown(pkg = pkg, override = override)
    emit_ok(out, fn_name)
  } else if (fn_name == "build_articles") {
    pkg <- as.character(require_field("pkg", payload, fn_name))
    quiet <- if (is.null(payload$quiet)) TRUE else as.logical(payload$quiet)
    lazy <- if (is.null(payload$lazy)) FALSE else as.logical(payload$lazy)
    seed <- if (is.null(payload$seed)) NULL else as.integer(payload$seed)
    override <- payload$override
    preview <- if (is.null(payload$preview)) FALSE else as.logical(payload$preview)
    name <- if (is.null(payload$name)) NULL else as.character(payload$name)
    new_process <- if (is.null(payload$new_process)) TRUE else as.logical(payload$new_process)
    pandoc_args <- if (is.null(payload$pandoc_args)) NULL else as.character(payload$pandoc_args)
    
    out <- pkgdown::build_articles(
      pkg = pkg,
      quiet = quiet,
      lazy = lazy,
      seed = seed,
      override = override,
      preview = preview,
      name = name,
      new_process = new_process,
      pandoc_args = pandoc_args
    )
    emit_ok(out, fn_name)
  } else if (fn_name == "build_favicons") {
    pkg <- as.character(require_field("pkg", payload, fn_name))
    overwrite <- if (is.null(payload$overwrite)) FALSE else as.logical(payload$overwrite)
    out <- pkgdown::build_favicons(pkg = pkg, overwrite = overwrite)
    emit_ok(out, fn_name)
  } else if (fn_name == "build_home") {
    pkg <- as.character(require_field("pkg", payload, fn_name))
    override <- payload$override
    preview <- if (is.null(payload$preview)) FALSE else as.logical(payload$preview)
    quiet <- if (is.null(payload$quiet)) TRUE else as.logical(payload$quiet)
    
    out <- pkgdown::build_home(
      pkg = pkg,
      override = override,
      preview = preview,
      quiet = quiet
    )
    emit_ok(out, fn_name)
  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
