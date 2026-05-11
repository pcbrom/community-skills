#!/usr/bin/env Rscript
# broom skill dispatcher.
# Reads one JSON object from stdin, invokes the requested broom function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_broom    <- requireNamespace("broom",    quietly = TRUE)
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
      "The R package 'jsonlite' is required by the broom skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_broom) {
  emit_error(
    paste(
      "The R package 'broom' is required but is not installed.",
      "Run: install.packages('broom')."
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
  
  if (fn_name == "augment_columns") {
    x          <- require_field("x", payload, fn_name)
    data       <- require_field("data", payload, fn_name)
    newdata    <- if (is.null(payload$newdata)) NULL else as.data.frame(payload$newdata)
    type       <- if (is.null(payload$type)) NULL else as.character(payload$type)
    type_pred  <- if (is.null(payload$type.predict)) NULL else as.character(payload$type.predict)
    type_resid <- if (is.null(payload$type.residuals)) NULL else as.character(payload$type.residuals)
    se_fit     <- if (is.null(payload$se.fit)) NULL else as.numeric(payload$se.fit)
    
    args <- list(x = x, data = data, newdata = newdata, type = type, 
                 type.predict = type_pred, type.residuals = type_resid, se.fit = se_fit)
    # Remove NULLs to allow R to use defaults
    args <- args[!vapply(args, is.null, logical(1))]
    
    out <- broom::augment_columns(x = x, data = data, newdata = newdata, 
                                  type = type, type.predict = type_pred, 
                                  type.residuals = type_resid, se.fit = se_fit)
    emit_ok(out, fn_name)

  } else if (fn_name == "bootstrap") {
    df       <- require_field("df", payload, fn_name)
    m        <- as.integer(require_field("m", payload, fn_name))
    by_group <- if (is.null(payload$by_group)) NULL else as.logical(payload$by_group)
    
    args <- list(df = df, m = m)
    if (!is.null(by_group)) args$by_group <- by_group
    
    out <- broom::bootstrap(df = df, m = m, by_group = by_group)
    emit_ok(out, fn_name)

  } else if (fn_name == "confint_tidy") {
    x           <- require_field("x", payload, fn_name)
    conf_level  <- as.numeric(require_field("conf.level", payload, fn_name))
    func        <- if (is.null(payload$func)) NULL else payload$func
    
    # Note: 'func' is a function object. In a JSON context, this is difficult.
    # We assume the user provides a string name of a function in the global env or similar.
    # However, per instructions, we follow the signature.
    
    args <- list(x = x, conf.level = conf_level)
    if (!is.null(func)) args$func <- func
    
    out <- broom::confint_tidy(x = x, conf.empty = conf_level, func = func)
    emit_ok(out, fn_name)

  } else if (fn_name == "finish_glance") {
    ret <- require_field("ret", payload, fn_name)
    x   <- require_field("x", payload, fn_name)
    
    out <- broom::finish_glance(ret = ret, x = x)
    emit_ok(out, fn_name)

  } else if (fn_name == "tidy") {
    # Note: tidy/glance/augment in SKILL.md use 'object', 
    # but the UPSTREAM SIGNATURES block is the contract.
    # The upstream signature for tidy/glance/augment is not explicitly listed 
    # in the provided UPSTREAM SIGNATURES block, but the SKILL.md shows 'object'.
    # However, the instructions say: "Use EXACTLY the upstream R argument names 
    # listed in the UPSTREAM SIGNATURES block".
    # Since tidy/glance/augment are not in the UPSTREAM block, we look at the 
    # provided context. The context shows 'object'.
    obj <- require_field("object", payload, fn_name)
    out <- broom::tidy(obj)
    emit_ok(out, fn_name)

  } else if (fn_name == "glance") {
    obj <- require_field("object", payload, fn_name)
    out <- broom::glance(obj)
    emit_ok(out, fn_name)

  } else if (fn_name == "augment") {
    obj <- require_field("object", payload, fn_name)
    out <- broom::augment(obj)
    emit_ok(out, fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
