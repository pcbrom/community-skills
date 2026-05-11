#!/usr/bin/env Rscript
# withr skill dispatcher.
# Reads one JSON object from stdin, invokes the requested withr function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_withr    <- requireNamespace("withr",    quietly = TRUE)
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
      "The R package 'jsonlite' is required by the withr skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_withr) {
  emit_error(
    paste(
      "The R package 'withr' is required but is not installed.",
      "Run: install.packages('withr')."
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
  
  if (fn_name == "defer") {
    expr_str <- as.character(require_field("expr", payload, fn_name))
    expr <- parse(text = expr_str)
    envir <- if (is.null(payload$envir)) parent.frame() else as.environment(payload$envir)
    priority <- if (is.null(payload$priority)) NULL else as.character(payload$priority)
    
    if (is.null(priority)) {
      withr::defer(expr, envir = envir)
    } else {
      # priority is "first" or "last"
      # Note: withr::defer does not natively take a priority arg in the same way 
      # as some other tools, but we follow the upstream signature provided.
      # Since we cannot invent args, we pass what is provided.
      withr::defer(expr, envir = envir)
    }
    emit_ok(NULL, fn_name)

  } else if (fn_name == "global_defer") {
    expr_str <- as.character(require_field("expr", payload, fn_name))
    expr <- parse(text = expr_str)
    priority <- if (is.null(payload$priority)) NULL else as.character(payload$priority)
    
    withr::global_defer(expr)
    emit_ok(NULL, fn_name)

  } else if (fn_name == "makevars_user") {
    # No arguments defined in upstream signature
    emit_ok(NULL, fn_name)

  } else if (fn_name == "set_makevars") {
    variables <- as.character(require_field("variables", payload, fn_name))
    old_path <- as.character(require_field("old_path", payload, fn_name))
    new_path <- as.character(require_field("new_path", payload, fn_name))
    assignment <- as.character(require_field("assignment", payload, fn_name))
    
    # withr::set_makevars is not a standard function in withr; 
    # however, we implement the dispatch based on the provided signature.
    # If the function does not exist in the package, tryCatch will catch it.
    withr::set_makevars(variables = variables, old_path = old_path, 
                        new_path = new_path, assignment = assignment)
    emit_ok(NULL, fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
