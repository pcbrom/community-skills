#!/usr/bin/env Rscript
# rmarkdown skill dispatcher.
# Reads one JSON object from stdin, invokes the requested rmarkdown function,
# and writes one JSON object to stdout. Errors are reported as
# {"ok": false, "error": "..."} with non-zero exit code.

# Redirect any R-level output to stderr so the only thing on stdout is the final JSON.
sink(stderr(), type = "output")

suppressPackageStartupMessages({
  ok_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)
  ok_rmarkdown <- requireNamespace("rmarkdown", quietly = TRUE)
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
      "The R package 'jsonlite' is required by the rmarkdown skill but is not",
      "installed. Run: install.packages('jsonlite')."
    )
  )
}

if (!ok_rmarkdown) {
  emit_error(
    paste(
      "The R package 'rmarkdown' is required but is not installed.",
      "Run: install.packages('rmarkdown')."
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
  
  if (fn_name == "render") {
    input <- as.character(require_field("input", payload, fn_name))
    output_format <- if (is.null(payload$output_format)) NULL else as.character(payload$output_format)
    
    args <- list(input = input)
    if (!is.null(output_format)) args$output_format <- output_format
    
    # Pass through other optional arguments from payload
    for (arg_name in setdiff(names(payload), c("fn", "input", "output_format"))) {
      args[[arg_name]] <- payload[[arg_name]]
    }

    res <- tryCatch(
      do.call(rmarkdown::render, args),
      error = function(e) e
    )
    if (inherits(res, "error")) stop(conditionMessage(res))
    emit_ok(as.character(res), fn_name)

  } else if (fn_name == "all_output_formats") {
    input <- as.character(require_field("input", payload, fn_name))
    
    res <- tryCatch(
      rmarkdown::all_output_formats(input = input),
      error = function(e) e
    )
    if (inherits(res, "error")) stop(conditionMessage(res))
    emit_ok(as.character(res), fn_name)

  } else if (fn_name == "available_templates") {
    package <- if (is.null(payload$package)) "rmarkdown" else as.character(payload$package)
    full_path <- if (is.null(payload$full_path)) NULL else as.logical(payload$full_path)
    
    args <- list(package = package)
    if (!is.null(full_path)) args$full_path <- full_path
    
    res <- tryCatch(
      do.call(rmarkdown::available_templates, args),
      error = function(e) e
    )
    if (inherits(res, "error")) stop(conditionMessage(res))
    emit_ok(as.character(res), fn_name)

  } else if (fn_name == "beamer_presentation") {
    toc <- if (is.null(payload$toc)) NULL else as.logical(payload$toc)
    slide_level <- if (is.null(payload$slide_level)) NULL else as.character(payload$slide_level)
    number_sections <- if (is.null(payload$number_sections)) NULL else as.logical(payload$number_sections)
    incremental <- if (is.null(payload$incremental)) NULL else as.logical(payload$incremental)
    fig_width <- if (is.null(payload$fig_width)) NULL else as.numeric(payload$fig_width)
    fig_height <- if (is.null(payload$fig_height)) NULL else as.numeric(payload$fig_height)
    fig_crop <- if (is.null(payload$fig_crop)) NULL else as.logical(payload$fig_crop)
    fig_caption <- if (is.null(payload$fig_caption)) NULL else as.logical(payload$fig_caption)
    dev <- if (is.null(payload$dev)) NULL else as.character(payload$dev)
    df_print <- if (is.null(payload$df_print)) NULL else as.character(payload$df_print)
    theme <- if (is.null(payload$theme)) NULL else as.character(payload$theme)
    colortheme <- if (is.null(payload$colortheme)) NULL else as.character(payload$colortheme)
    fonttheme <- if (is.null(payload$fonttheme)) NULL else as.character(payload$fonttheme)
    highlight <- if (is.null(payload$highlight)) NULL else as.character(payload$highlight)
    template <- if (is.null(payload$template)) NULL else payload$template
    keep_tex <- if (is.null(payload$keep_tex)) NULL else as.logical(payload$keep_tex)
    keep_md <- if (is.null(payload$keep_md)) NULL else as.logical(payload$keep_md)
    latex_engine <- if (is.null(payload$latex_engine)) NULL else as.character(payload$latex_engine)
    citation_package <- if (is.null(payload$citation_package)) NULL else as.character(payload$citation_package)
    self_contained <- if (is.null(payload$self_contained)) NULL else as.logical(payload$self_contained)
    includes <- if (is.null(payload$includes)) NULL else payload$includes
    md_extensions <- if (is.null(payload$md_extensions)) NULL else payload$md_extensions
    pandoc_args <- if (is.null(payload$pandoc_args)) NULL else payload$pandoc_args
    extra_dependencies <- if (is.null(payload$extra_dependencies)) NULL else payload$extra_dependencies

    args <- list()
    if (!is.null(toc)) args$toc <- toc
    if (!is.null(slide_level)) args$slide_level <- slide_level
    if (!is.null(number_sections)) args$number_sections <- number_sections
    if (!is.null(incremental)) args$incremental <- incremental
    if (!is.null(fig_width)) args$fig_width <- fig_width
    if (!is.null(fig_height)) args$fig_height <- fig_height
    if (!is.null(fig_crop)) args$fig_crop <- fig_crop
    if (!is.null(fig_caption)) args$fig_caption <- fig_caption
    if (!is.null(dev)) args$dev <- dev
    if (!is.null(df_print)) args$df_print <- df_print
    if (!is.null(theme)) args$theme <- theme
    if (!is.null(colortheme)) args$colortheme <- colortheme
    if (!is.null(fonttheme)) args$fonttheme <- fonttheme
    if (!is.null(highlight)) args$highlight <- highlight
    if (!is.null(template)) args$template <- template
    if (!is.null(keep_tex)) args$keep_tex <- keep_tex
    if (!is.null(keep_md)) args$keep_md <- keep_md
    if (!is.null(latex_engine)) args$latex_engine <- latex_engine
    if (!is.null(citation_package)) args$citation_package <- citation_package
    if (!is.null(self_contained)) args$self_contained <- self_contained
    if (!is.null(includes)) args$includes <- includes
    if (!is.null(md_extensions)) args$md_extensions <- md_extensions
    if (!is.null(pandoc_args)) args$pandoc_args <- pandoc_args
    if (!is.null(extra_dependencies)) args$extra_dependencies <- extra_dependencies

    res <- tryCatch(
      do.call(rmarkdown::beamer_presentation, args),
      error = function(e) e
    )
    if (inherits(res, "error")) stop(conditionMessage(res))
    emit_ok(res, fn_name)

  } else if (fn_name == "context_document") {
    toc <- if (is.null(payload$toc)) NULL else as.logical(payload$toc)
    toc_depth <- if (is.null(payload$toc_depth)) NULL else as.integer(payload$toc_depth)
    number_sections <- if (is.null(payload$number_sections)) NULL else as.logical(payload$number_sections)
    fig_width <- if (is.null(payload$fig_width)) NULL else as.numeric(payload$fig_width)
    fig_height <- if (is.null(payload$fig_height)) NULL else as.numeric(payload$fig_height)
    fig_crop <- if (is.null(payload$fig_crop)) NULL else as.logical(payload$fig_crop)
    fig_caption <- if (is.null(payload$fig_caption)) NULL else as.logical(payload$fig_caption)
    dev <- if (is.null(payload$dev)) NULL else as.character(payload$dev)
    df_print <- if (is.null(payload$df_print)) NULL else as.character(payload$df_print)
    template <- if (is.null(payload$template)) NULL else payload$template
    keep_tex <- if (is.null(payload$keep_tex)) NULL else as.logical(payload$keep_tex)
    keep_md <- if (is.null(payload$keep_md)) NULL else as.logical(payload$keep_md)
    citation_package <- if (is.null(payload$citation_package)) NULL else as.else(payload$citation_package)
    includes <- if (is.null(payload$includes)) NULL else payload$includes
    md_extensions <- if (is.null(payload$md_extensions)) NULL else payload$md_extensions
    output_extensions <- if (is.null(payload$output_extensions)) NULL else payload$output_extensions
    pandoc_args <- if (is.null(payload$pandoc_args)) NULL else payload$pandoc_args
    context_path <- if (is.null(payload$context_path)) NULL else as.character(payload$context_path)
    context_args <- if (is.null(payload$context_args)) NULL else payload$context_args
    ext <- if (is.null(payload$ext)) NULL else as.character(payload$ext)

    args <- list()
    if (!is.null(toc)) args$toc <- toc
    if (!is.null(toc_depth)) args$toc_depth <- toc_depth
    if (!is.null(number_sections)) args$number_sections <- number_sections
    if (!is.null(fig_width)) args$fig_width <- fig_width
    if (!is.null(fig_height)) args$fig_height <- fig_height
    if (!is.null(fig_crop)) args$fig_crop <- fig_crop
    if (!is.null(fig_caption)) args$fig_caption <- fig_caption
    if (!is.null(dev)) args$dev <- dev
    if (!is.null(df_print)) args$df_print <- df_print
    if (!is.null(template)) args$template <- template
    if (!is.null(keep_tex)) args$keep_tex <- keep_tex
    if (!is.null(keep_md)) args$keep_md <- keep_md
    if (!is.null(citation_package)) args$citation_package <- citation_package
    if (!is.null(includes)) args$includes <- includes
    if (!is.null(md_extensions)) args$md_extensions <- md_extensions
    if (!is.null(output_extensions)) args$output_extensions <- output_extensions
    if (!is.null(pandoc_args)) args$pandoc_args <- pandoc_args
    if (!is.null(context_path)) args$context_path <- context_path
    if (!is.null(context_args)) args$context_args <- context_args
    if (!is.null(ext)) args$ext <- ext

    res <- tryCatch(
      do.call(rmarkdown::context_document, args),
      error = function(e) e
    )
    if (inherits(res, "error")) stop(conditionMessage(res))
    emit_ok(res, fn_name)

  } else {
    emit_error(sprintf("Unknown fn '%s'. See SKILL.md for the supported set.", fn_name), fn_name)
  }
}

err <- tryCatch(dispatch(payload), error = function(e) e)
if (inherits(err, "error")) {
  emit_error(conditionMessage(err), fn_name)
}
