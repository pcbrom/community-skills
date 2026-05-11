#!/usr/bin/env Rscript
# zoo skill dispatcher.
# Reads one JSON object from stdin, invokes the requested zoo function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_zoo      <- requireNamespace("zoo",      quietly = TRUE)
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
      "The R package 'jsonlite' is required by the zoo skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_zoo) {
  emit_error(
    paste(
      "The R package 'zoo' is required but is not installed.",
      "Run: install.packages('zoo')."
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
  
  if (fn_name == "as.zoo") {
    x <- require_field("x", payload, fn_name)
    # as.zoo uses ... for extra args. We pass them if provided in payload.
    # Since ... is hard to map from JSON without a list, we check for common keys.
    # The signature says x is the primary object.
    out <- zoo::as.zoo(x)
    emit_ok(as.character(out), fn_name)
    
  } else if (fn_name == "zooreg") {
    data <- as.numeric(require_field("data", payload, fn_name))
    start <- if (is.null(payload$start)) NULL else as.numeric(payload$start)
    end <- if (is.null(payload$end)) NULL else as.numeric(payload$end)
    frequency <- if (is.null(payload$frequency)) NULL else as.integer(payload$frequency)
    deltat <- if (is.null(payload$deltat)) NULL else as.numeric(payload$deltat)
    ts.eps <- if (is.null(payload$ts.eps)) NULL else as.numeric(payload$ts.eps)
    order.by <- if (is.null(payload$order.by)) NULL else as.numeric(payload$order.by)
    calendar <- if (is.null(payload$calendar)) NULL else as.logical(payload$calendar)
    
    # Note: zooreg signature in upstream uses 'data' for the values.
    # We use the provided 'data' as the first argument.
    # We must handle the logic of the provided arguments.
    args <- list(data = data)
    if (!is.null(start)) args$start <- start
    if (!is.null(end)) args$end <- end
    if (!is.null(frequency)) args$frequency <- frequency
    if (!is.null(deltat)) args$deltat <- deltat
    if (!is.null(ts.eps)) args$`ts.eps` <- ts.eps
    if (!is.null(order.by)) args$`order.by` <- order.by
    if (!is.null(calendar)) args$calendar <- calendar
    
    out <- do.call(zoo::zooreg, args)
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "merge") {
    # merge.zoo uses ... for objects. In JSON, we expect an array of objects.
    # However, the payload structure for merge is often x, y, etc.
    # We will look for 'x' and 'y' as the primary objects to merge.
    x <- require_field("x", payload, fn_name)
    y <- require_field("y", payload, fn_name)
    
    all_val <- if (is.null(payload$all)) NULL else as.logical(payload$all)
    fill <- if (is.null(payload$fill)) NULL else as.numeric(payload$fill)
    suffixes <- if (is.null(payload$suffixes)) NULL else as.character(payload$suffixes)
    check.names <- if (is.null(payload$check.names)) NULL else as.logical(payload$check.names)
    retclass <- if (is.null(payload$retclass)) NULL else as.character(payload$retclass)
    drop <- if (is.null(payload$drop)) NULL else as.logical(payload$drop)
    sep <- if (is.null(payload$sep)) NULL else as.character(payload$sep)
    
    args <- list(x = x, y = y)
    if (!is.null(all_val)) args$all <- all_val
    if (!is.null(fill)) args$fill <- fill
    if (!is.null(suffixes)) args$suffixes <- suffixes
    if (!is.null(check.names)) args$`check.names` <- check.names
    if (!is.null(retclass)) args$retclass <- retclass
    if (!is.null(drop)) args$drop <- drop
    if (!is.null(sep)) args$sep <- sep
    
    out <- do.call(zoo::merge, args)
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "read.zoo") {
    file_arg <- require_field("file", payload, fn_name)
    format_arg <- if (is.null(payload$format)) NULL else as.character(payload$format)
    tz_arg <- if (is.null(payload$tz)) NULL else as.character(payload$tz)
    regular <- if (is.null(payload$regular)) NULL else as.logical(payload$regular)
    index.column <- if (is.null(payload$index.column)) NULL else as.numeric(payload$index.column)
    drop_arg <- if (is.null(payload$drop)) NULL else as.logical(payload$drop)
    text_arg <- if (is.null(payload$text)) NULL else as.character(payload$text)
    
    # Note: FUN and FUN2 are functions, which cannot be passed via JSON easily.
    # We assume standard usage or that the user provides strings for simple cases.
    # For this dispatcher, we focus on the data-driven arguments.
    
    args <- list(file = file_arg)
    if (!is.null(format_arg)) args$format <- format_arg
    if (!is.null(tz_arg)) args$tz <- tz_arg
    if (!is.null(regular)) args$regular <- regular
    if (!is.null(index.column)) args$index.column <- index.column
    if (!is.null(drop_arg)) args$drop <- drop_arg
    if (!is.null(text_arg)) args$text <- text_arg
    
    out <- do.call(zoo::read.zoo, args)
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "rollapply") {
    x <- require_field("x", payload, fn_name)
    width <- as.integer(require_field("width", payload, fn_name))
    # FUN is a function. In JSON, we can only support a predefined set or 
    # assume the user provides a name that we map.
    # For this implementation, we check if 'FUN' is a string name.
    fun_name <- payload$FUN
    if (is.null(fun_name)) {
      emit_error("Field `FUN` is required for rollapply.", fn_name)
    }
    
    # Map string names to actual R functions
    f <- if (fun_name == "mean") mean else if (fun_name == "sum") sum else if (fun_name == "sd") sd else NULL
    if (is.null(f)) {
      emit_error("Only 'mean', 'sum', and 'sd' are supported for FUN in rollapply.", fn_name)
    }
    
    out <- zoo::rollapply(x = x, width = width, FUN = f)
    emit_ok(as.character(out), fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
