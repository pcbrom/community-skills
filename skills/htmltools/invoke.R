#!/usr/bin/env Rscript
# htmltools skill dispatcher.
# Reads one JSON object from stdin, invokes the requested htmltools function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_htmltools <- requireNamespace("htmltools", quietly = TRUE)
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
      "The R package 'jsonlite' is required by the htmltools skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_htmltools) {
  emit_error(
    paste(
      "The R package 'htmltools' is required but is not installed.",
      "Run: install.packages('htmltools')."
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
  
  if (fn_name == "HTML") {
    # HTML(text, ..., .noWS = NULL)
    # Note: ... is handled by passing the rest of the payload
    text <- as.character(require_field("text", payload, fn_name))
    
    # Extract ... arguments
    # We identify keys that are not 'fn' or 'text' or '.noWS'
    all_keys <- names(payload)
    extra_keys <- setdiff(all_keys, c("fn", "text", ".noWS"))
    
    # Prepare args for HTML
    args <- list(text = text)
    for (key in extra_keys) {
      args[[key]] <- as.character(payload[[key]])
    }
    
    if (!is.null(payload$.noWS)) {
      args$.noWS <- as.character(payload$.noWS)
    }
    
    out <- do.call(htmltools::HTML, args)
    # HTML returns an HTML object; convert to character for JSON transport
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "as.tags") {
    # as.tags(x, ...)
    x <- payload$x
    # Since x can be 'any', we pass it as is. 
    # If it's a vector, we don't force type unless it's clearly numeric/int/char
    if (is.numeric(x)) x <- as.numeric(x)
    if (is.integer(x)) x <- as.integer(x)
    if (is.character(x)) x <- as.character(x)
    
    # Handle ...
    extra_keys <- setdiff(names(payload), c("fn", "x"))
    args <- list(x = x)
    for (key in extra_keys) {
      args[[key]] <- payload[[key]]
    }
    
    out <- do.call(htmltools::as.tags, args)
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "bindFillRole") {
    # bindFillRole(x, ..., item, container, overwrite, .cssSelector)
    x <- payload$x
    if (is.numeric(x)) x <- as.numeric(x)
    if (is.integer(x)) x <- as.integer(x)
    if (is.character(x)) x <- as.character(x)
    
    item <- if (is.null(payload$item)) NULL else as.logical(payload$item)
    container <- if (is.null(payload$container)) NULL else as.logical(payload$container)
    overwrite <- if (is.null(payload$overwrite)) NULL else as.logical(payload$overwrite)
    css_selector <- if (is.null(payload$.cssSelector)) NULL else as.character(payload$.cssSelector)
    
    args <- list(x = x)
    if (!is.null(item)) args$item <- item
    if (!is.null(container)) args$container <- container
    if (!is.null(overwrite)) args$overwrite <- overwrite
    if (!is.null(css_selector)) args$.cssSelector <- css_selector
    
    # Handle ... (currently unused per upstream, but we pass it if present)
    extra_keys <- setdiff(names(payload), c("fn", "x", "item", "container", "overwrite", ".cssSelector"))
    for (key in extra_keys) {
      args[[key]] <- payload[[key]]
    }
    
    out <- do.call(htmltools::bindFillRole, args)
    emit_ok(out, fn_name)

  } else if (fn_name == "browsable") {
    # browsable(x, value)
    x <- payload$x
    if (is.numeric(x)) x <- as.numeric(x)
    if (is.integer(x)) x <- as.integer(x)
    if (is.character(x)) x <- as.character(x)
    
    value <- if (is.null(payload$value)) NULL else payload$value
    
    args <- list(x = x)
    if (!is.null(value)) args$value <- value
    
    out <- do.call(htmltools::browsable, args)
    emit_ok(out, fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
