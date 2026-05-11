#!/usr/bin/env Rscript
# curl skill dispatcher.
# Reads one JSON object from stdin, invokes the requested curl function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_curl     <- requireNamespace("curl",     quietly = TRUE)
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
      "The R package 'jsonlite' is required by the curl skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_curl) {
  emit_error(
    paste(
      "The R package 'curl' is required but is not installed.",
      "Run: install.packages('curl')."
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
  if (fn_name == "curl") {
    url   <- as.character(require_field("url", payload, fn_name))
    open  <- if (is.null(payload$open)) NULL else as.character(payload$open)
    h     <- if (is.null(payload$handle)) NULL else payload$handle
    
    args <- list(url = url)
    if (!is.null(open)) args$open <- open
    if (!is.null(handle)) args$handle <- h
    
    out <- do.call(curl::curl, args)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "curl_download") {
    url       <- as.character(require_field("url", payload, fn_name))
    destfile  <- as.character(require_field("destfile", payload, fn_name))
    quiet     <- if (is.null(payload$quiet)) NULL else isTRUE(payload$quiet)
    mode      <- if (is.null(payload$mode)) NULL else as.character(payload$mode)
    h         <- if (is.null(payload$handle)) NULL else payload$handle
    
    args <- list(url = url, destfile = destfile)
    if (!is.null(quiet)) args$quiet <- quiet
    if (!is.null(mode)) args$mode <- mode
    if (!is.null(h)) args$handle <- h
    
    out <- do.call(curl::curl_download, args)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "curl_echo") {
    h       <- if (is.null(payload$handle)) NULL else payload$handle
    port    <- if (is.null(payload$port)) NULL else as.integer(payload$port)
    progress <- if (is.null(payload$progress)) NULL else isTRUE(payload$progress)
    file    <- if (is.null(payload$file)) NULL else as.character(payload$file)
    range   <- if (is.null(payload$range)) NULL else as.integer(payload$range)
    
    args <- list(handle = h)
    if (!is.null(port)) args$port <- port
    if (!is.null(progress)) args$progress <- progress
    if (!is.null(file)) args$file <- file
    if (!is.null(range)) args$range <- range
    
    out <- do.call(curl::curl_echo, args)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "curl_escape") {
    url <- as.character(require_field("url", payload, fn_name))
    out <- curl::curl_escape(url)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "curl_version") {
    out <- curl::curl_version()
    emit_ok(out, fn_name)
    
  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
