#!/usr/bin/env Rscript
# usethis skill dispatcher.
# Reads one JSON object from stdin, invokes the requested usethis function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_usethis  <- requireNamespace("usethis",  quietly = TRUE)
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
      "The R package 'jsonlite' is required by the usethis skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_usethis) {
  emit_error(
    paste(
      "The R package 'usethis' is required but is not installed.",
      "Run: install.packages('usethis')."
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
  if (fn_name == "create_from_github") {
    repo_spec <- as.character(require_field("repo_spec", payload, fn_name))
    destdir   <- if (is.null(payload$destdir)) NULL else as.character(payload$destdir)
    fork      <- if (is.null(payload$fork)) NULL else as.logical(payload$fork)
    rstudio   <- if (is.null(payload$rstudio)) NULL else as.logical(payload$rstudio)
    open      <- if (is.null(payload$open)) NULL else as.logical(payload$open)
    protocol  <- if (is.null(payload$protocol)) NULL else as.character(payload$protocol)
    host      <- if (is.null(payload$host)) NULL else as.character(payload$host)
    
    args <- list(repo_spec = repo_spec)
    if (!is.null(destdir)) args$destdir <- destdir
    if (!is.null(fork))    args$fork <- fork
    if (!is.null(rstudio)) args$rstudio <- rstudio
    if (!is.null(open))    args$open <- open
    if (!is.null(protocol)) args$protocol <- protocol
    if (!is.null(host))    args$host <- host
    
    out <- do.call(usethis::create_from_github, args)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "create_package") {
    path     <- as.character(require_field("path", payload, fn_name))
    fields   <- if (is.null(payload$fields)) NULL else payload$fields
    rstudio  <- if (is.null(payload$rstudio)) NULL else as.logical(payload$rstudio)
    roxygen  <- if (is.null(payload$roxygen)) NULL else as.logical(payload$roxygen)
    check_name <- if (is.null(payload$check_name)) NULL else as.logical(payload$check_name)
    open     <- if (is.null(payload$open)) NULL else as.logical(payload$open)
    type     <- if (is.null(payload$type)) NULL else as.character(payload$type)
    
    args <- list(path = path)
    if (!is.null(fields))  args$fields <- fields
    if (!is.null(rstudio)) args$rstudio <- rstudio
    if (!is.null(roxygen)) args$roxygen <- roxygen
    if (!is.null(check_name)) args$check_name <- check_name
    if (!is.null(open))    args$open <- open
    if (!is.null(type))    args$type <- type
    
    out <- do.call(usethis::create_package, args)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "edit_file") {
    path     <- as.character(require_field("path", payload, fn_name))
    open     <- if (is.null(payload$open)) NULL else as.logical(payload$open)
    template <- if (is.null(payload$template)) NULL else as.character(payload$template)
    
    args <- list(path = path)
    if (!is.null(open))     args$open <- open
    if (!is.null(template)) args$template <- template
    
    out <- do.call(usethis::edit_file, args)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "git_protocol") {
    protocol <- as.character(require_field("protocol", payload, fn_name))
    
    out <- do.call(usethile::git_protocol, list(protocol = protocol))
    emit_ok(out, fn_name)
    
  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
