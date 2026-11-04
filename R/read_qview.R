#' Read a .Q-View project file
#'
#' `r lifecycle::badge("stable")`
#'
#' Parses a `.Q-View` binary container (a chemiluminescent multiplex
#' ELISA project file holding an embedded H2 database plus binary LOB
#' segments) and extracts the assay data: project metadata, analyte
#' panel with units, well-group sample assignments, per-well replicate
#' pixel intensities, summary statistics, and (when present) the
#' embedded CSV report.
#'
#' This reverse-engineered reader scans printable report text inside the
#' container. It does not open the H2 database or establish transaction
#' recency. Identical repeated records are collapsed; conflicting candidate
#' records and incomplete analyte rows are refused rather than selecting
#' values by page-copy frequency. An authoritative flat CSV/XLSX report can
#' be read with [read_qview_report()] when binary extraction is ambiguous.
#' The binary scan is limited to printable ASCII spans, not a general CLOB
#' decoder, and cannot recover a complete report across arbitrary page or
#' encoding boundaries. Report wells are limited to A1 through H12.
#' Sample and Assay/Lot continuation never crosses an opaque binary gap.
#'
#' Parsing is done in pure R: no Java runtime, no H2 database driver,
#' no system dependencies beyond a working R installation.
#'
#' @param path Character. Path to the `.Q-View` file.
#' @param strip_prefix Logical. If `TRUE`, reverse Q-View's internal
#'   naming convention via [strip_qview_prefix()] so identifiers match
#'   the original well-assignment template. Default `FALSE`.
#' @param verbose Logical. Print a short summary after parsing.
#'   Default `TRUE`.
#' @param call The execution environment of the calling function. Used
#'   for error reporting; experts only.
#'
#' @return A list with class `"qview"` containing:
#' \describe{
#'   \item{`metadata`}{Named list: `project`, `plate`, `image`,
#'     `imager`, `product`, `user`, `report_created`, `qview_version`,
#'     `template`, `container_version`, `file_path`, `parsed_at`.}
#'   \item{`manifest`}{Tibble with one row per declared file entry
#'     (`name`, `size_bytes`, `parent`).}
#'   \item{`segments`}{Tibble of H2 segment byte ranges (`segment`,
#'     `start`, `end`, `size`).}
#'   \item{`analytes`}{Tibble: `spot_number`, `analyte`, `unit`, plus
#'     `lod`, `lloq`, `uloq`, `assay_control_low`, `assay_control_high`
#'     when reported.}
#'   \item{`well_groups`}{Tibble: `well_group`, `sample_id`,
#'     `is_standard`, `is_negative`, `is_sample`, `is_control`,
#'     `well_type`.}
#'   \item{`pixel_intensities`}{Long-format tibble of replicate readings:
#'     `well_group`, `sample_id`, `well`, `replicate`, `analyte`,
#'     `unit`, `pixel_intensity`, `dilution`.}
#'   \item{`summary_statistics`}{Long-format tibble of per-group
#'     averages, std-dev, and CV statistics: `well_group`, `sample_id`,
#'     `statistic`, `analyte`, `value`, `unit`.}
#'   \item{`concentrations`}{Long-format concentration tibble or `NULL`
#'     when no supported concentration rows were extracted.}
#'   \item{`curve_fit`}{Tibble with `analyte`, `regression_model`, or
#'     `NULL` if not reported.}
#'   \item{`report_csv`}{Extracted candidate report lines in source order,
#'     including repeated copies, or `NULL` if none were found. This is not
#'     a complete or transaction-verified CLOB.}
#'   \item{`plate_layout`}{Tibble with one row per well: `well`,
#'     `plate_row`, `plate_col`, `well_group`, `sample_id`,
#'     `well_type`, `dilution`.}
#' }
#'
#' Measurement tables preserve decoded `raw_value`, `flag`, `error_codes`
#' and `statistic_label`. Missing and incalculable cells remain explicit rows;
#' censored numeric cells retain their bound and flag, not an invented point
#' estimate. Nonblank malformed or nonfinite numeric values are refused.
#' See [read_qview_report()] for the shared value and identity rules.
#'
#' @examples
#' # A small synthetic .Q-View ships with the package:
#' path <- system.file("extdata", "example.Q-View", package = "qviewparsR")
#' qv <- read_qview(path)
#' qv
#' qv$analytes
#' head(qv$pixel_intensities)
#'
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   plot(qv, type = "plate_map")
#' }
#'
#' @seealso [strip_qview_prefix()], [read_qview_template()],
#'   [print.qview()], [plot.qview()].
#' @family qview-reader
#'
#' @export
read_qview <- function(path,
                       strip_prefix = FALSE,
                       verbose = TRUE,
                       call = rlang::caller_env()) {
  rlang::check_required(path)
  .check_path(path, call = call)
  .check_flag(strip_prefix, call = call)
  .check_flag(verbose, call = call)

  raw <- readBin(path, what = "raw", n = file.info(path)$size)
  .qv_check_magic(raw, path, call = call)

  manifest <- .qv_parse_manifest(raw)
  segments <- .qv_find_h2_segments(raw)
  metadata <- .qv_extract_metadata(raw, path)
  analytes <- .qv_extract_analyte_panel(raw)
  report_lines <- .qv_extract_report_lines(raw)
  rows <- .qv_parse_report_rows(report_lines, analytes)

  pixel_intensities <- rows$replicates
  summary_statistics <- rows$summaries
  curve_fit <- rows$curve_fit
  concentrations <- rows$concentrations

  group_source <- tibble::tibble(well_group = c(
    pixel_intensities$well_group, summary_statistics$well_group,
    if (is.null(concentrations)) character() else concentrations$well_group))
  well_groups <- .qv_build_well_groups(group_source, group_source)
  plate_layout <- .qv_build_plate_layout(rows$well_source, well_groups)

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
      manifest           = manifest,
      segments           = segments,
      analytes           = analytes,
      well_groups        = well_groups,
      pixel_intensities  = pixel_intensities,
      summary_statistics = summary_statistics,
      concentrations     = concentrations,
      curve_fit          = curve_fit,
      report_csv         = if (is.null(report_lines)) NULL else as.character(report_lines),
      plate_layout       = plate_layout
    ),
    class = "qview"
  )

  if (isTRUE(verbose)) {
    n_groups <- nrow(well_groups)
    n_analytes <- nrow(analytes)
    n_reps <- nrow(pixel_intensities)
    cli::cli_inform(c(
      "v" = "Parsed {.path {basename(path)}}: {.val {n_groups}} well group{?s} x {.val {n_analytes}} analyte{?s} ({.val {n_reps}} replicate row{?s}).",
      i = if (!is.na(metadata$qview_version))
        "Q-View Version: {.val {metadata$qview_version}}" else NULL
    ))
  }

  out
}


