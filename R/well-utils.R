#' Convert plate row / column to a well label
#'
#' `r lifecycle::badge("stable")`
#'
#' Converts 0-based or 1-based row and column indices to the standard
#' `"A1"` ... `"H12"` plate notation. Vectorised.
#'
#' @param row Integer or character. Either a 0/1-based row index or
#'   already a single letter (`"A"`...).
#' @param col Integer column index (1-based or 0-based; values >= 1 are
#'   treated as 1-based).
#' @param zero_based Logical. If `TRUE`, treat `row` and `col` as
#'   0-based; if `FALSE` (default), treat them as 1-based.
#'
#' @return Character vector of well labels (e.g. `"A1"`, `"H12"`),
#'   recycled to the longer of `row` / `col`.
#'
#' @examples
#' well_label(0, 0, zero_based = TRUE)   # "A1"
#' well_label(7, 11, zero_based = TRUE)  # "H12"
#' well_label("C", 5)                    # "C5"
#'
#' @family qview-helper
#' @export
well_label <- function(row, col, zero_based = FALSE) {
  if (is.character(row)) {
    letters_part <- toupper(row)
  } else {
    idx <- as.integer(row)
    if (!zero_based) idx <- idx - 1L
    letters_part <- LETTERS[idx + 1L]
  }
  col_int <- as.integer(col)
  if (zero_based) col_int <- col_int + 1L
  paste0(letters_part, col_int)
}


# Internal: build a tibble describing every well of an Nrow x Ncol plate.
.qv_plate_grid <- function(nrows = 8L, ncols = 12L) {
  tibble::tibble(
    plate_row = rep(LETTERS[seq_len(nrows)], times = ncols),
    plate_col = rep(seq_len(ncols), each = nrows),
    well      = paste0(rep(LETTERS[seq_len(nrows)], times = ncols),
                       rep(seq_len(ncols), each = nrows))
  )
}
