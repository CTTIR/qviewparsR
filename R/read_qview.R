#' Read a .Q-View project file
#'
#' `r lifecycle::badge("experimental")`
#'
#' Parses a `.Q-View` binary container (a chemiluminescent multiplex
#' ELISA project file holding an embedded H2 database plus binary LOB
#' segments) and extracts the assay data: project metadata, analyte
#' panel with units, well-group sample assignments, per-well replicate
#' pixel intensities, summary statistics, and (when present) the
#' embedded CSV report.
#'
#' The file format is reverse-engineered from public binary inspection:
#' it begins with a plain-text manifest, followed by three concatenated
#' H2 database segments. The fully-formatted report Q-View renders for
#' the user is stored as a CLOB inside the main H2 segment. This
#' parser scans the binary for that CLOB, reassembles it across H2 page
#' boundaries (2048-byte pages), and parses it as CSV.
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
#'     if the regression model is `"Qualitative"`.}
#'   \item{`curve_fit`}{Tibble with `analyte`, `regression_model`, or
#'     `NULL` if not reported.}
#'   \item{`report_csv`}{Character vector of the raw CSV report lines,
#'     or `NULL` if no report was generated.}
#'   \item{`plate_layout`}{Tibble with one row per well: `well`,
#'     `plate_row`, `plate_col`, `well_group`, `sample_id`,
#'     `well_type`, `dilution`.}
#' }
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

  well_groups <- .qv_build_well_groups(
    pixel_intensities, summary_statistics)
  plate_layout <- .qv_build_plate_layout(pixel_intensities, well_groups)

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
      report_csv         = if (is.null(report_lines)) NULL else unique(report_lines),
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
      } else NA_character_
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

  md_pos <- grepRaw(charToRaw("Project: "), raw, fixed = TRUE)
  if (length(md_pos) > 0L) {
    md_chunk <- raw[md_pos[1L]:min(md_pos[1L] + 2000L, length(raw))]
    md_chunk <- md_chunk[md_chunk >= as.raw(9) & md_chunk <= as.raw(126)]
    md_text <- rawToChar(md_chunk)
    md_lines <- strsplit(md_text, "[\r\n]+")[[1L]]
    pull <- function(prefix) {
      hit <- md_lines[startsWith(md_lines, prefix)]
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
  }
  metadata
}


.qv_extract_analyte_panel <- function(raw) {
  marker <- grepRaw(charToRaw("Well Group,Statistic,Well,Error Codes"),
                    raw, fixed = TRUE)
  empty <- tibble::tibble(spot_number = integer(),
                          analyte = character(), unit = character(),
                          lod = numeric(), lloq = numeric(),
                          uloq = numeric(),
                          assay_control_low = numeric(),
                          assay_control_high = numeric())
  if (length(marker) == 0L) return(empty)
  end <- min(marker[1L] + 2000L, length(raw))
  chunk <- raw[marker[1L]:end]
  chunk <- chunk[chunk >= as.raw(9) & chunk <= as.raw(126)]
  text <- rawToChar(chunk)
  hdr_line <- strsplit(text, "[\r\n]+")[[1L]][1L]
  fields <- .qv_split_csv_row(hdr_line)
  if (length(fields) <= 4L) return(empty)
  panel <- fields[-seq_len(4L)]
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
  # Pull the "Limit of Detection", "Lower / Upper Limit of Quantification",
  # and assay control range rows from the same first contiguous chunk.
  # These come in two stacked blocks: an "Assay" block (often
  # "Incalculable") and a "Lot" block (the numeric limits we want). Only
  # the block's first row carries the label; continuation rows have an
  # empty first field, so track the carried-forward section and match on
  # it -- otherwise the leading-comma rows are missed and the Assay block
  # is indistinguishable from the Lot block.
  lines <- strsplit(text, "[\r\n]+")[[1L]]
  section <- ""
  sect_of <- vapply(lines, function(ln) {
    f1 <- trimws(sub(",.*$", "", ln))
    if (nzchar(f1)) section <<- f1
    section
  }, character(1L), USE.NAMES = FALSE)
  pull_row <- function(stat, want = "Lot") {
    idx <- which(sect_of == want &
                 grepl(paste0(",", stat, ","), lines, fixed = TRUE))
    if (length(idx) == 0L) return(NULL)
    parts <- .qv_split_csv_row(lines[idx[1L]])
    vals <- parts[-seq_len(4L)]
    suppressWarnings(as.numeric(vals[seq_len(nrow(out))]))
  }
  lod  <- pull_row("Limit of Detection",            want = "Lot")
  lloq <- pull_row("Lower Limit of Quantification", want = "Lot")
  uloq <- pull_row("Upper Limit of Quantification", want = "Lot")
  acl  <- pull_row("Assay Control Range Low",  want = "Assay")
  ach  <- pull_row("Assay Control Range High", want = "Assay")
  if (!is.null(lod))  out$lod  <- lod
  if (!is.null(lloq)) out$lloq <- lloq
  if (!is.null(uloq)) out$uloq <- uloq
  if (!is.null(acl))  out$assay_control_low  <- acl
  if (!is.null(ach)) out$assay_control_high <- ach
  out
}


