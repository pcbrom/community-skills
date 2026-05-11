#!/usr/bin/env Rscript
# jsonlite skill dispatcher.
# Reads one JSON object from stdin, invokes the requested jsonlite function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
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
      "The R package 'jsonlite' is required by the jsonlite skill but is not",
      "installed. Run: install.packages('jsonlite')."
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
  
  if (fn_name == "flatten") {
    x <- require_field("x", payload, fn_name)
    recursive <- if (is.null(payload$recursive)) FALSE else as.logical(payload$recursive)
    out <- jsonlite::flatten(x = x, recursive = recursive)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "toJSON") {
    x <- require_field("x", payload, fn_name)
    
    # Optional arguments
    dataframe <- if (is.null(payload$dataframe)) NULL else as.character(payload$dataframe)
    matrix    <- if (is.null(payload$matrix))    NULL else as.character(payload$matrix)
    Date      <- if (is.null(payload$Date))      NULL else as.character(payload$Date)
    POSIXt    <- if (is.null(payload$POSIXt))    NULL else as.character(payload$POSIXt)
    factor    <- if (is.null(payload$factor))    NULL else as.character(payload$factor)
    complex   <- if (is.null(payload$complex))   NULL else as.character(payload$complex)
    raw       <- if (is.null(payload$raw))       NULL else as.character(payload$raw)
    null      <- if (is.null(payload$null))      NULL else as.character(payload$null)
    na        <- if (is.null(payload$na))        NULL else as.character(payload$na)
    auto_unbox <- if (is.null(payload$auto_unbox)) NULL else as.logical(payload$auto_unbox)
    digits    <- if (is.null(payload$digits))    NULL else as.numeric(payload$digits)
    pretty    <- if (is.null(payload$pretty))    NULL else payload$pretty
    force     <- if (is.null(payload$force))     NULL else payload$force

    # Build argument list for toJSON
    args <- list(x = x)
    if (!is.null(dataframe)) args$dataframe <- dataframe
    if (!is.null(matrix))    args$matrix    <- matrix
    if (!is.null(Date))      args$Date      <- Date
    if (!is.null(POSIXt))    args$POSIXt    <- POSIXt
    if (!is.null(factor))    args$factor    <- factor
    if (!is.null(complex))   args$complex   <- complex
    if (!is.null(raw))       args$raw       <- raw
    if (!is.null(null))      args$null      <- null
    if (!is.null(na))        args$na        <- na
    if (!is.null(auto_unbox)) args$auto_unbox <- auto_unbox
    if (!is.null(digits))    args$digits    <- digits
    if (!is.null(pretty))    args$pretty    <- pretty
    if (!is.null(force))     args$force     <- force

    out <- do.call(jsonlite::toJSON, c(args, list(auto_unbox = TRUE)))
    emit_ok(out, fn_name)

  } else if (fn_name == "fromJSON") {
    txt <- require_field("txt", payload, fn_name)
    
    simplifyVector <- if (is.null(payload$simplifyVector)) TRUE else as.logical(payload$simplifyVector)
    simplifyDataFrame <- if (is.null(payload$simplifyDataFrame)) TRUE else as.logical(payload$simplifyDataFrame)
    simplifyMatrix <- if (is.null(payload$simplifyMatrix)) TRUE else as.logical(payload$simplifyMatrix)
    flatten <- if (is.null(payload$flatten)) FALSE else as.logical(payload$flatten)

    args <- list(txt = txt, simplifyVector = simplifyVector, 
                 simplifyDataFrame = simplifyDataFrame, simplifyMatrix = simplifyMatrix,
                 flatten = flatten)
    
    out <- do.call(jsonlite::fromJSON, args)
    emit_ok(out, fn_name)

  } else if (fn_name == "prettify") {
    txt <- require_field("txt", payload, fn_name)
    indent <- if (is.null(payload$indent)) 2 else as.integer(payload$indent)
    
    # prettify is a wrapper around toJSON with pretty=TRUE
    # We use the logic of toJSON to generate the string
    out <- jsonlite::toJSON(jsonlite::fromJSON(txt), pretty = indent, auto_unbox = TRUE)
    emit_ok(out, fn_name)

  } else if (fn_name == "minify") {
    txt <- require_field("txt", payload, fn_name)
    # minify is essentially toJSON with pretty=0 or no whitespace
    out <- jsonlite::toJSON(jsonlite::fromJSON(txt), pretty = 0, auto_unbox = TRUE)
    emit_ok(out, fn_name)

  } else if (fn_name == "rbind_pages") {
    pages <- require_field("pages", payload, fn_name)
    out <- do.call(rbind, pages)
    emit_ok(out, fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
