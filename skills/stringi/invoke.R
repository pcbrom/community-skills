#!/usr/bin/env Rscript
# stringi skill dispatcher.
# Reads one JSON object from stdin, invokes the requested stringi function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_stringi  <- requireNamespace("stringi",  quietly = TRUE)
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
      "The R package 'jsonlite' is required by the stringi skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_stringi) {
  emit_error(
    paste(
      "The R package 'stringi' is required but is not installed.",
      "Run: install.packages('stringi')."
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
  
  if (fn_name == "stri_compare") {
    e1 <- as.character(require_field("e1", payload, fn_name))
    e2 <- as.character(require_field("e2", payload, fn_name))
    
    args <- list(e1 = e1, e2 = e2)
    
    if (!is.null(payload$opts_collator)) {
      args$opts_collator <- payload$opts_collator
    }
    
    # Handle additional ... arguments
    for (arg_name in names(payload)) {
      if (!(arg_name %in% c("fn", "e1", "e2", "opts_collator", "pattern"))) {
        args[[arg_name]] <- payload[[arg_name]]
      }
    }
    
    out <- do.call(stringi::stri_compare, args)
    emit_ok(as.integer(out), fn_name)

  } else if (fn_name == "stri_count") {
    str <- as.character(require_field("str", payload, fn_name))
    
    args <- list(str = str)
    
    # Handle pattern-style modes
    if (!is.null(payload$pattern)) args$pattern <- as.character(payload$pattern)
    if (!is.null(payload$regex))    args$regex    <- as.character(payload$regex)
    if (!is.null(payload$fixed))    args$fixed    <- as.character(payload$fixed)
    if (!is.null(payload$coll))     args$coll     <- as.character(payload$coll)
    if (!is.null(payload$charclass)) args$charclass <- as.character(payload$charclass)
    
    # Handle opts
    if (!is.null(payload$opts_collator)) args$opts_collator <- payload$opts_collator
    if (!is.null(payload$opts_fixed))    args$opts_fixed    <- payload$opts_fixed
    if (!is.null(payload$opts_regex))    args$opts_regex    <- payload$opts_regex
    
    # Fallback for pattern
    if (!is.null(payload$pattern) &&
        is.null(payload$regex) &&
        is.null(payload$fixed) &&
        is.null(payload$coll) &&
        is.null(payload$charclass)) {
      args$regex <- as.character(payload$pattern)
      args$pattern <- NULL
    }
    
    # Capture any other ... arguments
    for (arg_name in names(payload)) {
      if (!(arg_name %in% c("fn", "str", "pattern", "regex", "fixed", "coll", "charclass", 
                            "opts_collator", "opts_fixed", "opts_regex"))) {
        args[[arg_name]] <- payload[[arg_name]]
      }
    }
    
    out <- do.call(stringi::stri_count, args)
    emit_ok(as.integer(out), fn_name)

  } else if (fn_name == "stri_count_boundaries") {
    str <- as.character(require_field("str", payload, fn_name))
    type <- as.character(require_field("type", payload, fn_name))
    
    args <- list(str = str, type = type)
    
    if (!is.null(payload$locale)) args$locale <- as.character(payload$locale)
    if (!is.null(payload$opts_brkiter)) args$opts_brkiter <- payload$opts_brkiter
    
    for (arg_name in names(payload)) {
      if (!(arg_name %in% c("fn", "str", "type", "locale", "opts_brkiter"))) {
        args[[arg_name]] <- payload[[arg_name]]
      }
    }
    
    out <- do.call(stringi::stri_count_boundaries, args)
    emit_ok(as.integer(out), fn_name)

  } else if (fn_name == or_is_datetime_add <- "stri_datetime_add") {
    time <- as.character(require_field("time", payload, fn_name))
    value <- as.integer(require_field("value", payload, fn_name))
    units <- as.character(require_field("units", payload, fn_name))
    
    args <- list(time = time, value = value, units = units)
    
    if (!is.null(payload$tz)) args$tz <- as.character(payload$tz)
    if (!is.null(payload$locale)) args$locale <- as.character(payload$locale)
    
    for (arg_name in names(payload)) {
      if (!(arg_name %in% c("fn", "time", "value", "units", "tz", "locale"))) {
        args[[arg_name]] <- payload[[arg_name]]
      }
    }
    
    # Convert time to POSIXct as per requirement
    args$time <- as.POSIXct(args$time)
    
    out <- do.call(stringi::stri_datetime_add, args)
    emit_ok(as.character(out), fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
