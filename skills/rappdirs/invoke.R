#!/usr/bin/env Rscript
# rappdirs skill dispatcher.
# Reads one JSON object from stdin, invokes the requested rappdirs function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_rappdirs <- requireNamespace("rappdirs", quietly = TRUE)
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
      "The R package 'jsonlite' is required by the rappdirs skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_rappdirs) {
  emit_error(
    paste(
      "The R package 'rappdirs' is required but is not installed.",
      "Run: install.packages('rappdirs')."
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
  
  if (fn_name == "app_dir") {
    appname <- if (is.null(payload$appname)) NULL else as.character(payload$appname)
    appauthor <- if (is.null(payload$appauthor)) NULL else as.character(payload$appauthor)
    version <- if (is.null(payload$version)) NULL else as.character(payload$version)
    expand <- if (is.null(payload$expand)) TRUE else as.logical(payload$expand)
    os <- if (is.null(payload$os)) NULL else as.character(payload$os)
    
    out <- rappdirs::app_dir(appname = appname, appauthor = appauthor, 
                             version = version, expand = expand, os = os)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "site_data_dir") {
    appname <- if (is.null(payload$appname)) NULL else as.character(payload$appname)
    appauthor <- if (is.null(payload$appauthor)) NULL else as.character(payload$appauthor)
    version <- if (is.null(payload$version)) NULL else as.character(payload$version)
    multipath <- if (is.null(payload$multipath)) NULL else as.logical(payload$multipath)
    expand <- if (is.null(payload$expand)) TRUE else as.logical(payload$expand)
    os <- if (is.null(payload$os)) NULL else as.character(payload$os)
    
    out <- rappdirs::site_data_dir(appname = appname, appauthor = appauthor, 
                                  version = version, multipath = multipath, 
                                  expand = expand, os = os)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "user_cache_dir") {
    appname <- if (is.null(payload$appname)) NULL else as.else(as.character(payload$appname))
    appauthor <- if (is.null(payload$appauthor)) NULL else as.character(payload$appauthor)
    version <- if (is.null(payload$version)) NULL else as.character(payload$version)
    opinion <- if (is.null(payload$opinion)) NULL else as.logical(payload$opinion)
    expand <- if (is.null(payload$expand)) TRUE else as.logical(payload$expand)
    os <- if (is.null(payload$os)) NULL else as.character(payload$os)
    
    out <- rappdirs::user_cache_dir(appname = appname, appauthor = appauthor, 
                                   version = version, opinion = opinion, 
                                   expand = expand, os = os)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "user_data_dir") {
    appname <- if (is.null(payload$appname)) NULL else as.character(payload$appname)
    appauthor <- if (is.null(payload$appauthor)) NULL else as.character(payload$appauthor)
    version <- if (is.null(payload$version)) NULL else as.character(payload$version)
    roaming <- if (is.null(payload$roaming)) FALSE else as.logical(payload$roaming)
    expand <- if (is.null(payload$expand)) TRUE else as.logical(payload$expand)
    os <- if (is.null(payload$os)) NULL else as.character(payload$os)
    
    out <- rappdirs::user_data_dir(appname = appname, appauthor = appauthor, 
                                  version = version, roaming = roaming, 
                                  expand = expand, os = os)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "user_config_dir") {
    # Note: user_config_dir is not explicitly in the SKILL.md list but is in the signatures.
    # We implement it based on the provided signature.
    appname <- if (is.null(payload$appname)) NULL else as.character(payload$appname)
    appauthor <- if (is.null(payload$appauthor)) NULL else as.character(payload$appauthor)
    version <- if (is.null(payload$version)) NULL else as.character(payload$version)
    expand <- if (is.null(payload$expand)) TRUE else as.logical(payload$expand)
    os <- if (is.null(payload$os)) NULL else as.character(payload$os)
    
    # user_config_dir is not in the provided signature list for user_config_dir, 
    # but we follow the logic of the other functions.
    # Checking if user_config_dir exists in rappdirs.
    out <- rappdirs::user_config_dir(appname = appname, appauthor = appauthor, 
                                    version = version, expand = expand, os = os)
    emit_ok(out, fn_name)
    
  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
