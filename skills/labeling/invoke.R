#!/usr/bin/env Rscript
# labeling skill dispatcher.
# Reads one JSON object from stdin, invokes the requested labeling function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_labeling <- requireNamespace("labeling", quietly = TRUE)
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
      "The R package 'jsonlite' is required by the labeling skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_labeling) {
  emit_error(
    paste(
      "The R package 'labeling' is required but is not installed.",
      "Run: install.packages('labeling')."
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
  if (fn_name == "heckbert") {
    dmin <- as.numeric(require_field("dmin", payload, fn_name))
    dmax <- as.numeric(require_field("dmax", payload, fn_name))
    m    <- as.integer(require_field("m",    payload, fn_name))
    out  <- labeling::heckbert(dmin = dmin, dmax = dmax, m = m)
    emit_ok(as.numeric(out), fn_name)
  } else if (fn_name == "wilkinson") {
    dmin        <- as.numeric(require_field("dmin",        payload, fn_name))
    dmax        <- as.numeric(require_field("dmax",        payload, fn_name))
    m           <- as.integer(require_field("m",           payload, fn_name))
    Q           <- if (is.null(payload$Q)) NULL else as.numeric(payload$Q)
    mincoverage <- if (is.null(payload$mincoverage)) NULL else as.numeric(payload$mincoverage)
    mrange      <- if (is.null(payload$mrange))      NULL else as.numeric(payload$mrange)
    
    args <- list(dmin = dmin, dmax = dmax, m = m)
    if (!is.null(Q))           args$Q           <- Q
    if (!is.null(mincoverage)) args$mincoverage <- mincoverage
    if (!is.null(mrange))      args$mrange      <- mrange
    
    out <- do.call(labeling::wilkinson, args)
    emit_ok(as.numeric(out), fn_name)
  } else if (fn_name == "extended") {
    dmin       <- as.numeric(require_field("dmin", payload, fn_name))
    dmax       <- as.numeric(require_field("dmax", payload, fn_name))
    m          <- as.integer(require_field("m",    payload, fn_name))
    Q          <- if (is.null(payload$Q)) NULL else as.numeric(payload$Q)
    only.loose <- if (is.null(payload$only.loose)) NULL else isTRUE(payload$only.loose)
    w          <- if (is.null(payload$w)) NULL else as.numeric(payload$w)
    
    args <- list(dmin = dmin, dmax = dmax, m = m)
    if (!is.null(Q))           args$Q           <- Q
    if (!is.null(only.loose))  args$only.loose  <- only.loose
    if (!is.null(w))           args$w           <- w
    
    out <- do.call(labeling::extended, args)
    emit_ok(as.numeric(out), fn_name)
  } else if (fn_name == "extended.figures") {
    samples <- as.integer(require_field("samples", payload, fn_name))
    out     <- labeling::extended.figures(samples = samples)
    emit_ok(out, fn_name)
  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
