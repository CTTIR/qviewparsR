#' Read a Q-View report export (CSV or XLSX)
#'
#' `r lifecycle::badge("experimental")`
#'
#' Parses one of the flat report files Q-View exports next to the native
#' `.Q-View` container -- the `..._auto_report` or
#' `..._auto_all-parameters_report` export, as either `.csv` or `.xlsx` --
#' and returns the same [`qview`][read_qview()] object [read_qview()] builds
#' from the binary container. Use it when only the exports were kept and the
#' original `.Q-View` project file is unavailable.
#'
#' The export shares its report layout with the CLOB embedded in the binary
#' container, so the two readers agree on concentrations and pixel
#' intensities. Two behaviours differ from [read_qview()], both to preserve
#' information the study workflows rely on:
#' \itemize{
#'   \item The plain `"Reduced Concentration"` point estimate (one row per
#'     sample, the value the exports headline) is captured with
#'     `statistic == "reduced"`. [read_qview()] currently keeps only the
#'     per-replicate / summary concentration rows.
#'   \item Out-of-range cells are **preserved, not dropped**: a `"< 52.50"`
#'     cell yields `concentration = 52.50` with `flag = "<"`, a `"> 7700"`
#'     cell `flag = ">"`, and an `"Incalculable ..."` cell
#'     `concentration = NA` with `flag = "incalculable"`. In-range cells carry
#'     `flag = NA`.
#' }
#'
#' @param path Character. Path to a Q-View report export (`.csv`, `.xlsx`,
#'   or `.xls`).
#' @param strip_prefix Logical. If `TRUE`, reverse Q-View's internal naming
#'   convention via [strip_qview_prefix()]. Default `FALSE`.
#' @param verbose Logical. Print a short summary after parsing. Default `TRUE`.
#' @param call The execution environment of the calling function. Used for
#'   error reporting; experts only.
#'
#' @return A list with class `"qview"`, structured exactly as the
#'   [read_qview()] return value. Container-only slots (`manifest`,
#'   `segments`) are zero-row tibbles; `metadata$container_version` is `NA`.
#'   The `concentrations` tibble carries one extra column, `flag`
#'   (`NA` / `"<"` / `">"` / `"incalculable"`), relative to [read_qview()].
#'
#' @examples
#' path <- system.file("extdata", "example-report.csv",
#'                     package = "qviewparsR")
#' if (nzchar(path)) {
#'   qv <- read_qview_report(path)
#'   qv$concentrations
#' }
#'
#' @seealso [read_qview()], [read_qview_template()].
#' @family qview-reader
#'
#' @export
read_qview_report <- function(path,
                              strip_prefix = FALSE,
                              verbose = TRUE,
                              call = rlang::caller_env()) {
  rlang::check_required(path)
  .check_path(path, call = call)
  .check_flag(strip_prefix, call = call)
  .check_flag(verbose, call = call)

  rows <- .qv_read_export_rows(path, call = call)
  hdr_idx <- .qv_find_report_header(rows)
  if (is.na(hdr_idx)) {
    cli::cli_abort(
      c("{.arg path} is not a recognisable Q-View report export.",
        "x" = "{.path {path}} has no {.val Well Group,Statistic,Well,Error Codes} header row.",
        "i" = "Expected an {.field auto_report} or {.field all-parameters_report} export (csv or xlsx)."),
      call = call
    )
  }

  metadata <- .qv_meta_from_rows(rows, path)
  analytes <- .qv_analytes_from_rows(rows, hdr_idx)
  parsed   <- .qv_parse_export_rows(rows, hdr_idx, analytes)

  pixel_intensities  <- parsed$replicates
  summary_statistics <- parsed$summaries
  concentrations     <- parsed$concentrations
  curve_fit          <- parsed$curve_fit

  # well groups can come from any parsed family; auto_report has only
  # concentration rows, so union all three sources.
  wg_src <- tibble::tibble(well_group = c(
    pixel_intensities$well_group, summary_statistics$well_group,
    if (is.null(concentrations)) character() else concentrations$well_group))
  well_groups  <- .qv_build_well_groups(wg_src, wg_src)
  # auto_report exports carry no pixel-intensity replicates; fall back to the
  # concentration rows so the plate layout still maps every physical well.
  well_src <- .qv_well_source(pixel_intensities, concentrations)
  plate_layout <- .qv_build_plate_layout(well_src, well_groups)

  if (isTRUE(strip_prefix)) {
    pixel_intensities$sample_id  <- strip_qview_prefix(pixel_intensities$sample_id)
    summary_statistics$sample_id <- strip_qview_prefix(summary_statistics$sample_id)
    well_groups$sample_id        <- strip_qview_prefix(well_groups$sample_id)
    plate_layout$sample_id       <- strip_qview_prefix(plate_layout$sample_id)
    if (!is.null(concentrations)) {
      concentrations$sample_id <- strip_qview_prefix(concentrations$sample_id)
    }
  }

  out <- structure(
    list(
      metadata           = metadata,
      manifest           = tibble::tibble(name = character(),
                                          size_bytes = integer(),
                                          parent = character()),
      segments           = tibble::tibble(segment = integer(), start = integer(),
                                          end = integer(), size = integer()),
      analytes           = analytes,
      well_groups        = well_groups,
      pixel_intensities  = pixel_intensities,
      summary_statistics = summary_statistics,
      concentrations     = concentrations,
      curve_fit          = curve_fit,
      report_csv         = .qv_rows_to_csv(rows),
      plate_layout       = plate_layout
    ),
    class = "qview"
  )

  if (isTRUE(verbose)) {
    n_groups <- nrow(well_groups)
    n_analytes <- nrow(analytes)
    n_conc <- if (is.null(concentrations)) 0L else nrow(concentrations)
    cli::cli_inform(c(
      "v" = "Parsed report export {.path {basename(path)}}: {.val {n_groups}} well group{?s} x {.val {n_analytes}} analyte{?s} ({.val {n_conc}} concentration row{?s}).",
      i = if (!is.na(metadata$qview_version))
        "Q-View Version: {.val {metadata$qview_version}}" else NULL
    ))
  }

  out
}


