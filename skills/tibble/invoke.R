#!/usr/bin/env Rscript
# tibble skill dispatcher.
# Reads one JSON object from stdin, invokes the requested tibble function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_tibble   <- requireNamespace("tibble",   quietly = TRUE)
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
      "The R package 'jsonlite' is required by the tibble skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_tibble) {
  emit_error(
    paste(
      "The R package 'tibble' is required but is not installed.",
      "Run: install.packages('tibble')."
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
  emit_arg_error <- emit_error("Field `fn` is required.", fn_name)
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
  
  if (fn_name == "add_column") {
    .data <- require_field(".data", payload, fn_name)
    # Handle dots (...) via name-value pairs in payload
    # We extract all keys that are not part of the explicit signature
    dots_keys <- setdiff(names(payload), c("fn", ".data", ".before", ".after", ".name_repair"))
    dots_list <- list()
    for (k in dots_keys) {
      dots_list[[k]] <- payload[[k]]
    }
    
    args <- list(.data = .data)
    if (!is.null(payload$.before)) args$.before <- payload$.before
    if (!is.null(payload$.after)) args$.after <- payload$.after
    if (!is.null(payload$.name_repair)) args$.name_repair <- payload$.name_repair
    
    # Inject dots
    for (k in names(dots_list)) {
      args[[k]] <- dots_list[[k]]
    }
    
    # Use do.call to pass the list as arguments to handle the ...
    # Note: add_column uses rlang::new_class or similar internally via dots
    # but the signature says passed to tibble().
    res <- do.call(tibble::add_column, args)
    emit_ok(res, fn_name)

  } else if (fn_name == "add_row") {
    .data <- require_field(".data", payload, fn_name)
    dots_keys <- setdiff(names(payload), c("fn", ".data", ".before", ".after"))
    dots_list <- list()
    for (k in dots_keys) {
      dots_list[[k]] <- payload[[k]]
    }
    
    args <- list(.data = .data)
    if (!is.null(payload$.before)) args$.before <- payload$.before
    if (!is.null(payload$.after)) args$.after <- payload$.after
    for (k in names(dots_list)) {
      args[[k]] <- dots_list[[k]]
    }
    
    res <- do.call(tibble::add_row, args)
    emit_ok(res, fn_name)

  } else if (fn_name == "as_tibble") {
    x <- require_field("x", payload, fn_name)
    # Coerce x if it is a matrix or list
    if (is.matrix(x)) x <- as.matrix(x)
    
    args <- list(x = x)
    if (!is.null(payload$.rows)) args$.rows <- as.integer(payload$.rows)
    if (!is.null(payload$.name_repair)) args$.name_repair <- as.character(payload$.name_repair)
    if (!is.null(payload$rownames)) args$rownames <- payload$rownames
    if (!is.null(payload$n)) args$n <- as.character(payload$n)
    if (!is.null(payload$column_name)) args$column_name <- as.character(payload$column_name)
    
    # Handle deprecated/compatibility args
    if (!is.null(payload$._n)) args$._n <- payload$._n
    if (!is.null(payload$validate)) args$validate <- payload$validate

    res <- do.call(tibble::as_tibble, args)
    emit_ok(res, fn_name)

  } else if (fn_name == "char") {
    x <- as.character(require_field("x", payload, fn_name))
    args <- list(x = x)
    if (!is.null(payload$min_chars)) args$min_chars <- as.numeric(payload$min_chars)
    if (!is.null(payload$shorten)) args$shorten <- as.character(payload$shorten)
    
    res <- do.call(tibble::char, args)
    emit_ok(res, fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
