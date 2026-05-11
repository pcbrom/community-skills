#!/usr/bin/env Rscript
# data.table skill dispatcher.
# Reads one JSON object from stdin, invokes the requested data.table function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_dt       <- requireNamespace("data.table", quietly = TRUE)
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
      "The R package 'jsonlite' is required by the data.table skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_dt) {
  emit_error(
    paste(
      "The R package 'data.table' is required but is not installed.",
      "Run: install.packages('data.table')."
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
  
  if (fn_name == "data.table") {
    # Note: ... is handled via the payload keys provided in the JSON
    # Since ... is not a valid JSON key, we assume the user provides 
    # the arguments as individual keys.
    # For data.table(x, i, j, by, ...)
    # We must find the x and i/j/by/etc.
    # The signature says ... is passed.
    
    # We need to identify which keys in payload belong to ...
    # The only fixed keys in the signature are x, i, j, by, keyby, with, etc.
    # However, the user might pass '...' as part of the payload.
    # Since JSON keys cannot be '...', we look for the specific keys.
    
    # We'll check for x first.
    x_val <- payload$x
    if (is.null(x_val)) {
      # If x is not provided, it might be an empty data.table call
      # but the signature implies x is a data.table.
      # We'll check if the payload contains other keys that might be '...'
      # In a real scenario, the caller must provide the data.table object.
      # Since we cannot pass R objects via JSON easily, we assume x is a 
      # reference or a pre-existing object, but for this dispatcher, 
      # we treat it as a value.
      emit_error("Field `x` is required for fn=data.table.", fn_name)
    }
    
    # Extracting arguments that are not x or fn
    # We iterate through all keys in payload and see if they are part of the signature
    args <- list()
    # We must be careful not to include 'fn' or 'ok'
    all_keys <- names(payload)
    valid_args <- c("i", "j", "by", "keyby", "with", "nomatch", "mult", "roll", 
                    "rollends", "which", ".SDcols", "allow.cartel", "on", "env", 
                    "showProgress", "keep.rownames", "check.names", "key", "stringsAsFactors")
    
    for (k in all_keys) {
      if (k %in% valid_args) {
        args[[k]] <- payload[[k]]
      }
    }
    
    # Call data.table
    res <- do.call(data.table::data.table, c(list(x = x_val), args))
    emit_ok(res, fn_name)

  } else if (fn_name == "fread") {
    file_path <- as.character(require_field("file", payload, fn_name))
    res <- data.table::fread(file = file_path)
    emit_ok(res, fn_name)

  } else if (fn_name == "fwrite") {
    x_val <- payload$x
    file_path <- as.character(require_field("file", payload, fn_name))
    res <- data.table::fwrite(x = x_val, file = file_path)
    emit_ok(res, fn_name)

  } else if (fn_name == "setkey") {
    x_val <- payload$x
    # The signature says ... is the columns to sort by.
    # We look for keys in payload that are not x, verbose, or physical.
    cols <- list()
    for (k in names(payload)) {
      if (k %in% c("x", "verbose", "physical", "cols") && k != "cols") {
        # skip
      } else if (k == "cols") {
        cols <- payload$cols
      } else {
        cols[[k]] <- payload[[k]]
      }
    }
    
    # If 'cols' was provided explicitly as a vector
    if (!is.null(payload$cols)) {
      # The signature says 'cols' is a character vector.
      # We use it if provided.
      data.table::setkey(x_val, payload$cols)
    } else {
      # Otherwise use the ... logic
      # This is tricky in JSON. We assume the keys are the column names.
      # We'll use the keys found in the payload.
      # But we must not include 'fn'.
      # We'll assume the user provides them as a list or individual keys.
      # For simplicity, if 'cols' is not there, we use the keys.
      # However, the signature says '...' is the columns.
      # We'll check for a 'cols' key first.
      data.table::setkey(x_val) 
    }
    emit_ok(NULL, fn_name)

  } else if (fn_name == "tables") {
    env_val <- if (is.null(payload$env)) .GlobalEnv else payload$env
    res <- data.table::tables(env = env_val)
    emit_ok(res, fn_name)

  } else if (fn_name == "copy") {
    x_val <- payload$x
    res <- data.table::copy(x = x_val)
    emit_ok(res, fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
