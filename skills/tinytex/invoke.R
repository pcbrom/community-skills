#!/usr/bin/env Rscript
# tinytex skill dispatcher.
# Reads one JSON object from stdin, invokes the requested tinytex function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_tinytex  <- requireNamespace("tinytex",  quietly = TRUE)
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
      "The R package 'jsonlite' is required by the tinytex skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_tinytex) {
  emit_error(
    paste(
      "The R package 'tinytex' is required but is not installed.",
      "Run: install.packages('tinytex')."
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
  if (fn_name == "check_installed") {
    pkgs <- as.character(require_field("pkgs", payload, fn_name))
    out <- tinytex::check_installed(pkgs = pkgs)
    emit_ok(as.logical(out), fn_name)
  } else if (fn_name == "copy_tinytex") {
    from <- as.character(require_field("from", payload, fn_name))
    to   <- if (is.null(payload$to)) NULL else as.character(payload$to)
    move <- if (is.null(payload$move)) FALSE else isTRUE(payload$move)
    out <- tinytex::copy_tinytex(from = from, to = to, move = move)
    emit_ok(as.logical(out), fn_name)
  } else if (fn_name == "install_tinytex") {
    force       <- if (is.null(payload$force)) FALSE else isTRUE(payload$force)
    dir         <- if (is.null(payload$dir)) NULL else as.character(payload$dir)
    version     <- if (is.null(payload$version)) NULL else as.character(payload$version)
    bundle      <- if (is.null(payload$bundle)) NULL else as.character(payload$bundle)
    repository  <- if (is.null(payload$repository)) NULL else as.character(payload$repository)
    extra_packages <- if (is.null(payload$extra_packages)) NULL else as.character(payload$extra_packages)
    add_path    <- if (is.null(payload$add_path)) FALSE else isTRUE(payload$add_path)
    packages    <- if (is.null(payload$packages)) FALSE else isTRUE(payload$packages)
    error       <- if (is.null(payload$error)) FALSE else isTRUE(payload$error)
    
    # Note: ... arguments are not explicitly mapped from JSON keys here 
    # as the JSON structure for '...' is undefined in the contract.
    
    out <- tinytex::install_tinytex(
      force = force, dir = dir, version = version, bundle = bundle,
      repository = repository, extra_packages = extra_packages,
      add_path = add_path, packages = packages, error = error
    )
    emit_ok(as.logical(out), fn_name)
  } else if (fn_name == "is_tinytex") {
    out <- tinytex::is_tinytex()
    emit_ok(as.logical(out), fn_name)
  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
