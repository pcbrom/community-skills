#!/usr/bin/env Rscript
# lavaan skill dispatcher.
# Reads one JSON object from stdin, invokes the requested lavaan function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_lavaan   <- requireNamespace("lavaan",   quietly = TRUE)
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
      "The R package 'jsonlite' is required by the lavaan skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_lavaan) {
  emit_error(
    paste(
      "The R package 'lavaan' is required but is not installed.",
      "Run: install.packages('lavaan')."
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

# Helper to handle the common argument set for lavaan, cfa, sem, and growth
handle_lavaan_family <- function(payload, fn_name) {
  model <- as.character(require_field("model", payload, fn_name))
  
  # data is a data.frame. In JSON, this is often passed as a list of lists or similar.
  # We pass it through.
  data <- payload$data
  
  args <- list(model = model)
  if (!is.null(data)) args$data <- data
  
  # Optional arguments
  if (!is.null(payload$ordered)) args$ordered <- as.character(payload$ordered)
  if (!is.null(payload$sampling.weights)) args$sampling.weights <- as.character(payload$sampling.weights)
  if (!is.null(payload$sample.cov)) args$sample.cov <- as.numeric(payload$sample.cov)
  if (!is.null(payload$sample.mean)) args$sample.mean <- as.numeric(payload$sample.mean)
  if (!is.null(payload$sample.th)) args$sample.th <- as.numeric(payload$sample.th)
  if (!is.null(payload$sample.nobs)) args$sample.nobs <- as.numeric(payload$sample.nobs)
  if (!is.null(payload$group)) args$group <- as.character(payload$group)
  if (!is.null(payload$cluster)) args$cluster <- as.character(payload$cluster)
  if (!is.null(payload$constraints)) args$constraints <- as.character(payload$constraints)
  if (!is.null(payload$WLS.V)) args$WLS.V <- payload$WLS.V
  if (!is.null(payload$NACOV)) args$NACOV <- payload$NACOV
  if (!is.null(payload$ov.order)) args$ov.order <- as.character(payload$ov.order)
  
  # Slot overrides
  if (!is.null(payload$slotOptions)) args$slotOptions <- payload$slotOptions
  if (!is.null(payload$slotParTable)) args$slotParTable <- payload$slotParTable
  if (!is.null(payload$slotSampleStats)) args$slotSampleStats <- payload$slotSampleStats
  if (!is.null(payload$slotData)) args$slotData <- payload$slotData
  if (!is.null(payload$slotModel)) args$slotModel <- payload$slotModel
  if (!is.null(payload$slotCache)) args$slotCache <- payload$slotCache
  if (!is.null(payload$sloth1)) args$sloth1 <- payload$sloth1

  # Handle extra dots (...)
  # We look for keys in payload that are not in the explicit list above and not 'fn'
  known_keys <- c("fn", "model", "data", "ordered", "sampling.weights", "sample.cov", 
                  "sample.mean", "sample.th", "sample.nobs", "group", "cluster", 
                  "constraints", "WLS.V", "NACOV", "ov.order", "slotOptions", 
                  "slotParTable", "slotSampleStats", "slotData", "slotModel", 
                  "slotCache", "sloth1")
  
  extra_keys <- setdiff(names(payload), known_keys)
  for (k in extra_keys) {
    args[[k]] <- payload[[k]]
  }

  # Execute the function
  func <- if (fn_name == "cfa") lavaan::cfa else if (fn_name == "sem") lavaan::sem else if (fn_name == "growth") lavaan::growth else lavaan::lavaan
  
  res <- tryCatch(
    do.call(func, args),
    error = function(e) e
  )
  
  if (inherits(res, "error")) {
    emit_error(conditionMessage(res), fn_name)
  }
  
  # Return summary or object. For simplicity in JSON, we return the object's class/status.
  # In a real scenario, one might return summary(res).
  emit_ok(list(class = class(res), status = "fitted"), fn_name)
}

dispatch <- function(payload) {
  fn_name <- payload$fn
  
  if (fn_name %in% c("lavaan", "cfa", "sem", "growth")) {
    handle_lavaan_family(payload, fn_name)
  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
