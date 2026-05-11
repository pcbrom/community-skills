#!/usr/bin/env Rscript
# tidyr skill dispatcher.
# Reads one JSON object from stdin, invokes the requested tidyr function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_tidyr    <- requireNamespace("tidyr",    quietly = TRUE)
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
      "The R package 'jsonlite' is required by the tidyr skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_tidyr) {
  emit_error(
    paste(
      "The R package 'tidyr' is required but is not installed.",
      "Run: install.packages('tidyr')."
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
  
  if (fn_name == "check_pivot_spec") {
    spec <- require_field("spec", payload, fn_name)
    out <- tidyr::check_pivot_spec(spec = spec)
    emit_ok(as.data.frame(out), fn_name)

  } else if (fn_name == "chop") {
    data <- as.data.frame(require_field("data", payload, fn_name))
    cols <- require_field("cols", payload, fn_name)
    
    # Handle optional arguments
    keep_empty <- if (is.null(payload$keep_empty)) TRUE else as.logical(payload$keep_empty)
    ptype <- if (is.null(payload$ptype)) NULL else as.list(payload$ptype)
    
    # Note: '...' and 'error_call' are handled by R's native argument passing
    # We pass only what is explicitly provided in the payload.
    args <- list(data = data, cols = cols, keep_empty = keep_empty, ptype = ptype)
    
    # Filter out NULLs to allow R to use defaults
    args <- args[!vapply(args, is.null, logical(1))]
    
    out <- do.call(tidyr::chop, args)
    emit_ok(as.data.frame(out), fn_name)

  } else if (fn_name == "complete") {
    data <- as.data.frame(require_field("data", payload, fn_name))
    
    # '...' is handled via data-masking; in JSON we treat it as a list of specs
    # We extract all keys that are not 'data', 'fill', or 'explicit'
    dots_args <- payload[!(names(payload) %in% c("fn", "data", "fill", "explicit"))]
    
    fill <- if (is.null(payload$fill)) NULL else as.list(payload$fill)
    explicit <- if (is.null(payload$explicit)) NULL else as.logical(payload$explicit)
    
    args <- list(data = data, fill = fill, explicit = explicit)
    # Add the dots arguments
    for (name in names(dots_args)) {
      args[[name]] <- dots_args[[name]]
    }
    
    # Filter out NULLs
    args <- args[!vapply(args, is.null, logical(1))]
    
    out <- do.call(tidyr::complete, args)
    emit_ok(as.data.frame(out), fn_name)

  } else if (fn_name == "drop_na") {
    data <- as.data.frame(require_field("data", payload, fn_name))
    
    # Extract dots arguments (columns to inspect)
    dots_args <- payload[!(names(payload) %in% c("fn", "data"))]
    
    # In R, '...' in drop_na is the selection. 
    # If payload has extra keys, we treat them as the selection.
    # If no extra keys, all columns are used.
    
    if (length(dots_args) == 0) {
      out <- tidyr::drop_na(data)
    } else {
      # We must pass the selection as the '...' argument.
      # Since we cannot easily pass '...' via a list in do.call without 
      # knowing the names, we use the keys provided in the payload.
      # For drop_na, the user provides column names as keys.
      # We'll use the first available key from dots_args as the selection if it's a single string,
      # or use the list of keys.
      
      # A common pattern for tidy-select in JSON is providing the column name as a value.
      # We will attempt to pass the selection via the first key found in dots_args.
      # However, the standard way is to pass the selection as a vector.
      # We's assume the user provides the column names as a list or vector in the payload.
      
      # If the user provided: {"fn": "drop_na", "data": ..., "x": "x"}
      # We need to call drop_na(data, x)
      
      # We'll use a trick: find the first key in dots_args that isn't 'fn' or 'data'
      # and use its value as the selection.
      selection <- dots_args[[1]]
      out <- tidyr::drop_na(data, all_of(selection))
    }
    emit_ok(as.data.frame(out), fn_name)

  } else if (fn_name == "pivot_longer") {
    data <- as.data.frame(require_field("data", payload, fn_name))
    cols <- as.character(require_field("cols", payload, fn_name))
    names_to <- as.character(require_field("names_to", payload, fn_name))
    values_to <- as.character(require_field("values_to", payload, fn_name))
    
    out <- tidyr::pivot_longer(data = data, cols = !!rlang::sym(cols), 
                               names_to = names_to, values_to = values_to)
    emit_ok(as.data.frame(out), fn_name)

  } else if (fn_name == "pivot_wider") {
    data <- as.data.frame(require_field("data", payload, fn_name))
    names_from <- as.character(require_field("names_from", payload, fn_name))
    values_from <- as.character(require_field("values_from", payload, fn_name))
    
    out <- tidyr::pivot_wider(data = data, names_from = !!rlang::sym(names_from), 
                              values_from = !!rlang::sym(values_from))
    emit_ok(as.data.frame(out), fn_name)

  } else if (fn_name == "unnest") {
    data <- as.data.frame(require_field("data", payload, fn_name))
    cols <- as.character(require_field("cols", payload, fn_name))
    
    out <- tidyr::unnest(data, !!rlang::sym(cols))
    emit_ok(as.data.frame(out), fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
