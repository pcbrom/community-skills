#!/usr/bin/env Rscript
# openssl skill dispatcher.
# Reads one JSON object from stdin, invokes the requested openssl function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_openssl  <- requireNamespace("openssl",  quietly = TRUE)
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
      "The R package 'jsonlite' is required by the openssl skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_openssl) {
  emit_error(
    paste(
      "The R package 'openssl' is required but is not installed.",
      "Run: install.packages('openssl')."
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
  
  if (fn_name == "base64_encode") {
    bin <- if (is.null(payload$bin)) NULL else as.raw(as.integer(require_field("bin", payload, fn_name)))
    linebreaks <- if (is.null(payload$linebreaks)) NULL else as.logical(payload$linebreaks)
    
    out <- openssl::base64_encode(bin)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "bignum") {
    x <- if (is.null(payload$x)) NULL else as.character(require_field("x", payload, fn_name))
    hex <- if (is.null(payload$hex)) NULL else as.logical(payload$hex)
    a <- if (is.null(payload$a)) NULL else as.numeric(payload$a)
    b <- if (is.null(payload$b)) NULL else as.numeric(payload$b)
    m <- if (is.null(payload$m)) NULL else as.numeric(payload$m)
    
    # Note: bignum in openssl returns an object; we return the string representation
    out <- openssl::bignum(x = x, hex = hex, a = a, b = b, m = m)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "ec_dh") {
    key <- if (is.null(payload$key)) NULL else require_field("key", payload, fn_name)
    peerkey <- if (is.null(payload$peerkey)) NULL else require_field("peerkey", payload, fn_name)
    password <- if (is.null(payload$password)) NULL else as.character(payload$password)
    
    out <- openssl::ec_dh(key = key, peerkey = peerkey, password = password)
    emit_ok(as.raw(out), fn_name)
    
  } else if (fn_name == "encrypt_envelope") {
    data <- if (is.null(payload$data)) NULL else as.raw(as.integer(require_field("data", payload, fn_name)))
    pubkey <- if (is.null(payload$pubkey)) NULL else require_field("pubkey", payload, fn_name)
    iv <- if (is.null(payload$iv)) NULL else as.raw(as.integer(payload$iv))
    session <- if (is.null(payload$session)) NULL else as.raw(as.integer(payload$session))
    key <- if (is.null(payload$key)) NULL else require_field("key", payload, fn_name)
    password <- if (is.null(payload$password)) NULL else as.character(payload$password)
    
    out <- openssl::encrypt_envelope(
      data = data, pubkey = pubkey, iv = iv, 
      session = session, key = key, password = password
    )
    
    # Convert raw vectors to integer arrays for JSON compatibility
    res_list <- list(
      data = if (is.null(out$data)) NULL else as.integer(out$data),
      iv = if (is.null(out$iv)) NULL else as.integer(out::as.raw(out$iv)),
      session = if (is.null(out$session)) NULL else as.integer(out$session)
    )
    emit_ok(res_list, fn_name)
    
  } else if (fn_name == "sha256") {
    data <- if (is.null(payload$data)) NULL else as.raw(as.integer(require_field("data", payload, fn_name)))
    out <- openssl::sha256(data)
    emit_ok(as.raw(out), fn_name)
    
  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