.qv_extract_report_lines <- function(raw) {
  is_text <- raw >= as.raw(9) & raw <= as.raw(126)
  r <- rle(is_text)
  ends   <- cumsum(r$lengths)
  starts <- ends - r$lengths + 1L
  mask <- r$values & r$lengths >= 30L
  patterns <- "(?:Pixel Intensity|Reduced Concentration|Theoretical Concentration|Backfit|Concentration|Regression Model|Limit of Detection|Limit of Quantification|Assay Control Range)"
  any_pattern <- paste0("(",
    "^[^,\\r\\n]+,", patterns, " (?:Average|\\(|$|,)", "|",
    "^,",            patterns,                          ")")
  captured <- character()
  for (i in which(mask)) {
    s <- starts[i]; L <- r$lengths[i]
    txt <- rawToChar(raw[s:(s + L - 1L)])
    parts <- unlist(strsplit(txt, "[\r\n]+"))
    if (length(parts) == 0L) next
    keep <- grepl(any_pattern, parts, perl = TRUE)
    if (any(keep)) captured <- c(captured, parts[keep])
  }
  if (length(captured) == 0L) return(NULL)
  # Keep duplicate copies: the H2 container flushes the current row to more
  # than one page, and that copy frequency is what lets the row parser tell
  # the committed reading from stale/truncated versions. De-duplication for
  # display happens later, in read_qview().
  trimws(captured)
}


