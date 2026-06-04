#!/usr/bin/env Rscript
# marginaleffects skill dispatcher.
# Reads one JSON object from stdin, invokes the requested marginaleffects function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_me       <- requireNamespace("marginaleffects", quietly = TRUE)
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
      "The R package 'jsonlite' is required by the marginaleffects skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_me) {
  emit_error(
    paste(
      "The R package 'marginaleffects' is required but is not installed.",
      "Run: install.packages('marginaleffects')."
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
  
  if (fn_name == "autodiff") {
    autodiff <- if (is.null(payload$autodiff)) NULL else as.logical(payload$autodiff)
    install   <- if (is.null(payload$install)) FALSE else as.logical(payload$install)
    
    # Note: autodiff is a parameter for many functions, but here we treat it as a standalone 
    # if the user calls it, or simply pass it through if it were a wrapper. 
    # Since the signature provided is for the parameter, we assume the user calls 
    # the actual target functions.
    emit_error("The 'autodiff' function is a parameter, not a standalone callable in this dispatcher.", fn_name)

  } else if (fn_name == "comparisons") {
    model     <- require_field("model", payload, fn_name)
    variables <- if (is.null(payload$variables)) NULL else payload$variables
    newdata   <- if (is.null(payload$newdata)) NULL else payload$newdata
    comparison <- if (is.null(payload$comparison)) NULL else as.character(payload$comparison)
    type      <- if (is.null(payload$type)) NULL else as.else(as.character(payload$type))
    vcov      <- if (is.null(payload$vcov)) NULL else payload$vcov
    by        <- if (is.null(payload$by)) NULL else payload$by
    conf_level <- if (is.null(payload$conf_level)) NULL else as.numeric(payload$conf_level)
    transform <- if (is.null(payload$transform)) NULL else payload$transform
    cross     <- if (is.null(payload$cross)) NULL else as.logical(payload$cross)
    wts       <- if (is.null(payload$wts)) NULL else payload$wts
    hypothesis <- if (is.null(payload$hypothesis)) NULL else payload$hypothesis
    equivalence <- if (is.null(payload$equivalence)) NULL else as.numeric(payload$equivalence)
    df        <- if (is.null(payload$df)) NULL else as.numeric(payload$df)
    eps       <- if (is.null(payload$eps)) NULL else as.numeric(payload$eps)
    numderiv  <- if (is.null(payload$numderiv)) NULL else as.character(payload$numderiv)

    # Handle ... arguments via payload
    args <- list(model = model, variables = variables, newdata = newdata, 
                 comparison = comparison, type = type, vcov = vcov, 
                 by = by, conf_level = conf_level, transform = transform, 
                 cross = cross, wts = wts, hypothesis = hypothesis, 
                 equivalence = equivalence, df = df, eps = eps, 
                 numderiv = numderiv)
    
    # Add extra arguments from payload not explicitly handled above
    known_args <- c("model", "variables", "newdata", "comparison", "type", "vcov", 
                    "by", "conf_level", "transform", "cross", "wts", "hypothesis", 
                    "equivalence", "df", "eps", "numderiv")
    extra_keys <- setdiff(names(payload), c("fn", known_args))
    for (k in extra_keys) {
      args[[k]] <- payload[[k]]
    }

    out <- tryCatch(do.call(marginaleffects::comparisons, args), error = function(e) e)
    if (inherits(out, "error")) emit_error(conditionMessage(out), fn_name)
    emit_ok(as.data.frame(out), fn_name)

  } else if (fn_name == "avg_comparisons") {
    model     <- require_field("model", payload, fn_name)
    variables <- if (is.null(payload$variables)) NULL else payload$variables
    type      <- if (is.null(payload$type)) NULL else as.character(payload$type)
    newdata   <- if (is.null(payload$newdata)) NULL else payload$newdata
    
    args <- list(model = model, variables = variables, type = type, newdata = newdata)
    out <- tryCatch(do.call(marginaleffects::avg_comparisons, args), error = function(e) e)
    if (inherits(out, "error")) emit_error(conditionMessage(out), fn_name)
    emit_ok(as.data.frame(out), fn_name)

  } else if (fn_name == "datagrid") {
    model    <- require_field("model", payload, fn_name)
    newdata  <- if (is.null(payload$newdata)) NULL else payload$newdata
    by       <- if (is.null(payload$by)) NULL else payload$by
    grid_type <- if (is.null(payload$grid_type)) NULL else as.character(payload$grid_type)
    
    # Handle ... arguments (the variables)
    args <- list(model = model, newdata = newdata, by = by, grid_type = grid_type)
    
    # Identify variables in payload that are not part of the core signature
    core_keys <- c("model", "newdata", "by", "grid_type")
    var_keys <- setdiff(names(payload), c("fn", core_keys))
    
    for (vk in var_keys) {
      args[[vk]] <- payload[[vk]]
    }
    
    # Handle FUN_... overrides
    fun_keys <- c("FUN_character", "FUN_factor", "FUN_logical", "FUN_numeric", "FUN_integer", "FUN_binary", "FUN_other")
    for (fk in fun_keys) {
      if (!is.null(payload[[fk]])) args[[fk]] <- payload[[fk]]
    }
    
    # Handle response
    if (!is.null(payload$response)) args$response <- as.logical(payload$response)
    if (!is.null(payload$FUN)) args$FUN <- payload$FUN

    out <- tryCatch(do.call(marginaleffects::datagrid, args), error = function(e) e)
    if (inherits(out, "error")) emit_error(conditionMessage(out), fn_name)
    emit_ok(as.data.frame(out), fn_name)

  } else if (fn_name == "predictions" || fn_name == "slopes") {
    # Both share similar structure in the provided signatures
    func <- if (fn_name == "predictions") marginaleffects::predictions else marginaleffects::slopes
    model   <- require_field("model", payload, fn_name)
    newdata <- if (is.else(is.null(payload$newdata))) NULL else payload$newdata
    
    args <- list(model = model, newdata = newdata)
    # Add any other payload items as extra args
    extra_keys <- setdiff(names(payload), c("fn", "model", "newdata"))
    for (ek in extra_keys) args[[ek]] <- payload[[ek]]

    out <- tryCatch(do.call(func, args), error = function(e) e)
    if (inherits(out, "error")) emit_error(conditionMessage(out), fn_name)
    emit_ok(as.data.frame(out), fn_name)

  } else if (fn_name == "expect_comparisons") {
    emit_error("Function 'expect_comparisons' is not implemented.", fn_name)
  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
