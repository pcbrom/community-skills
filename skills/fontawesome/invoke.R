#!/usr/bin/env Rscript
# fontawesome skill dispatcher.
# Reads one JSON object from stdin, invokes the requested fontawesome function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_fontawesome <- requireNamespace("fontawesome", quietly = TRUE)
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
      "The R package 'jsonlite' is required by the fontawesome skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_fontawesome) {
  emit_error(
    paste(
      "The R package 'fontawesome' is required but is not installed.",
      "Run: install.packages('fontawesome')."
    )
  )
}

stdin_text <- paste(readLines("stdin", warn = FALSE), collapse = "\and")
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
  
  if (fn_name == "fa") {
    name <- as.character(require_field("name", payload, fn_name))
    
    # Optional arguments
    args <- list(name = name)
    if (!is.null(payload$fill)) args$fill <- as.character(payload$fill)
    if (!is.null(payload$fill_opacity)) args$fill_opacity <- as.numeric(payload$fill_opacity)
    if (!is.null(payload$stroke)) args$stroke <- as.character(payload$stroke)
    if (!is.null(payload$stroke_width)) args$stroke_width <- as.numeric(payload$stroke_width)
    if (!is.null(payload$stroke_opacity)) args$stroke_opacity <- as.numeric(payload$stroke_opacity)
    if (!is.null(payload$height)) args$height <- as.character(payload$height)
    if (!is.null(payload$width)) args$width <- as.character(payload$width)
    if (!is.null(payload$margin_left)) args$margin_left <- as.character(payload$margin_left)
    if (!is.null(payload$margin_right)) args$margin_right <- as.character(payload$margin_right)
    if (!is.null(payload$vertical_align)) args$vertical_align <- as.character(payload$vertical_align)
    if (!is.null(payload$position)) args$position <- as.character(payload$position)
    if (!is.null(payload$title)) args$title <- as.character(payload$title)
    if (!is.null(payload$prefer_type)) args$prefer_type <- as.character(payload$prefer_type)
    if (!is.null(payload$a11y)) args$a11y <- as.character(payload$a11y)
    
    out <- do.call(fontawesome::fa, args)
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "fa_html_dependency") {
    out <- fontawesome::fa_html_dependency()
    emit_ok(out, fn_name)

  } else if (fn_name == "fa_i") {
    name <- as.character(require_field("name", payload, fn_name))
    
    args <- list(name = name)
    if (!is.null(payload$class)) args$class <- as.character(payload$class)
    if (!is.null(payload$prefer_type)) args$prefer_type <- as.character(payload$prefer_type)
    if (!is.null(payload$html_dependency)) args$html_dependency <- payload$html_dependency
    
    out <- do.call(fontawesome::fa_i, args)
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "fa_metadata") {
    out <- fontawesome::fa_metadata()
    emit_ok(out, fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
