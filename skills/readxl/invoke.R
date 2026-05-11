#!/usr/bin/env Rscript
# readxl skill dispatcher.
# Reads one JSON object from stdin, invokes the requested readxl function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_readxl   <- requireNamespace("readxl",   quietly = TRUE)
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
      "The R package 'jsonlite' is required by the readxl skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_readxl) {
  emit_error(
    paste(
      "The R package 'readxl' is required but is not installed.",
      "Run: install.packages('readxl')."
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
  if (fn_name == "excel_format") {
    path <- as.character(require_field("path", payload, fn_name))
    guess <- if (is.null(payload$guess)) TRUE else isTRUE(payload$guess)
    out <- readxl::excel_format(path = path, guess = guess)
    emit_ok(as.character(out), fn_name)
  } else if (fn_name == "excel_sheets") {
    path <- as.character(require_field("path", payload, fn_name))
    out <- readxl::excel_sheets(path = path)
    emit_ok(as.character(out), fn_name)
  } else if (fn_name == "read_excel") {
    path <- as.character(require_field("path", payload, fn_name))
    sheet <- if (is.null(payload$sheet)) NULL else if (is.numeric(payload$sheet)) as.integer(payload$sheet) else as.character(payload$sheet)
    range <- if (is.null(payload$range)) NULL else as.character(payload$range)
    col_names <- if (is.null(payload$col_names)) NULL else as.logical(payload$col_names)
    col_types <- if (is.null(payload$col_types)) NULL else as.character(payload$col_types)
    na <- if (is.null(payload$na)) NULL else as.character(payload$na)
    trim_ws <- if (is.null(payload$trim_ws)) NULL else as.logical(payload$trim_ws)
    skip <- if (is.null(payload$skip)) NULL else as.integer(payload$skip)
    n_max <- if (is.null(payload$n_max)) NULL else as.integer(payload$n_max)
    guess_max <- if (is.null(payload$guess_max)) NULL else as.integer(payload$guess_max)
    progress <- if (is.null(payload$progress)) NULL else as.logical(payload$progress)
    .name_repair <- if (is.null(payload$.name_repair)) NULL else as.character(payload$.name_repair)

    # Construct arguments list to avoid passing NULLs to functions that use defaults
    args <- list(path = path)
    if (!is.null(sheet)) args$sheet <- sheet
    if (!is.null(range)) args$range <- range
    if (!is.null(col_names)) args$col_names <- col_names
    if (!is.null(col_types)) args$col_types <- col_types
    if (!is.null(na)) args$na <- na
    if (!is.null(trim_ws)) args$trim_ws <- trim_ws
    if (!is.null(skip)) args$skip <- skip
    if (!is.null(n_max)) args$n_max <- n_max
    if (!is.null(guess_max)) args$guess_max <- guess_max
    if (!is.null(progress)) args$progress <- progress
    if (!is.null(.name_repair)) args$.name_repair <- .name_repair

    out <- do.call(readxl::read_excel, args)
    # Convert tibble/data.frame to list/array for JSON serialization
    emit_ok(as.list(out), fn_name)
  } else if (fn_name == "readxl_example") {
    path <- if (is.null(payload$name)) NULL else as.character(payload$name)
    out <- readxl::readxl_example(path = path)
    emit_ok(as.character(out), fn_name)
  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
