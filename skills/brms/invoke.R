#!/usr/bin/env Rscript
# brms skill dispatcher.
# Reads one JSON object from stdin, invokes the requested brms function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_brms     <- requireNamespace("brms",     quietly = TRUE)
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
      "The R package 'jsonlite' is required by the brms skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_brms) {
  emit_error(
    paste(
      "The R package 'brms' is required but is not installed.",
      "Run: install.packages('brms')."
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
  
  if (fn_name == "brm") {
    formula <- as.character(require_field("formula", payload, fn_name))
    data    <- require_field("data",    payload, fn_name)
    family  <- as.character(require_field("family",  payload, fn_name))
    prior   <- if (is.null(payload$prior))   NULL else payload$prior
    cores   <- if (is.null(payload$cores))   NULL else as.integer(payload$cores)
    chains  <- if (is.null(payload$chains))  NULL else as.integer(payload$chains)
    
    args <- list(formula = formula, data = data, family = family)
    if (!is.null(prior))  args$prior  <- prior
    if (!is.null(cores))  args$cores  <- cores
    if (!is.null(chains)) args$chains <- chains
    
    res <- tryCatch(do.call(brms::brm, args), error = function(e) e)
    if (inherits(res, "error")) emit_error(conditionMessage(res), fn_name)
    emit_ok(res, fn_name)

  } else if (fn_name == "add_criterion") {
    x           <- require_field("x",           payload, fn_name)
    criterion   <- as.character(require_field("criterion", payload, fn_name))
    model_name  <- if (is.null(payload$model_name))  NULL else as.character(payload$model_name)
    overwrite   <- if (is.null(payload$overwrite))   FALSE else as.logical(payload$overwrite)
    file        <- if (is.null(payload$file))        NULL else as.character(payload$file)
    force_save  <- if (is.null(payload$force_save))  NULL else as.logical(payload$force_save)
    
    args <- list(x = x, criterion = criterion)
    if (!is.null(model_name)) args$model_name <- model_name
    if (!is.null(overwrite))  args$overwrite  <- overwrite
    if (!is.null(file))       args$file       <- file
    if (!is.null(force_save)) args$force_save <- force_save
    
    # Note: ... is handled by passing remaining payload elements if they exist
    # but the contract specifies specific keys.
    
    res <- tryCatch(do.call(brms::add_criterion, args), error = function(e) e)
    if (inherinds(res, "error")) emit_error(conditionMessage(res), fn_name)
    emit_ok(res, fn_name)

  } else if (fn_name == "add_loo") {
    x          <- require_field("x",          payload, fn_name)
    ic         <- as.character(require_field("ic",         payload, fn_name))
    value      <- as.character(require_field("value",      payload, fn_name))
    model_name <- if (is.null(payload$model_name)) NULL else as.character(payload$model_name)
    
    args <- list(x = x, ic = ic, value = value)
    if (!is.null(model_name)) args$model_name <- model_name
    
    res <- tryCatch(do.call(brms::add_loo, args), error = function(e) e)
    if (inherits(res, "error")) emit_error(conditionMessage(res), fn_name)
    emit_ok(res, fn_name)

  } else if (fn_name == "R2D2") {
    mean_R2  <- as.numeric(require_field("mean_R2",  payload, fn_name))
    prec_R2  <- as.numeric(require_field("prec_R2",  payload, fn_name))
    cons_D2  <- as.numeric(require_field("cons_D2",  payload, fn_name))
    autoscale <- if (is.null(payload$autoscale)) TRUE else as.logical(payload$autoscale)
    main      <- if (is.null(payload$main))      FALSE else as.logical(payload$main)
    
    args <- list(mean_R2 = mean_R2, prec_R2 = prec_R2, cons_D2 = cons_D2)
    if (!is.null(autoscale)) args$autoscale <- autoscale
    if (!is.null(main))      args$main      <- main
    
    res <- tryCatch(do.call(brms::R2D2, args), error = function(e) e)
    if (inherits(res, "error")) emit_error(conditionMessage(res), fn_name)
    emit_ok(res, fn_name)

  } else if (fn_name == "add_rstan_model") {
    x         <- require_field("x", payload, fn_name)
    overwrite <- if (is.null(payload$overwrite)) FALSE else as.logical(payload$overwrite)
    
    args <- list(x = x, overwrite = overwrite)
    res <- tryCatch(do.call(brms::add_rstan_model, args), error = function(e) e)
    if (inherits(res, "error")) emit_error(conditionMessage(res), fn_name)
    emit_ok(res, fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
