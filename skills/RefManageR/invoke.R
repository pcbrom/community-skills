#!/usr/bin/env Rscript
# RefManageR skill dispatcher.
# Reads one JSON object from stdin, invokes the requested RefManageR function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_RefManageR <- requireNamespace("RefManageR", quietly = TRUE)
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
      "The R package 'jsonlite' is required by the RefManageR skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_RefManageR) {
  emit_error(
    paste(
      "The R package 'RefManageR' is required but is not installed.",
      "Run: install.packages('RefManageR')."
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
  
  if (fn_name == "BibEntry") {
    bibtype <- as.character(require_field("bibtype", payload, fn_name))
    textVersion <- if (is.null(payload$textVersion)) NULL else as.character(payload$textVersion)
    header <- if (is.null(payload$header)) NULL else as.character(payload$header)
    footer <- if (is.null(payload$footer)) NULL else as.character(payload$footer)
    key <- as.character(require_field("key", payload, fn_name))
    mheader <- if (is.null(payload$mheader)) NULL else as.character(payload$mheader)
    mfooter <- if (is.null(payload$mfooter)) NULL else as.character(payload$mfooter)
    
    # Handle 'other' as a named list
    other <- if (is.null(payload$other)) NULL else payload$other
    
    # Handle '...' via 'tag = value' logic from payload
    # We extract keys that are not part of the explicit signature
    explicit_keys <- c("bibtype", "textVersion", "header", "footer", "key", "mheader", "mfooter", "other")
    extra_args <- list()
    for (name in names(payload)) {
      if (!(name %in% c("fn", explicit_keys))) {
        extra_args[[name]] <- payload[[name]]
      }
    }

    args <- list(
      bibtype = bibtype,
      textVersion = textVersion,
      header = header,
      footer = footer,
      key = key,
      mheader = mheader,
      mfooter = mfooter,
      other = other
    )
    # Remove NULLs so R uses defaults
    args <- args[!vapply(args, is.null, logical(1))]
    # Add extra tags
    args <- c(args, extra_args)

    out <- do.call(RefManageR::BibEntry, args)
    emit_ok(out, fn_name)

  } else if (fn_name == "BibOptions") {
    restore.defaults <- if (is.null(payload$restore.defaults)) NULL else as.logical(payload$restore.defaults)
    
    # Handle '...'
    extra_args <- list()
    for (name in names(payload)) {
      if (!(name %in% c("fn", "restore.defaults"))) {
        extra_args[[name]] <- payload[[name]]
      }
    }
    
    args <- list(restore.defaults = restore.defaults)
    args <- args[!vapply(args, is.null, logical(1))]
    args <- c(args, extra_args)
    
    out <- do.call(RefManageR::BibOptions, args)
    emit_ok(out, fn_name)

  } else if (fn_name == "Cite") {
    bib <- require_field("bib", payload, fn_name)
    textual <- if (is.null(payload$textual)) NULL else as.logical(payload$textual)
    before <- if (is.null(payload$before)) NULL else as.character(payload$before)
    after <- if (is.null(payload$after)) NULL else as.character(payload$after)
    start <- if (is.null(payload$start)) NULL else as.integer(payload$start)
    end <- if (is.null(payload$end)) NULL else as.integer(payload$end)
    
    # Handle '.opts' as a list
    dot_opts <- if (is.null(payload$.opts)) NULL else payload$.opts
    
    # Handle '...'
    extra_args <- list()
    for (name in names(payload)) {
      if (!(name %in% c("fn", "bib", "textual", "before", "after", "start", "end", ".opts"))) {
        extra_args[[name]] <- payload[[name]]
      }
    }

    args <- list(
      bib = bib,
      textual = textual,
      before = before,
      after = after,
      start = start,
      end = end,
      ".opts" = dot_opts
    )
    args <- args[!vapply(args, is.null, logical(1))]
    args <- c(args, extra_args)

    out <- do.call(RefManageR::Cite, args)
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "GetBibEntryWithDOI") {
    doi <- as.character(require_field("doi", payload, fn_name))
    temp.file <- if (is.null(payload$temp.file)) NULL else as.character(payload$temp.file)
    delete.file <- if (is.null(payload$delete.file)) NULL else as.logical(payload$delete.file)

    args <- list(doi = doi, temp.file = temp.file, delete.file = delete.file)
    args <- args[!vapply(args, is.null, logical(1))]

    out <- do.call(RefManageR::GetBibEntryWithDOI, args)
    emit_ok(out, fn_name)

  } else if (fn_name == "ReadBib") {
    filename <- as.character(require_field("filename", payload, fn_name))
    out <- RefManageR::ReadBib(filename = filename)
    emit_ok(out, fn_name)

  } else if (fn_name == "SearchBib") {
    bib <- require_field("bib", payload, fn_name)
    field <- as.character(require_field("field", payload, fn_name))
    
    # Multi-modal pattern fallback
    pattern <- if (is.null(payload$pattern)) NULL else as.character(payload$pattern)
    
    # Check if pattern is provided but no specific pattern-mode is provided
    # In SearchBib, the pattern is usually passed via the 'pattern' argument.
    # If the user provided 'pattern' but not 'pattern' (redundant), we handle it.
    # The prompt mentions regex/fixed/coll/charclass logic for stringi, 
    # but for SearchBib we just ensure 'pattern' is routed.
    
    args <- list(bib = bib, field = field)
    if (!is.null(pattern)) args$pattern <- pattern
    
    # Check for other pattern-style args in payload
    for (name in c("regex", "fixed", "coll", "charclass")) {
      if (!is.null(payload[[name]])) {
        args[[name]] <- payload[[name]]
      }
    }

    out <- do.call(RefManageR::SearchBib, args)
    emit_ok(out, fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