# --- File -> list of trimmed character field-vectors --------------------------

.qv_read_export_rows <- function(path, call = rlang::caller_env()) {
  ext <- tolower(tools::file_ext(path))
  if (ext %in% c("xlsx", "xls")) {
    if (!requireNamespace("openxlsx2", quietly = TRUE)) {
      cli::cli_abort(
        c("Reading an {.val {ext}} export needs the {.pkg openxlsx2} package.",
          "i" = "Install it, or pass the {.val .csv} export instead."),
        call = call)
    }
    m <- openxlsx2::wb_to_df(
      openxlsx2::wb_load(path), sheet = 1L, col_names = FALSE,
      skip_empty_rows = FALSE, skip_empty_cols = FALSE)
    m <- as.matrix(m)
    mode(m) <- "character"
    # Q-View writes exports in the imager's Latin-1 locale (e.g. the "ue" in
    # template names); normalise to UTF-8 before anything touches the strings.
    m[] <- iconv(m, from = "latin1", to = "UTF-8")
    m[is.na(m)] <- ""
    lapply(seq_len(nrow(m)), function(r) unname(trimws(m[r, ])))
  } else {
    lines <- readLines(path, encoding = "latin1", warn = FALSE)
    lines <- iconv(lines, from = "latin1", to = "UTF-8")
    lapply(lines, .qv_split_csv_row)
  }
}


.qv_find_report_header <- function(rows) {
  for (i in seq_along(rows)) {
    f <- rows[[i]]
    if (length(f) >= 4L &&
        identical(f[[1L]], "Well Group") &&
        identical(f[[2L]], "Statistic")) {
      return(i)
    }
  }
  NA_integer_
}


.qv_meta_from_rows <- function(rows, path) {
  metadata <- list(
    project = NA_character_, plate = NA_character_,
    image = NA_character_, imager = NA_character_,
    product = NA_character_, user = NA_character_,
    report_created = NA_character_, qview_version = NA_character_,
    template = NA_character_, container_version = NA_character_,
    file_path = normalizePath(path, mustWork = FALSE),
    parsed_at = Sys.time()
  )
  first <- vapply(rows, function(f) if (length(f) >= 1L) f[[1L]] else "", "")
  pull <- function(prefix) {
    hit <- first[startsWith(first, prefix)]
    if (length(hit) == 0L) return(NA_character_)
    trimws(sub(paste0("^", prefix), "", hit[1L]))
  }
  metadata$project        <- pull("Project: ")
  metadata$plate          <- pull("Plate: ")
  metadata$image          <- pull("Image: ")
  metadata$imager         <- pull("Imager: ")
  metadata$product        <- pull("Product: ")
  metadata$user           <- pull("User: ")
  metadata$report_created <- pull("Report Created: ")
  metadata$qview_version  <- pull("Q-View Version: ")
  metadata$template       <- pull("Well Assignment Template: ")
  metadata
}


