#!/usr/bin/env Rscript
# survival skill dispatcher.
# Reads one JSON object from stdin, invokes the requested survival function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_survival <- requireNamespace("survival", quietly = TRUE)
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
      "The R package 'jsonlite' is required by the survival skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_survival) {
  emit_error(
    paste(
      "The R package 'survival' is required but is not installed.",
      "Run: install.packages('survival')."
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
  
  if (fn_name == "Surv") {
    time  <- as.numeric(require_field("time",  payload, fn_name))
    event <- as.integer(require_field("event", payload, fn_name))
    # type, origin are optional
    type   <- if (is.null(payload$type)) NULL else as.character(payload$type)
    origin <- if (is.null(payload$origin)) NULL else as.character(payload$origin)
    
    args <- list(time = time, event = event)
    if (!is.null(type)) args$type <- type
    if (!is.null(origin)) args$origin <- origin
    
    out <- do.call(survival::Surv, args)
    emit_ok(out, fn_name)

  } else if (fn_name == "Surv2") {
    time    <- as.numeric(require_field("time", payload, fn_name))
    event   <- as.integer(require_field("event", payload, fn_name))
    repeated <- if (is.null(payload$repeated)) NULL else as.logical(payload$repeated)
    
    args <- list(time = time, event = event)
    if (!is.null(repeated)) args$repeated <- repeated
    
    out <- do.call(survival::Surv2, args)
    emit_ok(out, fn_name)

  } else if (fn_name == "Surv2data") {
    formula <- as.character(require_field("formula", payload, fn_name))
    data    <- require_field("data", payload, fn_name)
    
    args <- list(formula = as.formula(formula), data = data)
    if (!is.null(payload$subset)) args$subset <- payload$subset
    if (!is.null(payload$id))     args$id     <- payload$id
    
    out <- do.call(survival::Surv2data, args)
    emit_ok(out, fn_name)

  } else if (fn_name == "coxph") {
    formula <- as.character(require_field("formula", payload, fn_name))
    data    <- require_field("data", payload, fn_name)
    
    args <- list(formula = as.formula(formula), data = data)
    
    out <- do.call(survival::coxph, args)
    emit_ok(out, fn_name)

  } else if (fn_name == "survfit") {
    formula <- as.character(require_field("formula", payload, fn_name))
    data    <- require_field("data", payload, fn_name)
    
    args <- list(formula = as.formula(formula), data = as.data.frame(data))
    
    out <- do.call(survival::survfit, args)
    emit_ok(out, fn_name)

  } else if (fn_name == "aeqSurv") {
    x         <- require_field("x", payload, fn_name)
    tolerance <- if (is.null(payload$tolerance)) NULL else as.numeric(payload$tolerance)
    
    args <- list(x = x)
    if (!is.null(tolerance)) args$tolerance <- tolerance
    
    out <- do.call(survival::aeqSurv, args)
    emit_ok(out, fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
