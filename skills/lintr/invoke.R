#!/usr/bin/env Rscript
# lintr skill dispatcher.
# Reads one JSON object from stdin, invokes the requested lintr function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_lintr    <- requireNamespace("lintr",    quietly = TRUE)
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
      "The R package 'jsonlite' is required by the lintr skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_lintr) {
  emit_error(
    paste(
      "The R package 'lintr' is required but is not installed.",
      "Run: install.packages('lintr')."
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
  if (fn_name == "lint") {
    text <- as.character(require_field("text", payload, fn_name))
    linters <- if (is.null(payload$linters)) NULL else payload$linters
    
    # lintr::lint accepts a file path or a source file object.
    # For text input, we use a temporary file to ensure lintr can parse it.
    tmp <- tempfile(fileext = ".R")
    writeLines(text, tmp)
    on.exit(unlink(tmp), add = TRUE)
    
    out <- tryCatch(
      lintr::lint(file = tmp, linters = linters),
      error = function(e) e
    )
    
    if (inherits(out, "error")) {
      emit_error(conditionMessage(out), fn_name)
    } else {
      # Convert lint objects to a list/array format for JSON output
      res_list <- lapply(out, function(l) {
        list(
          line = l$line_number,
          column = l$column_number,
          type = l$type,
          message = l$message
        )
      })
      emit_ok(res_list, fn_name)
    }
    
  } else if (fn_name == "lint_dir") {
    path <- as.character(require_field("path", payload, fn_name))
    out <- tryCatch(
      lintr::lint_dir(path = path),
      error = function(e) e
    )
    
    if (inherits(out, "error")) {
      emit_error(conditionMessage(out), fn_name)
    } else {
      res_list <- lapply(out, function(l) {
        list(
          file = l$filename,
          line = l$line_number,
          column = l$column_number,
          type = l$type,
          message = l$message
        )
      })
      emit_ok(res_list, fn_name)
    }
    
  } else if (fn_name == "lint_package") {
    package <- as.character(require_field("package", payload, fn_name))
    out <- tryCatch(
      lintr::lint_package(package = package),
      error = function(e) e
    )
    
    if (inherits(out, "error")) {
      emit_error(conditionMessage(out), fn_name)
    } else {
      res_list <- lapply(out, function(l) {
        list(
          file = l$filename,
          line = l$line_number,
          column = l$column_number,
          type = l$type,
          message = l$message
        )
      })
      emit_ok(res_list, fn_name)
    }
    
  } else if (fn_name == "T_and_F_symbol_linter") {
    # No arguments defined in upstream signature
    out <- tryCatch(
      lintr::T_and_F_symbol_linter(),
      error = function(e) e
    )
    if (inherits(out, "error")) {
      emit_error(conditionMessage(out), fn_name)
    } else {
      emit_ok(as.character(out), fn_name)
    }
    
  } else if (fn_name == "absolute_path_linter") {
    lax <- if (is.null(payload$lax)) NULL else as.logical(payload$lax)
    
    # Note: absolute_path_linter is a linter object factory.
    # We assume the user wants the linter object itself or its application.
    # Since the skill context implies checking code, we treat this as 
    # returning the linter configuration.
    out <- tryCatch(
      lintr::absolute_path_linter(lax = lax),
      error = function(e) e
    )
    
    if (inherits(out, "error")) {
      emit_error(conditionMessage(out), fn_name)
    } else {
      emit_ok(as.character(out), fn_name)
    }
    
  } else if (fn_name == "all_equal_linter") {
    out <- tryCatch(
      lintr::all_equal_linter(),
      error = function(e) e
    )
    if (inherits(out, "error")) {
      emit_error(conditionMessage(out), fn_name)
    } else {
      emit_ok(as.character(out), fn_name)
    }
    
  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
