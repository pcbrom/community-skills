#!/usr/bin/env Rscript
# prettyunits skill dispatcher.
# Reads one JSON object from stdin, invokes the requested prettyunits function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_prettyunits <- requireNamespace("prettyunits", quietly = TRUE)
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
      "The R package 'jsonlite' is required by the prettyunits skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_prettyunits) {
  emit_error(
    paste(
      "The R package 'prettyunits' is required but is not installed.",
      "Run: install.packages('prettyunits')."
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
  
  if (fn_name == "pretty_bytes") {
    bytes <- as.numeric(require_field("bytes", payload, fn_name))
    style <- if (is.null(payload$style)) NULL else as.character(payload$style)
    smallest_unit <- if (is.null(payload$smallest_unit)) NULL else as.character(payload$smallest_unit)
    
    out <- prettyunits::pretty_bytes(
      bytes = bytes,
      style = style,
      smallest_unit = smallest_unit
    )
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "pretty_color") {
    color <- as.character(require_field("color", payload, fn_name))
    out <- prettyunits::pretty_color(color = color)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "pretty_dt") {
    dt <- require_field("dt", payload, fn_name)
    # Note: difftime objects are usually passed as numeric/seconds in JSON
    # but we treat the input as the raw value to be converted.
    dt_val <- as.numeric(dt)
    # Reconstruct a difftime object for the function
    dt_obj <- as.difftime(dt_val, units = "secs")
    
    compact <- if (is.null(payload$compact)) NULL else isTRUE(payload$compact)
    
    out <- prettyunits::pretty_dt(dt = dt_obj, compact = compact)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "pretty_ms") {
    ms <- as.numeric(require_field("ms", payload, fn_name))
    compact <- if (is.null(payload$compact)) NULL else isTRUE(payload$compact)
    
    out <- prettyunits::pretty_ms(ms = ms, compact = compact)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "pretty_p_value") {
    # Note: pretty_p_value is not in the UPSTREAM SIGNATURES block, 
    # but is in the SKILL.md. We implement it if it exists in the package.
    p_val <- as.numeric(require_field("x", payload, fn_name))
    
    # Check if function exists in package to avoid crash
    if (exists("pretty_p_value", where = asNamespace("prettyunits"))) {
      out <- prettyunits::pretty_p_value(x = p_val)
      emit_ok(as.character(out), fn_name)
    } else {
      emit_error("Function 'pretty_p_value' not found in prettyunits package.", fn_name)
    }
    
  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
