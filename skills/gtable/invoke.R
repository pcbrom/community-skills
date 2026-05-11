#!/usr/bin/env Rscript
# gtable skill dispatcher.
# Reads one JSON object from stdin, invokes the requested gtable function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_gtable   <- requireNamespace("gtable",   quietly = TRUE)
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
      "The R package 'jsonlite' is required by the gtable skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_gtable) {
  emit_error(
    paste(
      "The R package 'gtable' is required but is not installed.",
      "Run: install.packages('gtable')."
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
  
  if (fn_name == "as.gtable") {
    x <- require_field("x", payload, fn_name)
    out <- gtable::as.gtable(x = x)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "gtable") {
    widths  <- if (is.null(payload$widths)) NULL else as.numeric(payload$widths)
    heights <- if (is.null(payload$heights)) NULL else as.numeric(payload$heights)
    respect <- if (is.null(payload$respect)) NULL else as.logical(payload$respect)
    name    <- if (is.null(payload$name)) NULL else as.character(payload$name)
    rownames <- if (is.null(payload$rownames)) NULL else as.character(payload$rownames)
    colnames <- if (is.null(payload$colnames)) NULL else as.character(payload$colnames)
    vp      <- if (is.null(payload$vp)) NULL else payload$vp
    
    # Construct args list to allow R to use defaults for NULL values
    args <- list()
    if (!is.null(widths))  args$widths  <- widths
    if (!is.null(heights)) args$heights <- heights
    if (!is.null(respect)) args$respect <- respect
    if (!is.null(name))    args$name    <- name
    if (!is.null(rownames)) args$rownames <- rownames
    if (!is.null(colnames)) args$colnames <- colnames
    if (!is.null(vp))      args$vp      <- vp
    
    out <- do.call(gtable::gtable, args)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "gtable_add_cols") {
    x      <- require_field("x", payload, fn_name)
    widths <- as.numeric(require_field("widths", payload, fn_name))
    pos    <- if (is.null(payload$pos)) NULL else as.integer(payload$pos)
    
    args <- list(x = x, widths = widths)
    if (!is.null(pos)) args$pos <- pos
    
    out <- do.call(gtable::gtable_add_cols, args)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "gtable_add_grob") {
    x      <- require_field("x", payload, fn_name)
    grobs  <- require_field("grobs", payload, fn_name)
    t      <- as.numeric(require_field("t", payload, fn_name))
    l      <- as.numeric(require_field("l", payload, fn_name))
    b      <- if (is.null(payload$b)) NULL else as.numeric(payload$b)
    r      <- if (is.null(payload$r)) NULL else as.numeric(payload$r)
    z      <- if (is.null(payload$z)) NULL else as.numeric(payload$z)
    clip   <- if (is.null(payload$clip)) NULL else as.character(payload$clip)
    name   <- if (is.null(payload$name)) NULL else as.character(payload$name)
    
    args <- list(x = x, grobs = grobs, t = t, l = l)
    if (!is.null(b)) args$b <- b
    if (!is.null(r)) args$r <- r
    if (!is.null(z)) args$z <- z
    if (!is.null(clip)) args$clip <- clip
    if (!is.null(name)) args$name <- name
    
    out <- do.call(gtable::gtable_add_grob, args)
    emit_ok(out, fn_name)
    
  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
