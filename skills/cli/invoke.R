#!/usr/bin/env Rscript
# cli skill dispatcher.
# Reads one JSON object from stdin, invokes the requested cli function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output (e.g. package banners) to stderr
# so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_cli      <- requireNamespace("cli",      quietly = TRUE)
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
      "The R package 'jsonlite' is required by the cli skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_cli) {
  emit_error(
    paste(
      "The R package 'cli' is required but is not installed.",
      "Run: install.packages('cli')."
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
  
  if (fn_name == "ansi_align") {
    text   <- as.character(require_field("text",   payload, fn_name))
    width  <- if (is.null(payload$width))  NULL else as.numeric(payload$width)
    align  <- if (is.null(payload$align))  NULL else as.character(payload$align)
    type   <- if (is.null(payload$type))   NULL else as.character(payload$type)
    
    args <- list(text = text)
    if (!is.null(width))  args$width  <- width
    if (!is.null(align))  args$align  <- align
    if (!is.null(type))   args$type   <- type
    
    out <- do.call(cli::ansi_align, args)
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "ansi_collapse") {
    x      <- as.character(require_field("x",      payload, fn_name))
    sep    <- if (is.null(payload$sep))    NULL else as.character(payload$sep)
    sep2   <- if (is.null(payload$sep2))   NULL else as.character(payload$sep2)
    last   <- if (is.null(payload$last))   NULL else as.character(payload$last)
    trunc  <- if (is.null(payload$trunc))  NULL else as.numeric(payload$trunc)
    width  <- if (is.null(payload$width))  NULL else as.numeric(payload$width)
    ellipsis <- if (is.null(payload$ellipsis)) NULL else as.character(payload$ellipsis)
    style  <- if (is.null(payload$style))  NULL else as.character(payload$style)
    
    args <- list(x = x)
    if (!is.null(sep))    args$sep    <- sep
    if (!is.null(sep2))   args$sep2   <- sep2
    if (!is.null(last))   args$last   <- last
    if (!is.null(trunc))  args$trunc  <- trunc
    if (!is.null(width))  args$width  <- width
    if (!is.null(ellipsis)) args$ellipsis <- ellipsis
    if (!is.null(style))  args$style  <- style
    
    out <- do.call(cli::ansi_collapse, args)
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "ansi_columns") {
    text   <- as.character(require_field("text",   payload, fn_name))
    width  <- if (is.null(payload$width))  NULL else as.numeric(payload$width)
    sep    <- if (is.null(payload$sep))    NULL else as.character(payload$sep)
    fill   <- if (is.null(payload$fill))   NULL else as.character(payload$fill)
    max_cols <- if (is.null(payload$max_cols)) NULL else as.integer(payload$max_cols)
    align  <- if (is.null(payload$align))  NULL else as.character(payload$align)
    type   <- if (is.null(payload$type))   NULL else as.character(payload$type)
    ellipsis <- if (is.null(payload$ellipsis)) NULL else as.character(payload$ellipsis)
    
    args <- list(text = text)
    if (!is.null(width))    args$width    <- width
    if (!is.null(sep))      args$sep      <- sep
    if (!is.null(fill))     args$fill     <- fill
    if (!is.null(max_cols)) args$max_cols <- max_cols
    if (!is.null(align))    args$align    <- align
    if (!is.null(type))     args$type     <- type
    if (!is.null(ellipsis)) args$ellipsis <- ellipsis
    
    out <- do.call(cli::ansi_columns, args)
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "ansi_grep") {
    pattern <- as.character(require_field("pattern", payload, fn_name))
    x       <- as.character(require_field("x",       payload, fn_name))
    ignore.case <- if (is.null(payload$ignore.case)) NULL else as.logical(payload$ignore.case)
    perl    <- if (is.null(payload$perl))    NULL else as.logical(payload$perl)
    value   <- if (is.null(payload$value))   NULL else as.logical(payload$value)
    
    args <- list(pattern = pattern, x = x)
    if (!is.null(ignore.case)) args$ignore.case <- ignore.case
    if (!is.null(perl))        args$perl        <- perl
    if (!is.null(value))       args$value       <- value
    
    # Note: ... arguments are not explicitly mapped here as they are dynamic.
    # We only handle the explicitly listed upstream arguments.
    
    out <- do.call(cli::ansi_grep, args)
    emit_ok(as.integer(out), fn_name)

  } else if (fn_name == "cli_alert_success") {
    msg <- as.character(require_field("msg", payload, fn_name))
    # cli_alert_success returns invisibly, so we capture the side effect.
    # Since we cannot capture stdout easily without breaking the dispatcher,
    # we assume the user wants the function executed.
    # However, for a skill, we return null as per the contract.
    cli::cli_alert_success(msg = msg)
    emit_ok(NULL, fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
