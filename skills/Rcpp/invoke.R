#!/usr/bin/env Rscript
# Rcpp skill dispatcher.
# Reads one JSON object from stdin, invokes the requested Rcpp function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_Rcpp     <- requireNamespace("Rcpp",     quietly = TRUE)
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
      "The R package 'jsonlite' is required by the Rcpp skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_Rcpp) {
  emit_error(
    paste(
      "The R package 'Rcpp' is required but is not installed.",
      "Run: install.packages('Rcpp')."
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
  
  if (fn_name == "cppFunction") {
    code <- as.character(require_field("code", payload, fn_name))
    out <- tryCatch(
      Rcpp::cppFunction(code = code),
      error = function(e) e
    )
    if (inherits(out, "error")) {
      emit_error(conditionMessage(out), fn_name)
    }
    emit_ok("function", fn_name)

  } else if (fn_name == "sourceCpp") {
    file <- as.character(require_field("file", payload, fn_name))
    out <- tryCatch(
      Rcpp::sourceCpp(file = file),
      error = function(e) e
    )
    if (inherits(out, "error")) {
      emit_error(conditionMessage(out), fn_name)
    }
    emit_ok(NULL, fn_name)

  } else if (fn_name == "Rcpp.package.skeleton") {
    name      <- as.character(require_field("name", payload, fn_name))
    cpp_files <- if (is.null(payload$cpp_files)) NULL else as.character(payload$cpp_files)
    
    # Map remaining arguments from UPSTREAM SIGNATURES
    args <- list()
    if (!is.null(payload$path))      args$path      <- as.character(payload$path)
    if (!is.null(payload$force))     args$force     <- as.logical(payload$force)
    if (!is.null(payload$code_files)) args$code_files <- as.character(payload$code_files)
    if (!is.null(payload$example_code)) args$example_code <- as.logical(payload$example_code)
    if (!is.null(payload$attributes))   args$attributes   <- as.logical(payload$attributes)
    if (!is.null(payload$module))       args$module       <- as.logical(payload$module)
    if (!is.null(payload$author))       args$author       <- as.character(payload$author)
    if (!is.null(payload$maintainer))   args$maintainer   <- as.character(payload$maintainer)
    if (!is.null(payload$email))        args$email        <- as.character(payload$email)
    if (!is.null(payload$githubuser))   args$githubuser   <- as.character(payload$githubuser)
    if (!is.null(payload$license))      args$license      <- as.character(payload$license)
    
    out <- tryCatch(
      do.call(utils::package.skeleton, c(list(name = name), args)),
      error = function(e) e
    )
    if (inherits(out, "error")) {
      emit_error(conditionMessage(out), fn_name)
    }
    emit_ok(NULL, fn_name)

  } else if (fn_name == "Module") {
    module_name <- as.character(require_field("module_name", payload, fn_name))
    out <- tryCatch(
      Rcpp::Module(module_name),
      error = function(e) e
    )
    if (inherits(out, "error")) {
      emit_error(conditionMessage(out), fn_name)
    }
    emit_ok("module", fn_name)

  } else if (fn_name == "populate") {
    module_name <- as.character(require_field("module", payload, fn_name))
    env_name    <- as.character(require_field("env", payload, fn_name))
    # Note: env is passed as a string name, we must find the actual environment
    target_env  <- if (env_name == "namespace") asNamespace(module_name) else as.environment(env_name)
    
    out <- tryCatch(
      Rcpp::populate(module = module_name, env = target_env),
      error = function(e) e
    )
    if (inherits(out, "error")) {
      emit_error(conditionMessage(out), fn_name)
    }
    emit_ok(NULL, fn_name)

  } else if (fn_name == "setRcppClass") {
    class_name <- as.character(require_field("Class", payload, fn_name))
    cpp_class  <- as.character(require_field("CppClass", payload, fn_name))
    module_name <- as.character(require_field("module", payload, fn_name))
    
    # Handle optional arguments
    args <- list()
    if (!is.null(payload$fields))   args$fields   <- payload$fields
    if (!is.null(payload$contains)) args$contains <- payload$contains
    if (!is.null(payload$methods))  args$methods  <- payload$methods
    if (!is.null(payload$saveAs))   args$saveAs   <- payload$saveAs
    if (!is.null(payload$where))    args$where    <- payload$where
    
    out <- tryCatch(
      do.call(Rcpp::setRcppClass, c(list(Class = class_name, CppClass = cpp_class, module = module_name), args)),
      error = function(e) e
    )
    if (inherits(out, "error")) {
      emit_error(conditionMessage(out), fn_name)
    }
    emit_ok(NULL, fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
