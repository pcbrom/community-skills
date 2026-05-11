#!/usr/bin/env Rscript
# tidyselect skill dispatcher.
# Reads one JSON object from stdin, invokes the requested tidyselect function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_tidyselect <- requireNamespace("tidyselect", quietly = TRUE)
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
      "The R package 'jsonlite' is required by the tidyselect skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_tidyselect) {
  emit_error(
    paste(
      "The R package 'tidyselect' is required but is not installed.",
      "Run: install.packages('tidyselect')."
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
  
  if (fn_name == "all_of") {
    x <- as.character(require_field("x", payload, fn_name))
    # Note: ... is empty per requirements
    out <- tidyselect::all_of(x)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "any_of") {
    x <- as.character(require_field("x", payload, fn_name))
    out <- tidyselect::any_of(x)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "contains") {
    pattern <- as.character(require_field("contains", payload, fn_name))
    # Note: ... is empty per requirements
    out <- tidyselect::contains(pattern)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "starts_with") {
    prefix <- as.character(require_field("prefix", payload, fn_name))
    out <- tidyselect::starts_with(prefix)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "ends_with") {
    suffix <- as.character(require_field("suffix", payload, fn_name))
    out <- tidyselect::ends_with(suffix)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "everything") {
    # offset is optional
    offset <- if (is.null(payload$offset)) NULL else as.integer(payload$offset)
    out <- if (is.null(offset)) tidyselect::everything() else tidyselect::everything(offset = offset)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "eval_relocate") {
    expr <- payload$expr
    data <- payload$data
    before <- payload$before
    after <- payload$after
    strict <- if (is.null(payload$strict)) TRUE else isTRUE(payload$strict)
    name_spec <- payload$name_spec
    allow_rename <- if (is.null(payload$allow_rename)) TRUE else isTRUE(payload$allow_rename)
    allow_empty <- if (is.null(payload$allow_empty)) TRUE else isTRUE(payload$allow_empty)
    allow_predicates <- if (is.null(payload$allow_predicates)) TRUE else isTRUE(payload$allow_predicates)
    before_arg <- payload$before_arg
    after_arg <- payload$after_arg
    env <- payload$env
    error_call <- payload$error_call
    
    # Reconstruct call for eval_relocate
    # Since expr is defused R code (passed as string or list), we rely on the caller 
    # providing a format that can be evaluated or passed through.
    # For this dispatcher, we assume expr is passed in a way that tidyselect can use.
    
    # We must ensure data is present
    if (is.null(data)) emit_error("Field `data` is required for eval_relocate.", fn_name)
    
    # Note: eval_relocate is complex; we pass arguments through.
    # We use a simplified approach for the defused expr.
    res <- tidyselect::eval_relocate(
      expr = expr, data = data, before = before, after = after,
      strict = strict, name_spec = name_spec, allow_rename = allow_rename,
      allow_empty = allow_empty, allow_predicates = allow_predicates,
      before_arg = before_arg, after_arg = after_arg, env = env, error_call = error_call
    )
    emit_ok(as.character(res), fn_name)

  } else if (fn_name == "eval_rename") {
    expr <- payload$expr
    data <- payload$data
    env <- payload$env
    strict <- if (is.null(payload$strict)) TRUE else is.logical(payload$strict) && isTRUE(payload$strict)
    name_spec <- payload$name_spec
    allow_predicates <- if (is.null(payload$allow_predicates)) TRUE else is.logical(payload$allow_predicates) && isTRUE(payload$allow_predicates)
    error_call <- payload$error_call
    include <- if (is.null(payload$include)) NULL else as.character(payload$include)
    exclude <- if (is.null(payload$exclude)) NULL else as.character(payload$exclude)
    allow_rename <- if (is.null(payload$allow_rename)) TRUE else is.logical(payload$allow_rename) && isTRUE(payload$allow_rename)
    allow_empty <- if (is.null(payload$allow_empty)) TRUE else is.logical(payload$allow_empty) && isTRUE(payload$allow_empty)

    if (is.null(data)) emit_error("Field `data` is required for eval_rename.", fn_name)

    res <- tidyselect::eval_rename(
      expr = expr, data = data, env = env, strict = strict,
      name_spec = name_spec, allow_predicates = allow_predicates,
      error_call = error_call, include = include, exclude = exclude,
      allow_rename = allow_rename, allow_empty = allow_empty
    )
    emit_ok(as.character(res), fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
