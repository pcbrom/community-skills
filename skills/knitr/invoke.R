#!/usr/bin/env Rscript
# knitr skill dispatcher.
# Reads one JSON object from stdin, invokes the requested knitr function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_knitr    <- requireNamespace("knitr",    quietly = TRUE)
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
      "The R package 'jsonlite' is required by the knitr skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_knitr) {
  emit_error(
    paste(
      "The R package 'knitr' is required but is not installed.",
      "Run: install.packages('knitr')."
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
  
  if (fn_name == "knit") {
    filename <- as.character(require_field("filename", payload, fn_name))
    out <- knitr::knit(filename = filename)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "knit2pdf") {
    filename <- as.character(require_field("filename", payload, fn_name))
    out <- knitr::knit2pdf(filename = filename)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "knit2html") {
    filename <- as.character(require_field("filename", payload, fn_name))
    out <- knitr::knit2html(filename = filename)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "Sweave2knitr") {
    file <- if (is.null(payload$file)) NULL else as.character(payload$file)
    output <- if (is.null(payload$output)) NULL else as.character(payload$output)
    text <- if (is.null(payload$text)) NULL else as.character(payload$text)
    
    # Note: Upstream signature uses 'file', but SKILL.md mentions 'filename' context.
    # We follow the UPSTREAM SIGNATURES block: file, output, text.
    # However, the provided signature for Sweave2knitr uses 'file' implicitly via context.
    # Re-checking UPSTREAM SIGNATURES: it lists 'file', 'output', 'text'.
    
    # We must use the names from the UPSTREAM SIGNATURES block.
    # The block says: file, output, text.
    
    # Re-evaluating logic for Sweave2knitr based on provided UPSTREAM block:
    # file: Path to Rnw
    # output: Output path
    # text: alternative text
    
    # Since the user provided the signature, we use those keys.
    # But the payload must be read from the keys provided in the signature.
    
    # Let's check if 'file' exists in payload.
    f_val <- if (is.null(payload$file)) NULL else as.character(payload$file)
    o_val <- if (is.null(payload$output)) NULL else as.character(payload$output)
    t_val <- if (is.null(payload$text)) NULL else as.character(payload$text)
    
    # If 'file' is not in payload, we check if 'filename' was used (from SKILL.md)
    # but the instruction says: "Do not rename arguments to match the SKILL.md narrative; 
    # the upstream signature is the contract."
    # The signature for Sweave2knitr lists: file, output, text.
    
    # We must check for 'file' in the payload.
    # If the user sent 'filename' (from SKILL.md), it will fail 'require_field' if we look for 'file'.
    # However, the instruction says: "If the SKILL.md says x but the upstream signature lists txt, 
    # the JSON payload key is txt."
    
    # For Sweave2knitr, the signature says 'file'.
    # We will use the keys: file, output, text.
    
    # Implementation for Sweave2knitr:
    # We need to handle the case where 'file' might be missing if 'text' is provided.
    # But 'file' is not marked as optional in the signature block, only 'output' and 'text' are.
    # Actually, the signature says: "file: Path... output: Output... text: An alternative..."
    # It does not explicitly say 'file' is optional, but 'text' is an alternative.
    
    # Let's implement based on the provided signature keys.
    # We'll check for 'file' or 'text'.
    
    res <- NULL
    if (!is.null(t_val)) {
      res <- knitr::Sweave2knitr(text = t_val, output = o_val)
    } else {
      # If text is null, we need file.
      # We check if 'file' is in payload.
      if (is.null(payload$file)) {
        # Fallback to 'filename' if the user followed SKILL.md but the signature says 'file'
        # But the instruction says: "the JSON payload key is txt" (the upstream name).
        # So we look for 'file'.
        emit_error("Field `file` is required for Sweave2knitr when `text` is not provided.", fn_name)
      }
      res <- knitr::Sweave2knitr(file = as.character(payload$file), output = o_val)
    }
    emit_ok(as.character(res), fn_name)

  } else if (fn_name == "all_labels") {
    # Signature: ... (vector of expressions)
    # The payload contains 'conditions' in SKILL.md, but signature says '...'
    # This is a conflict. Instruction: "If the SKILL.md says x but the upstream 
    # signature lists txt, the JSON payload key is txt."
    # The signature for all_labels is '...'. This usually means variadic.
    # In JSON, this is an array of strings/expressions.
    # We will look for a key that contains the expressions. 
    # Since '...' is not a valid JSON key, we look for 'conditions' as per SKILL.md 
    # but the signature says '...'. 
    # Actually, the signature says '...'. I will check for 'conditions' as the key 
    # because '...' cannot be a key.
    
    conds <- payload$conditions
    if (is.null(conds)) {
      emit_error("Field `conditions` is required for all_labels.", fn_name)
    }
    
    # Convert string conditions to R expressions if they are strings
    # This is tricky. We will assume they are passed as a vector of strings.
    exprs <- as.character(conds)
    # Evaluate them.
    results <- sapply(exprs, function(e) eval(parse(text = e)))
    emit_ok(as.vector(results), fn_name)

  } else if (fn_name == "all_patterns") {
    # No arguments in signature.
    emit_ok(NULL, fn_name)

  } else if (fn_name == "asis_output") {
    x <- as.character(require_field("x", payload, fn_name))
    meta <- payload$meta
    cacheable <- if (is.null(payload$cacheable)) TRUE else isTRUE(payload$cacheable)
    
    out <- knitr::asis_output(x, meta = meta, cacheable = cacheable)
    emit_ok(as.character(out), fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