# --- Magic-byte / manifest validation -----------------------------------------

.qv_check_magic <- function(raw, path, call = rlang::caller_env()) {
  hdr <- raw[seq_len(min(64L, length(raw)))]
  hdr[hdr == as.raw(0)] <- charToRaw(" ")
  txt <- rawToChar(hdr)
  if (!grepl("^[0-9]+\\s+Q-View Project", txt, perl = TRUE)) {
    cli::cli_abort(
      c("{.arg path} is not a valid {.field .Q-View} project file.",
        "x" = "{.path {path}} is missing the expected container header.",
        "i" = "Expected a numeric container version followed by {.val Q-View Project}."),
      call = call
    )
  }
  invisible(TRUE)
}


.qv_parse_manifest <- function(raw) {
  hdr <- raw[seq_len(min(2048L, length(raw)))]
  hdr[hdr == as.raw(0)] <- charToRaw("\n")
  txt <- rawToChar(hdr)
  # Cut at the first H2 marker -- the manifest sits before the H2 segments.
  txt <- strsplit(txt, "-- H2", fixed = TRUE)[[1L]][1L]
  lines <- strsplit(txt, "[\r\n]+")[[1L]]
  lines <- trimws(lines)
  lines <- lines[nzchar(lines)]
  # Manifest layout: version, then triplets of (size, name, parent?).
  if (length(lines) < 2L) {
    return(tibble::tibble(name = character(), size_bytes = integer(),
                          parent = character()))
  }
  # We can't fully trust positional parsing across all Q-View versions, so
  # extract every (size, name) pair we recognise: a numeric line followed
  # by a non-numeric line.
  is_num <- grepl("^[0-9]+$", lines)
  rows <- list()
  i <- 1L
  while (i < length(lines)) {
    if (is_num[i] && !is_num[i + 1L]) {
      size <- as.integer(lines[i])
      name <- lines[i + 1L]
      parent <- if (i + 2L <= length(lines) && !is_num[i + 2L] &&
                    startsWith(lines[i + 2L], "\\")) {
        lines[i + 2L]
      } else {
        NA_character_
      }
      rows[[length(rows) + 1L]] <- tibble::tibble(
        name = name, size_bytes = size, parent = parent
      )
      i <- if (!is.na(parent)) i + 3L else i + 2L
    } else {
      i <- i + 1L
    }
  }
  if (length(rows) == 0L) {
    return(tibble::tibble(name = character(), size_bytes = integer(),
                          parent = character()))
  }
  dplyr::bind_rows(rows)
}


