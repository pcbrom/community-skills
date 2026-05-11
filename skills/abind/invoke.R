#!/usr/bin/env Rscript
# abind skill dispatcher.
# Reads one JSON object from stdin, invokes the requested abind function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_abind    <- requireNamespace("abind",    quietly = TRUE)
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
      "The R package 'jsonlite' is required by the abind skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_abind) {
  emit_error(
    paste(
      "The R package 'abind' is required but is not installed.",
      "Run: install.packages('abind')."
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
  
  if (fn_name == "abind") {
    # Note: ... is handled by passing the list of arrays. 
    # In JSON, this is typically an array of arrays/matrices.
    # We must extract the arrays from the payload.
    # The upstream signature uses ... for the arrays.
    # We will treat the payload as containing the arrays in a field 'x'.
    # Since '...' is not a valid JSON key, we look for 'x' as the collection.
    
    args_list <- require_field("x", payload, fn_name)
    # Ensure args_list is a list of objects
    if (!is.list(args_list)) args_list <- list(args_list)
    
    along <- if (is.null(payload$along)) NULL else as.integer(payload$along)
    rev.along <- if (is.null(payload$rev.along)) NULL else as.integer(payload$rev.along)
    new.names <- payload$new.names
    force.array <- if (is.null(payload$force.array)) NULL else as.logical(payload$force.array)
    make.names <- if (is.null(payload$make.names)) NULL else as.logical(payload$make.names)
    use.anon.names <- if (is.null(payload$use.anon.names)) NULL else as.logical(payload$use.anon.names)
    use.first.dimnames <- if (is.null(payload$use.first.dimnames)) NULL else as.logical(payload$use.first.dimnames)
    use.dnns <- if (is.null(payload$use.dnns)) NULL else as.logical(payload$use.dnns)
    hier.names <- if (is.null(payload$hier.names)) NULL else as.logical(payload$hier.names)

    # Construct the call with ...
    call_args <- list()
    for (item in args_list) {
      call_args <- c(call_args, list(item))
    }
    
    if (!is.null(along)) call_args$along <- along
    if (!is.null(rev.along)) call_args$rev.along <- rev.along
    if (!is.null(new.names)) call_args$new.names <- new.names
    if (!is.null(force.array)) call_args$force.array <- force.array
    if (!is.null(make.names)) call_args$make.names <- make.names
    if (!is.null(use.anon.names)) call_args$use.anon.names <- use.anon.names
    if (!is.null(use.first.dimnames)) call_args$use.first.dimnames <- use.first.dimnames
    if (!is.null(use.dnns)) call_args$use.dnns <- use.dnns
    if (!is.null(hier.names)) call_args$hier.names <- hier.names

    out <- do.call(abind::abind, call_args)
    emit_ok(out, fn_name)

  } else if (fn_name == "asub") {
    x <- require_field("x", payload, fn_name)
    idx <- require_field("idx", payload, fn_name)
    dims <- if (is.null(payload$dims)) NULL else as.numeric(payload$dims)
    drop <- if (is.null(payload$drop)) NULL else payload$drop
    
    out <- abind::asub(x = x, idx = idx, dims = dims, drop = drop)
    emit_ok(out, fn_name)

  } else if (fn_name == "adrop") {
    x <- require_field("x", payload, fn_name)
    drop <- require_field("drop", payload, fn_name)
    named.vector <- if (is.null(payload$named.vector)) NULL else as.logical(payload$named.vector)
    one.d.array <- if (is.null(payload$one.d.array)) NULL else as.logical(payload$one.d.array)
    
    out <- abind::adrop(x = x, drop = drop, named.vector = named.vector, one.d.array = one.d.array)
    emit_ok(out, fn_name)

  } else if (fn_name == "acorn") {
    x <- require_field("x", payload, fn_name)
    n <- require_field("n", payload, fn_name)
    m <- if (is.null(payload$m)) NULL else as.numeric(payload$m)
    r <- if (is.null(payload$r)) NULL else as.numeric(payload$else_r) # Note: 'r' is a reserved word in some contexts, but here it is the arg name
    # Re-checking upstream: 'r' is the argument name.
    r_val <- if (is.null(payload$r)) NULL else as.numeric(payload$r)
    
    # The ... arguments for acorn are not explicitly mapped in the JSON structure 
    # provided in the prompt, but we handle the primary ones.
    out <- abind::acorn(x = x, n = n, m = m, r = r_val)
    emit_ok(out, fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
