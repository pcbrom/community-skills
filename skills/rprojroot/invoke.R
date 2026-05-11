#!/usr/bin/env Rscript
# rprojroot skill dispatcher.
# Reads one JSON object from stdin, invokes the requested rprojroot function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_rprojroot <- requireNamespace("rprojroot", quietly = TRUE)
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
      "The R package 'jsonlite' is required by the rprojroot skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_rprojroot) {
  emit_error(
    paste(
      "The R package 'rprojroot' is required but is not installed.",
      "Run: install.packages('rprojroot')."
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
  
  if (fn_name == "find_root") {
    criterion <- require_field("criterion", payload, fn_name)
    path      <- as.character(require_field("path", payload, fn_name))
    out <- rprojroot::find_root(criterion = criterion, path = path)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "find_root_file") {
    path_components <- as.character(require_field("path_components", payload, fn_name))
    criterion       <- require_field("criterion", payload, fn_name)
    path            <- as.character(require_field("path", payload, fn_name))
    out <- rprojroot::find_root_file(path_components = path_components, 
                                      criterion = criterion, 
                                      path = path)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "root_criterion") {
    # Note: testfun is a function/list of functions. 
    # JSON cannot natively pass R functions. 
    # We assume the user provides the components to reconstruct it or 
    # uses predefined criteria via the 'criterion' logic.
    # However, following the signature:
    testfun   <- payload$testfun 
    desc      <- as.character(require_field("desc", payload, fn_name))
    subdir    <- if (is.null(payload$subdir)) NULL else as.character(payload$subdir)
    
    # Since we cannot easily pass R functions via JSON, we handle the 
    # logic for the other fields. If testfun is missing, we cannot 
    # construct a custom root_criterion object.
    if (is.null(testfun)) {
      emit_error("Field `testfun` cannot be passed via JSON. Use predefined criteria.", fn_name)
    }
    
    # This part is highly dependent on how the LLM provides the function.
    # For the purpose of this dispatcher, we attempt to call it.
    out <- rprojroot::root_criterion(testfun = testfun, desc = desc, subdir = subdir)
    emit_ok(out, fn_name)

  } else if (fn_name == "is_r_package") {
    path <- as.character(require_field("path", payload, fn_name))
    # is_r_package is not in the provided UPSTREAM SIGNATURES, 
    # but is in SKILL.md. We implement it using find_root logic.
    out <- tryCatch({
      rprojroot::find_root(rprojroot::has_file("DESCRIPTION"), path = path)
      TRUE
    }, error = function(e) FALSE)
    emit_ok(as.logical(out), fn_name)

  } else if (fn_name == "has_file") {
    # Using the logic from the signature for 'contents' and 'fixed'
    file_path <- as.character(require_field("file", payload, fn_name))
    contents  <- if (is.null(payload$contents)) NULL else as.character(payload$contents)
    fixed     <- if (is.null(payload$fixed)) TRUE else isTRUE(payload$fixed)
    n         <- if (is.null(payload$n)) NULL else as.integer(payload$n)
    
    # We use the logic of checking file existence and content
    exists <- file.exists(file_path)
    match <- FALSE
    if (exists && !is.null(contents)) {
      lines <- readLines(file_path, warn = FALSE)
      if (!is.null(n)) lines <- head(lines, n)
      match <- any(grepl(contents, lines, fixed = fixed))
    } else if (exists) {
      match <- TRUE
    }
    emit_ok(match, fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
