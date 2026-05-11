#!/usr/bin/env Rscript
# progress skill dispatcher.
# Reads one JSON object from stdin, invokes the requested progress function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_progress <- requireNamespace("progress", quietly = TRUE)
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
      "The R package 'jsonlite' is required by the progress skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_progress) {
  emit_error(
    paste(
      "The R package 'progress' is required but is not installed.",
      "Run: install.packages('progress')."
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
  
  if (fn_name == "progress_bar$new") {
    total  <- as.integer(require_field("total", payload, fn_name))
    format <- if (is.null(payload$format)) NULL else as.character(payload$format)
    clear  <- if (is.null(payload$clear)) NULL else as.logical(payload$clear)
    width  <- if (is.null(payload$width)) NULL else as.integer(payload$is_null(payload$width))
    # Note: width check logic corrected to handle potential NULLs from JSON
    width  <- if (is.null(payload$width)) NULL else as.integer(payload$width)
    
    # Re-evaluating width/clear/format to ensure we only pass non-NULL
    args <- list(total = total)
    if (!is.null(format)) args$format <- format
    if (!is.null(clear))  args$clear  <- clear
    if (!is.null(width))  args$width  <- width
    
    res <- do.call(progress::progress_bar$new, args)
    # R6 objects cannot be serialized to JSON easily; return a string representation
    emit_ok(format(res), fn_name)
    
  } else if (fn_name == "tick") {
    delta <- if (is.null(payload$delta)) NULL else as.integer(payload$delta)
    # Note: tick is a method on a progress_bar object. 
    # In this dispatcher context, we assume the user is calling the function.
    # However, 'tick' is not a top-level function in the package, it is a method.
    # Since the skill defines 'tick' as a function, we treat it as an instruction.
    # This implementation assumes the user provides the object or we handle the logic.
    # Given the constraints, we attempt to call the function if it exists.
    # Since 'tick' is a method, we check if it's callable.
    emit_error("The 'tick' function is a method of a progress_bar object and cannot be called standalone in this dispatcher.", fn_name)
    
  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

# Re-implementing dispatch with correct logic for the provided signatures
dispatch_fixed <- function(payload) {
  fn_name <- payload$fn
  
  if (fn_name == "progress_bar$new") {
    total  <- as.integer(require_field("total", payload, fn_name))
    format <- if (is.null(payload$format)) NULL else as.character(payload$format)
    clear  <- if (is.null(payload$clear)) NULL else as.logical(payload$clear)
    width  <- if (is.null(payload$width)) NULL else as.integer(payload$width)
    
    args <- list(total = total)
    if (!is.null(format)) args$format <- format
    if (!is.null(clear))  args$clear  <- clear
    if (!is.null(width))  args$width  <- width
    
    res <- do.call(progress::progress_bar$new, args)
    emit_ok(format(res), fn_name)
    
  } else if (fn_name == "tick") {
    # The 'tick' function in the skill refers to updating an existing bar.
    # Since we cannot persist R6 objects between calls in a stateless dispatcher,
    # we can only simulate the logic or error out if no object is provided.
    # However, following the prompt's requirement to call the named function:
    delta <- if (is.null(payload$delta)) NULL else as.integer(payload$delta)
    emit_error("The 'tick' function requires an existing progress_bar object, which cannot be persisted across stateless calls.", fn_name)
    
  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

# Final dispatch logic
err <- tryCatch(
  {
    fn_name <- payload$fn
    if (fn_name == "progress_bar$new") {
      total  <- as.integer(require_field("total", payload, fn_name))
      format <- if (is.null(payload$format)) NULL else as.character(payload$format)
      clear  <- if (is.null(payload$clear)) NULL else as.logical(payload$clear)
      width  <- if (is.null(payload$width)) NULL else as.integer(payload$width)
      
      args <- list(total = total)
      if (!is.null(format)) args$format <- format
      if (!is.null(clear))  args$clear  <- clear
      if (!is.null(width))  args$width  <- width
      
      res <- do.call(progress::progress_bar$new, args)
      emit_ok(format(res), fn_name)
    } else if (fn_name == "tick") {
      # As noted, tick is a method. Without a persistent object, we cannot call it.
      emit_error("The 'tick' function is a method of a progress_bar object and cannot be called without a persistent object.", fn_name)
    } else {
      emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
    }
  }, 
  error = function(e) emit_error(conditionMessage(e), payload$fn)
)

if (inherits(err, "error")) {
  emit_error(conditionMessage(err), payload$fn)
}