.qv_analytes_from_rows <- function(rows, hdr_idx) {
  empty <- tibble::tibble(spot_number = integer(), analyte = character(),
                          unit = character(), lod = numeric(), lloq = numeric(),
                          uloq = numeric(), assay_control_low = numeric(),
                          assay_control_high = numeric())
  hdr <- rows[[hdr_idx]]
  if (length(hdr) <= 4L) return(empty)
  panel <- hdr[-seq_len(4L)]
  m <- regmatches(panel, regexec("^(.+?)\\s*\\(([^)]+)\\)\\s*$", panel))
  analyte <- vapply(m, function(x) if (length(x) == 3L) x[2L] else NA_character_, "")
  unit    <- vapply(m, function(x) if (length(x) == 3L) x[3L] else NA_character_, "")
  bad <- is.na(analyte); analyte[bad] <- panel[bad]
  out <- tibble::tibble(
    spot_number = seq_along(panel), analyte = analyte, unit = unit,
    lod = NA_real_, lloq = NA_real_, uloq = NA_real_,
    assay_control_low = NA_real_, assay_control_high = NA_real_)

  # The Assay/Lot limit blocks sit between the header and the first data row;
  # only a block's first row carries the section label (Assay / Lot), so carry
  # it forward. Pull the numeric limits from the Lot block, control ranges from
  # the Assay block -- mirroring .qv_extract_analyte_panel().
  section <- ""
  n <- nrow(out)
  numify <- function(f) suppressWarnings(as.numeric(.qv_value_number(f[-seq_len(4L)][seq_len(n)])))
  vals <- list()
  for (i in seq(hdr_idx + 1L, length(rows))) {
    f <- rows[[i]]
    if (length(f) < 4L) { if (length(f) == 0L || !nzchar(paste(f, collapse = ""))) break else next }
    if (nzchar(f[[1L]])) section <- f[[1L]]
    stat <- if (length(f) >= 2L) f[[2L]] else ""
    key <- paste(section, stat, sep = "|")
    if (!is.null(vals[[key]])) next
    if (stat %in% c("Limit of Detection", "Lower Limit of Quantification",
                    "Upper Limit of Quantification", "Assay Control Range Low",
                    "Assay Control Range High")) {
      vals[[key]] <- numify(f)
    }
    # stop scanning once we reach the calibrator/sample block
    if (grepl("Concentration|Pixel Intensity", stat)) break
  }
  set <- function(col, key) if (!is.null(vals[[key]])) out[[col]] <<- vals[[key]]
  set("lod",  "Lot|Limit of Detection")
  set("lloq", "Lot|Lower Limit of Quantification")
  set("uloq", "Lot|Upper Limit of Quantification")
  set("assay_control_low",  "Assay|Assay Control Range Low")
  set("assay_control_high", "Assay|Assay Control Range High")
  out
}


# Parse a single Q-View value cell, preserving out-of-range information.
#   "1815.82"          -> list(value = 1815.82, flag = NA)
#   "< 52.50"          -> list(value = 52.50,   flag = "<")
#   "> 7700.00"        -> list(value = 7700,    flag = ">")
#   "Incalculable ..." -> list(value = NA,      flag = "incalculable")
.qv_parse_value_cell <- function(x) {
  x <- trimws(x)
  if (!nzchar(x) || is.na(x)) return(list(value = NA_real_, flag = NA_character_))
  if (grepl("^Incalculable", x, ignore.case = TRUE)) {
    return(list(value = NA_real_, flag = "incalculable"))
  }
  flag <- NA_character_
  if (startsWith(x, "<")) { flag <- "<"; x <- sub("^<\\s*", "", x) }
  else if (startsWith(x, ">")) { flag <- ">"; x <- sub("^>\\s*", "", x) }
  v <- suppressWarnings(as.numeric(x))
  list(value = v, flag = if (is.na(v)) NA_character_ else flag)
}

# Numeric-only helper for the limit blocks (strips <,>, drops Incalculable).
.qv_value_number <- function(x) {
  vapply(x, function(z) .qv_parse_value_cell(z)$value, numeric(1L), USE.NAMES = FALSE)
}


