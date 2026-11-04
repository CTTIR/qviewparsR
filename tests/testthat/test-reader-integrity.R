.integrity_report <- function(rows, panel = "X (ng/mL)") {
  path <- withr::local_tempfile(fileext = ".csv", .local_envir = parent.frame())
  writeLines(c(paste0("Well Group,Statistic,Well,Error Codes,", panel), rows),
             path, useBytes = TRUE)
  path
}

.integrity_template <- function() {
  c(
  "2x2,,,", ",1,2,Group Name", "A,001,S2,", "B,S3,S4,",
  ",1,2,Group Type", "A,sample,sample,", "B,sample,sample,",
  ",1,2,Dilution Factor", "A,,1,", "B,2,3,"
  )
}

.integrity_template_file <- function(lines) {
  path <- withr::local_tempfile(fileext = ".csv", .local_envir = parent.frame())
  writeLines(lines, path, useBytes = TRUE)
  path
}

test_that("conflicting candidate pages never create a hybrid measurement", {
  panel <- tibble::tibble(spot_number = 1:3, analyte = c("X", "Y", "Z"), unit = "ng/mL")
  rows <- c("S-A,Pixel Intensity (Replicate 1),A1,,1,20,30",
            "S-B,Pixel Intensity (Replicate 1),A1,,1,2,300",
            "S-C,Pixel Intensity (Replicate 1),A1,,10,2,30")
  expect_error(.qv_parse_report_rows(rows, panel), "Ambiguous conflicting")
  expect_error(.qv_parse_report_rows(c(rep(rows[1L], 10L), rows[2L]), panel),
               "Ambiguous conflicting")
  expect_error(.qv_parse_report_rows(rev(rows), panel), "Ambiguous conflicting")
  clean <- .qv_parse_report_rows(rep(rows[1L], 3L), panel)$replicates
  expect_identical(clean$pixel_intensity, c(1, 20, 30))
  expect_identical(clean$sample_id, rep("S-A", 3L))
  expect_equal(nrow(clean), 3L)
})

test_that("missing and censored records retain sample identity and raw evidence", {
  path <- .integrity_report(c(
    "S1,Pixel Intensity (Replicate 1),A1,E1,",
    "S2,Pixel Intensity (Replicate 1),A2,,< 5",
    "S3,Pixel Intensity Average,A3,,Incalculable High",
    'S4,Reduced Concentration,A4,E4," 1.5 "',
    "S5,Reduced Concentration,A5,,> 7",
    "S6,Reduced Concentration,A6,,NA"))
  q <- read_qview_report(path, verbose = FALSE)
  expect_setequal(q$well_groups$sample_id, paste0("S", 1:6))
  expect_setequal(stats::na.omit(q$plate_layout$sample_id), paste0("S", 1:6))
  expect_identical(q$pixel_intensities$flag, c("missing", "<"))
  expect_identical(q$pixel_intensities$raw_value, c("", "< 5"))
  expect_identical(q$pixel_intensities$error_codes, c("E1", ""))
  expect_true(is.na(q$pixel_intensities$pixel_intensity[1L]))
  expect_identical(q$summary_statistics$flag, "incalculable")
  expect_identical(q$concentrations$raw_value, c(" 1.5 ", "> 7", "NA"))
  expect_identical(q$concentrations$flag, c(NA_character_, ">", "missing"))
  expect_identical(q$report_csv, readLines(path))
  binary <- .qv_parse_report_rows(readLines(path)[-1L], q$analytes)
  expect_identical(binary$concentrations, q$concentrations)
  expect_identical(binary$replicates, q$pixel_intensities)
})

test_that("unknown nonblank numeric values fail instead of removing samples", {
  for (token in c("garbage", "123oops", "Inf", "-Inf", "NaN", "< nonsense", "1e999", "1e-999")) {
    path <- .integrity_report(paste0("S1,Reduced Concentration,A1,,", token))
    expect_error(read_qview_report(path, verbose = FALSE), "Invalid value at report row")
  }
  expect_identical(.qv_parse_value_cell("0e-9999")$value, 0)
  expect_identical(.qv_parse_value_cell("4.9406564584124654e-324")$value,
                   .Machine$double.xmin * .Machine$double.eps)
  expect_error(read_qview_report(.integrity_report("S1,Reduced Concentration,A1,,1", "X (ng/mL),Y (ng/mL)"), verbose = FALSE),
               "Incomplete or extra")
  expect_error(read_qview_report(.integrity_report("S1,Reduced Concentration,A1,,1,2"), verbose = FALSE),
               "Incomplete or extra")
})

