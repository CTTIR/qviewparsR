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
#'   treated as 1-based). Nonintegral or out-of-range indices are refused.
#' @param zero_based Logical. If `TRUE`, treat `row` and `col` as
#'   0-based; if `FALSE` (default), treat them as 1-based.
#'
#' @return Character vector of well labels (e.g. `"A1"`, `"H12"`),
#'   recycled to the longer of `row` / `col` only when lengths divide exactly.
#'   Rows are single letters A through Z; this helper does not extend the
#'   96-well scope of report extraction.
#'
#' @examples
#' well_label(0, 0, zero_based = TRUE)   # "A1"
#' well_label(7, 11, zero_based = TRUE)  # "H12"
#' well_label("C", 5)                    # "C5"
#'
#' @family qview-helper
#' @export
well_label <- function(row, col, zero_based = FALSE) {
  .check_flag(zero_based)
  integer_values <- function(x, minimum, maximum, label) {
    if (!is.numeric(x) || is.complex(x) || anyNA(x) ||
        any(!is.finite(x)) || any(x != trunc(x)) ||
        any(x < minimum | x > maximum)) {
      cli::cli_abort("{label} must contain finite integer indices in the supported range.")
    }
  }
  if (is.character(row)) {
    letters_part <- toupper(row)
    if (anyNA(row) || any(!grepl("^[A-Z]$", letters_part))) {
      cli::cli_abort("Row labels must be single letters A through Z.")
    }
  } else {
    integer_values(row, if (zero_based) 0 else 1,
                   if (zero_based) 25 else 26, "Rows")
    letters_part <- LETTERS[as.integer(row) + if (zero_based) 1L else 0L]
  }
  integer_values(col, if (zero_based) 0 else 1,
                 .Machine$integer.max - 1L, "Columns")
  if (!length(row) || !length(col)) return(character())
  size <- max(length(row), length(col))
  if (size %% min(length(row), length(col)) != 0L) {
    cli::cli_abort("Row and column lengths must recycle exactly.")
  }
  col_int <- as.integer(col) + if (zero_based) 1L else 0L
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
# Version 1.0.0
