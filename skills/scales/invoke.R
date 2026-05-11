#!/usr/bin/env Rscript
# scales skill dispatcher.
# Reads one JSON object from stdin, invokes the requested scales function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_scales   <- requireNamespace("scales",   quietly = TRUE)
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
      "The R package 'jsonlite' is required by the scales skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_scales) {
  emit_error(
    paste(
      "The R package 'scales' is required but is not installed.",
      "Run: install.packages('scales')."
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
  if (fn_name == "alpha") {
    colour <- as.character(require_field("colour", payload, fn_name))
    alpha  <- if (is.null(payload$alpha)) NULL else as.numeric(payload$alpha)
    
    # If alpha is NULL, we pass it as NA to let scales preserve existing alpha
    res <- scales::alpha(colour, alpha = if (is.null(alpha)) NA else alpha)
    emit_ok(as.character(res), fn_name)

  } else if (fn_name == "breaks_exp") {
    n <- as.integer(require_field("n", payload, fn_name))
    # ... is handled by passing remaining payload elements via do.call
    args <- payload[setdiff(names(payload), c("fn", "n"))]
    res <- do.call(scales::breaks_exp, c(list(n = n), as.list(args)))
    emit_ok(as.numeric(res), fn_name)

  } else if (fn_name == "breaks_extended") {
    n <- as.integer(require_field("n", payload, fn_name))
    args <- payload[setdiff(names(payload), c("fn", "n"))]
    res <- do.call(scales::breaks_extended, c(list(n = n), as.list(args)))
    emit_ok(as.numeric(res), fn_name)

  } else if (fn_name == "comma") {
    x <- as.numeric(require_field("x", payload, fn_name))
    res <- scales::comma(x)
    emit_ok(as.character(res), fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