test_that("CSV quoting, Unicode and literal suffixes preserve identities", {
  rows <- c('"Sample ""A""",Reduced Concentration,A1,,2',
            "Sample (before),Reduced Concentration,A2,,3",
            "001 (1:100),Reduced Concentration,A3,,4",
            '"Müller, synthetic",Reduced Concentration,A4,,5',
            '"two', 'lines",Reduced Concentration,A5,,6')
  path <- .integrity_report(rows)
  q <- read_qview_report(path, verbose = FALSE)
  expect_identical(q$concentrations$sample_id,
                   c('Sample "A"', "Sample (before)", "001", "Müller, synthetic", "two\nlines"))
  expect_identical(q$concentrations$dilution, c(NA_real_, NA_real_, 100, NA_real_, NA_real_))
  expect_identical(q$report_csv, readLines(path))
  x <- list(c('Sample "A"', "x,y", "a\nb", " padded "))
  expect_identical(.qv_csv_records(strsplit(.qv_rows_to_csv(x), "\n")[[1L]]), x)
  bom <- withr::local_tempfile(fileext = ".csv")
  writeBin(c(as.raw(c(239, 187, 191)), charToRaw(paste(readLines(path), collapse = "\n"))), bom)
  expect_identical(read_qview_report(bom, verbose = FALSE)$concentrations, q$concentrations)
  latin <- withr::local_tempfile(fileext = ".csv")
  writeBin(charToRaw(iconv(paste(readLines(path), collapse = "\n"), to = "latin1")), latin)
  expect_identical(read_qview_report(latin, verbose = FALSE)$concentrations, q$concentrations)
})

test_that("XLSX text is decoded once", {
  path <- withr::local_tempfile(fileext = ".xlsx")
  m <- rbind(c("Well Group", "Statistic", "Well", "Error Codes", "X (ng/mL)"),
             c("Müller", "Reduced Concentration", "A1", "", "2"))
  openxlsx2::write_xlsx(as.data.frame(m), path, col_names = FALSE)
  q <- read_qview_report(path, verbose = FALSE)
  expect_identical(q$concentrations$sample_id, "Müller")
  expect_identical(q$well_groups$sample_id, "Müller")
})

test_that("malformed quoting and duplicate analyte identities are refused", {
  for (row in c('"unclosed,Reduced Concentration,A1,,1', 'bad"quote,Reduced Concentration,A1,,1')) {
    expect_error(read_qview_report(.integrity_report(row), verbose = FALSE), "Malformed CSV")
  }
  expect_error(read_qview_report(.integrity_report("S,Reduced Concentration,A1,,1,2", "X (ng/mL),X (ug/mL)"), verbose = FALSE),
               "nonempty and unique")
})

test_that("unsupported report wells and invalid dilution are explicit", {
  for (well in c("H13", "I1", "A0", "A1.5")) {
    expect_error(read_qview_report(.integrity_report(paste0("S,Reduced Concentration,", well, ",,1")), verbose = FALSE),
                 "Unsupported or repeated report well")
  }
  for (dilution in c("0", "-1", "Inf", "garbage")) {
    expect_error(read_qview_report(.integrity_report(paste0("S (1:", dilution, "),Reduced Concentration,A1,,1")), verbose = FALSE))
  }
  expect_error(read_qview_report(.integrity_report(c("S1,Pixel Intensity (Replicate 1),A1,,1", "S2,Reduced Concentration,A1,,2")), verbose = FALSE),
               "Conflicting sample assignments")
})

