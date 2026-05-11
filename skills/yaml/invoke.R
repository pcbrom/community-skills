#!/usr/bin/env Rscript
# yaml skill dispatcher.
# Reads one JSON object from stdin, invokes the requested yaml function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_yaml     <- requireNamespace("yaml",     quietly = TRUE)
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
      "The R package 'jsonlite' is required by the yaml skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_yaml) {
  emit_error(
    paste(
      "The R package 'yaml' is required but is not installed.",
      "Run: install.packages('yaml')."
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
  if (fn_name == "as.yaml") {
    x                <- payload$x
    line.sep         <- if (is.null(payload$line.sep)) NULL else as.character(payload$line.sep)
    indent           <- if (is.null(payload$indent)) NULL else as.integer(payload$indent)
    omap             <- if (is.null(payload$omap)) NULL else as.logical(payload$omap)
    column.major     <- if (is.null(payload$column.major)) NULL else as.logical(payload$column.major)
    unicode          <- if (is.null(payload$unicode)) NULL else as.logical(payload$on_unicode)
    precision        <- if (is.null(payload$precision)) NULL else as.numeric(payload$precision)
    indent.mapping.sequence <- if (is.null(payload$indent.mapping.sequence)) NULL else as.logical(payload$indent.mapping.sequence)
    handlers         <- if (is.null(payload$handlers)) NULL else payload$handlers

    args <- list(x = x)
    if (!is.null(line.sep)) args$line.sep <- line.sep
    if (!is.null(indent)) args$indent <- indent
    if (!is.null(omap)) args$omap <- omap
    if (!is.null(column.major)) args$column.major <- column.major
    if (!is.null(unicode)) args$unicode <- unicode
    if (!is.null(precision)) args$precision <- precision
    if (!is.null(indent.mapping.sequence)) args$indent.mapping.sequence <- indent.mapping.sequence
    if (!is.null(handlers)) args$handlers <- handlers

    out <- do.call(yaml::as.yaml, args)
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "read_yaml") {
    file          <- if (is.null(payload$file)) NULL else as.character(payload$file)
    fileEncoding  <- if (is.null(payload$fileEncoding)) NULL else as.character(payload$fileEncoding)
    text          <- if (is.null(payload$text)) NULL else as.character(payload$text)
    error.label   <- if (is.null(payload$error.label)) NULL else as.character(payload$error.label)
    readLines.warn <- if (is.null(payload$readLines.warn)) NULL else as.logical(payload$readLines.warn)

    args <- list()
    if (!is.null(file)) args$file <- file
    if (!is.null(fileEncoding)) args$fileEncoding <- fileEncoding
    if (!is.null(text)) args$text <- text
    if (!is.null(error.label)) args$error.label <- error.label
    if (!is.null(readLines.warn)) args$readLines.warn <- readLines.warn

    out <- yaml::read_yaml(do.call(args))
    emit_ok(out, fn_name)

  } else if (fn_name == "verbatim_logical") {
    x <- as.logical(require_field("x", payload, fn_name))
    out <- yaml::verbatim_logical(x = x)
    emit_ok(as.logical(out), fn_name)

  } else if (fn_name == "write_yaml") {
    x               <- payload$x
    file            <- if (is.null(payload$file)) NULL else as.character(payload$file)
    fileEncoding    <- if (is.null(payload$fileEncoding)) NULL else as.character(payload$fileEncoding)
    # Note: ... arguments are handled via as.yaml logic in as.yaml call
    # but for write_yaml we pass them through.
    
    args <- list(x = x)
    if (!is.null(file)) args$file <- file
    if (!is.null(fileEncoding)) args$fileEncoding <- fileEncoding
    
    # Pass through additional arguments from payload to as.yaml
    extra_args <- setdiff(names(payload), c("fn", "x", "file", "fileEncoding"))
    for (arg in extra_args) {
      args[[arg]] <- payload[[arg]]
    }

    out <- yaml::write_yaml(do.call(args))
    emit_ok(NULL, fn_name)

  } else if (fn_name == "yaml.load") {
    text <- if (is.null(payload$text)) NULL else as.character(payload$text)
    
    args <- list()
    if (!is.null(text)) args$text <- text
    
    # Handle additional ... arguments
    extra_args <- setdiff(names(payload), c("fn", "text"))
    for (arg in extra_args) {
      args[[arg]] <- payload[[arg]]
    }

    out <- yaml::yaml.load(do.call(args))
    emit_ok(out, fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
