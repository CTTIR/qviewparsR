# Shared text and identity checks. These do not interpret H2 transactions.
.qv_read_text_lines <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "bytes")
  if (!length(lines)) return(character())
  bom <- startsWith(lines[1L], "\xef\xbb\xbf")
  if (bom) lines[1L] <- rawToChar(charToRaw(lines[1L])[-seq_len(3L)])
  utf8 <- iconv(lines, from = "UTF-8", to = "UTF-8")
  if (all(!is.na(utf8))) {
    attr(utf8, "source_encoding") <- "UTF-8"
    return(utf8)
  }
  if (bom) cli::cli_abort("The UTF-8 report contains invalid text bytes.")
  out <- iconv(lines, from = "latin1", to = "UTF-8")
  attr(out, "source_encoding") <- "latin1"
  out
}

.qv_csv_records <- function(lines, delim = ",") {
  records <- list()
  fields <- character()
  buffer <- character(64L)
  used <- 0L
  quoted <- FALSE
  closed <- FALSE
  for (line_no in seq_along(lines)) {
    chars <- strsplit(lines[[line_no]], "", fixed = TRUE)[[1L]]
    i <- 1L
    while (i <= length(chars)) {
      ch <- chars[[i]]
      if (quoted) {
        if (ch == '"') {
          if (i < length(chars) && chars[[i + 1L]] == '"') {
            used <- used + 1L
            if (used > length(buffer)) length(buffer) <- 2L * length(buffer)
            buffer[[used]] <- '"'
            i <- i + 1L
          } else {
            quoted <- FALSE
            closed <- TRUE
          }
        } else {
          used <- used + 1L
          if (used > length(buffer)) length(buffer) <- 2L * length(buffer)
          buffer[[used]] <- ch
        }
      } else if (ch == delim) {
        fields <- c(fields, paste0(buffer[seq_len(used)], collapse = ""))
        used <- 0L
        closed <- FALSE
      } else if (ch == '"' && used == 0L && !closed) {
        quoted <- TRUE
      } else if (ch == '"' || closed) {
        cli::cli_abort("Malformed CSV quoting at source line {line_no}.")
      } else {
        used <- used + 1L
        if (used > length(buffer)) length(buffer) <- 2L * length(buffer)
        buffer[[used]] <- ch
      }
      i <- i + 1L
    }
    if (quoted) {
      used <- used + 1L
      if (used > length(buffer)) length(buffer) <- 2L * length(buffer)
      buffer[[used]] <- "\n"
    } else {
      fields <- c(fields, paste0(buffer[seq_len(used)], collapse = ""))
      used <- 0L
      closed <- FALSE
      records[[length(records) + 1L]] <- fields
      fields <- character()
    }
  }
  if (quoted) cli::cli_abort("Malformed CSV: unterminated quoted field.")
  records
}

.qv_check_panel <- function(analytes) {
  names <- analytes$analyte
  if (anyNA(names) || any(!nzchar(trimws(names))) || anyDuplicated(names)) {
    cli::cli_abort("The report analyte names must be nonempty and unique.")
  }
  invisible(TRUE)
}

.qv_report_values <- function(fields, n, context) {
  values <- fields[-seq_len(4L)]
  if (length(values) < n ||
      (length(values) > n && any(nzchar(trimws(values[-seq_len(n)]))))) {
    cli::cli_abort("Incomplete or extra analyte cells in {context}.")
  }
  values[seq_len(n)]
}

.qv_sample_identity <- function(groups) {
  sample <- groups
  dilution <- rep(NA_real_, length(groups))
  for (i in seq_along(groups)) {
    g <- groups[[i]]
    if (is.na(g) || !grepl("\\(1:", g)) next
    match <- regmatches(g, regexec("^(.*?)[[:space:]]*\\(1:([^()]*)\\)[[:space:]]*$", g))[[1L]]
    if (length(match) != 3L) next
    value <- .qv_parse_value_cell(match[[3L]])
    if (!is.na(value$flag) || !is.finite(value$value) || value$value <= 0) {
      cli::cli_abort("Dilution must be a positive finite number in {.val {g}}.")
    }
    sample[[i]] <- sub("[[:space:]]+$", "", match[[2L]])
    dilution[[i]] <- value$value
  }
  list(sample_id = sample, dilution = dilution)
}

