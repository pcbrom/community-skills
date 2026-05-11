#!/usr/bin/env Rscript
# htmlwidgets skill dispatcher.
# Reads one JSON object from stdin, invokes the requested htmlwidgets function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_htmlwidgets <- requireNamespace("htmlwidgets", quietly = TRUE)
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
      "The R package 'jsonlite' is required by the htmlwidgets skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_htmlwidgets) {
  emit_error(
    paste(
      "The R package 'htmlwidgets' is required but is not installed.",
      "Run: install.packages('htmlwidgets')."
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
  
  if (fn_name == "JS") {
    js_code <- as.character(require_field("x", payload, fn_name))
    out <- htmlwidgets::JS(js_code)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "JSEvals") {
    evals <- as.list(require_field("list", payload, fn_name))
    out <- htmlwidgets::JSEvals(evals)
    emit_ok(as.list(out), fn_name)
    
  } else if (fn_name == "createWidget") {
    name <- as.character(require_field("name", payload, fn_name))
    x    <- require_field("x", payload, fn_name)
    
    # Optional arguments
    width        <- if (is.null(payload$width)) NULL else as.numeric(payload$width)
    height       <- if (is.null(payload$height)) NULL else as.numeric(payload$height)
    sizingPolicy <- if (is.null(payload$sizingPolicy)) NULL else payload$sizingPolicy
    package      <- if (is.null(payload$package)) name else as.character(payload$package)
    dependencies <- if (is.null(payload$dependencies)) NULL else payload$dependencies
    elementId    <- if (is.null(payload$elementId)) NULL else as.character(payload$elementId)
    preRenderHook <- if (is.null(payload$preRenderHook)) NULL else payload::as.function(payload$preRenderHook)

    out <- htmlwidgets::createWidget(
      name = name,
      x = x,
      width = width,
      height = height,
      sizingPolicy = sizingPolicy,
      package = package,
      dependencies = dependencies,
      elementId = elementId,
      preRenderHook = preRenderHook
    )
    emit_ok(as.list(out), fn_name)
    
  } else if (fn_name == "getDependency") {
    name    <- as.character(require_field("name", payload, fn_name))
    package <- if (is.null(payload$package)) name else as.character(payload$package)
    
    out <- htmlwidgets::getDependency(name = name, package = package)
    emit_ok(as.list(out), fn_name)
    
  } else if (fn_name == "saveWidget") {
    x             <- require_field("x", payload, fn_name)
    file          <- as.character(require_field("file", payload, fn_name))
    selfcontained <- if (is.null(payload$selfcontained)) TRUE else isTRUE(payload$selfcontained)
    
    out <- htmlwidgets::saveWidget(x = x, file = file, selfcontained = selfcontained)
    emit_ok(asTRUE(out), fn_name)
    
  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
