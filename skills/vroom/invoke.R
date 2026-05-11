#!/usr/bin/env Rscript
# vroom skill dispatcher.
# Reads one JSON object from stdin, invokes the requested vroom function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output (e.g. package banners) to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_vroom    <- requireNamespace("vroom",    quietly = TRUE)
})

emit_error <- function(message_text, fn_name = NA_character_, code = 1L) {
  payload <- list(ok = FALSE, error = unname(message_text))
  if (!is.na(fn_name)) payload$fn <- fn_name
  sink(NULL, type = "output")  # restore stdout before writing the final JSON
  if (ok_jsonlite) {
    cat(jsonlite::toJSON(payload, auto_unbox = TRUE, na = "null"))
  } else {
    cat(sprintf('{"ok":false,"error":%s}',
                shQuote(message, type = "cmd")))
  }
  cat("\n")
  quit(status = code, save = "no")
}

if (!ok_jsonlite) {
  emit_error(
    paste(
      "The R package 'jsonlite' is required by the vroom skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_vroom) {
  emit_error(
    paste(
      "The R package 'vroom' is required but is not installed.",
      "Run: install.packages('vroom')."
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
  
  if (fn_name == "vroom") {
    file     <- as.character(require_field("file", payload, fn_name))
    delim    <- if (is.null(payload$delim)) NULL else as.character(payload$delim)
    col_types <- if (is.null(payload$col_types)) NULL else payload$col_types
    
    # vroom() uses delim, not delim_arg
    res <- vroom::vroom(file = file, delim = delim, col_types = col_types)
    emit_ok(res, fn_name)

  } else if (fn_name == "vroom_write") {
    x      <- require_field("x", payload, fn_name)
    file   <- as.character(require_field("file", payload, fn_name))
    delim  <- if (is.null(payload$delim)) "," else as.character(payload$delim)
    
    vroom::vroom_write(x = x, file = file, delim = delim)
    emit_ok(NULL, fn_name)

  } else if (fn_name == "cols") {
    # The ... argument is passed via the payload keys excluding 'fn'
    # We extract all other keys as the column specification
    spec_list <- payload[names(payload) != "fn"]
    # vroom::cols() takes ...
    res <- vroom::cols(...)
    # Since we cannot easily pass ... from a list in this context without 
    # manual mapping, we use do.call
    res <- do.call(vroom::cols, spec_list)
    emit_ok(res, fn_name)

  } else if (fn_name == "gen_tbl") {
    rows      <- as.integer(require_field("rows", payload, fn_name))
    cols_val  <- if (is.null(payload$cols)) NULL else as.integer(payload$cols)
    col_types <- if (is.null(payload$col_types)) NULL else as.character(payload$col_types)
    locale    <- if (is.null(payload$locale)) NULL else payload$locale
    missing   <- if (is.null(payload$missing)) NULL else as.numeric(payload$missing)
    
    # Note: gen_tbl is not a standard vroom function, but we implement 
    # based on the provided UPSTREAM SIGNATURES for the skill.
    # Since gen_tbl is not in the vroom package itself but requested in the skill:
    # We assume a helper or implementation exists. 
    # If it's a placeholder for a custom logic, we implement it here.
    # However, the prompt implies wrapping vroom. 
    # If the function doesn't exist in vroom, we must handle it.
    # Given the context, we will attempt to call it from vroom.
    
    # For the sake of this dispatcher, we assume the user wants the logic 
    # provided in the signature.
    
    # Implementation of gen_tbl logic if it were available:
    # (This is a fallback for the specific requirement)
    if (!exists("gen_tbl", envir = asNamespace("vroom"))) {
       emit_error("Function 'gen_tbl' is not available in the vroom package.", fn_name)
    }
    
    # Constructing args
    args <- list(rows = rows)
    if (!is.null(cols_val)) args$cols <- cols_val
    if (!is.null(col_types)) args$col_types <- col_types
    if (!is.null(locale)) args$locale <- locale
    if (!is.null(missing)) args$missing <- missing
    
    res <- do.call(vroom::gen_tbl, args)
    emit_ok(res, fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
