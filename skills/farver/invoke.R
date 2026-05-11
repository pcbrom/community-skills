#!/usr/bin/env Rscript
# farver skill dispatcher.
# Reads one JSON object from stdin, invokes the requested farver function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_farver   <- requireNamespace("farver",   quietly = TRUE)
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
      "The R package 'jsonlite' is required by the farver skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_farver) {
  emit_error(
    paste(
      "The R package 'farver' is required but is not installed.",
      "Run: install.packages('farver')."
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
  
  if (fn_name == "as_white_ref") {
    x <- if (is.character(payload$x)) as.character(payload$x) else as.numeric(payload$x)
    fow <- if (is.null(payload$fow)) NULL else as.numeric(payload$fow)
    
    args <- list(x = x)
    if (!is.null(fow)) args$fow <- fow
    
    out <- farver::as_white_ref(do.call(farver::as_white_ref, args))
    emit_ok(as.numeric(out), fn_name)

  } else if (fn_name == "compare_colour") {
    from <- as.numeric(require_field("from", payload, fn_name))
    to   <- if (is.null(payload$to)) NULL else as.numeric(require_field("to", payload, fn_name))
    from_space <- if (is.null(payload$from_space)) NULL else as.character(payload$from_space)
    to_space   <- if (is.null(payload$to_space)) NULL else as.character(payload$to_space)
    method     <- if (is.null(payload$method)) NULL else as.character(payload$method)
    white_from <- if (is.null(payload$white_from)) NULL else payload$white_from
    white_to   <- if (is.null(payload$white_to)) NULL else payload$white_to
    lightness  <- if (is.null(payload$lightness)) NULL else as.numeric(payload$lightness)
    chroma     <- if (is.null(payload$chroma)) NULL else as.numeric(payload$chroma)

    args <- list(from = from, to = to, from_space = from_space, to_space = to_space,
                 method = method, white_from = white_from, white_to = white_to,
                 lightness = lightness, chroma = chroma)
    
    # Filter NULLs to allow R to use defaults
    args <- args[!vapply(args, is.null, logical(1))]
    
    out <- farver::compare_colour(do.call(farver::compare_colour, args))
    emit_ok(as.numeric(out), fn_name)

  } else if (fn_name == "convert_colour") {
    colour <- as.numeric(require_field("colour", payload, fn_name))
    from   <- as.character(require_field("from", payload, fn_name))
    to     <- as.character(require_field("to", payload, fn_name))
    white_from <- if (is.null(payload$white_from)) NULL else payload$white_from
    white_to   <- if (is.null(payload$white_to)) NULL else payload$white_to

    args <- list(colour = colour, from = from, to = to, 
                 white_from = white_from, white_to = white_to)
    args <- args[!vapply(args, is.null, logical(1))]

    out <- farver::convert_colour(do.call(farver::convert_colour, args))
    emit_ok(as.numeric(out), fn_name)

  } else if (fn_name == "decode_colour") {
    colour <- as.character(require_field("colour", payload, fn_name))
    alpha  <- if (is.null(payload$alpha)) NULL else as.logical(payload$alpha)
    to     <- if (is.null(payload$to)) NULL else as.character(payload$to)
    white  <- if (is.null(payload$white)) NULL else payload$white
    na_value <- if (is.null(payload$na_value)) NULL else payload$na_value

    args <- list(colour = colour, alpha = alpha, to = to, white = white, na_value = na_value)
    args <- args[!vapply(args, is.null, logical(1))]

    out <- farver::decode_colour(do.call(farver::decode_colour, args))
    emit_ok(as.numeric(out), fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
