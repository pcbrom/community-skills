#!/usr/bin/env Rscript
# pkgbuild skill dispatcher.
# Reads one JSON object from stdin, invokes the requested pkgbuild function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_pkgbuild <- requireNamespace("pkgbuild",  quietly = TRUE)
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
      "The R package 'jsonlite' is required by the pkgbuild skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_pkgbuild) {
  emit_error(
    paste(
      "The R package 'pkgbuild' is required but is not installed.",
      "Run: install.packages('pkgbuild')."
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
  
  if (fn_name == "build") {
    path <- as.character(require_field("path", payload, fn_name))
    dest_path <- if (!is.null(payload$dest_path)) as.character(payload$dest_path) else NULL
    binary <- if (!is.null(payload$binary)) as.logical(payload$binary) else NULL
    vignettes <- if (!is.null(payload$vignettes)) as.logical(payload$vignettes) else NULL
    manual <- if (!is.null(payload$manual)) as.logical(payload$manual) else NULL
    clean_doc <- if (!is.null(payload$clean_doc)) as.logical(payload$clean_doc) else NULL
    args <- if (!is.null(payload$args)) as.character(payload$args) else NULL
    quiet <- if (!is.null(payload$quiet)) as.logical(payload$quiet) else NULL
    needs_compilation <- if (!is.null(payload$needs_compilation)) as.logical(payload$needs_compilation) else NULL
    compile_attributes <- if (!is.null(payload$compile_attributes)) as.logical(payload$compile_attributes) else NULL
    register_routines <- if (!is.null(payload$register_routines)) as.logical(payload$register_routines) else NULL

    res <- pkgbuild::build(
      path = path,
      dest_path = dest_path,
      binary = binary,
      vignettes = vignettes,
      manual = manual,
      clean_doc = clean_doc,
      args = args,
      quiet = quiet,
      needs_compilation = needs_compulation,
      compile_attributes = compile_attributes,
      register_routines = register_routines
    )
    emit_ok(as.character(res), fn_name)

  } else if (fn_name == "clean_dll") {
    path <- as.character(require_field("path", payload, fn_name))
    res <- pkgbuild::clean_dll(path = path)
    emit_ok(as.logical(res), fn_name)

  } else if (fn_name == "compile_dll") {
    path <- as.character(require_field("path", payload, fn_name))
    force <- if (!is.null(payload$force)) as.logical(payload$force) else NULL
    compile_attributes <- if (!is.null(payload$compile_attributes)) as.logical(payload$compile_attributes) else NULL
    register_routines <- if (!is.null(payload$register_routines)) as.logical(payload$register_routines) else NULL
    quiet <- if (!is.null(payload$quiet)) as.logical(payload$quiet) else NULL
    debug <- if (!is.null(payload$debug)) as.logical(payload$debug) else NULL

    res <- pkgbuild::compile_dll(
      path = path,
      force = force,
      compile_attributes = compile_attributes,
      register_routines = register_routines,
      quiet = quiet,
      debug = debug
    )
    emit_ok(as.logical(res), fn_name)

  } else if (fn_name == "compiler_flags") {
    debug <- if (!is.null(payload$debug)) as.logical(payload$debug) else NULL
    res <- pkgbuild::compiler_flags(debug = debug)
    emit_ok(as.character(res), fn_name)

  } else if (fn_name == "check_build_tools") {
    # Note: check_build_tools is in SKILL.md but not in UPSTREAM SIGNATURES.
    # However, it is a standard pkgbuild function.
    res <- pkgbuild::check_build_tools()
    emit_ok(as.logical(res), fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
