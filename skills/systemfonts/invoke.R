#!/usr/bin/env Rscript
# systemfonts skill dispatcher.
# Reads one JSON object from stdin, invokes the requested systemfonts function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_systemfonts <- requireNamespace("systemfonts", quietly = TRUE)
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
      "The R package 'jsonlite' is required by the systemfonts skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_systemfonts) {
  emit_error(
    paste(
      "The R package 'systemfonts' is required but is not installed.",
      "Run: install.packages('systemfonts')."
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
  
  if (fn_name == "add_fonts") {
    files <- as.character(require_field("files", payload, fn_name))
    out <- systemfonts::add_fonts(files = files)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "as_font_weight") {
    weight <- as.character(require_field("weight", payload, fn_name))
    width  <- if (!is.null(payload$width)) as.character(payload$width) else NULL
    
    # Note: The upstream signature uses 'weight' and 'width'
    # The payload keys are mapped from the signature.
    out <- systemfonts::as_font_weight(weight = weight, width = width)
    emit_ok(as.numeric(out), fn_name)
    
  } else if (fn_name == "font_fallback") {
    string  <- as.character(require_field("string", payload, fn_name))
    family  <- if (!is.null(payload$family)) as.character(payload$family) else NULL
    italic  <- if (!is.null(payload$italic)) as.logical(payload$italic) else NULL
    weight  <- if (!is.null(payload$weight)) payload$weight else NULL
    width   <- if (!is.null(payload$width)) payload$width else NULL
    path    <- if (!is.null(payload$path)) as.character(payload$path) else NULL
    index   <- if (!is.null(payload$index)) as.integer(payload$index) else NULL
    variation <- if (!is.null(payload$variation)) payload$variation else NULL
    bold    <- if (!is.null(payload$bold)) payload$bold else NULL
    
    out <- systemfonts::font_fallback(
      string = string,
      family = family,
      italic = italic,
  	  weight = weight,
  	  width = width,
  	  path = path,
  	  index = index,
  	  variation = variation,
  	  bold = bold
    )
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "font_feature") {
    # The signature uses ligatures, letters, numbers, and ...
    # We pass the payload elements directly to the ellipsis.
    # We must extract the specific named arguments.
    ligatures <- if (!is.null(payload$ligatures)) payload$ligatures else NULL
    letters   <- if (!is.null(payload$letters)) payload$letters else NULL
    numbers   <- if (!is.null(payload$numbers)) payload$numbers else NULL
    
    # Collect all other keys as the ... arguments
    extra_args <- list()
    all_keys <- names(payload)
    reserved <- c("fn", "ligatures", "letters", "numbers")
    for (key in all_keys) {
      if (!(key %in% reserved)) {
        extra_args[[key]] <- payload[[key]]
      }
    }
    
    out <- systemfonts::font_feature(
      ligatures = ligatures,
      letters = letters,
      numbers = numbers,
      ... = extra_args
    )
    emit_ok(out, fn_name)
    
  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