.qv_find_h2_segments <- function(raw) {
  marker <- charToRaw("-- H2 0.5/B --")
  positions <- grepRaw(marker, raw, all = TRUE)
  if (length(positions) < 3L) {
    return(tibble::tibble(segment = integer(), start = integer(),
                          end = integer(), size = integer()))
  }
  # Each H2 segment is preceded by exactly three triplet markers; pick
  # every third hit as a segment start.
  starts <- positions[seq(1L, length(positions), by = 3L)]
  ends   <- c(starts[-1L] - 1L, length(raw))
  tibble::tibble(
    segment = seq_along(starts),
    start   = starts,
    end     = ends,
    size    = ends - starts + 1L
  )
}


.qv_extract_metadata <- function(raw, path) {
  metadata <- list(
    project = NA_character_, plate = NA_character_,
    image = NA_character_, imager = NA_character_,
    product = NA_character_, user = NA_character_,
    report_created = NA_character_, qview_version = NA_character_,
    template = NA_character_,
    container_version = NA_character_,
    file_path = normalizePath(path, mustWork = FALSE),
    parsed_at = Sys.time()
  )
  hdr <- raw[seq_len(min(64L, length(raw)))]
  hdr[hdr == as.raw(0)] <- charToRaw(" ")
  m <- regmatches(rawToChar(hdr),
                  regexec("^([0-9]+)", rawToChar(hdr)))[[1L]]
  if (length(m) == 2L) metadata$container_version <- m[2L]

  prefixes <- c(project = "Project: ", plate = "Plate: ", image = "Image: ",
                imager = "Imager: ", product = "Product: ", user = "User: ",
                report_created = "Report Created: ", qview_version = "Q-View Version: ",
                template = "Well Assignment Template: ")
  line_starts <- c(1L, which(raw %in% as.raw(c(10L, 13L))) + 1L)
  for (field in names(prefixes)) {
    prefix <- prefixes[[field]]
    positions <- grepRaw(charToRaw(prefix), raw, all = TRUE, fixed = TRUE)
    # A key mentioned inside another value is not a second metadata record.
    positions <- positions[positions %in% line_starts]
    if (!length(positions)) next
    values <- vapply(positions, function(pos) {
      line <- .qv_binary_line(raw, pos, paste("metadata", field))
      substring(line, nchar(prefix) + 1L)
    }, character(1L))
    if (length(unique(values)) > 1L) {
      cli::cli_abort("Ambiguous conflicting binary metadata: {.val {field}}.")
    }
    metadata[[field]] <- values[[1L]]
  }
  metadata
}


