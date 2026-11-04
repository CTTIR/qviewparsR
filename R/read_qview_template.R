#' Read a Q-View well-assignment template CSV
#'
#' Parses the plate-template CSV that Q-View imports for sample
#' assignment. The file uses a multi-section layout: an `NxM` cell in
#' the top-left declares the plate dimensions, followed by sections
#' labelled `Group Name`, `Group Type`, and `Dilution Factor`. Each
#' section is one row per plate row and one column per plate column.
#'
#' All three required sections must have each declared row and column
#' exactly once. Dimensions must fit the source and use at most 26 single-
#' letter rows; this does not extend binary report support beyond 96 wells.
#' Nonblank dilution values must be positive finite numbers. Blank sample
#' and dilution cells remain missing. Identifiers are decoded as text,
#' preserving leading zeroes, quoted punctuation and non-dilution suffixes.
#' Text uses the UTF-8-then-Latin-1 fallback described in [read_qview_report()].
#' The template is an independent assignment source; binary report extraction
#' does not recover every original template field.
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' @param path Path to the template file (csv).
#' @param verbose Logical. Print a short summary after parsing.
#'   Default `TRUE`.
#' @param call The execution environment of the calling function. Used
#'   for error reporting; experts only.
#'
#' @return A [tibble::tibble()] with one row per well and columns
#'   `well` (character, e.g. `"A1"`), `plate_row` (character, `"A"`..),
#'   `plate_col` (integer), `sample_id` (character), `group_type`
#'   (character), `dilution` (numeric).
#'
#' @examples
#' path <- system.file("extdata", "example-template.csv",
#'                     package = "qviewparsR")
#' layout <- read_qview_template(path)
#' head(layout)
#'
#' @family qview-reader
#'
#' @export
read_qview_template <- function(path,
                                verbose = TRUE,
                                call = rlang::caller_env()) {
  rlang::check_required(path)
  .check_path(path, call = call)
  .check_flag(verbose, call = call)
  ext <- tolower(tools::file_ext(path))
  if (ext %in% c("xls", "xlsx")) {
    cli::cli_abort(
      c("{.arg path} must be a CSV template, not an Excel workbook.",
        "x" = "{.path {path}} is a {.val {ext}} file.",
        "i" = "Save the template as CSV from your spreadsheet application before reading."),
      call = call
    )
  }
  delim <- .qv_sniff_delim(path)
  rows <- .qv_csv_records(.qv_read_text_lines(path), delim = delim)
  dim_cell <- if (length(rows) && length(rows[[1L]])) rows[[1L]][[1L]] else ""
  m <- regmatches(dim_cell,
                  regexec("^([0-9]+)x([0-9]+)$", trimws(dim_cell)))[[1L]]
  if (length(m) != 3L) {
    cli::cli_abort(
      c("{.arg path} is not a recognisable Q-View well-assignment template.",
        "x" = "{.path {path}} is missing the top-left {.val NxM} dimensions cell.",
        "i" = "Expected the top-left cell to look like {.val 12x8}."),
      call = call
    )
  }
  dims <- suppressWarnings(as.numeric(m[2:3]))
  if (any(!is.finite(dims)) || any(dims < 1) || dims[[2L]] > 26 ||
      dims[[2L]] > length(rows) || dims[[1L]] > max(lengths(rows)) - 2L) {
    cli::cli_abort("Template dimensions must be positive, fit the source rows/columns, and use at most 26 lettered rows.", call = call)
  }
  ncols <- as.integer(dims[[1L]])
  nrows <- as.integer(dims[[2L]])
  hdr_idx <- which(vapply(rows, function(f) {
    length(f) >= 2L && !nzchar(trimws(f[[1L]])) && trimws(f[[2L]]) == "1"
  }, logical(1L)))
  if (!length(hdr_idx)) {
    cli::cli_abort(c(
      "{.arg path} has no recognisable section headers.",
      "i" = "Each section needs a blank first cell followed by numbered columns."
    ), call = call)
  }
  label_to_field <- function(lbl) {
    key <- tolower(trimws(lbl))
    if (grepl("^group name", key)) return("sample_id")
    if (grepl("^group type", key)) return("group_type")
    if (grepl("^dilution", key)) return("dilution")
    NA_character_
  }
  out <- .qv_plate_grid(nrows, ncols)
  out <- out[, c("well", "plate_row", "plate_col")]
  seen <- character()
  for (start in hdr_idx) {
    header <- rows[[start]]
    if (length(header) < ncols + 2L) {
      cli::cli_abort("Incomplete template section header at row {start}.")
    }
    field <- label_to_field(header[[ncols + 2L]])
    if (is.na(field)) next
    if (field %in% seen) cli::cli_abort("Duplicate template section: {.val {field}}.")
    seen <- c(seen, field)
    columns <- trimws(header[seq_len(ncols) + 1L])
    if (!identical(columns, as.character(seq_len(ncols)))) {
      cli::cli_abort("Template section columns must be numbered consecutively.")
    }
    end <- start + nrows
    if (end > length(rows) || any(hdr_idx > start & hdr_idx <= end)) {
      cli::cli_abort("Incomplete template section {.val {field}}.")
    }
    body <- rows[seq.int(start + 1L, end)]
    if (any(lengths(body) < ncols + 1L)) {
      cli::cli_abort("Incomplete columns in template section {.val {field}}.")
    }
    row_letters <- vapply(body, function(f) trimws(f[[1L]]), character(1L))
    if (anyDuplicated(row_letters) || !setequal(row_letters, LETTERS[seq_len(nrows)])) {
      cli::cli_abort("Template section {.val {field}} must contain every declared row letter exactly once.")
    }
    body <- body[match(LETTERS[seq_len(nrows)], row_letters)]
    extra <- unlist(lapply(body, function(f) f[-seq_len(ncols + 1L)]))
    if (any(nzchar(trimws(extra)))) {
      cli::cli_abort("Unexpected cells beyond the declared template columns.")
    }
    values <- as.vector(t(vapply(body, function(f) f[seq_len(ncols) + 1L], character(ncols))))
    if (field == "dilution") {
      values <- vapply(values, function(x) {
        if (!nzchar(trimws(x))) return(NA_real_)
        value <- .qv_parse_value_cell(x)
        if (!is.na(value$flag) || value$value <= 0) {
          cli::cli_abort("Template dilution must be blank or a positive finite number.")
        }
        value$value
      }, numeric(1L), USE.NAMES = FALSE)
    } else {
      values[!nzchar(trimws(values))] <- NA_character_
    }
    out[[field]] <- values
  }
  missing <- setdiff(c("sample_id", "group_type", "dilution"), seen)
  if (length(missing)) {
    cli::cli_abort("Missing required template section(s): {.val {missing}}.")
  }
  if (isTRUE(verbose)) {
    n_samples <- length(unique(stats::na.omit(out$sample_id)))
    cli::cli_inform(c(
      "v" = "Parsed Q-View template: {.val {nrow(out)}} wells, {.val {n_samples}} unique sample{?s} from {.path {path}}."
    ))
  }
  out
}


# Detect the field separator of a template export. Q-View on a European
# locale writes semicolon-separated values (and the .csv/.tsv/.txt the app
# accepts may be tab-separated); pick whichever delimiter is most frequent
# in the header. Defaults to comma when nothing stands out.
.qv_sniff_delim <- function(path) {
  sniff <- tryCatch(readLines(path, n = 10L, warn = FALSE),
                    error = function(e) character())
  sniff <- sniff[nzchar(trimws(sniff))]
  sniff <- if (length(sniff)) sniff[[1L]] else ""
  if (!nzchar(sniff)) return(",")
  cand <- c(",", ";", "\t")
  counts <- vapply(cand, function(d) {
    m <- gregexpr(d, sniff, fixed = TRUE)[[1L]]
    if (length(m) == 1L && m[1L] == -1L) 0L else length(m)
  }, integer(1L))
  if (max(counts) == 0L) return(",")
  cand[which.max(counts)]
}
# Version 1.0.0
