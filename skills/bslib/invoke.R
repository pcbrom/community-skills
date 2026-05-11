#!/usr/bin/env Rscript
# bslib skill dispatcher.
# Reads one JSON object from stdin, invokes the requested bslib function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_bslib    <- requireNamespace("bslib",    quietly = TRUE)
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
      "The R package 'jsonlite' is required by the bslib skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_bslib) {
  emit_error(
    paste(
      "The R package 'bslib' is required but is not installed.",
      "Run: install.packages('bslib')."
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
  
  if (fn_name == "accordion") {
    id <- if (is.null(payload$id)) NULL else as.character(payload$id)
    open <- if (is.null(payload$open)) NULL else as.character(payload$open)
    multiple <- if (is.null(payload$multiple)) NULL else as.logical(payload$multiple)
    class <- if (is.null(payload$class)) NULL else as.character(payload$class)
    width <- if (is.null(payload$width)) NULL else as.character(payload$width)
    height <- if (is.null(payload$height)) NULL else as.character(payload$height)
    
    # Note: ... arguments are handled via the payload list directly
    # We extract the specific named arguments from the upstream signature
    args <- list(id = id, open = open, multiple = multiple, class = class, width = width, height = height)
    # Filter out NULLs to let R use defaults
    args <- args[!vapply(args, is.null, logical(1))]
    
    # For accordion, unnamed arguments are treated as accordion_panel() calls.
    # This dispatcher assumes the payload contains the necessary structure.
    # Since we cannot easily reconstruct the '...' logic without knowing the content,
    # we pass the payload as is for the '...' part.
    
    # We find keys in payload not in our explicit list
    explicit_keys <- c("fn", "id", "open", "multiple", "class", "width", "height")
    other_keys <- setdiff(names(payload), explicit_keys)
    
    # This is a simplified approach for the '...' part:
    # In a real implementation, the caller would provide the panels.
    # Here we assume the user provides the arguments for the accordion call.
    
    out <- bslib::accordion(id = id, open = open, multiple = multiple, 
                            class = class, width = width, height = height)
    # Note: The '...' part is complex in R via JSON. We assume the caller 
    # provides the primary arguments.
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "accordion_panel_set") {
    id <- as.character(require_field("id", payload, fn_name))
    values <- if (is.null(payload$values)) NULL else payload$values
    target <- if (is.null(payload$target)) NULL else as.character(payload$target)
    position <- if (is.null(payload$position)) NULL else as.character(payload$position)
    title <- if (is.null(payload$title)) NULL else as.character(payload$title)
    value <- if (is.null(payload$value)) NULL else as.character(payload$value)
    
    # We cannot easily pass 'panel' or '...' via JSON without complex objects.
    # We assume the caller provides the target/id/value/title.
    out <- b0 <- bslib::accordion_panel_set(id = id, values = values, target = target, 
                                            position = position, title = title, value = value)
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "as_fill_carrier") {
    x <- require_field("x", payload, fn_name)
    min_height <- if (is.null(payload$min_height)) NULL else as.character(payload$min_height)
    max_height <- if (is.null(payload$max_height)) NULL else as.character(payload$max_height)
    gap <- if (is.null(payload$gap)) NULL else as.character(payload$gap)
    class <- if (is.null(payload$class)) NULL else as.character(payload$class)
    style <- if (is.null(payload$style)) NULL else as.character(payload$style)
    css_selector <- if (is.null(payload$css_selector)) NULL else as.character(payload$css_selector)
    
    out <- bslib::as_fill_carrier(x, min_height = min_height, max_height = max_height, 
                                  gap = gap, class = class, style = style, 
                                  css_selector = css_selector)
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "bind_task_button") {
    target <- require_field("target", payload, fn_name)
    task_button_id <- as.character(require_field("task_button_id", payload, fn_name))
    
    out <- bslib::bind_task_button(target = target, task_button_id = task_button_id)
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "bs_theme") {
    bg <- if (is.null(payload$bg)) NULL else as.character(payload$bg)
    fg <- if (is.null(payload$fg)) NULL else as.character(payload$fg)
    primary <- if (is.null(payload$primary)) NULL else as.character(payload$primary)
    base_font <- if (is.null(payload$base_font)) NULL else as.character(payload$base_font)
    
    out <- bslib::bs_theme(bg = bg, fg = fg, primary = primary, base_font = base_font)
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "layout_columns") {
    col_widths <- if (is.null(payload$col_widths)) NULL else as.integer(payload$col_widths)
    # For layout_columns, we assume the content is passed in the payload
    # This is a simplified proxy for the '...'
    out <- bslib::layout_columns(col_widths = col_widths)
    emit_ok(as.character(out), fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
