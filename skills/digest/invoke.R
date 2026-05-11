#!/usr/bin/env Rscript
# digest skill dispatcher.
# Reads one JSON object from stdin, invokes the requested digest function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_digest   <- requireNamespace("digest",   quietly = TRUE)
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
      "The R package 'jsonlite' is required by the digest skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_digest) {
  emit_error(
    paste(
      "The R package 'digest' is required but is not installed.",
      "Run: install.packages('digest')."
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
  
  if (fn_name == "digest") {
    # Note: 'object' is the primary argument in upstream signature.
    # We check for 'object' or 'x' as per SKILL.md/Upstream discrepancy.
    # Using 'object' as per Upstream Signature contract.
    obj <- if (!is.null(payload$object)) payload$object else payload$x
    
    algo         <- if (is.null(payload$algo)) "md5" else as.character(payload$algo)
    serialize    <- if (is.null(payload$serialize)) TRUE else as.logical(payload$serialize)
    file         <- if (is.null(payload$file)) NULL else as.logical(payload$file)
    length_val   <- if (is.null(payload$length)) NULL else as.numeric(payload$length)
    skip         <- if (is.null(payload$skip)) NULL else payload$skip
    ascii         <- if (is.null(payload$ascii)) NULL else as.logical(payload$ascii)
    raw          <- if (is.null(payload$raw)) FALSE else as.logical(payload$raw)
    seed         <- if (is.null(payload$seed)) NULL else as.integer(payload$seed)
    errormode    <- if (is.null(payload$errormode)) "stop" else as.character(payload$errormode)
    serializeVer <- if (is.null(payload$serializeVersion)) NULL else as.integer(payload$serializeVersion)
    
    # AES specific args (if provided in payload)
    key          <- if (is.null(payload$key)) NULL else payload$key
    mode         <- if (is.null(payload$mode)) NULL else as.character(payload$mode)
    IV           <- if (is.null(payload$IV)) NULL else payload$IV
    padding      <- if (is.null(payload$padding)) NULL else as.logical(payload$padding)

    # Construct call arguments
    args <- list(object = obj, algo = algo, serialize = serialize)
    if (!is.null(file)) args$file <- file
    if (!is.null(length_val)) args$length <- length_val
    if (!is.null(skip)) args$skip <- skip
    if (!is.null(ascii)) args$ascii <- ascii
    if (!is.null(raw)) args$raw <- raw
    if (!is.null(seed)) args$seed <- seed
    if (!is.null(errormode)) args$errormode <- errormode
    if (!is.null(serializeVer)) args$serializeVersion <- serializeVer
    
    # AES logic if key is present
    if (!is.null(key)) {
      # AES is not a direct function in digest but part of its capability
      # We assume the user wants to use the AES logic if key is provided
      # This part is complex as AES is not a single function call in digest
      # but we follow the provided signature.
      args$key <- key
      if (!is.null(mode)) args$mode <- mode
      if (!is.null(IV)) args$IV <- IV
      if (!is.null(padding)) args$padding <- padding
    }

    out <- do.call(digest::digest, args)
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "digest2int") {
    x    <- as.character(require_field("x", payload, fn_name))
    seed <- if (is.null(payload$seed)) NULL else as.integer(payload$seed)
    
    out <- if (is.null(seed)) digest::digest2int(x) else digest::digest2int(x, seed = seed)
    emit_ok(as.integer(out), fn_name)

  } else if (fn_name == "sha1") {
    x      <- if (is.null(payload$x)) NULL else payload$x
    digits <- if (is.null(payload$digits)) NULL else as.numeric(payload$digits)
    zapsmall <- if (is.null(payload$zapsmall)) NULL else as.numeric(payload$zapsmall)
    algo   <- if (is.null(payload$algo)) "sha1" else as.character(payload$algo)
    
    args <- list(x = x, algo = algo)
    if (!is.null(digits)) args$digits <- digits
    if (!is.null(zapsmall)) args$zapsmall <- zapsmall
    
    out <- do.call(digest::sha1, args)
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "hmac") {
    key    <- if (is.null(payload$key)) NULL else payload$key
    object <- if (is.null(payload$object)) NULL else payload$object
    algo   <- if (is.null(payload$algo)) "md5" else as.character(payload$algo)
    
    out <- digest::hmac(key = key, object = object, algo = algo)
    emit_ok(as.character(out), fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
