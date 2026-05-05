#' Write a Q-View object to a multi-sheet Excel workbook
#'
#' `r lifecycle::badge("experimental")`
#'
#' @param qv A `qview` object from [read_qview()].
#' @param path Output `.xlsx` path.
#' @param template Optional plate-template tibble (from
#'   [read_qview_template()]) to include as an extra sheet.
#' @param overwrite Logical. If `FALSE` (the default), an existing file
#'   at `path` triggers an error; set to `TRUE` to replace it.
#' @param call The execution environment of the calling function. Used
#'   for error reporting; experts only.
#'
#' @return `qv`, invisibly, to support pipelines.
#'
#' @family qview-export
#'
#' @export
qview_to_xlsx <- function(qv,
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


#' Write a Q-View object as a directory of CSV files
#'
#' `r lifecycle::badge("experimental")`
#'
#' @param qv A `qview` object from [read_qview()].
#' @param dir Output directory (created if it does not exist).
#' @param template Optional plate-template tibble to include.
#' @param call The execution environment of the calling function. Used
#'   for error reporting; experts only.
#'
#' @return `qv`, invisibly, to support pipelines.
#'
#' @family qview-export
#'
#' @export
qview_to_csv_dir <- function(qv,
                             dir,
                             template = NULL,
                             call = rlang::caller_env()) {
  rlang::check_required(qv)
  rlang::check_required(dir)
  .check_qview(qv, call = call)
  .check_string(dir, call = call)
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)
  write_one <- function(name, df) {
    if (is.null(df) || nrow(df) == 0L) return(invisible())
    readr::write_csv(df, file.path(dir, paste0(name, ".csv")))
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


.qv_metadata_tibble <- function(qv) {
  tibble::tibble(
    field = names(qv$metadata),
    value = vapply(qv$metadata, function(v) {
      if (length(v) == 0L) return(NA_character_)
      paste(format(v), collapse = "; ")
    }, character(1L))
  )
}
