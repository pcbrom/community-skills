#!/usr/bin/env Rscript
# ggplot2 skill dispatcher.
# Reads one JSON object from stdin, invokes the requested ggplot2 function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_ggplot2  <- requireNamespace("ggplot2",  quietly = TRUE)
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
      "The R package 'jsonlite' is required by the ggplot2 skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_ggplot2) {
  emit_error(
    paste(
      "The R package 'ggplot2' is required but is not installed.",
      "Run: install.packages('ggplot2')."
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
  
  if (fn_name == "geom_point") {
    mapping <- require_field("mapping", payload, fn_name)
    data    <- require_field("data",    payload, fn_name)
    size    <- if (is.null(payload$size))    NULL else as.numeric(payload$size)
    color   <- if (is.null(payload$color))   NULL else as.character(payload$color)
    
    out <- ggplot2::geom_point(mapping = mapping, data = data, size = size, color = color)
    emit_ok(as.list(out), fn_name)

  } else if (fn_name == "geom_line") {
    mapping   <- require_field("mapping",   payload, fn_name)
    data      <- require_field("data",      payload, fn_name)
    linewidth <- if (is.null(payload$linewidth)) NULL else as.numeric(payload$linewidth)
    
    out <- ggplot2::geom_line(mapping = mapping, data = data, linewidth = linewidth)
    emit_ok(as.list(out), fn_name)

  } else if (fn_name == "geom_bar") {
    mapping <- require_field("mapping", payload, fn_name)
    data    <- require_field("data",    payload, fn_name)
    stat    <- if (is.null(payload$stat))    NULL else as.character(payload$stat)
    
    out <- ggplot2::geom_bar(mapping = mapping, data = data, stat = stat)
    emit_ok(as.list(out), fn_name)

  } else if (fn_name == "facet_wrap") {
    formula <- require_field("formula", payload, fn_name)
    nrow    <- if (is.null(payload$nrow))    NULL else as.integer(payload$nrow)
    
    # Convert string formula to R formula object
    f_obj <- as.formula(formula)
    out <- ggplot2::facet_wrap(formula = f_obj, nrow = nrow)
    emit_ok(as.list(out), fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
