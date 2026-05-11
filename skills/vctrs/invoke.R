#!/usr/bin/env Rscript
# vctrs skill dispatcher.
# Reads one JSON object from stdin, invokes the requested vctrs function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_vctrs    <- requireNamespace("vctrs",    quietly = TRUE)
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
      "The R package 'jsonlite' is required by the vctrs skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_vctrs) {
  emit_error(
    paste(
      "The R package 'vctrs' is required but is not installed.",
      "Run: install.packages('vctrs')."
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
  
  if (fn_name == "data_frame") {
    # ... is a named list of vectors or data frames
    # We iterate through the payload keys that are not the control keys
    args <- list()
    control_keys <- c("fn", ".size", ".name_repair", ".error_call")
    
    for (key in names(payload)) {
      if (!(key %in% control_keys)) {
        args[[key]] <- payload[[key]]
      }
    }
    
    # Handle control arguments
    if (!is.null(payload$.size)) {
      args$.size <- payload$.size
    }
    if (!is.null(payload$.name_repair)) {
      args$.name_repair <- as.character(payload$.name_repair)
    }
    if (!is.null(payload$.error_call)) {
      args$.error_call <- payload$.error_call
    }
    
    out <- do.call(vctrs::data_frame, args)
    emit_ok(out, fn_name)

  } else if (fn_name == "df_list") {
    args <- list()
    control_keys <- c("fn", ".size", ".unpack", ".name_repair", ".error_call")
    
    for (key in names(payload)) {
      if (!(key %in% control_keys)) {
        args[[key]] <- payload[[key]]
      }
    }
    
    if (!is.null(payload$.size)) {
      args$.size <- payload$.size
    }
    if (!is.null(payload$.unpack)) {
      args$.unpack <- as.logical(payload$.unpack)
    }
    if (!is.null(payload$.name_repair)) {
      args$.name_repair <- as.character(payload$.name_repair)
    }
    if (!is.null(payload$.error_call)) {
      args$.error_call <- payload$.error_call
    }
    
    out <- do.call(vctrs::df_list, args)
    emit_ok(out, fn_name)

  } else if (fn_name == "df_ptype2") {
    x <- require_field("x", payload, fn_name)
    y <- require_field("y", payload, fn_name)
    
    args <- list(x = x, y = y)
    
    if (!is.null(payload$to)) {
      args$to <- payload$to
    }
    if (!is.null(payload$x_arg)) {
      args$x_arg <- as.character(payload$x_arg)
    }
    if (!is.null(payload$y_arg)) {
      args$y_arg <- as.character(payload$y_arg)
    }
    if (!is.null(payload$to_arg)) {
      args$to_arg <- as.character(payload$to_arg)
    }
    if (!is.null(payload$call)) {
      args$call <- payload$call
    }
    
    out <- do.call(vctrs::df_ptype2, args)
    emit_ok(out, fn_name)

  } else if (fn_name == "fields") {
    x <- require_field("x", payload, fn_name)
    out <- vctrs::fields(x = x)
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "field") {
    x <- require_field("x", payload, fn_name)
    # value is optional in the logic, but if present, we use it.
    # The signature says value: string.
    args <- list(x = x)
    if (!is.null(payload$value)) {
      args$value <- as.character(payload$value)
    }
    
    out <- do.call(vctrs::field, args)
    emit_ok(out, fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
