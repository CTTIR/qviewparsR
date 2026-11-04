#' Read a Q-View report export (CSV or XLSX)
#'
#' `r lifecycle::badge("stable")`
#'
#' Parses one of the flat report files Q-View exports next to the native
#' `.Q-View` container -- the `..._auto_report` or
#' `..._auto_all-parameters_report` export, as either `.csv` or `.xlsx` --
#' and returns the same [`qview`][read_qview()] object [read_qview()] builds
#' from the binary container. Use it when only the exports were kept and the
#' original `.Q-View` project file is unavailable.
#'
#' Binary and flat report readers use the same typed measurement parsing.
#' Censored cells retain their bound with `flag = "<"` or `">"`;
#' `Incalculable` cells retain `NA` with `flag = "incalculable"`.
#' Blank cells and explicit `NA` / `N/A` retain `NA` with `flag = "missing"`.
#' Ordinary measurements have a missing flag. Malformed nonblank values,
#' nonfinite numbers and nonzero values that underflow to zero are refused.
#'
#' CSV input is decoded as UTF-8 when valid (including an optional BOM),
#' otherwise as Latin-1. Encoding cannot be inferred perfectly; Windows-1252
#' and arbitrary encodings are not inferred. The selected interpretation is
#' recorded in `metadata$source_encoding`. XLSX strings are already decoded
#' by `openxlsx2` and are not reinterpreted as Latin-1. Quoted commas, escaped
#' quotes and quoted line breaks are preserved; malformed quoting is refused.
#'
#' Only report wells A1 through H12 are supported. Conflicting records,
#' duplicate analyte identities and conflicting well assignments are refused.
#' A sample suffix is removed only when it is a recognized positive finite
#' dilution of the form `(1:n)`; other parentheses remain part of the ID.
#'
#' @param path Character. Path to a Q-View report export (`.csv` or `.xlsx`).
#' @param strip_prefix Logical. If `TRUE`, reverse Q-View's internal naming
#'   convention via [strip_qview_prefix()]. Default `FALSE`.
#' @param verbose Logical. Print a short summary after parsing. Default `TRUE`.
#' @param call The execution environment of the calling function. Used for
#'   error reporting; experts only.
#'
#' @return A list with class `"qview"`, structured as the [read_qview()]
#'   return value. Container-only slots (`manifest`, `segments`) are empty;
#'   `metadata$container_version` is `NA`. Measurement tables add `raw_value`,
#'   `flag`, `error_codes` and `statistic_label`, preserving decoded cell text,
#'   censor/missing state and the original statistic label. Numeric censored
#'   values are bounds, not measured point estimates. Plain reduced estimates
#'   use `statistic == "reduced"`. `report_csv` retains decoded CSV source
#'   lines in order; XLSX rows are serialized with valid CSV quoting.
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
  metadata$source_encoding <- attr(rows, "source_encoding")
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
  well_src <- parsed$well_source
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
      report_csv         = attr(rows, "source_lines") %||% .qv_rows_to_csv(rows),
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
  if (ext == "xlsx") {
    m <- openxlsx2::wb_to_df(
      openxlsx2::wb_load(path), sheet = 1L, col_names = FALSE,
      skip_empty_rows = FALSE, skip_empty_cols = FALSE)
    m <- as.matrix(m)
    mode(m) <- "character"
    # XLSX strings have already been decoded by openxlsx2; never reinterpret
    # their UTF-8 bytes as a legacy single-byte locale.
    m[is.na(m)] <- ""
    rows <- lapply(seq_len(nrow(m)), function(r) unname(m[r, ]))
    attr(rows, "source_encoding") <- "XLSX decoded Unicode"
    rows
  } else {
    lines <- .qv_read_text_lines(path)
    rows <- .qv_csv_records(lines)
    attr(rows, "source_lines") <- as.character(lines)
    attr(rows, "source_encoding") <- attr(lines, "source_encoding")
    rows
  }
}

