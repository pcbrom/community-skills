#!/usr/bin/env Rscript
# utf8 skill dispatcher.
# Reads one JSON object from stdin, invokes the requested utf8 function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_utf8     <- requireNamespace("utf8",     quietly = TRUE)
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
      "The R package 'jsonlite' is required by the utf8 skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_utf8) {
  emit_error(
    paste(
      "The R package 'utf8' is required but is not installed.",
      "Run: install.packages('utf8')."
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
  
  if (fn_name == "as_utf8") {
    x <- as.character(require_field("x", payload, fn_name))
    normalize <- if (is.null(payload$normalize)) NULL else as.logical(payload$normalize)
    out <- utf8::as_utf8(x = x, normalize = normalize)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "utf8_valid") {
    x <- as.character(require_field("x", payload, fn_name))
    out <- utf8::utf8_valid(x = x)
    emit_ok(as.logical(out), fn_name)
    
  } else if (fn_name == "utf8_encode") {
    x <- as.character(require_field("x", payload, fn_name))
    width <- if (is.null(payload$width)) NULL else as.integer(payload$width)
    quote <- if (is.null(payload$quote)) NULL else as.logical(payload$quote)
    justify <- if (is.null(payload$justify)) NULL else as.character(payload$justify)
    escapes <- if (is.null(payload$escapes)) NULL else as.character(payload$escapes)
    display <- if (is.null(payload$display)) NULL else as.logical(payload$display)
    utf8_val <- if (is.null(payload$utf8)) NULL else as.logical(payload$utf8)
    
    # Construct args list to avoid passing NULLs to ... if they are not in the signature
    # but the signature explicitly lists them. We pass them as they are.
    out <- utf8::utf8_encode(
      x = x,
      width = width,
      quote = quote,
      justify = justify,
      escapes = escapes,
      display = display,
      utf8 = utf8_val
    )
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "utf8_format") {
    x <- as.character(require_field("x", payload, fn_name))
    trim <- if (is.null(payload$trim)) NULL else as.logical(payload$trim)
    chars <- if (is.null(payload$chars)) NULL else as.integer(payload$chars)
    justify <- if (is.null(payload$justify)) NULL else as.character(payload$else_justify <- payload$justify)
    # Note: the variable name 'justify' is used in the signature.
    justify <- if (is.null(payload$justify)) NULL else as.character(payload$justify)
    width <- if (is.null(payload$width)) NULL else as.integer(payload$width)
    na.encode <- if (is.null(payload$na.encode)) NULL else as.logical(payload$na.encode)
    quote <- if (is.null(payload$quote)) NULL else as.logical(payload$quote)
    na.print <- if (is.null(payload$na.print)) NULL else as.character(payload$na.print)
    print.gap <- if (is.null(payload$print.gap)) NULL else as.integer(payload$print.gap)
    utf8_val <- if (is.null(payload$utf8)) NULL else as.logical(payload$utf8)
    
    out <- utf8::utf8_format(
      x = x,
      trim = trim,
      chars = chars,
      justify = justify,
      width = width,
      na.encode = na.encode,
      quote = quote,
      na.print = na.print,
      print.gap = print.gap,
      utf8 = utf8_val
    )
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "output_ansi") {
    # No arguments defined in upstream signature
    out <- utf8::output_ansi()
    emit_ok(as.character(out), fn_name)
    
  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
