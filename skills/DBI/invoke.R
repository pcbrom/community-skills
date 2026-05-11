#!/usr/bin/env Rscript
# DBI skill dispatcher.
# Reads one JSON object from stdin, invokes the requested DBI function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_DBI      <- requireNamespace("DBI",      quietly = TRUE)
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
      "The R package 'jsonlite' is required by the DBI skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_DBI) {
  emit_error(
    paste(
      "The R package 'DBI' is required but is not installed.",
      "Run: install.packages('DBI')."
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
  
  if (fn_name == "dbConnect") {
    # Note: drv is an object/driver. In a JSON context, this is usually a placeholder.
    # We assume the driver is provided via the payload.
    drv <- require_field("drv", payload, fn_name)
    # dbConnect signature: (drv, ...)
    # We pass remaining payload elements as ...
    args <- payload[setdiff(names(payload), c("fn", "drv"))]
    res <- DBI::dbConnect(drv, ...)
    emit_ok(res, fn_name)

  } else if (fn_name == "dbGetQuery") {
    con <- require_field("con", payload, fn_name)
    statement <- as.character(require_field("statement", payload, fn_name))
    res <- DBI::dbGetQuery(con, statement)
    emit_ok(res, fn_name)

  } else if (fn_name == "dbExecute") {
    con <- require_field("con", payload, fn_name)
    statement <- as.character(require_field("statement", payload, fn_name))
    res <- DBI::dbExecute(con, statement)
    emit_ok(as.integer(res), fn_name)

  } else if (fn_name == "dbWriteTable") {
    con <- require_field("con", payload, fn_name)
    name <- as.character(require_field("name", payload, fn_name))
    value <- require_field("value", payload, fn_name)
    # dbWriteTable(conn, name, value, ...)
    # We pass remaining payload elements as ...
    args <- payload[setdiff(names(payload), c("fn", "con", "name", "value"))]
    res <- DBI::dbWriteTable(con, name, value, ...)
    emit_ok(as.logical(res), fn_name)

  } else if (fn_name == "dbAppendTable") {
    con <- require_field("con", payload, fn_name)
    name <- as.character(require_field("name", payload, fn_name))
    value <- require_field("value", payload, fn_name)
    # dbAppendTable(conn, name, value, ...)
    args <- payload[setdiff(names(payload), c("fn", "con", "name", "value"))]
    res <- DBI::dbAppendTable(con, name, value, ...)
    emit_ok(as.logical(res), fn_name)

  } else if (fn_name == "dbListTables") {
    con <- require_field("con", payload, fn_name)
    res <- DBI::dbListTables(con)
    emit_ok(as.character(res), fn_name)

  } else if (fn_name == "ANSI") {
    # No arguments block in Rd; do not invent arguments.
    emit_error("ANSI function has no defined arguments.", fn_name)

  } else if (fn_name == "Id") {
    # Id(hierarchy, ...)
    # hierarchy is the first element of the hierarchy vector
    hierarchy <- as.character(require_field("hierarchy", payload, fn_name))
    res <- DBI::Id(hierarchy = hierarchy)
    emit_ok(res, fn_name)

  } else if (fn_name == "SQL") {
    x <- as.character(require_field("x", payload, fn_name))
    names_arg <- if (!is.null(payload$names)) as.character(payload$names) else NULL
    # SQL(x, names, ...)
    args <- payload[setdiff(names(payload), c("fn", "x", "names"))]
    res <- DBI::SQL(x = x, names = names_arg, ...)
    emit_ok(res, fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
