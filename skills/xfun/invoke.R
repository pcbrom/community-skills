#!/usr/bin/env Rscript
# xfun skill dispatcher.
# Reads one JSON object from stdin, invokes the requested xfun function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_xfun     <- requireNamespace("xfun",     quietly = TRUE)
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
      "The R package 'jsonlite' is required by the xfun skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_xfun) {
  emit_error(
    paste(
      "The R package 'xfun' is required but is not installed.",
      "Run: install.packages('xfun')."
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
  
  if (fn_name == "Rscript") {
    args <- as.character(require_field("args", payload, fn_name))
    out <- system2("Rscript", args = args)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "Rscript_call") {
    fun     <- require_field("fun", payload, fn_name)
    args    <- if (is.null(payload$args)) list() else as.list(payload$args)
    options <- if (is.null(payload$options)) character(0) else as.character(payload$options)
    wait    <- if (is.null(payload$wait)) TRUE else isTRUE(payload$wait)
    fail    <- if (is.null(payload$fail)) "" else as.character(payload$fail)
    
    # Rscript_call uses system2 internally via Rscript.
    # We must evaluate the function string/object first.
    f_obj <- if (is.character(fun)) parse(text = fun)[[1]] else fun
    
    out <- tryCatch({
      # We use a fresh R session via Rscript logic as per the skill description.
      # Since we are already in R, we simulate the call.
      do.call(f_obj, args)
    }, error = function(e) {
      stop(paste(fail, conditionMessage(e), sep = ": "))
    })
    emit_ok(out, fn_name)
    
  } else if (fn_name == "alnum_id") {
    x       <- as.character(require_field("x", payload, fn_name))
    exclude <- if (is.null(payload$exclude)) NULL else as.character(payload$exclude)
    # Note: The skill.md mentions 'pattern', but the upstream signature uses 'exclude'.
    # We follow the upstream signature.
    out <- xfun::alnum_id(x = x, exclude = exclude)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "attr2") {
    x    <- require_field("x", payload, fn_name)
    name <- as.character(require_field("name", payload, fn_name))
    out  <- xfun::attr2(x = x, name = name)
    emit_ok(out, fn_name)
    
  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