.qv_parse_export_rows <- function(rows, hdr_idx, analytes) {
  empty <- list(replicates = .qv_empty_replicates(),
                summaries = .qv_empty_summaries(),
                concentrations = NULL, curve_fit = NULL)
  if (nrow(analytes) == 0L) return(empty)
  n <- nrow(analytes)
  current_group <- NA_character_
  acc <- list()
  csv_lines <- character()
  for (i in seq(hdr_idx + 1L, length(rows))) {
    f <- rows[[i]]
    if (length(f) < 4L) next
    csv_lines <- c(csv_lines, paste(f, collapse = ","))
    if (nzchar(f[[1L]])) current_group <- f[[1L]]
    well_group <- if (nzchar(f[[1L]])) f[[1L]] else current_group
    statistic_raw <- f[[2L]]
    well_field    <- f[[3L]]
    values        <- f[-seq_len(4L)]
    if (length(values) == 0L) next
    info <- .qv_classify_statistic(statistic_raw)
    if (is.na(info$family)) next
    # plain point estimate (e.g. "Reduced Concentration", "Pixel Intensity"):
    # family set but no Average/StdDev/CV/Replicate qualifier -> the reduced value
    if (is.na(info$kind)) info$kind <- "reduced"
    if (length(values) >= n) values <- values[seq_len(n)] else length(values) <- n
    cells <- lapply(values, .qv_parse_value_cell)
    acc[[length(acc) + 1L]] <- tibble::tibble(
      well_group = well_group,
      # keep a single physical well (samples + replicates); summary rows list
      # several wells ("A1, A2") -> no single well.
      well       = if (nzchar(well_field) && !grepl(",", well_field, fixed = TRUE))
                     well_field else NA_character_,
      replicate  = info$replicate,
      kind       = info$kind,
      family     = info$family,
      analyte    = analytes$analyte,
      value      = vapply(cells, `[[`, numeric(1L), "value"),
      flag       = vapply(cells, `[[`, character(1L), "flag"),
      unit       = analytes$unit
    )
  }
  if (length(acc) == 0L) return(empty)
  out <- dplyr::bind_rows(acc)
  out <- out[!is.na(out$analyte) & out$analyte != "Ref Spot", , drop = FALSE]
  out <- out[!is.na(out$well_group) & nzchar(out$well_group), , drop = FALSE]
  # keep out-of-range rows (flagged) even though value is NA; drop only rows
  # that are both value-NA and flag-NA (genuinely empty cells).
  out <- out[!(is.na(out$value) & is.na(out$flag)), , drop = FALSE]

  dilution <- rep(NA_real_, nrow(out))
  m <- regmatches(out$well_group, regexec("\\(1:([0-9.]+)\\)\\s*$", out$well_group))
  for (k in seq_along(m)) if (length(m[[k]]) == 2L) {
    dilution[k] <- suppressWarnings(as.numeric(m[[k]][2L]))
  }
  out$dilution  <- dilution
  out$sample_id <- trimws(sub("\\s*\\([^)]*\\)\\s*$", "", out$well_group))

  pi_rows   <- out[out$family == "pixel_intensity", , drop = FALSE]
  conc_rows <- out[out$family == "concentration", , drop = FALSE]
  replicates <- pi_rows[pi_rows$kind == "replicate", , drop = FALSE]
  summaries  <- pi_rows[pi_rows$kind != "replicate", , drop = FALSE]

  list(
    replicates = tibble::tibble(
      well_group = replicates$well_group, sample_id = replicates$sample_id,
      well = replicates$well, replicate = replicates$replicate,
      analyte = replicates$analyte, unit = replicates$unit,
      pixel_intensity = replicates$value, dilution = replicates$dilution),
    summaries = tibble::tibble(
      well_group = summaries$well_group, sample_id = summaries$sample_id,
      statistic = summaries$kind, analyte = summaries$analyte,
      value = summaries$value, unit = summaries$unit),
    concentrations = if (nrow(conc_rows) > 0L) tibble::tibble(
      well_group = conc_rows$well_group, sample_id = conc_rows$sample_id,
      well = conc_rows$well, replicate = conc_rows$replicate,
      statistic = conc_rows$kind, analyte = conc_rows$analyte,
      unit = conc_rows$unit, concentration = conc_rows$value,
      dilution = conc_rows$dilution, flag = conc_rows$flag) else NULL,
    curve_fit = .qv_extract_curve_fit(csv_lines, analytes)
  )
}


# Well-bearing rows to seed the plate layout: pixel replicates if present,
# otherwise the concentration rows (auto_report has no pixel data).
.qv_well_source <- function(replicates, concentrations) {
  cols <- c("well", "well_group", "sample_id", "dilution")
  if (!is.null(replicates) && nrow(replicates) > 0L) return(replicates[, cols])
  if (!is.null(concentrations) && nrow(concentrations) > 0L) {
    src <- concentrations[!is.na(concentrations$well) & nzchar(concentrations$well), , drop = FALSE]
    if (nrow(src) > 0L) return(src[, cols])
  }
  .qv_empty_replicates()[, cols]
}


.qv_rows_to_csv <- function(rows) {
  if (length(rows) == 0L) return(NULL)
  vapply(rows, function(f) paste(f, collapse = ","), character(1L))
}
