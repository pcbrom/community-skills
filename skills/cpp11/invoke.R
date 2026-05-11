#!/usr/bin/env Rscript
# cpp11 skill dispatcher.
# Reads one JSON object from stdin, invokes the requested cpp11 function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_cpp11    <- requireNamespace("cpp11",    quietly = TRUE)
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
      "The R package 'jsonlite' is required by the cpp11 skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_cpp11) {
  emit_error(
    paste(
      "The R package 'cpp11' is required but is not installed.",
      "Run: install.packages('cpp11')."
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
  
  if (fn_name == "cpp_register") {
    path      <- as.character(require_field("path", payload, fn_name))
    quiet     <- if (is.null(payload$quiet)) TRUE else isTRUE(payload$quiet)
    extension <- if (is.null(payload$extension)) ".cpp" else as.character(payload$extension)
    
    out <- cpp11::cpp_register(path = path, quiet = quiet, extension = extension)
    emit_ok(out, fn_name)

  } else if (fn_name == "cpp_source") {
    file      <- if (is.null(payload$file)) NULL else as.character(payload$file)
    code      <- if (is.null(payload$code)) NULL else as.character(payload$code)
    env       <- if (is.null(payload$env)) NULL else as.environment(payload$env)
    clean     <- if (is.null(payload$clean)) TRUE else isTRUE(payload$clean)
    quiet     <- if (is.null(payload$quiet)) TRUE else isTRUE(payload$quiet)
    cxx_std   <- if (is.null(payload$cxx_std)) NULL else as.character(payload$cxx_std)
    dir       <- if (is.null(payload$dir)) NULL else as.character(payload$dir)
    
    # Note: cpp_source handles file/code logic internally. 
    # We pass arguments as provided in the upstream signature.
    out <- cpp11::cpp_source(
      file = file, 
      code = code, 
      env = env, 
      clean = clean, 
      quiet = quiet, 
      cxx_std = cxx_std, 
      dir = dir
    )
    emit_ok(out, fn_name)

  } else if (fn_name == "cpp_vendor") {
    path <- as.character(require_field("path", payload, fn_name))
    out <- cpp11::cpp_vendor(path = path)
    emit_ok(out, fn_name)

  } else if (fn_name == "cpp_eval") {
    code <- as.character(require_field("code", payload, fn_name))
    out <- cpp11::cpp_eval(code = code)
    emit_ok(out, fn_name)

  } else if (fn_name == "cpp_function") {
    code <- as.character(require_field("code", payload, fn_name))
    out <- cpp11::cpp_function(code = code)
    emit_ok(out, fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