.qv_check_report_wells <- function(field, context) {
  if (is.na(field) || !nzchar(trimws(field))) return(character())
  wells <- trimws(strsplit(field, ",", fixed = TRUE)[[1L]])
  if (any(!grepl("^[A-H]([1-9]|1[0-2])$", wells)) || anyDuplicated(wells)) {
    cli::cli_abort(c(
      "Unsupported or repeated report well in {context}: {.val {field}}.",
      "i" = "Report extraction currently supports A1 through H12."
    ))
  }
  wells
}

.qv_unique_measurements <- function(out) {
  if (!nrow(out)) return(out)
  # Labels are provenance, not separate measurements: Replicate 01 and 1
  # have the same identity. Keep distinct concentration quantities (such as
  # Reduced and Theoretical) separate from their summary/replicate suffixes.
  out$.quantity_key <- sub("^(.*?(?:Pixel Intensity|Concentration)).*$",
                           "\\1", out$statistic_label, perl = TRUE)
  keys <- c("well", "replicate", "kind", "family", "analyte", ".quantity_key")
  # For physical measurements, a different sample identity is a conflict,
  # not another candidate from which to select an analyte independently.
  out$.group_key <- ifelse(is.na(out$well), out$well_group, "")
  keys <- c(keys, ".group_key")
  key_rows <- out[, keys, drop = FALSE]
  duplicate <- duplicated(key_rows) | duplicated(key_rows, fromLast = TRUE)
  if (any(duplicate)) {
    candidates <- out[duplicate, , drop = FALSE]
    comparison <- setdiff(names(out), c(".line", ".group_key", "statistic_label"))
    unique_rows <- unique(candidates[, comparison, drop = FALSE])
    unique_rows$.group_key <- ifelse(is.na(unique_rows$well), unique_rows$well_group, "")
    if (anyDuplicated(unique_rows[, keys, drop = FALSE])) {
      conflict <- unique_rows[duplicated(unique_rows[, keys, drop = FALSE]), , drop = FALSE][1L, ]
      matching <- Reduce(`&`, lapply(keys, function(key) {
        value <- conflict[[key]]
        if (is.na(value)) is.na(candidates[[key]]) else
          !is.na(candidates[[key]]) & candidates[[key]] == value
      }))
      location <- if (is.na(conflict$well)) conflict$well_group else conflict$well
      records <- sort(unique(candidates$.line[matching]))
      cli::cli_abort(c(
        "Ambiguous conflicting report records; no current value can be established.",
        "x" = "Well/group {.val {location}}, analyte {.val {conflict$analyte}}, candidate record(s) {.val {records}}.",
        "i" = "Use an authoritative Q-View CSV/XLSX report export. Copy frequency and file order do not establish transaction recency."
      ), class = "qview_ambiguous_report", candidates = candidates)
    }
  }
  out <- out[!duplicated(key_rows), , drop = FALSE]
  out$.group_key <- NULL
  out$.quantity_key <- NULL
  out
}

.qv_record_well_source <- function(out) {
  cols <- c("well", "well_group", "sample_id", "dilution")
  if (!nrow(out)) return(.qv_empty_replicates()[, cols])
  groups <- unique(out[, c("well_group", "sample_id", "dilution", "reported_wells")])
  pieces <- lapply(seq_len(nrow(groups)), function(i) {
    wells <- .qv_check_report_wells(groups$reported_wells[[i]], "plate assignment")
    tibble::tibble(well = wells, well_group = groups$well_group[[i]],
                   sample_id = groups$sample_id[[i]], dilution = groups$dilution[[i]])
  })
  dplyr::bind_rows(pieces)
}

.qv_binary_text_error <- function(start, end, context) {
  cli::cli_abort(c(
    "Unsupported or fractured binary report text in {context} at bytes {start}--{end}.",
    "i" = "No altered text was returned. Use an authoritative Q-View CSV/XLSX report export."
  ), class = "qview_binary_text_error")
}

.qv_binary_line <- function(raw, start, context) {
  # An explicit bound avoids an unbounded scan through opaque database data.
  end <- min(length(raw), start + 65535L)
  bytes <- raw[seq.int(start, end)]
  newline <- which(bytes %in% as.raw(c(10L, 13L)))
  if (length(newline)) {
    bytes <- bytes[seq_len(newline[[1L]] - 1L)]
  } else if (end < length(raw)) {
    .qv_binary_text_error(start, end, context)
  }
  text <- bytes == as.raw(9L) | (bytes >= as.raw(32L) & bytes <= as.raw(126L))
  if (any(!text)) .qv_binary_text_error(start, start + length(bytes) - 1L, context)
  rawToChar(bytes)
}
