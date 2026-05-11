#!/usr/bin/env Rscript
# magrittr skill dispatcher.
# Reads one JSON object from stdin, invokes the requested magrittr function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_magrittr <- requireNamespace("magrittr",  quietly = TRUE)
})

emit_error <- function(message_text, fn_name = NA_character_, code = 1L) {
  payload <- list(ok = FALSE, error = unname(message_text))
  if (!is.na(fn_name)) payload$fn <- fn_name
  sink(NULL, type = "output")  # restore stdout before writing the final JSON
  if (ok_jsonlite) {
    cat(jsonlite::toJSON(payload, auto_unbox = TRUE, na = "null"))
  } else {
    cat(sprintf('{"ok":false,"error":%s}',
                shQuote(message, type = "cmd")))
  }
  cat("\n")
  quit(status = code, save = "no")
}

if (!ok_jsonlite) {
  emit_error(
    paste(
      "The R package 'jsonlite' is required by the magrittr skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_magrittr) {
  emit_error(
    paste(
      "The R package 'magrittr' is required but is not installed.",
      "Run: install.packages('magrittr')."
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
  
  if (fn_name == "%>%") {
    # Note: The pipe operator is a syntax construct in R. 
    # In a JSON-based dispatch, we simulate the application of lhs to rhs.
    # Since we cannot inject syntax into the running R session, 
    # we treat this as a functional application if possible, 
    # but the pipe is primarily used for construction.
    # For the purpose of this dispatcher, we attempt to evaluate the rhs.
    lhs <- require_field("lhs", payload, fn_name)
    rhs_expr <- require_field("rhs", payload, fn_name)
    
    # We use a trick to evaluate the rhs in the context of lhs.
    # This is a simplified simulation of the pipe behavior.
    tryCatch({
      # We assume rhs is a string representing an expression or a value.
      # If rhs is a string, we parse it.
      res <- if(is.character(rhs_expr) && length(rhs_else) == 1) {
        eval(parse(text = rhs_expr), envir = list(x = lhs))
      } else {
        # If rhs is already an object (e.g. a function), apply it.
        rhs_expr(lhs)
      }
      emit_ok(res, fn_name)
    }, error = function(e) emit_error(conditionMessage(e), fn_name))

  } else if (fn_name == "freduce") {
    value <- require_field("value", payload, fn_name)
    function_list <- require_field("function_list", payload, fn_name)
    
    # function_list is expected to be a list of functions or strings to be parsed.
    # We convert strings to functions if necessary.
    funcs <- lapply(function_list, function(f) {
      if (is.character(f)) return(eval(parse(text = f)))
      return(f)
    })
    
    out <- value
    for (f in funcs) {
      out <- f(out)
    }
    emit_ok(out, fn_name)

  } else if (fn_name == "debug_pipe") {
    x <- require_field("x", payload, fn_name)
    # debug_pipe in magrittr is used for inspecting the pipe.
    # Here we return the value x.
    emit_ok(x, fn_name)

  } else if (fn::name == "functions") {
    fseq <- require_field("fseq", payload, fn_name)
    # fseq is a functional sequence.
    # We return the sequence as is.
    emit_ok(fseq, fn_name)

  } else if (fn_name == "debug_fseq") {
    fseq <- require_field("fseq", payload, fn_name)
    indices <- if (is.null(payload$indices)) integer(0) else as.integer(payload$indices)
    # Return the subset of the sequence for inspection.
    emit_ok(fseq[indices], fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
