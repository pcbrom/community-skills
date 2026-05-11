#!/usr/bin/env Rscript
# ragg skill dispatcher.
# Reads one JSON object from stdin, invokes the requested ragg function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_ragg     <- requireNamespace("ragg",     quietly = TRUE)
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
      "The R package 'jsonlite' is required by the ragg skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_ragg) {
  emit_error(
    paste(
      "The R package 'ragg' is required but is not installed.",
      "Run: install.packages('ragg')."
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
  
  if (fn_name == "agg_capture") {
    width      <- as.numeric(require_field("width",      payload, fn_name))
    height     <- as.numeric(require_field("height",     payload, fn_name))
    units      <- as.character(require_field("units",     payload, fn_name))
    pointsize  <- if (is.null(payload$pointsize))  NULL else as.numeric(payload$pointsize)
    background <- if (is.null(payload$background)) NULL else as.character(payload$background)
    res        <- if (is.null(payload$res))        NULL else as.numeric(payload$res)
    scaling     <- if (is.null(payload$scaling))    NULL else as.numeric(payload$numeric_scaling_fallback(payload$scaling))
    # Note: scaling is numeric in R, but payload might pass it as a number.
    # We use a helper to handle the logic if it were a complex object, 
    # but here we just coerce.
    scaling     <- if (is.null(payload$scaling))    NULL else as.numeric(payload$scaling)
    snap_rect   <- if (is.null(payload$snap_rect))  NULL else isTRUE(payload$snap_rect)
    bg          <- if (is.null(payload$bg))        NULL else as.character(payload$bg)

    # Re-assigning scaling logic to be safe
    args <- list(width = width, height = height, units = units, pointsize = pointsize, 
                 background = background, res = res, scaling = scaling, 
                 snap_rect = snap_rect, bg = bg)
    args <- args[!vapply(args, is.null, logical(1))]
    
    native <- if (is.null(payload$native)) FALSE else isTRUE(payload$native)
    
    out <- ragg::agg_capture(native = native, ...) # This is a placeholder for the logic below
    # Correct implementation:
    res_val <- tryCatch({
      ragg::agg_capture(width = width, height = height, units = units, 
                        pointsize = pointsize, background = background, 
                        res = res, scaling = scaling, snap_rect = snap_rect, bg = bg,
                        native = native)
    }, error = function(e) e)
    
    if (inherits(res_val, "error")) stop(conditionMessage(res_val))
    emit_ok(res_val, fn_name)

  } else if (fn_name == "agg_jpeg") {
    filename  <- as.character(require_field("filename",  payload, fn_name))
    width     <- as.numeric(require_field("width",     payload, fn_name))
    height    <- as.numeric(require_field("height",    payload, fn_name))
    units     <- as.character(require_field("units",     payload, fn_name))
    pointsize <- if (is.null(payload$pointsize))  NULL else as.numeric(payload$pointsize)
    background <- if (is.null(payload$background)) NULL else as.character(payload$background)
    res       <- if (is.null(payload$res))        NULL else as.numeric(payload$res)
    scaling    <- if (is.null(payload$scaling))    NULL else as.numeric(payload$scaling)
    snap_rect  <- if (is.null(payload$snap_rect))  NULL else isTRUE(payload$snap_rect)
    quality    <- if (is.null(payload$quality))    NULL else as.integer(payload$quality)
    smoothing  <- if (is.null(payload$smoothing))  NULL else payload$smoothing
    method     <- if (is.null(payload$method))     NULL else as.character(payload$method)
    bg         <- if (is.null(payload$bg))        NULL else as.character(payload$bg)

    args <- list(filename = filename, width = width, height = height, units = units,
                 pointsize = pointsize, background = background, res = res, 
                 scaling = scaling, snap_rect = snap_rect, quality = quality,
                 smoothing = smoothing, method = method, bg = bg)
    args <- args[!vapply(args, is.null, logical(1))]

    res_val <- tryCatch({
      do.call(ragg::agg_jpeg, args)
    }, error = function(e) e)

    if (inherits(res_val, "error")) stop(conditionMessage(res_val))
    emit_ok(NULL, fn_name)

  } else if (fn_name == "agg_png") {
    filename  <- as.character(require_field("filename",  payload, fn_name))
    width     <- as.numeric(require_field("width",     payload, fn_name))
    height    <- as.numeric(require_field("height",    payload, fn_name))
    units     <- as.character(require_field("units",     payload, fn_name))
    pointsize <- if (is.null(payload$pointsize))  NULL else as.numeric(payload$pointsize)
    background <- if (is.null(payload$background)) NULL else as.character(payload$background)
    res       <- if (is.null(payload$res))        NULL else as.numeric(payload$res)
    scaling    <- if (is.null(payload$scaling))    NULL else as.numeric(payload$scaling)
    snap_rect  <- if (is.null(payload$snap_rect))  NULL else isTRUE(payload$snap_rect)
    bitsize    <- if (is.null(payload$bitsize))    NULL else as.integer(payload$bitsize)
    bg         <- if (is.null(payload$bg))        NULL else as.character(payload$suppress_bg_logic(payload$bg))
    # Note: logic for bg/background is handled by passing what is provided.
    
    args <- list(filename = filename, width = width, height = height, units = units,
                 pointsize = pointsize, background = background, res = res, 
                 scaling = scaling, snap_rect = snap_rect, bitsize = bitsize, bg = bg)
    args <- args[!vapply(args, is.null, logical(1))]

    res_val <- tryCatch({
      do.call(ragg::agg_png, args)
    }, error = function(e) e)

    if (inherits(res_val, "error")) stop(conditionMessage(res_val))
    emit_ok(NULL, fn_name)

  } else if (fn_name == "agg_ppm") {
    filename  <- as.character(require_field("filename",  payload, fn_name))
    width     <- as.numeric(require_field("width",     payload, fn_name))
    height    <- as.numeric(require_field("height",    payload, fn_name))
    units     <- as.character(require_field("units",     payload, fn_name))
    pointsize <- if (is.null(payload$pointsize))  NULL else as.numeric(payload$pointsize)
    background <- if (is.null(payload$background)) NULL else as.character(payload$background)
    res       <- if (is.null(payload$res))        NULL else as.numeric(payload$res)
    scaling    <- if (is.null(payload$scaling))    NULL else as.numeric(payload$scaling)
    snap_rect  <- if (is.null(payload$snap_rect))  NULL else isTRUE(payload$snap_rect)
    bg         <- if (is.null(payload$bg))        NULL else as.character(payload$bg)

    args <- list(filename = filename, width = width, height = height, units = units,
                 pointsize = pointsize, background = background, res = res, 
                 scaling = scaling, snap_rect = snap_rect, bg = bg)
    args <- args[!vapply(args, is.null, logical(1))]

    res_val <- tryCatch({
      do.call(ragg::agg_ppm, args)
    }, error = function(e) e)

    if (inherities(res_val, "error")) stop(conditionMessage(res_val))
    emit_ok(NULL, fn_name)

  } else if (fn_name == "agg_webp") {
    filename <- as.character(require_field("filename", payload, fn_name))
    lossless <- if (is.null(payload$lossless)) NULL else isTRUE(payload$lossless)
    
    res_val <- tryCatch({
      ragg::agg_webp(filename = filename, lossless = lossless)
    }, error = function(e) e)

    if (inherits(res_val, "error")) stop(conditionMessage(res_val))
    emit_ok(NULL, fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

# Helper for the specific logic of agg_capture arg handling
# (The dispatch function above is the primary logic)

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
