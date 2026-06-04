#!/usr/bin/env Rscript
# gtsummary skill dispatcher.
# Reads one JSON object from stdin, invokes the requested gtsummary function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_gtsummary <- requireNamespace("gtsummary", quietly = TRUE)
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
      "The R package 'jsonlite' is required by the gtsummary skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_gtsummary) {
  emit_error(
    paste(
      "The R package 'gtsummary' is required but is not installed.",
      "Run: install.packages('gtsummary')."
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
  
  if (fn_name == "tbl_summary") {
    x        <- require_field("x", payload, fn_name)
    include  <- payload$include
    statistic <- payload$statistic
    missing  <- if (is.null(payload$missing)) NULL else as.character(payload$missing)
    
    args <- list(x = x)
    if (!is.null(include)) args$include <- include
    if (!is.null(statistic)) args$statistic <- statistic
    if (!is.null(missing)) args$missing <- missing
    
    out <- do.call(gtsummary::tbl_summary, args)
    emit_ok(out, fn_name)

  } else if (fn_name == "tbl_regression") {
    x <- require_field("x", payload, fn_name)
    out <- do.call(gtsummary::tbl_regression, list(x = x))
    emit_ok(out, fn_name)

  } else if (fn_name == "add_ci") {
    x       <- require_field("x", payload, fn_name)
    pattern <- if (!is.null(payload$pattern)) as.character(payload$pattern) else NULL
    
    args <- list(x = x)
    if (!is.null(pattern)) args$pattern <- pattern
    
    out <- do.call(gtsummary::add_ci, args)
    emit_ok(out, fn_name)

  } else if (fn_name == "add_difference") {
    x <- require_field("x", payload, fn_name)
    out <- do.call(gtsummary::add_difference, list(x = x))
    emit_ok(out, fn_name)

  } else if (fn_name == "add_difference_row") {
    x <- require_field("x", payload, fn_name)
    out <- do.call(gtsummary::add_difference_row, list(x = x))
    emit_ok(out, fn_name)

  } else if (fn_name == "add_global_p") {
    x        <- require_field("x", payload, fn_name)
    include  <- payload$include
    keep     <- if (is.null(payload$keep)) NULL else as.logical(payload$keep)
    anova_fun <- payload$anova_fun
    type     <- if (is.null(payload$type)) NULL else as.character(payload$type)
    
    args <- list(x = x)
    if (!is.null(include)) args$include <- include
    if (!is.null(keep)) args$keep <- keep
    if (!is.null(anova_fun)) args$anova_fun <- anova_fun
    if (!is.null(type)) args$type <- type
    
    out <- do.call(gtsummary::add_global_p, args)
    emit_ok(out, fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
