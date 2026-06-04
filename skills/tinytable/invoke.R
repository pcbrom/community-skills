#!/usr/bin/env Rscript
# tinytable skill dispatcher.
# Reads one JSON object from stdin, invokes the requested tinytable function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_tinytable <- requireNamespace("tinytable", quietly = TRUE)
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
      "The R package 'jsonlite' is required by the tinytable skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_tinytable) {
  emit_error(
    paste(
      "The R package 'tinytable' is required but is not installed.",
      "Run: install.packages('tinytable')."
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
  
  if (fn_name == "tt") {
    x <- require_field("x", payload, fn_name)
    out <- tinytable::tt(x = x)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "format_tt") {
    x <- require_field("x", payload, fn_name)
    j <- require_field("j", payload, fn_name)
    
    # Optional arguments
    i <- if (is.null(payload$i)) NULL else as.character(payload$i)
    digits <- if (is.null(payload$digits)) NULL else as.integer(payload$digits)
    num_fmt <- if (is.null(payload$num_fmt)) NULL else as.character(payload$num_fmt)
    num_zero <- if (is.null(payload$num_zero)) NULL else as.logical(payload$num_zero)
    num_suffix <- if (is.null(payload$num_suffix)) NULL else as.logical(payload$num_suffix)
    num_mark_big <- if (is.null(payload$num_mark_big)) NULL else as.character(payload$num_mark_big)
    num_mark_dec <- if (is.null(payload$num_mark_dec)) NULL else as.character(payload$num_mark_dec)
    date <- if (is.null(payload$date)) NULL else as.character(payload$date)
    bool <- if (is.null(payload$bool)) NULL else payload$bool # Function/logic
    math <- if (is.null(payload$math)) NULL else as.logical(payload$math)
    other <- if (is.null(payload$other)) NULL else payload$other # Function/logic
    replace <- if (is.null(payload$replace)) NULL else payload$replace # Logic/String/List
    escape <- if (is.null(payload$escape)) NULL else as.character(payload$escape)
    markdown <- if (is.null(payload$markdown)) NULL else as.logical(payload$markdown)
    quarto <- if (is.null(payload$quarto)) NULL else as.logical(payload$quarto)
    fn <- if (is.null(payload$fn)) NULL else payload$fn # Function
    sprintf <- if (is.null(payload$sprintf)) NULL else as.character(payload$sprintf)
    linebreak <- if (is.null(payload$linebreak)) NULL else as.character(payload$linebreak)
    output <- if (is.null(payload$output)) NULL else as.character(payload$output)

    args <- list(x = x, j = j, i = i, digits = digits, num_fmt = num_fmt, 
                 num_zero = num_zero, num_suffix = num_suffix, 
                 num_mark_big = num_mark_big, num_mark_dec = num_mark_dec, 
                 date = date, bool = bool, math = math, other = other, 
                 replace = replace, escape = escape, markdown = markdown, 
                 quarto = quarto, fn = fn, sprintf = sprintf, 
                 linebreak = linebreak, output = output)
    
    # Remove NULLs to allow R to use defaults
    args <- args[!vapply(args, is.null, logical(1))]
    
    out <- do.call(tinytable::format_tt, args)
    emit_ok(out, fn_name)

  } else if (fn_name == "format_vector") {
    x <- require_field("x", payload, fn_name)
    # x can be numeric, Date, or logical. We use the raw object.
    
    output <- if (is.null(payload$output)) NULL else as.character(payload$output)
    digits <- if (is.null(payload$digits)) NULL else as.integer(payload$digits)
    date <- if (is.null(payload$date)) NULL else as.character(payload$date)
    bool <- if (is.null(payload$bool)) NULL else payload$bool
    math <- if (is.null(payload$math)) NULL else as.logical(payload$math)
    other <- if (is.null(payload$other)) NULL else payload$other
    replace <- if (is.null(payload$replace)) NULL else payload$replace
    escape <- if (is.null(payload$escape)) NULL else as.character(payload$escape)
    markdown <- if (is.null(payload$markdown)) NULL else as.logical(payload$markdown)
    quarto <- if (is.null(payload$quarto)) NULL else as.logical(payload$quarto)
    fn <- if (is.null(payload$fn)) NULL else payload$fn
    sprintf <- if (is.null(payload$sprintf)) NULL else as.character(payload$suppressWarnings(payload$sprintf))
    linebreak <- if (is.null(payload$linebreak)) NULL else as.character(payload$linebreak)
    
    # Re-apply numeric/logic/date specific fields from upstream
    num_fmt <- if (is.null(payload$num_fmt)) NULL else as.character(payload$num_fmt)
    num_zero <- if (is.null(payload$num_zero)) NULL else as.logical(payload$num_zero)
    num_suffix <- if (is.null(payload$num_suffix)) NULL else as.logical(payload$num_suffix)
    num_mark_big <- if (is.null(payload$num_mark_big)) NULL else as.character(payload$num_mark_big)
    num_mark_dec <- if (is.null(payload$num_mark_dec)) NULL else as.character(payload$num_mark_dec)

    args <- list(x = x, output = output, digits = digits, date = date, bool = bool, 
                 math = math, other = other, replace = replace, escape = escape, 
                 markdown = markdown, quarto = quarto, fn = fn, sprintf = sprintf, 
                 linebreak = linebreak, num_fmt = num_fmt, num_zero = num_zero, 
                 num_suffix = num_suffix, num_mark_big = num_mark_big, 
                 num_mark_dec = num_mark_dec)
    
    args <- args[!vapply(args, is.null, logical(1))]
    
    out <- do.call(tinytable::format_vector, args)
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "group_tt") {
    x <- require_field("x", payload, fn_name)
    i <- if (is.null(payload$i)) NULL else payload$i
    j <- if (is.null(payload$j)) NULL else payload$j
    
    args <- list(x = x, i = i, j = j)
    args <- args[!vapply(args, is.null, logical(1))]
    
    out <- do.call(tinytable::group_tt, args)
    emit_ok(out, fn_name)
    
  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