.qv_extract_analyte_panel <- function(raw) {
  marker <- grepRaw(charToRaw("Well Group,Statistic,Well,Error Codes"),
                    raw, all = TRUE, fixed = TRUE)
  line_starts <- c(1L, which(raw %in% as.raw(c(10L, 13L))) + 1L)
  marker <- marker[marker %in% line_starts]
  empty <- tibble::tibble(spot_number = integer(),
                          analyte = character(), unit = character(),
                          lod = numeric(), lloq = numeric(),
                          uloq = numeric(),
                          assay_control_low = numeric(),
                          assay_control_high = numeric())
  if (length(marker) == 0L) return(empty)
  headers <- lapply(marker, function(pos) {
    .qv_split_csv_row(.qv_binary_line(raw, pos, "analyte header"))
  })
  if (length(unique(headers)) > 1L) {
    cli::cli_abort("Ambiguous conflicting binary analyte headers.")
  }
  fields <- headers[[1L]]
  if (length(fields) <= 4L) return(empty)
  panel <- trimws(fields[-seq_len(4L)])
  while (length(panel) && !nzchar(utils::tail(panel, 1L))) panel <- utils::head(panel, -1L)
  m <- regmatches(panel, regexec("^(.+?)\\s*\\(([^)]+)\\)\\s*$", panel))
  analyte <- vapply(m, function(x) if (length(x) == 3L) x[2L] else NA_character_, "")
  unit    <- vapply(m, function(x) if (length(x) == 3L) x[3L] else NA_character_, "")
  bad <- is.na(analyte)
  analyte[bad] <- panel[bad]
  out <- tibble::tibble(
    spot_number = seq_along(panel),
    analyte     = analyte,
    unit        = unit,
    lod         = NA_real_,
    lloq        = NA_real_,
    uloq        = NA_real_,
    assay_control_low  = NA_real_,
    assay_control_high = NA_real_
  )
  .qv_check_panel(out)
  # Read only intact, observed report lines. No non-ASCII/control byte is
  # discarded to join fragments into a different numeric or identity token.
  lines <- .qv_extract_report_lines(raw)
  section <- ""
  values <- list()
  source_runs <- attr(lines, "source_runs")
  for (i in seq_along(lines)) {
    if (i == 1L || source_runs[[i]] != source_runs[[i - 1L]]) section <- ""
    f <- .qv_split_csv_row(lines[[i]])
    if (length(f) < 4L) next
    if (nzchar(trimws(f[[1L]]))) section <- f[[1L]]
    stat <- trimws(f[[2L]])
    if (!stat %in% c("Limit of Detection", "Lower Limit of Quantification",
                     "Upper Limit of Quantification", "Assay Control Range Low",
                     "Assay Control Range High")) next
    if (!section %in% c("Assay", "Lot")) {
      cli::cli_abort("Missing Assay/Lot section for binary analyte limits at candidate record {i}.")
    }
    key <- paste(section, stat, sep = "|")
    value <- .qv_value_number(.qv_report_values(f, nrow(out), "analyte limits"))
    if (!is.null(values[[key]]) && !identical(values[[key]], value)) {
      cli::cli_abort("Ambiguous conflicting binary analyte limits: {.val {key}}.")
    }
    values[[key]] <- value
  }
  mapping <- c(lod = "Lot|Limit of Detection",
               lloq = "Lot|Lower Limit of Quantification",
               uloq = "Lot|Upper Limit of Quantification",
               assay_control_low = "Assay|Assay Control Range Low",
               assay_control_high = "Assay|Assay Control Range High")
  for (field in names(mapping)) {
    value <- values[[mapping[[field]]]]
    if (!is.null(value)) out[[field]] <- value
  }
  out
}


