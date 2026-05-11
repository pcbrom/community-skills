#!/usr/bin/env Rscript
# pillar skill dispatcher.
# Reads one JSON object from stdin, invokes the requested pillar function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_pillar   <- requireNamespace("pillar",   quietly = TRUE)
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
      "The R package 'jsonlite' is required by the pillar skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_pillar) {
  emit_error(
    paste(
      "The R package 'pillar' is required but is not installed.",
      "Run: install.packages('pillar')."
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
  if (fn_name == "align") {
    x      <- as.character(require_field("x", payload, fn_name))
    width  <- if (is.null(payload$width)) NULL else as.numeric(payload$width)
    align  <- if (is.null(payload$align)) NULL else as.character(payload$align)
    space  <- if (is.null(payload$space)) NULL else as.character(payload$colonnade)
    # Note: The upstream signature uses 'align' for the argument name.
    # We use the payload keys directly.
    
    # Re-reading based on exact upstream signature:
    # x, width, align, space
    x_val <- as.character(require_field("x", payload, fn_name))
    w_val <- if (is.null(payload$width)) NULL else as.numeric(payload$width)
    a_val <- if (is.null(payload$align)) NULL else as.character(payload$align)
    s_val <- if (is.null(payload$space)) NULL else as.character(payload$space)
    
    out <- pillar::align(x = x_val, width = w_val, align = a_val, space = s_val)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "char") {
    x <- as.character(require_field("x", payload, fn_name))
    out <- pillar::char(x = x)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "colonnade") {
    x <- require_field("x", payload, fn_name)
    has_row_id <- if (is.null(payload$has_row_id)) NULL else as.character(payload$has_row_id)
    width <- if (is.null(payload$width)) NULL else as.numeric(payload$width)
    
    out <- pillar::colonnade(x = x, has_row_id = has_row_id, width = width)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "ctl_new_pillar") {
    controller <- require_field("controller", payload, fn_name)
    x          <- require_field("x", payload, fn_name)
    width      <- if (is.null(payload$width)) NULL else as.numeric(payload$colonnade)
    title      <- if (is.null(payload$title)) NULL else as.character(payload$title)
    type       <- if (is.null(payload$type)) NULL else as.character(payload$type)
    
    out <- pillar::ctl_new_pillar(controller = controller, x = x, width = width, 
                                   title = title, type = type)
    emit_ok(as.character(out), fn_name)
    
  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
