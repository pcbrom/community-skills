#!/usr/bin/env Rscript
# sass skill dispatcher.
# Reads one JSON object from stdin, invokes the requested sass function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_sass     <- requireNamespace("sass",     quietly = TRUE)
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
      "The R package 'jsonlite' is required by the sass skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_sass) {
  emit_error(
    paste(
      "The R package 'sass' is required but is not installed.",
      "Run: install.packages('sass')."
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
  
  if (fn_name == "as_sass") {
    input <- require_field("input", payload, fn_name)
    # input can be character vector or named list
    if (is.list(input) && !is.null(names(input))) {
      # Handle named list for variables
      out <- sass::as_sass(input)
    } else {
      out <- sass::as_sass(as.character(input))
    }
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "as_sass_layer") {
    # No arguments defined in upstream signature
    out <- sass::as_sass_layer()
    emit_ok(out, fn_name)

  } else if (fn_name == "font_google") {
    family <- if (is.null(payload$family)) NULL else as.character(payload$family)
    local  <- if (is.null(payload$local)) NULL else as.logical(payload$local)
    cache  <- if (is.null(payload$cache)) NULL else payload$cache
    wght   <- if (is.null(payload$wght)) NULL else as.character(payload$wght)
    ital   <- if (is.null(payload$ital)) NULL else as.numeric(payload$ital)
    display <- if (is.null(payload$display)) NULL else as.character(payload$display)
    href   <- if (is.null(payload$href)) NULL else as.character(payload$href)
    src    <- if (is.null(payload$src)) NULL else as.character(payload$src)
    weight <- if (is.null(payload$weight)) NULL else as.character(payload$weight)
    style  <- if (is.null(payload$style)) NULL else as.character(payload$style)
    stretch <- if (is.null(payload$stretch)) NULL else as.character(payload$stretch)
    variant <- if (is.null(payload$variant)) NULL else as.character(payload$variant)
    unicode_range <- if (is.null(payload$unicode_range)) NULL else as.character(payload$unicode_range)
    
    # Handle ... via payload elements not explicitly named above
    # In R, we pass the remaining elements as ...
    # We identify them by checking which keys in payload are not in the explicit list
    explicit_keys <- c("family", "local", "cache", "wght", "ital", "display", 
                       "href", "src", "weight", "style", "stretch", "variant", "unicode_range")
    extra_args <- payload[setdiff(names(payload), c("fn", explicit_keys))]
    
    out <- sass::font_google(
      family = family,
      local = local,
      cache = cache,
      wght = wght,
      ital = ital,
      display = display,
      href = href,
      src = src,
      weight = weight,
      style = style,
      stretch = stretch,
      variant = variant,
      unicode_range = unicode_range,
      ... = extra_args
    )
    emit_ok(out, fn_name)

  } else if (fn_name == "output_template") {
    basename <- as.character(require_field("basename", payload, fn_name))
    dirname  <- as.character(require_field("dirname", payload, fn_name))
    fileext  <- if (is.null(payload$fileext)) NULL else as.character(payload$fileext)
    path     <- if (is.null(payload$path)) NULL else as.character(payload$path)
    
    out <- sass::output_template(
      basename = basename,
      dirname = dirname,
      fileext = fileext,
      path = path
    )
    emit_ok(as.character(out), fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