test_that("template dimensions, sections and physical identities are validated", {
  good <- .integrity_template()
  q <- read_qview_template(.integrity_template_file(good), verbose = FALSE)
  expect_identical(q$well, c("A1", "B1", "A2", "B2"))
  expect_identical(q$sample_id, c("001", "S3", "S2", "S4"))
  expect_identical(q$dilution, c(NA_real_, 2, 1, 3))
  bad <- good; bad[4L] <- "A,S3,S4,"
  expect_error(read_qview_template(.integrity_template_file(bad), verbose = FALSE), "exactly once")
  for (dims in c("0x2", "2x0", "2x27", "999999999999999999999x2", "3x2")) {
    bad <- good; bad[1L] <- paste0(dims, ",,,")
    expect_error(read_qview_template(.integrity_template_file(bad), verbose = FALSE))
  }
  bad <- good; bad[5L] <- ",1,2,Group Name"
  expect_error(read_qview_template(.integrity_template_file(bad), verbose = FALSE), "Duplicate template section")
  expect_error(read_qview_template(.integrity_template_file(good[-(8:10)]), verbose = FALSE), "Missing required template")
  expect_error(read_qview_template(.integrity_template_file(good[-10L]), verbose = FALSE), "Incomplete template")
  for (value in c("garbage", "-2", "0", "Inf", "NA")) {
    bad <- good; bad[10L] <- paste0("B,", value, ",3,")
    expect_error(read_qview_template(.integrity_template_file(bad), verbose = FALSE))
  }
})

test_that("well labels never truncate or silently recycle invalid indices", {
  expect_error(well_label(1.9, 2.9), "integer indices")
  expect_error(well_label(0, 1), "integer indices")
  expect_error(well_label(27, 1), "integer indices")
  expect_error(well_label("AA", 1), "single letters")
  expect_error(well_label(1:3, 1:2), "recycle exactly")
  expect_identical(well_label(integer(), integer()), character())
})

test_that("binary fragments cannot silently alter sample identity", {
  unicode <- charToRaw("Müller,Pixel Intensity (Replicate 1),A1,,100\n")
  expect_error(.qv_extract_report_lines(unicode), "fractured binary report text")
  control <- c(charToRaw("S1,Pixel Intensity (Replicate 1),A1,,10"),
               as.raw(0L), charToRaw("0\n"))
  expect_error(.qv_extract_report_lines(control), "bytes")
  metadata <- charToRaw("1 Q-View Project\nProject: Müller\n")
  expect_error(.qv_extract_metadata(metadata, "synthetic.Q-View"), "metadata project")
  header <- charToRaw("Well Group,Statistic,Well,Error Codes,Müller (ng/mL)\n")
  expect_error(.qv_extract_analyte_panel(header), "analyte header")
  intact <- "S1,Pixel Intensity (Replicate 1),A1,,100"
  recovered <- .qv_extract_report_lines(c(as.raw(0L), charToRaw(paste0("\n", intact, "\n"))))
  expect_identical(as.character(recovered), intact)
})

test_that("repeated binary metadata, panels, limits and models must agree", {
  literal <- charToRaw("1 Q-View Project\nProject: Study with Project: in its name\n")
  expect_identical(.qv_extract_metadata(literal, "synthetic.Q-View")$project,
                   "Study with Project: in its name")
  metadata <- charToRaw("1 Q-View Project\nProject: First\nProject: Second\n")
  expect_error(.qv_extract_metadata(metadata, "synthetic.Q-View"), "Ambiguous conflicting binary metadata")
  header <- "Well Group,Statistic,Well,Error Codes,X (ng/mL)"
  different <- sub("X ", "Y ", header, fixed = TRUE)
  literal_header <- charToRaw(paste0("Project: Note ", different, "\n", header, "\n"))
  expect_identical(.qv_extract_analyte_panel(literal_header)$analyte, "X")
  expect_error(.qv_extract_analyte_panel(charToRaw(paste(header, different, sep = "\n"))),
               "Ambiguous conflicting binary analyte headers")
  limits <- charToRaw(paste(header, "Lot,Limit of Detection,,,1", "Lot,Limit of Detection,,,2", sep = "\n"))
  expect_error(.qv_extract_analyte_panel(limits), "Ambiguous conflicting binary analyte limits")
  panel <- tibble::tibble(spot_number = 1L, analyte = "X", unit = "ng/mL")
  expect_error(.qv_extract_curve_fit(c(",Regression Model,,,4PL", ",Regression Model,,,5PL"), panel),
               "Ambiguous conflicting regression-model")
  same <- .qv_extract_curve_fit(rep(",Regression Model,,,4PL", 2L), panel)
  expect_identical(same$regression_model, "4PL")
})

