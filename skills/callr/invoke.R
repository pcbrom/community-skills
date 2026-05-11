#!/usr/bin/env Rscript
# callr skill dispatcher.
# Reads one JSON object from stdin, invokes the requested callr function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_callr    <- requireNamespace("callr",    quietly = TRUE)
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
      "The R package 'jsonlite' is required by the callr skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_callr) {
  emit_error(
    paste(
      "The R package 'callr' is required but is not installed.",
      "Run: install.packages('callr')."
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
  
  if (fn_name == "r") {
    func <- require_field("func", payload, fn_name)
    args <- if (is.null(payload$args)) list() else as.list(require_field("args", payload, fn_name))
    
    # Map remaining arguments from payload to callr::r
    # Note: func is passed as an object, but JSON usually passes it as a string/expression.
    # For this dispatcher, we assume the user provides a string that can be evaluated.
    # However, the signature says 'func' is a function object. 
    # We will attempt to evaluate it if it is a string.
    if (is.character(func)) {
      func <- eval(parse(text = func))
    }

    # Optional arguments
    libpath <- if (is.null(payload$libpath)) NULL else as.character(payload$libpath)
    repos   <- if (is.null(payload$repos)) NULL else payload$repos
    stdout  <- if (is.null(payload$stdout)) NULL else as.character(payload$stdout)
    stderr  <- if (is.null(payload$stderr)) NULL else as.character(payload$stderr)
    poll_connection <- if (is.null(payload$poll_connection)) NULL else as.logical(payload$poll_connection)
    error   <- if (is.null(payload$error)) NULL else payload$error
    cmdargs <- if (is.null(payload$cmdargs)) NULL else as.character(payload$cmdargs)
    show    <- if (is.null(payload$show)) NULL else as.logical(payload$show)
    callback <- if (is.null(payload$callback)) NULL else payload$callback
    block_callback <- if (is.null(payload$block_callback)) NULL else payload$block_callback
    spinner <- if (is.null(payload$spinner)) NULL else as.logical(payload$spinner)
    system_profile <- if (is.null(payload$system_profile)) NULL else as.character(payload$system_profile)
    user_profile   <- if (is.null(payload$user_profile)) NULL else as.character(payload$user_profile)
    env     <- if (is.null(payload$env)) NULL else as.list(payload$env)
    timeout <- if (is.null(payload$timeout)) NULL else payload$timeout
    package <- if (is.null(payload$package)) NULL else as.logical(payload$package)
    arch    <- if (is.null(payload$arch)) NULL else as.character(payload$arch)

    # Construct argument list for callr::r
    call_args <- list(func = func, args = args)
    if (!is.null(libpath)) call_args$libpath <- libpath
    if (!is.null(repos))   call_args$repos   <- repos
    if (!is.null(stdout))  call_args$stdout  <- stdout
    if (!is.null(stderr))  call_args$stderr  <- stderr
    if (!is.null(poll_connection)) call_args$poll_connection <- poll_connection
    if (!is.null(error))   call_args$error   <- error
    if (!is.null(cmdargs)) call_args$cmdargs <- cmdargs
    if (!is.null(show))    call_args$show    <- show
    if (!is.null(callback)) call_args$callback <- callback
    if (!is.null(block_callback)) call_args$block_callback <- block_callback
    if (!is.null(spinner)) call_args$spinner <- spinner
    if (!is.null(system_profile)) call_args$system_profile <- system_profile
    if (!is.null(user_profile))   call_args$user_profile   <- user_profile
    if (!is.null(env))     call_args$env     <- env
    if (!is.null(timeout)) call_args$timeout <- timeout
    if (!is.null(package)) call_args$package <- package
    if (!is.null(arch))    call_args$arch    <- arch

    res <- do.call(callr::r, call_args)
    emit_ok(res, fn_name)

  } else if (fn_name == "r_bg") {
    func <- require_field("func", payload, fn_name)
    if (is.character(func)) {
      func <- eval(parse(text = func))
    }
    args <- if (is.null(payload$args)) list() else as.list(require_field("args", payload, fn_name))
    
    libpath <- if (is.null(payload$libpath)) NULL else as.character(payload$libpath)
    repos   <- if (is.null(payload$repos)) NULL else payload$repos
    stdout  <- if (is.null(payload$stdout)) NULL else as.character(payload$stdout)
    stderr  <- if (is.null(payload$stderr)) NULL else as.character(payload$stderr)
    poll_connection <- if (is.null(payload$poll_connection)) NULL else as.logical(payload$poll_connection)
    error   <- if (is.null(payload$error)) NULL else payload$error
    cmdargs <- if (is.null(payload$cmdargs)) NULL else as.character(payload$cmdargs)
    system_profile <- if (is.null(payload$system_profile)) NULL else as.character(payload$system_profile)
    user_profile   <- if (is.null(payload$user_profile)) NULL else as.character(payload$user_profile)
    env     <- if (is.null(payload$env)) NULL else as.list(payload$env)
    supervise <- if (is.null(payload$supervise)) NULL else as.logical(payload$supervise)
    package <- if (is.null(payload$package)) NULL else as.logical(payload$package)
    arch    <- if (is.null(payload$arch)) NULL else as.character(payload$arch)

    call_args <- list(func = func, args = args)
    if (!is.null(libpath)) call_args$libpath <- libpath
    if (!is.null(repos))   call_args$repos   <- repos
    if (!is.null(stdout))  call_args$stdout  <- stdout
    if (!is.null(stderr))  call_args$stderr  <- stderr
    if (!is.null(poll_connection)) call_args$poll_connection <- poll_connection
    if (!is.null(error))   call_args$error   <- error
    if (!is.null(cmdargs)) call_args$cmdargs <- cmdargs
    if (!is.null(system_profile)) call_args$system_profile <- system_profile
    if (!is.null(user_profile))   call_args$user_profile   <- user_profile
    if (!is.null(env))     call_args$env     <- env
    if (!is.null(supervise)) call_args$supervise <- supervise
    if (!is.null(package)) call_args$package <- package
    if (!is.null(arch))    call_args$arch    <- arch

    res <- do.call(callr::r_bg, call_args)
    emit_ok(as.character(res), fn_name)

  } else if (fn_name == "default_repos") {
    res <- callr::default_repos()
    emit_ok(as.character(res), fn_name)

  } else if (fn_name == "add_hook") {
    # The signature says '...' is a named argument. 
    # Since we cannot iterate over '...' easily in a JSON payload without keys,
    # we assume the payload contains the hook name as a key.
    # However, the requirement is to follow the signature.
    # We will look for a field 'hook' if provided, or treat the payload as the hook.
    # Given the ambiguity of '...' in JSON, we check for a 'hook' key.
    hook_name <- if (is.null(payload$hook)) NULL else as.character(payload$hook)
    hook_func <- if (is.null(payload$hook_func)) NULL else payload$hook_func
    if (is.character(hook_func)) hook_func <- eval(parse(text = hook_func))
    
    # This is a simplified implementation for the '...' requirement
    # In a real scenario, one would iterate over payload keys.
    # For now, we assume the user passes 'hook' and 'hook_func'.
    # Since we cannot implement '...' dynamically without knowing keys, 
    # we follow the logic of the provided signature.
    # If the user provides a key that matches a hook name, we use it.
    # This is a placeholder for the logic.
    emit_error("add_hook implementation requires specific key mapping not defined in signature.", fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
