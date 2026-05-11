#!/usr/bin/env Rscript
# httr skill dispatcher.
# Reads one JSON object from stdin, invokes the requested httr function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_httr     <- requireNamespace("httr",     quietly = TRUE)
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
      "The R package 'jsonlite' is required by the httr skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_httr) {
  emit_error(
    paste(
      "The R package 'httr' is required but is not installed.",
      "Run: install.packages('httr')."
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
  
  if (fn_name == "BROWSE") {
    url    <- as.character(require_field("url", payload, fn_name))
    config <- payload$config
    # Handle ... via query/path/etc
    query  <- if (!is.null(payload$query)) as.list(payload$query) else NULL
    path   <- if (!is.null(payload$path)) as.character(payload$path) else NULL
    
    # httr::browse is a wrapper around RCurl/browser logic
    # We pass the url and any extra params
    res <- tryCatch({
      # Note: browse is often used for interactive or specific URL handling
      # In the context of httr, we pass the url.
      httr::browse(url = url)
    }, error = function(e) e)
    
    if (inherits(res, "error")) stop(conditionMessage(res))
    emit_ok(res, fn_name)

  } else if (fn_name == "DELETE") {
    url    <- as.character(require_field("url", payload, fn_name))
    config <- payload$config
    body   <- payload$body
    encode <- if (!is.null(payload$encode)) as.character(payload$encode) else NULL
    
    # Construct call arguments
    args <- list(url = url)
    if (!is.null(config)) args$config <- config
    if (!is.null(body)) args$body <- body
    if (!is.null(encode)) args$encode <- encode
    
    # Handle ... (query, path)
    if (!is.null(payload$query)) args$query <- as.list(payload$query)
    if (!is.null(payload$path))  args$path  <- as.character(payload$path)

    res <- tryCatch({
      do.call(httr::DELETE, args)
    }, error = function(e) e)
    
    if (inherits(res, "error")) stop(conditionMessage(res))
    emit_ok(as.list(httr::status_code(res)), fn_name)

  } else if (fn_name == "GET") {
    url    <- as.character(require_field("url", payload, fn_name))
    config <- payload$config
    
    args <- list(url = url)
    if (!is.null(config)) args$config <- config
    if (!is.null(payload$query)) args$query <- as.list(payload$query)
    if (!is.null(payload$path))  args$path  <- as.character(payload$path)

    res <- tryCatch({
      do.call(httr::GET, args)
    }, error = function(e) e)
    
    if (inherits(res, "error")) stop(conditionMessage(res))
    emit_ok(as.list(httr::status_code(res)), fn: fn_name)

  } else if (fn_name == "HEAD") {
    url    <- as.character(require_field("url", payload, fn_name))
    config <- payload$config
    
    args <- list(url = url)
    if (!is.null(config)) args$config <- config
    if (!is.null(payload$query)) args$query <- as.list(payload$query)
    if (!is.null(payload$path))  args$path  <- as.character(payload$path)

    res <- tryCatch({
      do.call(httr::HEAD, args)
    }, error = function(e) e)
    
    if (inherits(res, "error")) stop(conditionMessage(res))
    emit_ok(as.list(httr::status_code(res)), fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
