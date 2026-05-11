#!/usr/bin/env Rscript
# desc skill dispatcher.
# Reads one JSON object from stdin, invokes the requested desc function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_desc     <- requireNamespace("desc",     quietly = TRUE)
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
      "The R package 'jsonlite' is required by the desc skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_desc) {
  emit_error(
    paste(
      "The R package 'desc' is required but is not installed.",
      "Run: install.packages('desc')."
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
  
  if (fn_name == "desc_get") {
    path   <- as.character(require_field("path",   payload, fn_name))
    field  <- as.character(require_field("field",  payload, fn_name))
    out    <- desc::desc_get(file = path, field = field)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "desc_set") {
    path   <- as.character(require_field("path",   payload, fn_name))
    field  <- as.character(require_field("field",  payload, fn_name))
    value  <- as.character(require_field("value",  payload, fn_name))
    out    <- desc::desc_set(file = path, field = field, value = value)
    emit_ok(as.logical(out), fn_name)
    
  } else if (fn_name == "desc_add_dep") {
    path    <- as.character(require_field("path",    payload, fn_name))
    package <- as.character(require_field("package", payload, fn_name))
    type    <- as.character(require_field("type",    payload, fn_name))
    out     <- desc::desc_add_dep(file = path, package = package, type = type)
    emit_ok(as.logical(out), fn_name)
    
  } else if (fn_name == "desc_set_version") {
    path    <- as.character(require_field("path",    payload, fn_name))
    version <- as.character(require_field("version", payload, fn_name))
    out     <- desc::desc_set_version(file = path, version = version)
    emit_ok(as.logical(out), fn_name)
    
  } else if (fn_name == "check_field") {
    path   <- as.character(require_field("path",   payload, fn_name))
    field  <- as.character(require_field("field",  payload, fn_name))
    warn   <- if (is.null(payload$warn)) TRUE else isTRUE(payload$warn)
    out    <- desc::check_field(file = path, field = field, warn = warn)
    emit_ok(as.logical(out), fn_name)
    
  } else if (fn_name == "cran_ascii_fields") {
    path <- if (is.null(payload$path)) "DESCRIPTION" else as.character(payload$path)
    out  <- desc::cran_ascii_fields(file = path)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "cran_valid_fields") {
    path <- if (is.null(payload$path)) "DESCRIPTION" else as.character(payload$path)
    out  <- desc::cran_valid_fields(file = path)
    emit_ok(as.logical(out), fn_name)
    
  } else if (fn_name == "dep_types") {
    out <- desc::dep_types()
    emit_ok(as.character(out), fn_name)
    
  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
