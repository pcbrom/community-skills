#!/usr/bin/env Rscript
# dplyr skill dispatcher.
# Reads one JSON object from stdin, invokes the requested dplyr function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_dplyr    <- requireNamespace("dplyr",    quietly = TRUE)
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
      "The R package 'jsonlite' is required by the dplyr skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_dplyr) {
  emit_error(
    paste(
      "The R package 'dplyr' is required but is not installed.",
      "Run: install.packages('dplyr')."
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
  
  if (fn_name == "across") {
    .data <- require_field(".data", payload, fn_name)
    .cols <- require_field(".cols", payload, fn_name)
    .fns  <- require_field(".fns",  payload, fn_name)
    
    # .names and .unpack are optional
    .names <- if (is.null(payload$.names)) NULL else as.character(payload$.names)
    .unpack <- if (is.null(payload$.unpack)) NULL else isTRUE(payload$.unpack)
    
    out <- dplyr::across(.cols = .cols, .fns = .fns, .names = .names, .unpack = .unpack)
    # Note: across returns a selection/transformation context, 
    # but in a data frame context it is used within verbs.
    # For this dispatcher, we return the result of the operation.
    # Since across is a helper, we assume it is called in a context 
    # where the user expects the transformed columns.
    # However, as a standalone function, we return the result of the call.
    emit_ok(out, fn_name)

  } else if (fn_name == "all_equal") {
    target <- require_field("target", payload, fn_name)
    current <- require_field("current", payload, fn_name)
    ignore_col_order <- if (is.null(payload$ignore_col_order)) FALSE else isTRUE(payload$ignore_col_order)
    ignore_row_order <- if (is.null(payload$ignore_row_order)) FALSE else isTRUE(payload$ignore_row_order)
    convert <- if (is.null(payload$convert)) FALSE else isTRUE(payload$convert)
    
    out <- dplyr::all_equal(target, current, 
                             ignore_col_order = ignore_col_order, 
                             ignore_row_order = ignore_row_order, 
                             convert = convert)
    emit_ok(out, fn_name)

  } else if (fn_name == "all_vars") {
    # all_vars takes an expression. In this JSON context, we treat it as a string 
    # to be evaluated in the data mask.
    expr_str <- require_field("expr", payload, fn_name)
    # Since we don't have a .data provided for all_vars alone, 
    # we assume the user provides the context or we evaluate in global.
    # This is a limitation of stateless dispatch.
    out <- dplyr::all_vars(expr = parse(text = expr_str))
    emit_ok(out, fn_name)

  } else if (fn_name == "arrange") {
    .data <- require_field(".data", payload, fn_name)
    .by_group <- if (is.null(payload$.by_group)) FALSE else isTRUE(payload$.by_group)
    .locale <- if (is.null(payload$.locale)) NULL else as.character(payload$.locale)
    
    # The ... arguments are passed via the payload keys that are not .data, .by_group, or .locale
    # We extract all other keys as the '...' arguments.
    dots <- list()
    for (key in names(payload)) {
      if (!(key %in% c("fn", ".data", ".by_group", ".locale"))) {
        dots[[key]] <- payload[[key]]
      }
    }
    
    # We use do.call to pass the dots
    out <- do.call(dplyr::arrange, c(list(.data = .data, .by_group = .by_group, .locale = .locale), dots))
    emit_ok(out, fn_name)

  } else if (fn_name == "count") {
    .data <- require_field(".data", payload, fn_name)
    sort <- if (is.null(payload$sort)) FALSE else isTRUE(payload$sort)
    # count uses ... for grouping variables
    dots <- list()
    for (key in names(payload)) {
      if (!(key %in% c("fn", ".data", "sort"))) {
        dots[[key]] <- payload[[key]]
      }
    }
    out <- do.call(dplyr::count, c(list(.data = .data, sort = sort), dots))
    emit_ok(out, fn_name)

  } else if (fn_name == "distinct") {
    .data <- require_field(".data", payload, fn_name)
    .keep_all <- if (is.null(payload$.keep_all)) FALSE else is.logical(payload$.keep_all) && isTRUE(payload$.keep_all)
    
    dots <- list()
    for (key in names(payload)) {
      if (!(key %in% c("fn", ".data", ".keep_all"))) {
        dots[[key]] <- payload[[key]]
      }
    }
    out <- do.call(dplyr::distinct, c(list(.data = .data, .keep_all = .keep_all), dots))
    emit_ok(out, fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
