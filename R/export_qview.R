#' Write a Q-View object to a multi-sheet Excel workbook
#'
#' @param qv A `qview` object from [read_qview()].
#' @param path Output `.xlsx` path.
#' @param template Optional plate-template tibble (from
#'   [read_qview_template()]) to include as an extra sheet.
#'
#' @return `path`, invisibly.
#'
#' @export
qview_to_xlsx <- function(qv, path, template = NULL) {
  if (!inherits(qv, "qview")) {
    cli::cli_abort("{.arg qv} must be a {.cls qview} object.")
  }
  wb <- openxlsx2::wb_workbook()
  add <- function(name, df) {
    if (is.null(df) || nrow(df) == 0L) return(invisible())
    wb$add_worksheet(name)
    wb$add_data(sheet = name, x = df)
  }
  metadata_df <- tibble::tibble(
    field = names(qv$metadata),
    value = vapply(qv$metadata, function(v) {
      if (length(v) == 0L) return(NA_character_)
      paste(format(v), collapse = "; ")
    }, character(1L))
  )
  add("metadata",           metadata_df)
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
  invisible(path)
}


#' Write a Q-View object as a directory of CSV files
#'
#' @param qv A `qview` object from [read_qview()].
#' @param dir Output directory (created if it does not exist).
#' @param template Optional plate-template tibble to include.
#'
#' @return Vector of file paths written, invisibly.
#'
#' @export
qview_to_csv_dir <- function(qv, dir, template = NULL) {
  if (!inherits(qv, "qview")) {
    cli::cli_abort("{.arg qv} must be a {.cls qview} object.")
  }
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)
  out <- character()
  write_one <- function(name, df) {
    if (is.null(df) || nrow(df) == 0L) return(NULL)
    p <- file.path(dir, paste0(name, ".csv"))
    readr::write_csv(df, p)
    out <<- c(out, p)
  }
  metadata_df <- tibble::tibble(
    field = names(qv$metadata),
    value = vapply(qv$metadata, function(v) {
      if (length(v) == 0L) return(NA_character_)
      paste(format(v), collapse = "; ")
    }, character(1L))
  )
  write_one("metadata",           metadata_df)
  write_one("analytes",           qv$analytes)
  write_one("well_groups",        qv$well_groups)
  write_one("plate_layout",       qv$plate_layout)
  write_one("pixel_intensities",  qv$pixel_intensities)
  write_one("summary_statistics", qv$summary_statistics)
  write_one("concentrations",     qv$concentrations)
  write_one("curve_fit",          qv$curve_fit)
  write_one("manifest",           qv$manifest)
  if (!is.null(template))         write_one("template", template)
  invisible(out)
}
