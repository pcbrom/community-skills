#!/usr/bin/env Rscript
# highr skill dispatcher.
# Reads one JSON object from stdin, invokes the requested highr function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_highr    <- requireNamespace("highr",    quietly = TRUE)
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
      "The R package 'jsonlite' is required by the highr skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_highr) {
  emit_error(
    paste(
      "The R package 'highr' is required but is not installed.",
      "Run: install.packages('highr')."
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
  if (fn_name == "hi_andre") {
    code   <- as.character(require_field("code",   payload, fn_name))
    lang   <- if (is.null(payload$language)) NULL else as.character(payload$language)
    format <- if (is.null(payload$format))   NULL else as.character(payload$format)
    
    args <- list(code = code)
    if (!is.null(lang))   args$language <- lang
    if (!is.null(format)) args$format   <- format
    
    out <- do.call(highr::hi_andre, args)
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "hi_html") {
    code <- require_field("code", payload, fn_name)
    # code can be string or array of strings
    if (is.character(code) && length(code) > 1) {
      code <- paste(code, collapse = "\n")
    }
    out <- highr::hi_html(code = as.character(code))
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "hi_latex") {
    code <- require_field("code", payload, fn_name)
    if (is.character(code) && length(code) > 1) {
      code <- paste(code, collapse = "\n")
    }
    out <- highr::hi_latex(code = as.character(code))
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "hilight") {
    code   <- require_field("code",   payload, fn_name)
    if (is.character(code) && length(code) > 1) {
      code <- paste(code, collapse = "\n")
    }
    
    args <- list(code = as.character(code))
    
    if (!is.null(payload$format)) {
      args$format <- as.character(payload$format)
    }
    if (!is.null(payload$markup)) {
      args$markup <- as.data.frame(payload$markup)
    }
    if (!is.null(payload$prompt)) {
      args$prompt <- as.logical(payload$prompt)
    }
    if (!is.null(payload$fallback)) {
      args$fallback <- as.logical(payload$fallback)
    }
    
    # Pass through any other arguments
    extra_args <- setdiff(names(payload), c("fn", "code", "format", "markup", "prompt", "fallback"))
    for (arg in extra_args) {
      args[[arg]] <- payload[[arg]]
    }
    
    out <- do.call(highr::hilight, args)
    emit_ok(as.character(out), fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
