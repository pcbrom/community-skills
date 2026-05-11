#!/usr/bin/env Rscript
# isoband skill dispatcher.
# Reads one JSON object from stdin, invokes the requested isoband function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_isoband  <- requireNamespace("isoband",  quietly = TRUE)
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
      "The R package 'jsonlite' is required by the isoband skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_isoband) {
  emit_error(
    paste(
      "The R package 'isoband' is required but is not installed.",
      "Run: install.packages('isoband')."
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
  
  if (fn_name == "angle_halfcircle_bottom") {
    theta <- as.numeric(require_field("theta", payload, fn_name))
    out <- isoband::angle_halfcircle_bottom(theta = theta)
    emit_ok(as.numeric(out), fn_name)

  } else if (fn_name == "clip_lines") {
    x      <- as.numeric(require_field("x",      payload, fn_name))
    y      <- as.numeric(require_field("y",      payload, fn_name))
    id     <- as.integer(require_field("id",     payload, fn_name))
    boxes  <- require_field("clip_boxes", payload, fn_name)
    asp    <- if (is.null(payload$asp)) NULL else as.numeric(payload$asp)
    
    # Convert boxes list/data.frame to data.frame with correct types
    boxes_df <- as.data.frame(boxes)
    boxes_df$x     <- as.numeric(boxes_df$x)
    boxes_df$y     <- as.numeric(boxes_df$y)
    boxes_df$width <- as.numeric(boxes_df$width)
    boxes_df$height<- as.numeric(boxes_df$height)
    boxes_df$theta <- as.numeric(boxes_df$theta)

    # Note: The upstream signature uses 'clip_boxes' in the payload but 
    # the function expects 'clip_boxes' as an argument.
    # We pass the arguments as defined in the signature.
    out <- isoband::clip_lines(x = x, y = y, id = id, clip_boxes = boxes_df, asp = asp)
    emit_ok(as.numeric(out), fn_name)

  } else if (fn_name == "iso_to_sfg") {
    x <- require_field("x", payload, fn_name)
    out <- isoband::iso_to_sfg(x = x)
    emit_ok(out, fn_name)

  } else if (fn_name == "isobands") {
    x          <- as.numeric(require_field("x",          payload, fn_name))
    y          <- as.numeric(require_field("y",          payload, fn_name))
    z          <- as.numeric(require_field("z",          payload, fn_name))
    # z is a matrix, ensure it is treated as such
    z_mat      <- matrix(z, nrow = length(x), ncol = length(y), byrow = FALSE)
    levels_low <- if (is.null(payload$levels_low)) NULL else as.numeric(payload$levels_low)
    levels_high <- if (is.null(payload$levels_high)) NULL else as.numeric(payload$levels_high)
    levels     <- if (is.null(payload$levels)) NULL else as.numeric(payload$levels)
    
    out <- isoband::isobands(x = x, y = y, z = z_mat, 
                             levels_low = levels_low, 
                             levels_high = levels_high, 
                             levels = levels)
    emit_ok(as.numeric(out), fn_name)

  } else if (fn_name == "isolines") {
    x      <- as.numeric(require_field("x",      payload, fn_name))
    y      <- as.numeric(require_field("y",      payload, fn_name))
    z      <- as.numeric(require_field("z",      payload, fn_name))
    z_mat  <- matrix(z, nrow = length(x), ncol = length(y), byrow = FALSE)
    levels <- if (is.null(payload$levels)) NULL else as.numeric(payload$levels)
    
    out <- isoband::isolines(x = x, y = y, z = z_mat, levels = levels)
    emit_ok(as.numeric(out), fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
