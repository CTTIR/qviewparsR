#' Write a Q-View object to disk
#'
#' `r lifecycle::badge("experimental")`
#'
#' Three writers, one for each common destination. All return the input
#' `qv` invisibly so they compose with the pipe.
#'
#' * [write_qview_xlsx()] -- one sheet per parsed table.
#' * [write_qview_csv()]  -- one CSV per parsed table inside a directory.
#' * [write_qview_rds()]  -- a single `.rds` containing the full `qview`
#'   object (lossless, the only round-trippable format).
#'
#' @param qv A `qview` object from [read_qview()].
#' @param path Output path. For [write_qview_xlsx()] / [write_qview_rds()]
#'   this is a single file path; for [write_qview_csv()] it is the output
#'   directory (created if it does not exist).
#' @param template Optional plate-template tibble (from
#'   [read_qview_template()]) to include as an extra sheet / file.
#' @param overwrite Logical. If `FALSE` (the default), an existing
#'   destination triggers an error; set to `TRUE` to replace it.
#'   Ignored by [write_qview_csv()] (it only adds files).
#' @param call The execution environment of the calling function. Used
#'   for error reporting; experts only.
#'
#' @return `qv`, invisibly, to support pipelines.
#'
#' @examples
#' \dontrun{
#'   qv <- read_qview("plate.Q-View")
#'   qv |>
#'     write_qview_xlsx("plate.xlsx") |>
#'     write_qview_csv("plate_csv/")  |>
#'     write_qview_rds("plate.rds")
#' }
#'
#' @family qview-export
#' @name write_qview
NULL


#' @rdname write_qview
#' @export
write_qview_xlsx <- function(qv,
                             path,
                             template = NULL,
                             overwrite = FALSE,
                             call = rlang::caller_env()) {
  rlang::check_required(qv)
  rlang::check_required(path)
  .check_qview(qv, call = call)
  .check_string(path, call = call)
  .check_flag(overwrite, call = call)
  if (file.exists(path) && !overwrite) {
    cli::cli_abort(
      c("{.path {path}} already exists.",
        "i" = "Set {.code overwrite = TRUE} to replace it."),
      call = call
    )
  }
  wb <- openxlsx2::wb_workbook()
  add <- function(name, df) {
    if (is.null(df) || nrow(df) == 0L) return(invisible())
    wb$add_worksheet(name)
    wb$add_data(sheet = name, x = df)
  }
  add("metadata",           .qv_metadata_tibble(qv))
  add("analytes",           qv$analytes)
  add("well_groups",        qv$well_groups)
  add("plate_layout",       qv$plate_layout)
  add("pixel_intensities",  qv$pixel_intensities)
  add("summary_statistics", qv$summary_statistics)
  add("concentrations",     qv$concentrations)
  add("curve_fit",          qv$curve_fit)
  add("manifest",           qv$manifest)
  add("segments",           qv$segments)
  if (!is.null(template))   add("template", template)
  openxlsx2::wb_save(wb, file = path, overwrite = TRUE)
  invisible(qv)
}


#' @rdname write_qview
#' @export
write_qview_csv <- function(qv,
                            path,
                            template = NULL,
                            call = rlang::caller_env()) {
  rlang::check_required(qv)
  rlang::check_required(path)
  .check_qview(qv, call = call)
  .check_string(path, call = call)
  if (!dir.exists(path)) dir.create(path, recursive = TRUE)
  write_one <- function(name, df) {
    if (is.null(df) || nrow(df) == 0L) return(invisible())
    readr::write_csv(df, file.path(path, paste0(name, ".csv")))
  }
  write_one("metadata",           .qv_metadata_tibble(qv))
  write_one("analytes",           qv$analytes)
  write_one("well_groups",        qv$well_groups)
  write_one("plate_layout",       qv$plate_layout)
  write_one("pixel_intensities",  qv$pixel_intensities)
  write_one("summary_statistics", qv$summary_statistics)
  write_one("concentrations",     qv$concentrations)
  write_one("curve_fit",          qv$curve_fit)
  write_one("manifest",           qv$manifest)
  if (!is.null(template))         write_one("template", template)
  invisible(qv)
}


#' @rdname write_qview
#' @export
write_qview_rds <- function(qv,
                            path,
                            overwrite = FALSE,
                            call = rlang::caller_env()) {
  rlang::check_required(qv)
  rlang::check_required(path)
  .check_qview(qv, call = call)
  .check_string(path, call = call)
  .check_flag(overwrite, call = call)
  if (file.exists(path) && !overwrite) {
    cli::cli_abort(
      c("{.path {path}} already exists.",
        "i" = "Set {.code overwrite = TRUE} to replace it."),
      call = call
    )
  }
  saveRDS(qv, path)
  invisible(qv)
}


.qv_metadata_tibble <- function(qv) {
  tibble::tibble(
    field = names(qv$metadata),
    value = vapply(qv$metadata, function(v) {
      if (length(v) == 0L) return(NA_character_)
      paste(format(v), collapse = "; ")
    }, character(1L))
  )
}


# ---- Deprecated names ----------------------------------------------

#' @rdname write_qview
#' @param dir Deprecated alias for `path` accepted by `qview_to_csv_dir()`.
#'   Use `path` instead.
#' @export
qview_to_xlsx <- function(qv,
                          path,
                          template = NULL,
                          overwrite = FALSE,
                          call = rlang::caller_env()) {
  lifecycle::deprecate_warn(
    "1.1.0", "qview_to_xlsx()", "write_qview_xlsx()"
  )
  write_qview_xlsx(qv, path, template = template,
                   overwrite = overwrite, call = call)
}


#' @rdname write_qview
#' @export
qview_to_csv_dir <- function(qv,
                             dir,
                             template = NULL,
                             call = rlang::caller_env()) {
  lifecycle::deprecate_warn(
    "1.1.0", "qview_to_csv_dir()", "write_qview_csv()"
  )
  write_qview_csv(qv, path = dir, template = template, call = call)
}
