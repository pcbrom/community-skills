#!/usr/bin/env Rscript
# RcppEigen skill dispatcher.
# Reads one JSON object from stdin, invokes the requested RcppEigen function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_RcppEigen <- requireNamespace("RcppEigen", quietly = TRUE)
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
      "The R package 'jsonlite' is required by the RcppEigen skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_RcppEigen) {
  emit_error(
    paste(
      "The R package 'RcppEigen' is required but is not installed.",
      "Run: install.packages('RcppEigen')."
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
  
  if (fn_name == "fastLm") {
    y <- as.numeric(require_field("y", payload, fn_name))
    X <- as.matrix(require_field("X", payload, fn_name))
    
    # Optional arguments
    formula <- if (!is.null(payload$formula)) as.formula(payload$formula) else NULL
    data <- if (!is.null(payload$data)) as.data.frame(payload$data) else NULL
    method <- if (!is.null(payload$method)) as.integer(payload$method) else NULL
    
    # Note: fastLm in RcppEigen uses specific arguments. 
    # We use the provided upstream signature.
    # Since the signature provided is for fastLm, we map the logic.
    # If formula/data are provided, we use them.
    
    res <- tryCatch({
      if (!is.null(formula) && !is.null(data)) {
        # If formula and data are both present, we use the formula interface
        # but the RcppEigen implementation usually expects X and y.
        # However, we follow the provided signature.
        RcppEigen::fastLm(formula = formula, data = data)
      } else if (!is.null(formula)) {
        RcppEigen::fastLm(formula = formula)
      } else {
        RcppEigen::fastLm(y = y, X = X)
      }
    }, error = function(e) e)
    
    if (inherits(res, "error")) {
      emit_error(conditionMessage(res), fn_name)
    }
    emit_ok(res, fn_name)

  } else if (fn_name == "RcppEigen.package.skeleton") {
    name <- as.character(require_field("name", payload, fn_name))
    
    # Optional arguments
    list_arg <- if (!is.null(payload$list)) as.character(payload$list) else NULL
    env_arg  <- if (!is.null(payload$environment)) payload$environment else NULL
    path_arg  <- if (!is.null(payload$path)) as.character(payload$path) else NULL
    force_arg <- if (!is.null(payload$force)) as.logical(payload$force) else NULL
    code_files_arg <- if (!is.null(payload$code_files)) as.character(payload$code_files) else NULL
    example_code_arg <- if (!is.null(payload$example_code)) as.logical(payload$example_code) else NULL
    
    res <- tryCatch({
      RcppEigen::RcppEigen.package.skeleton(
        name = name,
        list = list_arg,
        environment = env_arg,
        path = path_arg,
        force = force_arg,
        code_files = code_files_arg,
        example_code = example_code_arg
      )
      NULL
    }, error = function(e) e)
    
    if (inherits(res, "error")) {
      emit_error(conditionMessage(res), fn_name)
    }
    emit_ok(res, fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