.qv_extract_report_lines <- function(raw) {
  is_text <- raw %in% as.raw(c(9L, 10L, 13L)) |
    (raw >= as.raw(32L) & raw <= as.raw(126L))
  runs <- rle(is_text)
  ends <- cumsum(runs$lengths)
  starts <- ends - runs$lengths + 1L
  patterns <- paste0("(?:Pixel Intensity|Reduced Concentration|",
    "Theoretical Concentration|Backfit Concentration|Expected Concentration|",
    "Concentration|Regression Model|Limit of Detection|",
    "Lower Limit of Quantification|Upper Limit of Quantification|Assay Control Range)")
  captured <- character()
  source_spans <- list()
  source_runs <- integer()
  for (i in which(runs$values & runs$lengths >= 20L)) {
    start <- starts[[i]]
    end <- ends[[i]]
    text <- rawToChar(raw[seq.int(start, end)])
    breaks <- gregexpr("[\r\n]", text)[[1L]]
    breaks <- breaks[breaks > 0L]
    begins <- c(1L, breaks + 1L)
    finishes <- c(breaks - 1L, nchar(text))
    for (j in which(begins <= finishes)) {
      line <- substr(text, begins[[j]], finishes[[j]])
      if (!grepl(paste0(",", patterns, "(?:[ ,]|$)"), line, perl = TRUE)) next
      # A report-like fragment touching an opaque byte boundary is not a
      # complete source record. Refuse it instead of changing its identity.
      left_ok <- begins[[j]] > 1L || start == 1L
      right_ok <- finishes[[j]] < nchar(text) || end == length(raw)
      if (!left_ok || !right_ok) {
        .qv_binary_text_error(start + begins[[j]] - 1L,
                              start + finishes[[j]] - 1L, "candidate record")
      }
      captured <- c(captured, line)
      source_spans[[length(source_spans) + 1L]] <- c(
        start = start + begins[[j]] - 1L, end = start + finishes[[j]] - 1L)
      source_runs <- c(source_runs, i)
    }
  }
  if (!length(captured)) return(NULL)
  # Copy counts and physical order are provenance, not transaction recency.
  attr(captured, "source_spans") <- source_spans
  attr(captured, "source_runs") <- source_runs
  captured
}

.qv_parse_report_rows <- function(lines, analytes) {
  rows <- if (is.null(lines)) list() else lapply(lines, .qv_split_csv_row)
  attr(rows, "source_runs") <- attr(lines, "source_runs")
  .qv_parse_export_rows(rows, 0L, analytes)
}

.qv_extract_curve_fit <- function(lines, analytes) {
  if (is.null(lines) || nrow(analytes) == 0L) return(NULL)
  rgx <- "^[^,]*,Regression Model,"
  hit <- lines[grepl(rgx, lines)]
  if (length(hit) == 0L) return(NULL)
  models <- lapply(hit, function(line) {
    .qv_report_values(.qv_split_csv_row(line), nrow(analytes), "regression model")
  })
  if (length(unique(models)) > 1L) {
    cli::cli_abort("Ambiguous conflicting regression-model records.")
  }
  parts <- .qv_split_csv_row(hit[1L])
  vals <- parts[-seq_len(4L)]
  if (length(vals) < nrow(analytes)) length(vals) <- nrow(analytes)
  tibble::tibble(
    spot_number      = analytes$spot_number,
    analyte          = analytes$analyte,
    regression_model = trimws(vals[seq_len(nrow(analytes))])
  )
}


.qv_build_well_groups <- function(replicates, summaries) {
  groups <- unique(c(replicates$well_group, summaries$well_group))
  groups <- groups[!is.na(groups) & nzchar(groups)]
  if (length(groups) == 0L) {
    return(tibble::tibble(well_group = character(),
                          sample_id  = character(),
                          is_standard = logical(),
                          is_negative = logical(),
                          is_sample   = logical(),
                          is_control  = logical(),
                          well_type   = factor(character(),
                            levels = c("standard", "negative", "sample", "control"))))
  }
  base <- .qv_sample_identity(groups)$sample_id
  classify <- function(g) {
    if (grepl("^ICal\\b|^Cal\\b", g)) return("standard")
    if (g == "GLow"  || g == "Low")    return("negative")
    if (g == "HHigh" || g == "High")   return("control")
    "sample"
  }
  type <- vapply(base, classify, character(1L))
  sample_id <- base
  tibble::tibble(
    well_group  = groups,
    sample_id   = sample_id,
    is_standard = type == "standard",
    is_negative = type == "negative",
    is_sample   = type == "sample",
    is_control  = type == "control",
    well_type   = factor(type,
      levels = c("standard", "negative", "sample", "control"))
  )
}


