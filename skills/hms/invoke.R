#!/usr/bin/env Rscript
# hms skill dispatcher.
# Reads one JSON object from stdin, invokes the requested hms function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_hms      <- requireNamespace("hms",      quietly = TRUE)
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
      "The R package 'jsonlite' is required by the hms skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_hms) {
  emit_error(
    paste(
      "The R package 'hms' is required but is not installed.",
      "Run: install.packages('hms')."
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
  if (fn_name == "hms") {
    seconds <- if (is.null(payload$seconds)) NULL else as.numeric(payload$seconds)
    minutes <- if (is.null(payload$minutes)) NULL else as.numeric(payload$minutes)
    hours   <- if (is.null(payload$hours))   NULL else as.numeric(payload$hours)
    days    <- if (is.null(payload$days))    NULL else as.numeric(payload$days)
    
    # Note: hms constructor uses 'days' in the signature provided in the prompt
    # but the prompt's signature block lists 'days' while the SKILL.md says 'day'.
    # We follow the UPSTREAM SIGNATURES block: 'days'.
    
    # The constructor hms(seconds, minutes, hours, days)
    # We pass arguments only if they are not NULL to allow R to use defaults.
    args <- list()
    if (!is.null(seconds)) args$seconds <- seconds
    if (!is.null(minutes)) args$minutes <- minutes
    if (!is.null(hours))   args$hours   <- hours
    if (!is.null(days))    args$days    <- days
    
    out <- do.call(hms::hms, args)
    emit_ok(out, fn_name)

  } else if (fn_name == "parse_hms") {
    x <- as.character(require_field("x", payload, fn_name))
    out <- hms::parse_hms(x)
    emit_ok(out, fn_name)

  } else if (fn_name == "round_hms") {
    x      <- require_field("x", payload, fn_name)
    secs   <- if (is.null(payload$secs)) NULL else as.numeric(payload$secs)
    digits <- if (is.null(payload$digits)) NULL else as.integer(payload$digits)
    
    # The signature uses 'secs' for the multiple of seconds.
    args <- list(x = x)
    if (!is.null(secs)) args$secs <- secs
    if (!is.null(digits)) args$digits <- digits
    
    out <- do.call(hms::round_hms, args)
    emit_ok(out, fn_name)

  } else if (fn_name == "vec_cast.hms") {
    x <- require_field("x", payload, fn_name)
    to <- if (is.null(payload$to)) NULL else as.character(payload$to)
    
    # Handle dots (...) if present
    dots <- payload[setdiff(names(payload), c("fn", "x", "to"))]
    
    out <- do.call(hms::vec_cast.hms, c(list(x = x, to = to), dots))
    emit_ok(out, fn_name)

  } else if (fn_name == "as_hms") {
    # as_hms is not in the UPSTREAM SIGNATURES block, but is in SKILL.md.
    # However, as_hms is usually a wrapper for vec_cast.hms or similar.
    # Since no signature was provided for as_hms, we implement it via x.
    x <- require_field("x", payload, fn_name)
    # We use the logic of the provided signature for x.
    out <- hms::as_hms(x)
    emit_ok(out, fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
