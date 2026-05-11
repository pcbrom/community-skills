#!/usr/bin/env Rscript
# glue skill dispatcher.
# Reads one JSON object from stdin, invokes the requested glue function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_glue     <- requireNamespace("glue",     quietly = TRUE)
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
      "The R package 'jsonlite' is required by the glue skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_glue) {
  emit_error(
    paste(
      "The R package 'glue' is required but is not installed.",
      "Run: install.packages('glue')."
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
  
  if (fn_name == "as_glue") {
    x <- require_field("x", payload, fn_name)
    # as_glue returns a glue object; we convert to character for JSON transport
    out <- glue::as_glue(x)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "glue") {
    # glue uses ... for expressions and .x for lookup
    # We must handle the unnamed arguments (expressions) and named arguments
    # Since JSON is a key-value structure, we look for the .x key and then 
    # iterate through other keys as named arguments.
    
    args <- list()
    
    # Handle .x if present
    if (!is.null(payload$.x)) {
      args$.x <- payload$.x
    }
    
    # Handle other named arguments (including .sep, .envir, etc.)
    # We exclude 'fn' and '.x' (already handled)
    all_keys <- names(payload)
    for (key in all_keys) {
      if (key != "fn" && key != ".x") {
        args[[key]] <- payload[[key]]
      }
    }
    
    # Note: JSON cannot natively represent unnamed arguments in a single object 
    # without a specific structure. We assume the user provides the template 
    # via a specific key if they want to use the '...' logic, but per 
    # UPSTREAM SIGNATURES, we treat the payload keys as the named arguments.
    # If the user wants to pass a template string, they must use a named key.
    # However, the signature implies '...' are expressions. 
    # In a JSON context, we look for a 'template' or similar, but since 
    # the signature says '...', we will check for a 'template' key as a fallback
    # or assume the first string-like key is the template if no .x is provided.
    
    # To strictly follow the signature: we look for the template in the payload.
    # Since JSON is key-based, we'll look for a key 'template' if not provided via .x
    template <- if (!is.null(payload$.x)) payload$.x else payload$template
    if (is.null(template)) {
      emit_error("`glue` requires a template string (via `.x` or `template` key).", fn_name)
    }
    
    # Prepare the call arguments
    call_args <- list()
    if (!is.null(payload$.x)) call_args$.x <- payload$.x
    
    # Map other keys to call arguments
    for (key in all_keys) {
      if (key %in% c("fn", ".x") || key == "template") next
      val <- payload[[key]]
      # Coerce types
      if (is.character(val)) val <- as.character(val)
      if (is.numeric(val)) val <- as.numeric(val)
      if (is.logical(val)) val <- as.logical(val)
      call_args[[key]] <- val
    }
    
    # We need the template string to be the first argument if not using .x
    # If .x is not used, we use the 'template' key.
    if (is.null(payload$.x)) {
      # We use the 'template' key as the primary expression string
      # and pass the rest as named arguments.
      out <- do.call(glue::glue, c(list(template), call_args))
    } else {
      out <- do.call(glue::glue, c(list(payload$.x), call_args))
    }
    
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "glue_col") {
    # Similar to glue, but handles color.
    # We look for a 'template' key or use .x
    template <- if (!is.null(payload$.x)) payload$.x else payload$template
    if (is.null(template)) {
      emit_error("`glue_col` requires a template string (via `.x` or `template` key).", fn_name)
    }
    
    call_args <- list()
    if (!is.null(payload$.x)) call_args$.x <- payload$.x
    
    for (key in names(payload)) {
      if (key %in% c("fn", ".x", "template")) next
      val <- payload[[key]]
      if (is.character(val)) val <- as.character(val)
      if (is.numeric(val)) val <- as.numeric(val)
      if (is.logical(val)) val <- as.logical(val)
      call_args[[key]] <- val
    }
    
    if (is.null(payload$.x)) {
      out <- do.call(glue::glue_col, c(list(template), call_args))
    } else {
      out <- do.call(glue::glue_col, c(list(payload$.x), call_args))
    }
    
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "glue_collapse") {
    x <- as.character(require_field("x", payload, fn_name))
    sep <- if (is.null(payload$sep)) "" else as.character(payload$sep)
    width <- if (is.null(payload$width)) NULL else as.numeric(payload$width)
    last <- if (is.null(payload$last)) NULL else as.character(payload$last)
    
    # Construct call arguments
    args <- list(x = x)
    if (!is.null(sep)) args$sep <- sep
    if (!is.null(width)) args$width <- width
    if (!is.null(last)) args$last <- last
    
    out <- do.call(glue::glue_collapse, args)
    emit_ok(as.character(out), fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