.qv_build_plate_layout <- function(replicates, well_groups) {
  grid <- .qv_plate_grid()
  if (is.null(replicates) || nrow(replicates) == 0L) {
    grid$well_group <- NA_character_
    grid$sample_id  <- NA_character_
    grid$well_type  <- factor(NA, levels = levels(well_groups$well_type))
    grid$dilution   <- NA_real_
    return(grid)
  }
  per_well <- dplyr::distinct(
    replicates[, c("well", "well_group", "sample_id", "dilution")])
  if (anyDuplicated(per_well$well)) {
    cli::cli_abort("Conflicting sample assignments for a physical report well.")
  }
  invisible(lapply(per_well$well, .qv_check_report_wells, context = "plate layout"))
  per_well <- dplyr::left_join(
    per_well,
    well_groups[, c("well_group", "well_type")],
    by = "well_group"
  )
  out <- dplyr::left_join(grid, per_well, by = "well")
  out
}


.qv_classify_statistic <- function(label) {
  label <- trimws(label)
  out <- list(kind = NA_character_, replicate = NA_integer_,
              family = NA_character_)
  family <- if (grepl("Pixel Intensity", label)) "pixel_intensity"
            else if (grepl("Concentration", label)) "concentration"
            else NA_character_
  if (is.na(family)) return(out)
  out$family <- family
  if (grepl("Average$", label)) {
    out$kind <- "average"
  } else if (grepl("Std Dev", label)) {
    out$kind <- "std_dev"
  } else if (grepl("% CV|Coefficient of Variation", label)) {
    out$kind <- "cv"
  } else if (grepl("\\(Replicate ([0-9]+)\\)", label)) {
    m <- regmatches(label, regexec("\\(Replicate ([0-9]+)\\)", label))[[1L]]
    out$kind <- "replicate"
    out$replicate <- suppressWarnings(as.integer(m[2L]))
    if (is.na(out$replicate) || out$replicate < 1L) {
      cli::cli_abort("Replicate indices must be positive representable integers.")
    }
  }
  out
}


# CSV row splitter that respects double-quoted fields. Q-View only quotes
# fields containing commas (e.g. "A1, A2"); a tiny state machine is enough.
.qv_split_csv_row <- function(line) {
  rows <- .qv_csv_records(line)
  if (length(rows) != 1L) cli::cli_abort("Expected one CSV record.")
  rows[[1L]]
}

.qv_empty_replicates <- function() {
  tibble::tibble(
    well_group      = character(),
    sample_id       = character(),
    well            = character(),
    replicate       = integer(),
    analyte         = character(),
    unit            = character(),
    pixel_intensity = numeric(),
    dilution        = numeric(),
    raw_value = character(), flag = character(), error_codes = character(),
    statistic_label = character()
  )
}


.qv_empty_summaries <- function() {
  tibble::tibble(
    well_group = character(),
    sample_id  = character(),
    statistic  = character(),
    analyte    = character(),
    value      = numeric(),
    unit       = character(),
    raw_value = character(), flag = character(), error_codes = character(),
    statistic_label = character()
  )
}


# Internal: detect Q-View binary file by magic / extension. Used by
# upstream code that needs to dispatch on file type.
.qv_is_qview_binary <- function(path) {
  if (!file.exists(path)) return(FALSE)
  ext <- tolower(tools::file_ext(path))
  if (ext == "q-view") return(TRUE)
  con <- file(path, "rb")
  on.exit(close(con))
  raw <- readBin(con, "raw", n = 512L)
  if (length(raw) == 0L) return(FALSE)
  ascii <- ifelse(raw >= as.raw(32) & raw <= as.raw(126),
                  rawToChar(raw, multiple = TRUE), " ")
  any(grepl("Q-View Project", paste0(ascii, collapse = ""), fixed = TRUE))
}
# Version 1.0.0
