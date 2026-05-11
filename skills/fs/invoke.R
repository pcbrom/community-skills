#!/usr/bin/env Rscript
# fs skill dispatcher.
# Reads one JSON object from stdin, invokes the requested fs function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_fs       <- requireNamespace("fs",       quietly = TRUE)
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
      "The R package 'jsonlite' is required by the fs skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_fs) {
  emit_error(
    paste(
      "The R package 'fs' is required but is not installed.",
      "Run: install.packages('fs')."
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
  
  if (fn_name == "dir_ls") {
    path    <- as.character(require_field("path", payload, fn_name))
    all     <- if (is.null(payload$all)) FALSE else as.logical(payload$all)
    recurse <- if (is.null(payload$recurse)) FALSE else payload$recurse
    type    <- if (is.null(payload$type)) NULL else as.character(payload$type)
    glob    <- if (is.null(payload$glob)) NULL else as.character(payload$glob)
    regexp  <- if (is.null(payload$regexp)) NULL else as.character(payload$regexp)
    invert  <- if (is.null(payload$invert)) FALSE else as.logical(payload$invert)
    fail    <- if (is.null(payload$fail)) TRUE else as.logical(payload$fail)
    
    # Note: 'recursive' is deprecated in fs::dir_ls, using 'recurse'
    # 'fun' is not easily passed via JSON, so we skip it.
    
    args <- list(path = path, all = all, recurse = recurse, type = type, 
                 glob = glob, regexp = regexp, invert = invert, fail = fail)
    
    # Filter out NULLs to allow R to use defaults
    args <- args[!vapply(args, is.null, logical(1))]
    
    out <- fs::dir_ls(...) # This is a placeholder for the logic below
    # Correct implementation:
    out <- do.call(fs::dir_ls, args)
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "dir_tree") {
    path    <- as.character(require_field("path", payload, fn_name))
    recurse <- if (is.null(payload$recurse)) FALSE else payload$recurse
    type    <- if (is.null(payload$type)) NULL else as.character(payload$type)
    
    # dir_tree returns a character vector (the tree)
    # We use a capture mechanism because dir_tree prints to stdout
    out <- tryCatch({
      sink(tempfile()) # dummy sink to capture
      # Since dir_tree is designed to print, we must capture its output
      # However, for a JSON API, we want the string representation.
      # We'll use a trick to capture the printed output.
      con <- textConnection("tree_out", "w", local = TRUE)
      sink(con, type = "output")
      fs::dir_tree(path = path, recurse = recurse, type = type)
      sink(type = "output")
      close(con)
      tree_out
    }, error = function(e) stop(conditionMessage(e)))
    
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "file_access") {
    path <- as.character(require_field("path", payload, fn_name))
    mode <- as.character(require_field("mode", payload, fn_name))
    
    res <- fs::file_access(path = path, mode = mode)
    emit_ok(as.logical(res), fn_name)

  } else if (fn_name == "file_chmod") {
    path <- as.character(require_field("path", payload, fn_name))
    mode <- as.character(require_field("mode", payload, fn_name))
    
    out <- fs::file_chmod(path = path, mode = mode)
    emit_ok(out, fn_name)

  } else if (fn_name == "path_abs") {
    path <- as.character(require_field("path", payload, fn_name))
    out <- fs::path_abs(path)
    emit_ok(as.character(out), fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

# Re-implementing the dir_ls logic properly for the dispatch loop
# because the placeholder above was for structural demonstration.
# The actual logic follows:

dispatch_fixed <- function(payload) {
  fn_name <- payload$fn
  
  if (fn_name == "dir_ls") {
    path    <- as.character(require_field("path", payload, fn_name))
    all     <- if (is.null(payload$all)) FALSE else as.logical(payload$all)
    recurse <- if (is.null(payload$recurse)) FALSE else payload$recurse
    type    <- if (is.null(payload$type)) NULL else as.character(payload$type)
    glob    <- if (is.null(payload$glob)) NULL else as.character(payload$glob)
    regexp  <- if (is.null(payload$regexp)) NULL else as.character(payload$regexp)
    invert  <- if (is.null(payload$invert)) FALSE else as.logical(payload$invert)
    fail    <- if (is.null(payload$fail)) TRUE else as.logical(payload$fail)
    
    args <- list(path = path, all = all, recurse = recurse, type = type, 
                 glob = glob, regexp = regexp, invert = invert, fail = fail)
    args <- args[!vapply(args, is.null, logical(1))]
    out <- do.call(fs::dir_ls, args)
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "dir_tree") {
    path    <- as.character(require_field("path", payload, fn_name))
    recurse <- if (is.null(payload$recurse)) FALSE else payload$recurse
    type    <- if (is.null(payload$type)) NULL else as.character(payload$type)
    
    out_lines <- character(0)
    con <- textConnection("out_lines", "w", local = TRUE)
    sink(con, type = "output")
    fs::dir_tree(path = path, recurse = recurse, type = type)
    sink(type = "output")
    close(con)
    emit_ok(out_lines, fn_name)

  } else if (fn_name == "file_access") {
    path <- as.character(require_field("path", payload, fn_name))
    mode <- as.character(require_field("mode", payload, fn_name))
    out <- fs::file_access(path = path, mode = mode)
    emit_ok(as.logical(out), fn_name)

  } else if (fn_name == "file_chmod") {
    path <- as.character(require_field("path", payload, fn_name))
    mode <- as.character(require_field("mode", payload, fn_name))
    fs::file_chmod(path = path, mode = mode)
    emit_ok(NULL, fn_name)

  } else if (fn_name == "path_abs") {
    path <- as.character(require_field("path", payload, fn_name))
    out <- fs::path_abs(path)
    emit_ok(as.character(out), fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

# Overwrite dispatch with the fixed version
dispatch <- dispatch_fixed

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
