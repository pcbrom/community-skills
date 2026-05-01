#!/usr/bin/env Rscript
# bgumbel skill dispatcher.
# Reads one JSON object from stdin, invokes the requested bgumbel function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output (e.g. Metropolis acceptance rate banner from
# mlebgumbel) to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_bgumbel  <- requireNamespace("bgumbel",  quietly = TRUE)
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
      "The R package 'jsonlite' is required by the bgumbel skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_bgumbel) {
  emit_error(
    paste(
      "The R package 'bgumbel' is required but is not installed.",
      "Run: install.packages('bgumbel')."
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
  if (fn_name == "dbgumbel") {
    x     <- as.numeric(require_field("x",     payload, fn_name))
    mu    <- as.numeric(require_field("mu",    payload, fn_name))
    sigma <- as.numeric(require_field("sigma", payload, fn_name))
    delta <- as.numeric(require_field("delta", payload, fn_name))
    out <- bgumbel::dbgumbel(x = x, mu = mu, sigma = sigma, delta = delta)
    if (isTRUE(payload$log)) out <- log(out)
    emit_ok(as.numeric(out), fn_name)
  } else if (fn_name == "pbgumbel") {
    q     <- as.numeric(require_field("q",     payload, fn_name))
    mu    <- as.numeric(require_field("mu",    payload, fn_name))
    sigma <- as.numeric(require_field("sigma", payload, fn_name))
    delta <- as.numeric(require_field("delta", payload, fn_name))
    lower <- if (is.null(payload$lower_tail)) TRUE else isTRUE(payload$lower_tail)
    out <- bgumbel::pbgumbel(q = q, mu = mu, sigma = sigma, delta = delta, lower.tail = lower)
    emit_ok(as.numeric(out), fn_name)
  } else if (fn_name == "qbgumbel") {
    p       <- as.numeric(require_field("p",     payload, fn_name))
    mu      <- as.numeric(require_field("mu",    payload, fn_name))
    sigma   <- as.numeric(require_field("sigma", payload, fn_name))
    delta   <- as.numeric(require_field("delta", payload, fn_name))
    initial <- if (is.null(payload$initial)) -10 else as.numeric(payload$initial)
    final   <- if (is.null(payload$final))    10 else as.numeric(payload$final)
    out <- bgumbel::qbgumbel(p = p, mu = mu, sigma = sigma, delta = delta,
                             initial = initial, final = final)
    emit_ok(as.numeric(out), fn_name)
  } else if (fn_name == "rbgumbel") {
    n     <- as.integer(require_field("n",     payload, fn_name))
    mu    <- as.numeric(require_field("mu",    payload, fn_name))
    sigma <- as.numeric(require_field("sigma", payload, fn_name))
    delta <- as.numeric(require_field("delta", payload, fn_name))
    if (!is.null(payload$seed)) set.seed(as.integer(payload$seed))
    out <- bgumbel::rbgumbel(n = n, mu = mu, sigma = sigma, delta = delta)
    emit_ok(as.numeric(out), fn_name)
  } else if (fn_name == "m1bgumbel") {
    mu    <- as.numeric(require_field("mu",    payload, fn_name))
    sigma <- as.numeric(require_field("sigma", payload, fn_name))
    delta <- as.numeric(require_field("delta", payload, fn_name))
    out <- bgumbel::m1bgumbel(mu = mu, sigma = sigma, delta = delta)
    emit_ok(as.numeric(out), fn_name)
  } else if (fn_name == "m2bgumbel") {
    mu    <- as.numeric(require_field("mu",    payload, fn_name))
    sigma <- as.numeric(require_field("sigma", payload, fn_name))
    delta <- as.numeric(require_field("delta", payload, fn_name))
    out <- bgumbel::m2bgumbel(mu = mu, sigma = sigma, delta = delta)
    emit_ok(as.numeric(out), fn_name)
  } else if (fn_name == "init_theta") {
    data <- as.numeric(require_field("data", payload, fn_name))
    if (length(data) < 4) {
      emit_error("`data` must have at least 4 observations for init_theta.", fn_name)
    }
    # Robust starting values:
    #   mu    = median (resistant to outliers from the second mode)
    #   sigma = MAD scaled to a Gumbel-equivalent scale, with a small floor
    #   delta = 0.1 as a near-unimodal seed; let the optimizer move it away
    mu_init    <- stats::median(data)
    sigma_init <- max(stats::mad(data, constant = 1.4826), 1e-3)
    delta_init <- 0.1
    out <- list(
      mu    = unname(mu_init),
      sigma = unname(sigma_init),
      delta = unname(delta_init),
      strategy = "median + MAD + delta=0.1 (near-unimodal seed)",
      n = length(data)
    )
    emit_ok(out, fn_name)
  } else if (fn_name == "mlebgumbel") {
    data <- as.numeric(require_field("data", payload, fn_name))
    user_theta <- payload$theta
    auto_flag <- if (is.null(payload$auto)) TRUE else isTRUE(payload$auto)

    # Robust auto-init (same logic as init_theta) used as fallback.
    auto_theta <- function(d) {
      mu_init    <- stats::median(d)
      sigma_init <- max(stats::mad(d, constant = 1.4826), 1e-3)
      c(mu_init, sigma_init, 0.1)
    }

    if (is.null(user_theta)) {
      theta <- auto_theta(data)
      used_init <- "auto"
    } else {
      theta <- as.numeric(user_theta)
      used_init <- "user_supplied"
    }

    fit_result <- tryCatch(
      bgumbel::mlebgumbel(data = data, theta = theta, auto = auto_flag),
      error = function(e) e
    )

    # Fallback: if user-supplied theta failed, retry with auto-init.
    if (inherits(fit_result, "error") && used_init == "user_supplied") {
      theta <- auto_theta(data)
      used_init <- "fallback_auto_after_user_failed"
      fit_result <- tryCatch(
        bgumbel::mlebgumbel(data = data, theta = theta, auto = auto_flag),
        error = function(e) e
      )
    }

    if (inherits(fit_result, "error")) {
      emit_error(
        paste0(
          "MLE failed even after auto-init fallback: ",
          conditionMessage(fit_result),
          ". Try calling init_theta to inspect the suggested starting values."
        ),
        fn_name
      )
    }

    est_named <- fit_result$estimate$estimate
    sd_named  <- fit_result$estimate$sd
    estimate <- list(
      mu    = unname(est_named["mu"]),
      sigma = unname(est_named["sigma"]),
      delta = unname(est_named["delta"])
    )
    standard_error <- list(
      mu    = unname(sd_named["mu"]),
      sigma = unname(sd_named["sigma"]),
      delta = unname(sd_named["delta"])
    )
    out <- list(
      estimate = estimate,
      standard_error = standard_error,
      loglik = unname(fit_result$loglik),
      n = unname(fit_result$estimate$n),
      init_strategy = used_init,
      theta_used = list(
        mu    = unname(theta[1]),
        sigma = unname(theta[2]),
        delta = unname(theta[3])
      )
    )
    emit_ok(out, fn_name)
  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
