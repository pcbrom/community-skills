#!/usr/bin/env Rscript
# crayon skill dispatcher.
# Reads one JSON object from stdin, invokes the requested crayon function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_crayon   <- requireNamespace("crayon",   quietly = TRUE)
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
      "The R package 'jsonlite' is required by the crayon skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_crayon) {
  emit_error(
    paste(
      "The R package 'crayon' is required but is not installed.",
      "Run: install.packages('crayon')."
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
  
  if (fn_name == "chr") {
    x <- as.character(require_field("x", payload, fn_name))
    # ... arguments are passed via ... in R, but here we handle explicit keys
    # Since ... is not a JSON key, we only pass x.
    out <- crayon::chr(x)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "col_align") {
    text  <- as.character(require_field("text",  payload, fn_name))
    width <- as.integer(require_field("width", payload, fn_name))
    align <- as.character(require_field("align", payload, fn_name))
    type  <- if (is.null(payload$type)) NULL else as.character(payload$type)
    
    # col_align uses 'align' in signature but 'justify' in SKILL.md. 
    # We follow the UPSTREAM SIGNATURES block: text, width, align, type.
    # Note: The user provided 'align' in the signature block.
    
    args <- list(text = text, width = width, align = align)
    if (!is.null(type)) args$type <- type
    
    out <- do.call(crayon::col_align, args)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "col_nchar") {
    x     <- as.character(require_field("x", payload, fn_name))
    out <- crayon::col_nchar(x)
    emit_ok(as.integer(out), fn_name)
    
  } else if (fn_name == "col_strsplit") {
    x     <- as.character(require_field("x", payload, fn_name))
    split <- as.character(require_field("split", payload, fn_name))
    out <- crayon::col_strsplit(x, split = split)
    emit_ok(as.character(out), fn_name)
    
  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
