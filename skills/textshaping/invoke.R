#!/usr/bin/env Rscript
# textshaping skill dispatcher.
# Reads one JSON object from stdin, invokes the requested textshaping function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_textshaping <- requireNamespace("textshaping", quietly = TRUE)
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
      "The R package 'jsonlite' is required by the textshaping skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_textshaping) {
  emit_error(
    paste(
      "The R package 'textshaping' is required but is not installed.",
      "Run: install.packages('textshaping')."
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
  
  if (fn_name == "get_font_features") {
    family <- as.character(require_field("family", payload, fn_name))
    italic <- if (is.null(payload$italic)) NULL else as.logical(payload$italic)
    path   <- if (is.null(payload$path)) NULL else as.character(payload$path)
    index  <- if (is.null(payload$index)) NULL else as.integer(payload$index)
    bold   <- if (is.null(payload$bold)) NULL else as.logical(payload$bold)
    
    # Note: 'bold' is deprecated in favor of 'weight', but kept for compatibility
    # if provided in the upstream signature.
    
    args <- list(family = family, italic = italic, path = path, index = index)
    if (!is.null(bold)) args$bold <- bold
    
    out <- textshaping::get_font_features(do.call(textshaping::get_font_features, args))
    # The function signature is actually textshaping::get_font_features(family, ...)
    # We use the args list to pass only non-NULL values.
    
    # Re-evaluating: the signature is family, italic, path, index, bold.
    # We must call it with the correct arguments.
    res <- textshaping::get_font_features(
      family = family,
      italic = italic,
      path = path,
      index = index,
      bold = bold
    )
    emit_ok(as.character(res), fn_name)

  } else if (fn_name == "lorem_text") {
    script <- if (is.null(payload$script)) NULL else as.character(payload$script)
    n      <- if (is.null(payload$n)) NULL else as.integer(payload$n)
    ltr    <- if (is.null(payload$ltr)) NULL else as.character(payload$ltr)
    rtl    <- if (is.null(payload$rtl)) NULL else as.character(payload$rtl)
    ltr_prop <- if (is.null(payload$ltr_prop)) NULL else as.numeric(payload$ltr_prop)
    
    out <- textshaping::lorem_text(
      script = script,
      n = n,
      ltr = ltr,
      rtl = rtl,
      ltr_prop = ltr_prop
    )
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "lorem_bidi") {
    out <- textshaping::lorem_bidi()
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "shape_text") {
    strings  <- as.character(require_field("strings", payload, fn_name))
    id       <- if (is.null(payload$id)) NULL else as.integer(payload$id)
    family   <- if (is.null(payload$family)) NULL else as.character(payload$family)
    italic   <- if (is.null(payload$italic)) NULL else as.logical(payload$italic)
    weight   <- if (is.null(payload$weight)) NULL else as.character(payload$weight)
    width    <- if (is.null(payload$width)) NULL else as.character(payload$width)
    features <- if (is.null(payload$features)) NULL else payload$features
    size     <- if (is.null(payload$size)) NULL else as.numeric(payload$size)
    res      <- if (is.null(payload$res)) NULL else as.numeric(payload$res)
    lineheight <- if (is.null(else_payload$lineheight)) NULL else as.numeric(payload$lineheight)
    # Note: The payload keys for shape_text in the JSON example (text, max_width) 
    # differ from the Upstream Signature (strings, max_width). 
    # Per instructions, we use the Upstream Signature names.
    
    # Re-mapping based on Upstream Signature:
    # strings, id, family, italic, weight, width, features, size, res, lineheight, align, hjust, vjust, max_width, tracking, indent, hanging, space_before, space_after, direction, path, index, bold
    
    # We must use the names from the UPSTREAM SIGNATURES block.
    # The JSON example in SKILL.md is secondary to the UPSTREAM SIGNATURES block.
    
    # Re-implementing shape_text logic using Upstream Signature names:
    args <- list(strings = strings, id = id, family = family, italic = italic, 
                 weight = weight, width = width, features = features, size = size, 
                 res = res, lineheight = if(is.null(payload$lineheight)) NULL else as.numeric(payload$lineheight),
                 align = if(is.null(payload$align)) NULL else as.character(payload$align),
                 hjust = if(is.null(payload$hjust)) NULL else as.numeric(payload$hjust),
                 vjust = if(is.null(payload$vjust)) NULL else as.numeric(payload$vjust),
                 max_width = if(is.null(payload$max_width)) NULL else as.numeric(payload$max_width),
                 tracking = if(is.null(payload$tracking)) NULL else as.numeric(payload$tracking),
                 indent = if(is.null(payload$indent)) NULL else as.numeric(payload$indent),
                 hanging = if(is.null(payload$hanging)) NULL else as.numeric(payload$hanging),
                 space_before = if(is.null(payload$space_before)) NULL else as.numeric(payload$space_before),
                 space_after = if(is.null(payload$space_after)) NULL else as.numeric(payload$space_after),
                 direction = if(is.null(payload$direction)) NULL else as.character(payload$direction),
                 path = if(is.null(payload$path)) NULL else as.character(payload$path),
                 index = if(is.null(payload$index)) NULL else as.integer(payload$index),
                 bold = if(is.null(payload$bold)) NULL else as.logical(payload$bold))
    
    # Filter NULLs for do.call
    args <- args[!vapply(args, is.null, logical(1))]
    
    out <- do.call(textshaping::shape_text, args)
    emit_ok(out, fn_name)

  } else if (fn_name == "plot_shape") {
    shape <- require_field("shape", payload, fn_name)
    out <- textshaping::plot_shape(shape = shape, id = if(is.null(payload$id)) NULL else as.integer(payload$id))
    emit_ok(as.logical(out), fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