.qv_find_report_header <- function(rows) {
  found <- NA_integer_
  for (i in seq_along(rows)) {
    f <- rows[[i]]
    if (length(f) >= 4L &&
        identical(trimws(f[seq_len(4L)]),
                  c("Well Group", "Statistic", "Well", "Error Codes"))) {
      if (!is.na(found) && !identical(f, rows[[found]])) {
        cli::cli_abort("Ambiguous conflicting report analyte headers.")
      }
      if (is.na(found)) found <- i
    }
  }
  found
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
    if (length(unique(hit)) > 1L) {
      cli::cli_abort("Ambiguous conflicting report metadata: {.val {prefix}}.")
    }
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
  panel <- trimws(hdr[-seq_len(4L)])
  while (length(panel) && !nzchar(utils::tail(panel, 1L))) panel <- utils::head(panel, -1L)
  m <- regmatches(panel, regexec("^(.+?)\\s*\\(([^)]+)\\)\\s*$", panel))
  analyte <- vapply(m, function(x) if (length(x) == 3L) x[2L] else NA_character_, "")
  unit    <- vapply(m, function(x) if (length(x) == 3L) x[3L] else NA_character_, "")
  bad <- is.na(analyte); analyte[bad] <- panel[bad]
  out <- tibble::tibble(
    spot_number = seq_along(panel), analyte = analyte, unit = unit,
    lod = NA_real_, lloq = NA_real_, uloq = NA_real_,
    assay_control_low = NA_real_, assay_control_high = NA_real_)

  .qv_check_panel(out)

  # Scan every report section, including repeated headers after measurements.
  # Only a block's first row carries its Assay/Lot label. A new header resets
  # that context; it cannot establish a limit block's identity by itself.
  section <- ""
  n <- nrow(out)
  numify <- function(f) .qv_value_number(.qv_report_values(f, n, "analyte limits"))
  vals <- list()
  for (i in seq_len(length(rows) - hdr_idx) + hdr_idx) {
    f <- rows[[i]]
    if (length(f) < 4L) next
    if (identical(trimws(f[seq_len(4L)]),
                  c("Well Group", "Statistic", "Well", "Error Codes"))) {
      section <- ""
      next
    }
    if (nzchar(trimws(f[[1L]]))) section <- trimws(f[[1L]])
    stat <- trimws(f[[2L]])
    key <- paste(section, stat, sep = "|")
    if (stat %in% c("Limit of Detection", "Lower Limit of Quantification",
                    "Upper Limit of Quantification", "Assay Control Range Low",
                    "Assay Control Range High")) {
      if (!section %in% c("Assay", "Lot")) {
        cli::cli_abort("Missing Assay/Lot section for analyte limits at report row {i}.")
      }
      value <- numify(f)
      if (!is.null(vals[[key]]) && !identical(vals[[key]], value)) {
        cli::cli_abort("Ambiguous conflicting report analyte limits: {.val {key}}.")
      }
      vals[[key]] <- value
    }
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
# Ordinary decimals have no flag; inequality prefixes retain their bound
# with a censor flag. Incalculable text retains missingness and its flag.
.qv_parse_value_cell <- function(x) {
  if (length(x) != 1L || is.na(x)) {
    return(list(value = NA_real_, flag = "missing"))
  }
  token <- trimws(x)
  if (!nzchar(token) || token %in% c("NA", "N/A")) {
    return(list(value = NA_real_, flag = "missing"))
  }
  if (grepl("^Incalculable(?:[[:space:]]|$)", token, ignore.case = TRUE, perl = TRUE)) {
    return(list(value = NA_real_, flag = "incalculable"))
  }
  flag <- NA_character_
  if (startsWith(token, "<") || startsWith(token, ">")) {
    flag <- substr(token, 1L, 1L)
    token <- trimws(substring(token, 2L))
  }
  grammar <- "^[+-]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?$"
  value <- suppressWarnings(as.numeric(token))
  mantissa <- sub("[eE].*$", "", token)
  if (!grepl(grammar, token, perl = TRUE) || !is.finite(value) ||
      (value == 0 && grepl("[1-9]", mantissa))) {
    cli::cli_abort("Invalid or unrepresentable numeric report cell: {.val {x}}.")
  }
  list(value = value, flag = flag)
}

# Numeric-only helper for the limit blocks (strips <,>, drops Incalculable).
.qv_value_number <- function(x) {
  vapply(x, function(z) .qv_parse_value_cell(z)$value, numeric(1L), USE.NAMES = FALSE)
}


.qv_parse_export_rows <- function(rows, hdr_idx, analytes) {
  empty <- list(replicates = .qv_empty_replicates(),
                summaries = .qv_empty_summaries(),
                concentrations = NULL, curve_fit = NULL,
                well_source = .qv_well_source(NULL, NULL))
  if (nrow(analytes) == 0L) return(empty)
  .qv_check_panel(analytes)
  n <- nrow(analytes)
  current_group <- NA_character_
  acc <- list()
  csv_lines <- character()
  source_runs <- attr(rows, "source_runs")
  for (i in seq_len(length(rows) - hdr_idx) + hdr_idx) {
    if (!is.null(source_runs) &&
        (i == 1L || source_runs[[i]] != source_runs[[i - 1L]])) {
      current_group <- NA_character_
    }
    f <- rows[[i]]
    if (length(f) < 4L) next
    if (identical(trimws(f[seq_len(4L)]),
                  c("Well Group", "Statistic", "Well", "Error Codes"))) {
      current_group <- NA_character_
      next
    }
    csv_lines <- c(csv_lines, .qv_rows_to_csv(list(f)))
    if (nzchar(trimws(f[[1L]]))) current_group <- f[[1L]]
    well_group <- current_group
    statistic_raw <- trimws(f[[2L]])
    well_field <- trimws(f[[3L]])
    info <- .qv_classify_statistic(statistic_raw)
    if (is.na(info$family)) next
    if (is.na(info$kind)) {
      if (identical(statistic_raw, "Reduced Concentration")) {
        info$kind <- "reduced"
      } else {
        next
      }
    }
    if (is.na(well_group) || !nzchar(trimws(well_group))) {
      cli::cli_abort("Missing sample group at report row {i}.")
    }
    wells <- .qv_check_report_wells(well_field, paste("report row", i))
    if (info$kind == "replicate" && length(wells) != 1L) {
      cli::cli_abort("A replicate needs one physical well at report row {i}.")
    }
    values <- .qv_report_values(f, n, paste("report row", i))
    cells <- lapply(seq_along(values), function(j) {
      tryCatch(.qv_parse_value_cell(values[[j]]), error = function(e) {
        cli::cli_abort("Invalid value at report row {i}, analyte {.val {analytes$analyte[[j]]}}.",
                       parent = e)
      })
    })
    acc[[length(acc) + 1L]] <- tibble::tibble(
      well_group = well_group,
      well = if (length(wells) == 1L) wells else NA_character_,
      replicate = info$replicate, kind = info$kind, family = info$family,
      analyte = analytes$analyte,
      value = vapply(cells, `[[`, numeric(1L), "value"),
      flag = vapply(cells, `[[`, character(1L), "flag"),
      raw_value = values, error_codes = f[[4L]],
      statistic_label = statistic_raw, unit = analytes$unit,
      reported_wells = well_field, .line = i
    )
  }
  if (length(acc) == 0L) return(empty)
  out <- dplyr::bind_rows(acc)
  out <- out[out$analyte != "Ref Spot", , drop = FALSE]
  out <- .qv_unique_measurements(out)
  identity <- .qv_sample_identity(out$well_group)
  out$dilution <- identity$dilution
  out$sample_id <- identity$sample_id
  pi_rows <- out[out$family == "pixel_intensity", , drop = FALSE]
  conc_rows <- out[out$family == "concentration", , drop = FALSE]
  replicates <- pi_rows[pi_rows$kind == "replicate", , drop = FALSE]
  summaries <- pi_rows[pi_rows$kind != "replicate", , drop = FALSE]
  list(
    replicates = tibble::tibble(
      well_group = replicates$well_group, sample_id = replicates$sample_id,
      well = replicates$well, replicate = replicates$replicate,
      analyte = replicates$analyte, unit = replicates$unit,
      pixel_intensity = replicates$value, dilution = replicates$dilution,
      raw_value = replicates$raw_value, flag = replicates$flag,
      error_codes = replicates$error_codes,
      statistic_label = replicates$statistic_label),
    summaries = tibble::tibble(
      well_group = summaries$well_group, sample_id = summaries$sample_id,
      statistic = summaries$kind, analyte = summaries$analyte,
      value = summaries$value, unit = summaries$unit,
      raw_value = summaries$raw_value, flag = summaries$flag,
      error_codes = summaries$error_codes,
      statistic_label = summaries$statistic_label),
    concentrations = if (nrow(conc_rows) > 0L) tibble::tibble(
      well_group = conc_rows$well_group, sample_id = conc_rows$sample_id,
      well = conc_rows$well, replicate = conc_rows$replicate,
      statistic = conc_rows$kind, analyte = conc_rows$analyte,
      unit = conc_rows$unit, concentration = conc_rows$value,
      dilution = conc_rows$dilution, flag = conc_rows$flag,
      raw_value = conc_rows$raw_value, error_codes = conc_rows$error_codes,
      statistic_label = conc_rows$statistic_label) else NULL,
    curve_fit = .qv_extract_curve_fit(csv_lines, analytes),
    well_source = .qv_record_well_source(out)
  )
}

# Well-bearing rows to seed the plate layout: pixel replicates if present,
# otherwise the concentration rows (auto_report has no pixel data).
.qv_well_source <- function(replicates, concentrations) {
  cols <- c("well", "well_group", "sample_id", "dilution")
  pieces <- lapply(list(replicates, concentrations), function(x) {
    if (is.null(x) || !nrow(x)) return(NULL)
    x[!is.na(x$well) & nzchar(x$well), cols, drop = FALSE]
  })
  out <- dplyr::bind_rows(pieces)
  if (!nrow(out)) return(.qv_empty_replicates()[, cols])
  out
}

.qv_rows_to_csv <- function(rows) {
  if (length(rows) == 0L) return(NULL)
  vapply(rows, function(f) {
    f[is.na(f)] <- ""
    quote <- grepl('[,"\\r\\n]', f, perl = TRUE) | grepl("^[[:space:]]|[[:space:]]$", f)
    f[quote] <- paste0('"', gsub('"', '""', f[quote], fixed = TRUE), '"')
    paste(f, collapse = ",")
  }, character(1L))
}
