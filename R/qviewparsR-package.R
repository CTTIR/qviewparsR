#' qviewparsR: Read Quansys Q-View ELISA Project Files
#'
#' @description
#' Pure-R parser for `.Q-View` binary project files produced by Quansys
#' Biosciences Q-View Software (v3.x). Extracts pixel intensities,
#' analyte mappings, sample assignments, plate layout, optional curve-fit
#' parameters, and the embedded CSV report from the H2 database container
#' format. Returns tidy tibbles ready for downstream statistical analysis.
#'
#' @section Main functions:
#' * Reader: [read_qview()] -- parse a `.Q-View` file.
#' * Helpers: [strip_qview_prefix()] reverse the Q-View internal naming
#'   convention; [well_label()] map (row, column) to plate notation.
#' * Optional: [read_qview_template()] parse a Q-View well-assignment
#'   template CSV.
#' * Methods: [print.qview()], [plot.qview()].
#' * Shiny: [qview_app()] interactive upload / preview / download.
#'
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom rlang .data
## usethis namespace: end
NULL
