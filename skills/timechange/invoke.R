#!/usr/bin/env Rscript
# timechange skill dispatcher.
# Reads one JSON object from stdin, invokes the requested timechange function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_timechange <- requireNamespace("timechange", quietly = TRUE)
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
      "The R package 'jsonlite' is required by the timechange skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_timechange) {
  emit_error(
    paste(
      "The R package 'timechange' is required but is not installed.",
      "Run: install.packages('timechange')."
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
  
  if (fn_name == "time_add") {
    time <- as.character(require_field("time", payload, fn_name))
    # periods is a named list
    periods <- payload$periods
    
    # Extract optional numeric/integer components from the periods list
    # Note: the upstream signature allows individual args or a list.
    # We follow the provided UPSTREAM SIGNATURES block.
    year   <- if (!is.null(payload$year))   as.integer(payload$year)   else NULL
    month  <- if (!is.null(payload$month))  as.integer(payload$month)  else NULL
    week   <- if (!is.null(payload$week))   as.integer(payload$week)   else NULL
    day    <- if (!is.null(payload$day))    as.integer(payload$day)    else NULL
    hour   <- if (!is.null(payload$hour))   as.integer(payload$hour)   else NULL
    minute <- if (!is.null(payload$minute)) as.integer(payload$minute) else NULL
    second <- if (!is.null(payload$second)) as.integer(payload$second) else NULL
    
    # Reconstruct the periods list for the function call
    p_list <- list()
    if (!is.null(year))   p_list$year   <- year
    if (!is.null(month))  p_list$month  <- month
    if (!is.null(week))   p_list$week   <- week
    if (!is.null(day))    p_list$day    <- day
    if (!is.null(hour))   p_list$hour   <- hour
    if (!is.null(minute)) p_list$minute <- minute
    if (!is.null(second)) p_list$second <- second
    
    # If the payload provided 'periods' directly as a list
    if (!is.null(payload$periods)) {
      p_list <- payload$periods
    }

    roll_month <- if (!is.null(payload$roll_month)) as.character(payload$roll_month) else NULL
    roll_dst   <- if (!is.null(payload$roll_dst))   as.character(payload$payload$roll_dst) else NULL
    # Note: roll_dst check uses payload$roll_dst directly
    roll_dst <- if (!is.null(payload$roll_dst)) as.character(payload$roll_dst) else NULL

    out <- timechange::time_add(
      time = as.POSIXct(time, tz = "UTC"), 
      periods = p_list,
      roll_month = roll_month,
      roll_dst = roll_dst
    )
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "time_get") {
    time <- as.character(require_field("time", payload, fn_name))
    components <- as.character(require_field("components", payload, fn_name))
    week_start <- if (!is.null(payload$week_start)) as.integer(payload$week_start) else NULL
    
    # time_get returns a list or vector depending on components
    # We use tryCatch to handle the internal logic
    out <- timechange::time_get(
      time = as.POSIXct(time, tz = "UTC"),
      components = components,
      week_start = week_start
    )
    emit_ok(out, fn_name)

  } else if (fn_name == "time_round") {
    time <- as.character(require_field("time", payload, fn_name))
    unit <- as.character(require_field("unit", payload, fn_name))
    week_start <- if (!is.null(payload$week_start)) as.integer(payload$week_start) else NULL
    origin <- if (!is.null(payload$origin)) as.character(payload$origin) else NULL
    change_on_boundary <- if (!is.null(payload$change_on_boundary)) payload$change_on_boundary else NULL

    out <- timechange::time_round(
      time = as.POSIXct(time, tz = "UTC"),
      unit = unit,
      week_start = week_start,
      origin = origin,
      change_on_boundary = change_on_boundary
    )
    emit_ok(as.character(out), fn_name)

  } else if (fn_name == "time_update") {
    time <- as.character(require_field("time", payload, fn_name))
    # updates is a named list
    updates <- payload$updates
    
    # If individual components are provided in the payload instead of 'updates' list
    if (!is.null(payload$year) || !is.null(payload$month) || !is.null(payload$mday) || 
        !is.null(payload$hour) || !is.null(payload$minute) || !is.null(payload$second)) {
      updates <- list()
      if (!is.null(payload$year))   updates$year   <- as.integer(payload$year)
      if (!is.null(payload$month))  updates$month  <- as.integer(payload$month)
      if (!is.null(payload$yday))   updates$yday   <- as.integer(payload$yday)
      if (!is.null(payload$wday))   updates$wday   <- as.integer(payload$wday)
      if (!is.null(payload$mday))   updates$mday   <- as.integer(payload$mday)
      if (!is.null(payload$hour))   updates$hour   <- as.integer(payload$hour)
      if (!is.null(payload$minute)) updates$minute <- as.integer(payload$minute)
      if (!is.null(payload$second)) updates$second <- as.integer(payload$second)
    }

    tz <- if (!is.null(payload$tz)) as.character(payload$tz) else NULL
    roll_month <- if (!is.null(payload$roll_month)) as.character(payload$roll_month) else NULL
    roll_dst <- if (!is.null(payload$roll_dst)) as.character(payload$roll_dst) else NULL
    week_start <- if (!is.null(payload$week_start)) as.integer(payload$week_start) else NULL
    exact <- if (!is.null(payload$exact)) as.logical(payload$exact) else NULL

    out <- timechange::time_update(
      time = as.POSIXct(time, tz = "UTC"),
      updates = updates,
      tz = tz,
      roll_month = roll_month,
      roll_dst = roll_dst,
      week_start = week_start,
      exact = exact
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
