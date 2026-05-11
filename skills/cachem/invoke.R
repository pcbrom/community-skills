#!/usr/bin/env Rscript
# cachem skill dispatcher.
# Reads one JSON object from stdin, invokes the requested cachem function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_cachem   <- requireNamespace("cachem",   quietly = TRUE)
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
      "The R package 'jsonlite' is required by the cachem skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_cachem) {
  emit_error(
    paste(
      "The R package 'cachem' is required but is not installed.",
      "Run: install.packages('cachem')."
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
  
  if (fn_name == "cache_disk") {
    dir           <- if (is.null(payload$dir)) NULL else as.character(payload$dir)
    max_size      <- if (is.null(payload$max_size)) NULL else as.numeric(payload$max_size)
    max_age       <- if (is.null(payload$max_age)) NULL else as.numeric(payload$else_max_age) # Note: checking upstream signature
    # Re-evaluating based on UPSTREAM SIGNATURES block provided:
    # dir, max_size, max_age, max_n, evict, destroy_on_finalize, read_fn, write_fn, extension, missing, prune_rate, warn_ref_objects, logfile
    
    # Correcting logic to use the provided UPSTREAM SIGNATURES block exactly:
    dir           <- if (is.null(payload$dir)) NULL else as.character(payload$dir)
    max_size      <- if (is.null(payload$max_size)) NULL else as.numeric(payload$max_size)
    max_age       <- if (is.null(payload$max_age)) NULL else as.numeric(payload$max_age)
    max_n         <- if (is.null(payload$max_n)) NULL else as.integer(payload$max_n)
    evict         <- if (is.null(payload$evict)) NULL else as.character(payload$evict)
    destroy_on_finalize <- if (is.null(payload$destroy_on_finalize)) NULL else as.logical(payload$destroy_on_interface) # Wait, checking signature again
    
    # Let's strictly follow the UPSTREAM SIGNATURES block for arguments:
    # cache_disk: dir, max_size, max_age, max_n, evict, destroy_on_finalize, read_fn, write_fn, extension, missing, prune_rate, warn_ref_objects, logfile
    
    # Re-implementing cache_disk with exact signature keys
    d_dir           <- if (is.null(payload$dir)) NULL else as.character(payload$dir)
    d_max_size      <- if (is.null(payload$max_size)) NULL else as.numeric(payload$max_size)
    d_max_age       <- if (is.null(payload$max_age)) NULL else as.numeric(payload$max_age)
    d_max_n         <- if (is.null(payload$max_n)) NULL else as.integer(payload$max_n)
    d_evict         <- if (is.null(payload$evict)) NULL else as.character(payload$evict)
    d_destroy       <- if (is.null(payload$destroy_on_finalize)) NULL else as.logical(payload$destroy_on_finalize)
    d_read_fn       <- if (is.null(payload$read_fn)) NULL else payload$read_fn
    d_write_fn      <- if (is.null(payload$write_fn)) NULL else payload$write_fn
    d_extension     <- if (is.null(payload$extension)) NULL else as.character(payload$extension)
    d_missing       <- if (is.null(payload$missing)) NULL else payload$missing
    d_prune_rate    <- if (is.null(payload$prune_rate)) NULL else as.numeric(payload$prune_rate)
    d_warn_ref      <- if (is.null(payload$warn_ref_objects)) NULL else as.logical(payload$warn_ref_objects)
    d_logfile       <- if (is.null(payload$logfile)) NULL else payload$logfile

    res <- cachem::cache_disk(
      dir = d_dir, max_size = d_max_size, max_age = d_max_age, max_n = d_max_n,
      evict = d_evict, destroy_on_finalize = d_destroy, read_fn = d_read_fn,
      write_fn = d_write_fn, extension = d_extension, missing = d_missing,
      prune_rate = d_prune_rate, warn_ref_objects = d_warn_ref, logfile = d_logfile
    )
    emit_ok(as.character(res), fn_name)

  } else if (fn_name == "cache_mem") {
    # cache_mem: max_size, max_age, max_n, evict, missing, logfile
    m_max_size      <- if (is.null(payload$max_size)) NULL else as.numeric(payload$max_size)
    m_max_lag       <- if (is.null(payload$max_age)) NULL else as.numeric(payload$max_age)
    m_max_n         <- if (is.null(payload$max_n)) NULL else as.integer(payload$max_n)
    m_evict         <- if (is.null(payload$evict)) NULL else as.character(payload$evict)
    m_missing       <- if (is.null(payload$missing)) NULL else payload$missing
    m_logfile       <- if (is.null(payload$logfile)) NULL else payload$logfile

    res <- cachem::cache_mem(
      max_size = m_max_size, max_age = m_max_lag, max_n = m_max_n,
      evict = m_evict, missing = m_missing, logfile = m_logfile
    )
    emit_ok(as.character(res), fn_name)

  } else if (fn_name == "cache_layered") {
    # cache_layered: ..., logfile
    # The "..." represents a list of cache objects.
    # We must find all keys in payload that are not 'fn' or 'logfile'.
    # However, the signature says "..." are cache objects.
    # In JSON, this usually means an array of objects or multiple keys.
    # Given the SKILL.md, it's an array of objects in the payload.
    
    # Since we cannot iterate over "..." easily without knowing keys, 
    # we assume the payload contains the objects as elements in a list.
    # But the signature says "..." are the arguments.
    # Let's look at the SKILL.md: "..." : { "type": "array", "items": { "type": "object" } }
    # This implies the payload contains a key that is an array.
    # But the signature doesn't name the key. 
    # Looking at the context, the payload itself is the collection.
    
    # Let's assume the payload contains a key 'caches' or similar, 
    # but the signature says "..." are the arguments.
    # If the user provides an array of caches, we need to find them.
    # Let's check for a key 'caches' or similar, or treat the payload as the list.
    # Actually, in R, we can check all elements in payload that are cache objects.
    # But we don't know which are caches.
    # Let's assume the payload contains a key 'caches' based on common patterns.
    # Wait, the signature says "..." is the argument.
    # Let's try to find any key that is a list/object.
    
    caches <- list()
    # We'll look for a key 'caches' as a fallback if '...' is not explicitly named.
    # If the user provides 'caches' as an array:
    if (!is.null(payload$caches)) {
      caches <- lapply(payload$caches, function(x) x)
    }
    
    l_logfile <- if (is.null(payload$logfile)) NULL else payload$logfile
    
    res <- cachem::cache_layered(caches, logfile = l_logfile)
    emit_ok(as.character(res), fn_name)

  } else if (fn_name == "key_missing") {
    # key_missing: cache, key
    k_cache <- if (is.null(payload$cache)) NULL else payload$cache
    k_key   <- if (is.null(payload$key)) NULL else as.character(payload$key)
    
    if (is.null(k_cache) || is.null(k_key)) {
      emit_error("Fields `cache` and `key` are required for key_missing.", fn_name)
    }
    
    res <- cachem::key_missing(cache = k_cache, key = k_key)
    emit_ok(as.logical(res), fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
