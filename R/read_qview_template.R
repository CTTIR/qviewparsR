#' Read a Q-View well-assignment template CSV
#'
#' Parses the plate-template CSV that Q-View imports for sample
#' assignment. The file uses a multi-section layout: an `NxM` cell in
#' the top-left declares the plate dimensions, followed by sections
#' labelled `Group Name`, `Group Type`, and `Dilution Factor`. Each
#' section is one row per plate row and one column per plate column.
#'
#' All template data is also embedded inside the `.Q-View` file itself
#' (and is recovered by [read_qview()]); this function exists for
#' setting up new plates or cross-validating Q-View imports against
#' the original template.
#'
#' @param path Path to the template file (csv or xlsx).
#' @param verbose Logical. Print a short summary after parsing.
#'   Default `TRUE`.
#'
#' @return A tibble with one row per well: `well`, `plate_row`,
#'   `plate_col`, `sample_id`, `group_type`, `dilution`.
#'
#' @examples
#' \dontrun{
#'   layout <- read_qview_template("plate-template.csv")
#' }
#'
#' @export
read_qview_template <- function(path, verbose = TRUE) {
  if (!file.exists(path)) {
    cli::cli_abort("File not found: {.path {path}}.")
  }
  ext <- tolower(tools::file_ext(path))
  if (ext %in% c("xls", "xlsx")) {
    cli::cli_abort(c(
      "{.path {path}} is an Excel file.",
      i = "Save the template as CSV from the spreadsheet application before reading."
    ))
  }
  raw <- readr::read_delim(
    path, delim = ",",
    col_names = FALSE,
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE
  )

  dim_cell <- as.character(raw[[1L]][1L])
  m <- regmatches(dim_cell,
                  regexec("^([0-9]+)x([0-9]+)$", trimws(dim_cell)))[[1L]]
  if (length(m) != 3L) {
    cli::cli_abort(c(
      "{.path {path}} is missing the {.val NxM} plate-dimensions cell.",
      i = "Expected the top-left cell to look like {.val 12x8}."
    ))
  }
  ncols <- as.integer(m[2L]); nrows <- as.integer(m[3L])

  col1 <- as.character(raw[[1L]])
  col2 <- if (ncol(raw) >= 2L) as.character(raw[[2L]]) else character()
  hdr_idx <- which(
    (is.na(col1) | trimws(col1) == "") &
    !is.na(col2) & trimws(col2) == "1"
  )
  if (length(hdr_idx) == 0L) {
    cli::cli_abort(c(
      "{.path {path}} has no recognisable section headers.",
      i = "Each section must start with a row whose first cell is blank and whose second cell is {.val 1}."
    ))
  }

  parse_section <- function(start) {
    label <- as.character(raw[[ncol(raw)]][start])
    body <- raw[(start + 1L):(start + nrows), , drop = FALSE]
    row_letter <- as.character(body[[1L]])
    vals <- body[, 2L:(1L + ncols), drop = FALSE]
    list(
      label = label,
      df = tibble::tibble(
        well = paste0(rep(row_letter, ncols),
                      rep(seq_len(ncols), each = nrows)),
        value = as.character(unlist(vals))
      )
    )
  }
  sections <- lapply(hdr_idx, parse_section)
  label_to_field <- function(lbl) {
    key <- tolower(trimws(lbl))
    if (grepl("^group name", key)) return("sample_id")
    if (grepl("^group type", key)) return("group_type")
    if (grepl("^dilution",   key)) return("dilution")
    NA_character_
  }

  out <- tibble::tibble(
    well = paste0(rep(LETTERS[seq_len(nrows)], ncols),
                  rep(seq_len(ncols), each = nrows))
  )
  for (s in sections) {
    field <- label_to_field(s$label)
    if (is.na(field)) next
    sub <- s$df
    colnames(sub) <- c("well", field)
    out <- dplyr::left_join(out, sub, by = "well")
  }
  if ("dilution" %in% colnames(out)) {
    suppressWarnings(out$dilution <- as.numeric(out$dilution))
  }
  for (col in c("sample_id", "group_type")) {
    if (col %in% colnames(out)) {
      v <- out[[col]]
      v[is.na(v) | trimws(v) == ""] <- NA_character_
      out[[col]] <- v
    }
  }
  out$plate_row <- substr(out$well, 1L, 1L)
  out$plate_col <- as.integer(substring(out$well, 2L))
  out <- out[, c("well", "plate_row", "plate_col", "sample_id",
                 "group_type", "dilution"), drop = FALSE]
  if (isTRUE(verbose)) {
    n_samples <- length(unique(stats::na.omit(out$sample_id)))
    cli::cli_inform(c(
      "v" = "Parsed Q-View template: {.val {nrow(out)}} wells, {.val {n_samples}} unique sample{?s} from {.path {path}}."
    ))
  }
  out
}
