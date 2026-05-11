#!/usr/bin/env Rscript
# pkgload skill dispatcher.
# Reads one JSON object from stdin, invokes the requested pkgload function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_pkgload  <- requireNamespace("pkgload",  quietly = TRUE)
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
      "The R package 'jsonlite' is required by the pkgload skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_pkgload) {
  emit_error(
    paste(
      "The R package 'pkgload' is required but is not installed.",
      "Run: install.packages('pkgload')."
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
  
  if (fn_name == "check_dep_version") {
    dep_name <- as.character(require_field("dep_name", payload, fn_name))
    dep_ver  <- as.character(require_field("dep_ver",  payload, fn_name))
    out <- pkgload::check_dep_version(dep_name = dep_name, dep_ver = dep_ver)
    emit_ok(as.logical(out), fn_name)
    
  } else if (fn_name == "check_suggested") {
    package <- as.character(require_field("package", payload, fn_name))
    version <- as.character(require_field("version", payload, fn_name))
    compare <- as.character(require_field("compare", payload, fn_name))
    out <- pkgload::check_suggested(package = package, version = version, compare = compare)
    emit_ok(as.logical(out), fn_name)
    
  } else if (fn_name == "dev_example") {
    topic      <- as.character(require_field("topic", payload, fn_name))
    path       <- if (is.null(payload$path)) NULL else as.character(payload$path)
    quiet      <- if (is.null(payload$quiet)) NULL else isTRUE(payload$quiet)
    run_donttest <- if (is.null(payload$run_donttest)) NULL else isTRUE(payload$run_donttest)
    run_dontrun   <- if (is.null(payload$run_dontrun)) NULL else isTRUE(payload$run_dontrun)
    env        <- if (is.null(payload$env)) NULL else payload$env
    macros     <- if (is.null(payload$macros)) NULL else payload$macros
    # Note: 'run' and 'test' are deprecated in upstream
    
    args <- list(topic = topic, path = path, quiet = quiet, 
                 run_donttest = run_donttest, run_dontrun = run_dontrun, 
                 env = env, macros = macros)
    # Filter NULLs to let R use defaults
    args <- args[!vapply(args, is.null, logical(1))]
    
    out <- do.call(pkgload::dev_example, args)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "dev_help") {
    topic       <- as.character(require_field("topic", payload, fn_name))
    pkg_name    <- if (is.null(payload$pkg_name)) NULL else as.character(payload$pkg_name)
    path        <- if (is.null(payload$path)) NULL else as.character(payload$path)
    stage       <- if (is.null(payload$stage)) NULL else as.character(payload$stage)
    type        <- if (is.null(payload$type)) NULL else as.character(payload$type)
    dev_packages <- if (is.null(payload$dev_packages)) NULL else as.character(payload$dev_packages)
    
    args <- list(topic = topic, pkg_name = pkg_name, path = path, 
                 stage = stage, type = type, dev_packages = dev_packages)
    args <- args[!vapply(args, is.null, logical(1))]
    
    out <- do.call(pkgload::dev_help, args)
    emit_ok(out, fn_name)
    
  } else if (fn_name == "load_all") {
    path <- as.character(require_field("path", payload, fn_name))
    out <- pkgload::load_all(path = path)
    emit_ok(out, fn_name)
    
  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
