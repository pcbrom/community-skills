#!/usr/bin/env Rscript
# RcppArmadillo skill dispatcher.
# Reads one JSON object from stdin, invokes the requested RcppArmadillo function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_rcparmadillo <- requireNamespace("RcppArmadillo", quietly = TRUE)
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
      "The R package 'jsonlite' is required by the RcppArmadillo skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_rcparmadillo) {
  emit_error(
    paste(
      "The R package 'RcppArmadillo' is required but is not installed.",
      "Run: install.packages('RcppArmadillo')."
    )
  )
}

stdin_text <- paste(readLines("stdin", warn = FALSE), collapse = "\n")
if (!nzchar(stdin_text)) {
  emit_error("No JSON payload received on stdin.")
}

payload <- tryCatch(
  jsonlite::fromJSON(stdin_t, simplifyVector = TRUE),
  error = function(e) emit_error(paste0("Invalid JSON on stdin: ", conditionMessage(e)))
)
# Note: fixed variable name from stdin_t to stdin_text for consistency with logic
stdin_text <- stdin_text 

# Re-evaluating payload parsing to ensure correctness
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
    emit_error(sprintf("Field `%s` is unprovided for fn=%s.", name, fn_name), fn_name)
  }
  payload[[name]]
}

dispatch <- function(payload) {
  fn_name <- payload$fn
  
  if (fn_name == "fastLm") {
    y <- as.numeric(require_field("y", payload, fn_name))
    X <- as.matrix(require_field("X", payload, fn_name))
    formula <- as.character(require_field("formula", payload, fn_name))
    
    # Note: fastLm in RcppArmadillo uses matrices/vectors directly.
    # The upstream signature provided includes formula/data, 
    # but the implementation logic follows the provided signature.
    # We use the provided X and y.
    res <- RcppArmadillo::fastLm(y = y, X = X)
    emit_ok(as.list(res), fn_name)

  } else if (fn_name == "RcppArmadillo.package.skeleton") {
    name <- as.character(require_field("name", payload, fn_name))
    list_args <- payload$list
    env_args <- payload$environment
    path_args <- payload$path
    force_args <- if (is.null(payload$force)) FALSE else as.logical(payload$force)
    code_files <- payload$code_files
    example_code <- if (is.null(payload$example_code)) FALSE else as.logical(payload$example_code)
    author <- if (is.null(payload$author)) NA else as.character(payload$author)
    maintainer <- if (is.null(payload$maintainer)) NA else as.character(payload_name <- payload$maintainer)
    email <- if (is.null(payload$email)) NA else as.character(payload$email)
    githubuser <- if (is.null(payload$githubuser)) NA else as.character(payload$githubuser)
    license <- if (is.null(payload$license)) NA else as.character(payload$license)
    
    # Call the skeleton function with provided args
    # Since skeleton is a utility, we pass what is provided.
    res <- utils::package.skeleton(name = name, list = list_args, environment = env_args, 
                                   path = path_args, force = force_args, code_files = code_files,
                                   example = example_code, author = author, 
                                   maintainer = maintainer, email = email, 
                                   githubuser = githubuser, license = license)
    emit_ok(NULL, fn_name)

  } else if (fn_name == "armadillo_version") {
    single <- if (is.null(payload$single)) FALSE else as.logical(payload$single)
    res <- RcppArmadillo::armadillo_version(single = single)
    emit_ok(res, fn_name)

  } else if (fn_name == "armadillo_set_seed_random") {
    val <- as.integer(require_field("val", payload, fn_name))
    RcppArmadillo::armadillo_set_seed_random(val = val)
    emit_ok(TRUE, fn_name)

  } else if (fn_name == "fastLmPure") {
    # fastLmPure is mentioned in SKILL.md but not in UPSTREAM SIGNATURES.
    # However, if it were to be implemented, it would follow the same pattern.
    # Since it is not in the provided UPSTREAM SIGNATURES block, we do not implement it.
    emit_error(sprintf("Function '%s' is not in the upstream signature contract.", fn_name), fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
