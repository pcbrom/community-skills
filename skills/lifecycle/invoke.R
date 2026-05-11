#!/usr/bin/env Rscript
# lifecycle skill dispatcher.
# Reads one JSON object from stdin, invokes the requested lifecycle function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_lifecycle <- requireNamespace("lifecycle", quietly = TRUE)
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
      "The R package 'jsonlite' is required by the lifecycle skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_lifecycle) {
  emit_error(
    paste(
      "The R package 'lifecycle' is required but is not installed.",
      "Run: install.packages('lifecycle')."
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
  
  if (fn_name == "badge") {
    stage <- as.character(require_field("stage", payload, fn_name))
    # Note: The upstream signature uses 'stage', SKILL.md uses 'status'.
    # We follow the upstream signature as per instructions.
    out <- lifecycle::badge(stage = stage)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "deprecate_soft") {
    when <- as.character(require_field("when", payload, fn_name))
    what <- as.character(require_field("what", payload, fn_name))
    
    # Optional arguments
    details <- if (is.null(payload$details)) NULL else as.character(payload$details)
    with_val <- if (is.null(payload$with)) NULL else as.character(payload$with)
    id <- if (is.null(payload$id)) NULL else as.character(payload$id)
    env <- if (is.null(payload$env)) NULL else payload$env
    user_env <- if (is.null(payload$user_env)) NULL else payload$user_env
    always <- if (is.null(payload$always)) NULL else as.logical(payload$always)
    
    # Construct args list to avoid passing NULLs to functions that don't expect them
    args <- list(when = when, what = what)
    if (!is.null(details)) args$details <- details
    if (!is.null(with_val)) args$with <- with_val
    if (!is.null(id)) args$id <- id
    if (!is.null(env)) args$env <- env
    if (!is.null(user_env)) args$user_env <- user_env
    if (!is.null(always)) args$always <- always
    
    out <- do.call(lifecycle::deprecate_soft, args)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "deprecated") {
    arg <- as.character(require_field("arg", payload, fn_name))
    out <- lifecycle::deprecated(arg = arg)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "expect_deprecated") {
    expr_str <- as.character(require_field("expr", payload, fn_name))
    regexp <- if (is.null(payload$regexp)) NULL else as.character(payload$regexp)
    fixed <- if (is.null(payload$fixed)) NULL else as.logical(payload$fixed)
    
    # We evaluate the expression string in the current environment
    expr_obj <- parse(text = expr_str)[[1]]
    
    # Note: expect_deprecated is a testthat-style function. 
    # It usually throws an error/warning rather than returning a value.
    # We wrap the call in tryCatch in the main body.
    res <- tryCatch({
      if (is.null(regexp)) {
        if (is.null(fixed)) {
          lifecycle::expect_deprecated(expr_obj)
        } else {
          lifecycle::expect_deprecated(expr_obj, fixed = fixed)
        }
      } else {
        lifecycle::expect_deprecated(expr_obj, regexp = regexp, fixed = fixed)
      }
      TRUE
    }, error = function(e) {
      # If it fails, it's an expected failure for the test, but we return the error
      stop(e)
    })
    emit_ok(res, fn_name)
    
  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKIM.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
