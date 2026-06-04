#!/usr/bin/env Rscript
# devtools skill dispatcher.
# Reads one JSON object from stdin, invokes the requested devtools function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_devtools <- requireNamespace("devtools",  quietly = TRUE)
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
      "The R package 'jsonlite' is required by the devtools skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_devtools) {
  emit_error(
    paste(
      "The R package 'devtools' is required but is not installed.",
      "Run: install.packages('devtools')."
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
  
  if (fn_name == "as.package") {
    x <- as.character(require_field("x", payload, fn_name))
    out <- devtools::as.package(x = x)
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "bash") {
    pkg <- as.character(require_field("pkg", payload, fn_name))
    out <- devtools::bash(pkg = pkg)
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "build") {
    pkg     <- as.character(require_field("pkg",     payload, fn_name))
    path    <- if (is.null(payload$path)) NULL else as.character(payload$path)
    binary  <- if (is.null(payload$binary)) FALSE else as.logical(payload$binary)
    vignettes <- if (is.null(payload$vignettes)) TRUE else as.logical(payload$vignettes)
    manual  <- if (is.null(payload$manual)) TRUE else as.logical(payload$manual)
    args    <- if (is.null(payload$args)) NULL else as.character(payload$args)
    quiet   <- if (is.null(payload$quiet)) TRUE else as.logical(payload$quiet)
    
    # Handle additional arguments via ...
    extra_args <- list()
    for (name in setdiff(names(payload), c("fn", "pkg", "path", "binary", "vignettes", "manual", "args", "quiet"))) {
      extra_args[[name]] <- payload[[name]]
    }

    out <- devtools::build(
      pkg = pkg, 
      path = path, 
      binary = binary, 
      vignettes = vignettes, 
      manual = manual, 
      args = args, 
      quiet = quiet,
      ... = extra_args
    )
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "build_manual") {
    pkg  <- as.character(require_field("pkg", payload, fn_name))
    path <- if (is.null(payload$path)) NULL else as.character(payload$path)
    out  <- devtools::build_manual(pkg = pkg, path = path)
    emit_ok(as.character(out), fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