test_that("binary point estimates and summary well lists retain assignments", {
  text <- paste("1 Q-View Project", "Project: Synthetic",
                "Well Group,Statistic,Well,Error Codes,X (ng/mL)",
                "S1,Reduced Concentration,A1,,< 5",
                'S2,Pixel Intensity Average,"A2, A3",,', sep = "\n")
  path <- withr::local_tempfile(fileext = ".Q-View")
  writeBin(charToRaw(text), path)
  q <- read_qview(path, verbose = FALSE)
  expect_identical(q$concentrations$statistic, "reduced")
  expect_identical(q$concentrations$flag, "<")
  expect_identical(q$plate_layout$sample_id[q$plate_layout$well %in% c("A1", "A2", "A3")], c("S1", "S2", "S2"))
  expect_identical(q$summary_statistics$flag, "missing")
})

test_that("normalized statistic identities cannot hide conflicting measurements", {
  rows <- c("S,Pixel Intensity (Replicate 1),A1,,10",
            "S,Pixel Intensity (Replicate 01),A1,,20")
  expect_error(read_qview_report(.integrity_report(rows), verbose = FALSE),
               "Ambiguous conflicting report records")
  same <- sub(",20$", ",10", rows)
  q <- read_qview_report(.integrity_report(same), verbose = FALSE)
  expect_identical(q$pixel_intensities$pixel_intensity, 10)
  expect_identical(q$pixel_intensities$replicate, 1L)
  expect_identical(q$pixel_intensities$statistic_label, "Pixel Intensity (Replicate 1)")
  expect_identical(q$report_csv[-1L], same)
  expect_error(read_qview_report(.integrity_report(c(
    "S,Pixel Intensity % CV,A1,,10",
    "S,Pixel Intensity Coefficient of Variation,A1,,20")), verbose = FALSE),
    "Ambiguous conflicting report records")
  different <- read_qview_report(.integrity_report(c(
    "S,Reduced Concentration Average,A1,,10",
    "S,Theoretical Concentration Average,A1,,20")), verbose = FALSE)
  expect_identical(different$concentrations$concentration, c(10, 20))
})

test_that("all repeated flat report limit sections must agree", {
  header <- "Well Group,Statistic,Well,Error Codes,X (ng/mL)"
  rows <- c("Lot,Limit of Detection,,,1", "S,Reduced Concentration,A1,,10",
            "", header, "Lot,Limit of Detection,,,9", "S,Reduced Concentration,A1,,10")
  expect_error(read_qview_report(.integrity_report(rows), verbose = FALSE),
               "Ambiguous conflicting report analyte limits")
  q <- read_qview_report(.integrity_report(sub(",9$", ",1", rows)), verbose = FALSE)
  expect_identical(q$analytes$lod, 1)
  expect_identical(q$concentrations$concentration, 10)
  rows[[5L]] <- ",Limit of Detection,,,1"
  expect_error(read_qview_report(.integrity_report(rows), verbose = FALSE),
               "Missing Assay/Lot section")
})

test_that("binary continuation cannot cross opaque source gaps", {
  prefix <- paste0("1 Q-View Project\n",
    "Well Group,Statistic,Well,Error Codes,X (ng/mL)\n")
  first <- "S,Pixel Intensity (Replicate 1),A1,,10\n"
  continuation <- ",Pixel Intensity (Replicate 2),A2,,20\n"
  path <- withr::local_tempfile(fileext = ".Q-View")
  writeBin(c(charToRaw(paste0(prefix, first)), as.raw(c(0L, 1L, 0L)),
             charToRaw(paste0("\n", continuation))), path)
  expect_error(read_qview(path, verbose = FALSE), "Missing sample group")
  writeBin(charToRaw(paste0(prefix, first, continuation)), path)
  q <- read_qview(path, verbose = FALSE)
  expect_identical(q$pixel_intensities$sample_id, c("S", "S"))
  expect_identical(q$pixel_intensities$pixel_intensity, c(10, 20))
  writeBin(c(charToRaw(paste0(prefix, first)), as.raw(c(0L, 1L, 0L)),
             charToRaw(paste0("\nT", continuation))), path)
  q <- read_qview(path, verbose = FALSE)
  expect_identical(q$pixel_intensities$sample_id, c("S", "T"))
  writeBin(c(charToRaw(paste0(prefix, "Lot,Limit of Detection,,,1\n")),
             as.raw(0L), charToRaw("\n,Lower Limit of Quantification,,,2\n")), path)
  expect_error(read_qview(path, verbose = FALSE), "Missing Assay/Lot section")
})
