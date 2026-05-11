#!/usr/bin/env Rscript
# lme4 skill dispatcher.
# Reads one JSON object from stdin, invokes the requested lme4 function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_lme4     <- requireNamespace("lme4",     quietly = TRUE)
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
      "The R package 'jsonlite' is required by the lme4 skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_lme4) {
  emit_error(
    paste(
      "The R package 'lme4' is required but is not installed.",
      "Run: install.packages('lme4')."
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
  
  if (fn_name == "lmer") {
    formula <- as.character(require_field("formula", payload, fn_name))
    data    <- require_field("data", payload, fn_name)
    out <- lme4::lmer(formula = as.formula(formula), data = data)
    emit_ok(out, fn_name)

  } else if (fn_name == "glmer") {
    formula <- as.character(require_field("formula", payload, fn_name))
    data    <- require_field("data", payload, fn_name)
    family  <- if (is.null(payload$family)) NULL else as.character(payload$family)
    
    # Handle family string conversion to R family object
    fam_obj <- if (is.null(family)) NULL else do.call(stats::family, list(family))
    
    out <- lme4::glmer(formula = as.formula(formula), data = data, family = fam_obj)
    emit_ok(out, fn_name)

  } else if (fn_name == "allFit") {
    object <- require_field("object", payload, fn_name)
    
    # Extract optional arguments from upstream signature
    meth_tab <- payload$meth.tab
    data     <- payload$data
    verbose  <- if (is.null(payload$verbose)) NULL else as.logical(payload$verbose)
    show_meth_tab <- if (is.null(payload$show.meth.tab)) NULL else as.logical(payload$show.meth.tab)
    maxfun   <- if (is.null(payload$maxfun)) NULL else as.numeric(payload$maxfun)
    parallel <- if (is.null(payload$parallel)) NULL else as.character(payload$parallel)
    ncpus    <- if (is.null(payload$ncpus)) NULL else as.integer(payload$ncpus)
    cl       <- if (is.null(payload$cl)) NULL else payload$cl
    catch_errs <- if (is.null(payload$catch.errs)) NULL else as.logical(payload$catch.errs)
    start_from_mle <- if (is.null(payload$start_from_mle)) NULL else as.logical(payload$start_from_mle)

    # Build argument list for allFit
    args <- list(object = object)
    if (!is.null(meth_tab)) args$meth.tab <- meth_tab
    if (!is.null(data)) args$data <- data
    if (!is.null(verbose)) args$verbose <- verbose
    if (!is.null(show_meth_tab)) args$show.meth.tab <- show_meth_tab
    if (!is.null(maxfun)) args$maxfun <- maxfun
    if (!is.null(parallel)) args$parallel <- parallel
    if (!is.null(ncpurs)) args$ncpus <- ncpus # Note: signature says ncpus
    if (!is.null(ncpus)) args$ncpus <- ncpus
    if (!is.null(cl)) args$cl <- cl
    if (!is.null(catch_errs)) args$catch.errs <- catch_errs
    if (!is.null(start_from_mle)) args$start_from_mle <- start_from_mle

    out <- do.call(lme4::allFit, args)
    emit_ok(out, fn_name)

  } else if (fn_name == "bootMer") {
    x      <- require_field("x", payload, fn_name)
    # Note: FUN is passed as a string/name in JSON, but needs to be an R function
    # For this dispatcher, we assume the user provides a string name of a function in base/lme4
    FUN_name <- as.character(require_field("FUN", payload, fn_name))
    nsim   <- as.integer(require_field("nsim", payload, fn_name))
    seed   <- if (is.null(payload$seed)) NULL else as.integer(payload$seed)
    use_u  <- if (is.null(payload$use.u)) NULL else as.logical(payload$use.u)
    re_form <- if (is.null(payload$re.form)) NULL else payload$re.form
    type   <- if (is.null(payload$type)) NULL else as.character(payload$type)
    verbose <- if (is.null(payload$verbose)) NULL else as.logical(payload$verbose)
    progress <- if (is.null(payload$.progress)) NULL else as.character(payload$.progress)
    PBargs <- if (is.null(payload$PBargs)) NULL else payload$PBargs
    parallel <- if (is.null(payload$parallel)) NULL else as.character(payload$parallel)
    ncpus  <- if (is.null(payload$ncpus)) NULL else as.integer(payload$ncpus)
    cl     <- if (is.null(payload$cl)) NULL else payload$cl

    # Convert string name to actual function
    FUN_obj <- if (exists(FUN_name, mode = "function")) get(FUN_name) else NULL
    if (is.null(FUN_obj)) emit_error(sprintf("Function '%s' not found.", FUN_name), fn_name)

    args <- list(x = x, FUN = FUN_obj, nsim = nsim)
    if (!is.null(seed)) args$seed <- seed
    if (!is.null(use_u)) args$use.u <- use_u
    if (!is.null(re_form)) args$re.form <- re_form
    if (!is.null(type)) args$type <- type
    if (!is.null(verbose)) args$verbose <- verbose
    if (!is.null(progress)) args$.progress <- progress
    if (!is.null(PBargs)) args$PBargs <- PBargs
    if (!is.null(parallel)) args$parallel <- parallel
    if (!is.null(ncpus)) args$ncpus <- ncpus
    if (!is.null(cl)) args$cl <- cl

    out <- do.call(lme4::bootMer, args)
    emit_ok(out, fn_name)

  } else if (fn_name == "checkConv") {
    derivs <- if (is.null(payload$derivs)) NULL else payload$derivs
    coefs  <- if (is.null(payload$coefs)) NULL else payload$coefs
    ctrl   <- if (is.null(payload$ctrl)) NULL else payload$ctrl
    lbound <- if (is.null(payload$lbound)) NULL else as.numeric(payload$lbound)
    ubound <- if (is.null(payload$ubound)) NULL else as.numeric(payload$ubound)
    debug  <- if (is.null(payload$debug)) NULL else as.logical(payload$debug)
    nobs   <- if (is.null(payload$nobs)) NULL else as.integer(payload$nobs)
    ndim   <- if (is.null(payload$ndim)) NULL else as.integer(payload$ndim)

    args <- list()
    if (!is.null(derivs)) args$derivs <- derivs
    if (!is.null(coefs))  args$coefs  <- coefs
    if (!is.null(ctrl))   args$ctrl   <- ctrl
    if (!is.null(lbound)) args$lbound <- lbound
    if (!is.null(ubound)) args$ubound <- ubound
    if (!is.null(debug))  args$debug  <- debug
    if (!is.null(nobs))   args$nobs   <- nobs
    if (!is.null(ndim))   args$ndim   <- ndim

    out <- do.call(lme4::checkConv, args)
    emit_ok(out, fn_name)

  } else if (fn_name == "devcomp") {
    x <- require_field("x", payload, fn_name)
    out <- lme4::devcomp(x = x)
    emit_ok(out, fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
