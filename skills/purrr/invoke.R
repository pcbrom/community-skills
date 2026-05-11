#!/usr/bin/env Rscript
# purrr skill dispatcher.
# Reads one JSON object from stdin, invokes the requested purrr function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_purrr    <- requireNamespace("purrr",    quietly = TRUE)
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
      "The R package 'jsonlite' is required by the purrr skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_purrr) {
  emit_error(
    paste(
      "The R package 'purrr' is required but is not installed.",
      "Run: install.packages('purrr')."
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
    emit_error(sprintf("Field `%s` is required for fn=%s.", name, fn_name))
  }
  payload[[name]]
}

dispatch <- function(payload) {
  fn_name <- payload$fn
  
  if (fn_name == "accumulate") {
    .x <- require_field(".x", payload, fn_name)
    .f <- payload$.f
    .init <- payload$.init
    .dir <- payload$.dir
    .simplify <- payload$.simplify
    .ptype <- payload$.ptype
    
    # Convert .x to appropriate type
    if (is.character(.x)) .x <- as.character(.x)
    if (is.numeric(.x)) .x <- as.numeric(.x)
    if (is.integer(.x)) .x <- as.integer(.x)
    
    # Handle .f as function/formula/character
    if (is.character(.f)) .f <- purrr::as_mapper(.f)
    if (is.formula(.f)) .f <- as.function(.f)
    
    res <- purrr::accumulate(.x, .f, .init = .init, .dir = .dir, 
                             .simplify = .simplify, .ptype = .ptype)
    emit_ok(res, fn_name)

  } else if (fn_name == "as_mapper") {
    .f <- payload$.f
    if (is.character(.f)) .f <- purrr::as_mapper(.f)
    if (is.formula(.f)) .f <- as.function(.f)
    
    .default <- payload$.default
    
    res <- purrr::as_mapper(.f, .default = .default)
    emit_ok(res, fn_name)

  } else if (fn_name == "as_vector") {
    .x <- require_field(".x", payload, fn_name)
    .type <- payload$.type
    
    # .x is a list of vectors
    res <- purrr::as_vector(.x, .type = .type)
    emit_ok(res, fn_name)

  } else if (fn_name == "attr_getter") {
    attr <- require_field("attr", payload, fn_name)
    
    # Create a function that returns the attribute
    res <- function(x) attr(x, attr)
    emit_ok(res, fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