.qv_parse_report_rows <- function(lines, analytes) {
  empty <- list(
    replicates     = .qv_empty_replicates(),
    summaries      = .qv_empty_summaries(),
    curve_fit      = NULL,
    concentrations = NULL
  )
  if (is.null(lines) || length(lines) == 0L || nrow(analytes) == 0L) {
    return(empty)
  }

  current_group <- NA_character_
  parsed <- vector("list", length(lines))

  for (i in seq_along(lines)) {
    parts <- .qv_split_csv_row(lines[[i]])
    if (length(parts) < 4L) next
    if (nzchar(parts[[1L]])) current_group <- parts[[1L]]
    well_group    <- if (nzchar(parts[[1L]])) parts[[1L]] else current_group
    statistic_raw <- parts[[2L]]
    well_field    <- parts[[3L]]
    values        <- parts[-seq_len(4L)]
    if (length(values) == 0L) next
    info <- .qv_classify_statistic(statistic_raw)
    if (is.na(info$kind)) next
    n <- nrow(analytes)
    if (length(values) >= n) values <- values[seq_len(n)] else length(values) <- n
    nums <- suppressWarnings(as.numeric(values))
    parsed[[i]] <- tibble::tibble(
      well_group  = well_group,
      well        = if (info$kind == "replicate") well_field else NA_character_,
      replicate   = info$replicate,
      kind        = info$kind,
      family      = info$family,
      analyte     = analytes$analyte,
      value       = nums,
      unit        = analytes$unit,
      .line       = i                      # source-line id; dropped before return
    )
  }

  out <- dplyr::bind_rows(parsed)
  if (nrow(out) == 0L) return(empty)
  out <- out[!is.na(out$analyte) & out$analyte != "Ref Spot",
             , drop = FALSE]
  out <- out[!is.na(out$well_group) & nzchar(out$well_group),
             , drop = FALSE]
  out <- out[!is.na(out$value), , drop = FALSE]
  # --- Collapse stale duplicate replicate readings ----------------------
  # The H2 container keeps superseded MVCC page versions of a well's row.
  # A version cut at a 2048-byte page boundary parses as a short row
  # (fewer analytes, a number sometimes truncated mid-digit) and can carry
  # a stale group label, so the same physical well appears several times
  # with different values. The current, committed row is flushed to more
  # than one page, so for each physical (well, replicate, family, analyte)
  # keep the value that occurs most often across the duplicate copies,
  # breaking ties toward the most complete source row (the intact, non-
  # truncated version). This must run on the raw rows -- before any
  # de-duplication that would discard the copy-frequency signal. Summary
  # rows (well == NA) are keyed by group and de-duplicated as before.
  is_rep <- out$kind == "replicate" & !is.na(out$well) & nzchar(out$well)
  rep_part <- out[is_rep, , drop = FALSE]
  other_part <- out[!is_rep, , drop = FALSE]
  if (nrow(rep_part) > 0L) {
    # completeness of the *source line* (a truncated copy carries fewer
    # analyte values than the intact one), independent of its group label.
    rep_part$.cov <- stats::ave(rep(1L, nrow(rep_part)), rep_part$.line,
                                FUN = length)
    cell <- paste(rep_part$well, rep_part$replicate, rep_part$family,
                  rep_part$analyte, sep = "\r")
    rep_part$.freq <- stats::ave(rep(1L, nrow(rep_part)),
                                 paste(cell, rep_part$value, sep = "\v"),
                                 FUN = length)
    ord <- order(rep_part$well, rep_part$replicate, rep_part$family,
                 rep_part$analyte, -rep_part$.freq, -rep_part$.cov)
    rep_part <- rep_part[ord, , drop = FALSE]
    rep_part <- dplyr::distinct(rep_part, .data$well, .data$replicate,
                               .data$family, .data$analyte, .keep_all = TRUE)
    rep_part$.cov <- NULL
    rep_part$.freq <- NULL
  }
  other_part <- dplyr::distinct(other_part, .data$well_group, .data$well,
                                .data$replicate, .data$kind, .data$family,
                                .data$analyte, .keep_all = TRUE)
  out <- dplyr::bind_rows(rep_part, other_part)
  out$.line <- NULL

  # Parse "(1:NNN)" dilution suffix off the well_group label.
  dilution <- rep(NA_real_, nrow(out))
  m <- regmatches(out$well_group,
                  regexec("\\(1:([0-9.]+)\\)\\s*$", out$well_group))
  for (k in seq_along(m)) {
    if (length(m[[k]]) == 2L) {
      dilution[k] <- suppressWarnings(as.numeric(m[[k]][2L]))
    }
  }
  out$dilution  <- dilution
  out$sample_id <- trimws(sub("\\s*\\([^)]*\\)\\s*$", "", out$well_group))

  pi_rows <- out[out$family == "pixel_intensity", , drop = FALSE]
  conc_rows <- out[out$family == "concentration", , drop = FALSE]

  replicates <- pi_rows[pi_rows$kind == "replicate", , drop = FALSE]
  summaries  <- pi_rows[pi_rows$kind != "replicate", , drop = FALSE]

  list(
    replicates = tibble::tibble(
      well_group      = replicates$well_group,
      sample_id       = replicates$sample_id,
      well            = replicates$well,
      replicate       = replicates$replicate,
      analyte         = replicates$analyte,
      unit            = replicates$unit,
      pixel_intensity = replicates$value,
      dilution        = replicates$dilution
    ),
    summaries = tibble::tibble(
      well_group = summaries$well_group,
      sample_id  = summaries$sample_id,
      statistic  = summaries$kind,
      analyte    = summaries$analyte,
      value      = summaries$value,
      unit       = summaries$unit
    ),
    concentrations = if (nrow(conc_rows) > 0L) {
      tibble::tibble(
        well_group    = conc_rows$well_group,
        sample_id     = conc_rows$sample_id,
        well          = conc_rows$well,
        replicate     = conc_rows$replicate,
        statistic     = conc_rows$kind,
        analyte       = conc_rows$analyte,
        unit          = conc_rows$unit,
        concentration = conc_rows$value,
        dilution      = conc_rows$dilution
      )
    } else NULL,
    curve_fit = .qv_extract_curve_fit(lines, analytes)
  )
}


.qv_extract_curve_fit <- function(lines, analytes) {
  if (is.null(lines) || nrow(analytes) == 0L) return(NULL)
  rgx <- "^[^,]*,Regression Model,"
  hit <- lines[grepl(rgx, lines)]
  if (length(hit) == 0L) return(NULL)
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
                            levels = c("standard","negative","sample","control"))))
  }
  base <- trimws(sub("\\s*\\([^)]*\\)\\s*$", "", groups))
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
  }
  out
}


# CSV row splitter that respects double-quoted fields. Q-View only quotes
# fields containing commas (e.g. "A1, A2"); a tiny state machine is enough.
.qv_split_csv_row <- function(line) {
  chars <- strsplit(line, "", fixed = TRUE)[[1L]]
  fields <- character()
  buf <- character()
  in_q <- FALSE
  for (ch in chars) {
    if (ch == "\"") {
      in_q <- !in_q
    } else if (ch == "," && !in_q) {
      fields <- c(fields, paste0(buf, collapse = ""))
      buf <- character()
    } else {
      buf <- c(buf, ch)
    }
  }
  fields <- c(fields, paste0(buf, collapse = ""))
  trimws(fields)
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
    dilution        = numeric()
  )
}


.qv_empty_summaries <- function() {
  tibble::tibble(
    well_group = character(),
    sample_id  = character(),
    statistic  = character(),
    analyte    = character(),
    value      = numeric(),
    unit       = character()
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
