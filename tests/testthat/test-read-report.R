test_that("read_qview_report() parses the CSV fixture into a qview object", {
  path <- system.file("extdata", "example-report.csv", package = "qviewparsR")
  skip_if(path == "", "fixture not installed")
  qv <- read_qview_report(path, verbose = FALSE)

  expect_s3_class(qv, "qview")
  expect_true(is_qview(qv))
  expect_identical(qv$metadata$project, "Example ELISA project")
  expect_identical(qv$metadata$qview_version, "3.13")
  # container-only slots are empty for an export
  expect_equal(nrow(qv$manifest), 0L)
  expect_true(is.na(qv$metadata$container_version))
})

test_that("the plain 'Reduced Concentration' point estimate is captured", {
  path <- system.file("extdata", "example-report.csv", package = "qviewparsR")
  skip_if(path == "", "fixture not installed")
  qv <- read_qview_report(path, verbose = FALSE)

  expect_true("reduced" %in% qv$concentrations$statistic)
  # Ref Spot is not a quantified analyte
  expect_false("Ref Spot" %in% qv$concentrations$analyte)

  ba <- qv$concentrations[
    qv$concentrations$sample_id == "N12345" &
    qv$concentrations$analyte == "Ba", ]
  expect_equal(ba$statistic, "reduced")
  expect_equal(ba$concentration, 2.5)
  expect_true(is.na(ba$flag))
})

test_that("out-of-range cells are preserved with a flag, not dropped", {
  path <- system.file("extdata", "example-report.csv", package = "qviewparsR")
  skip_if(path == "", "fixture not installed")
  qv <- read_qview_report(path, verbose = FALSE)
  conc <- qv$concentrations
  expect_true("flag" %in% names(conc))

  lo <- conc[conc$sample_id == "N23456" & conc$analyte == "Ba", ]
  hi <- conc[conc$sample_id == "N23456" & conc$analyte == "Bb", ]
  expect_equal(lo$concentration, 0.31); expect_identical(lo$flag, "<")
  expect_equal(hi$concentration, 0.42); expect_identical(hi$flag, ">")

  inc <- conc[conc$well == "A2" & conc$analyte == "Ba", ]
  expect_true(is.na(inc$concentration))
  expect_identical(inc$flag, "incalculable")
})

test_that(".qv_parse_value_cell handles every value form", {
  expect_equal(.qv_parse_value_cell("1815.82")$value, 1815.82)
  expect_true(is.na(.qv_parse_value_cell("1815.82")$flag))
  expect_equal(.qv_parse_value_cell("< 52.50")$value, 52.5)
  expect_identical(.qv_parse_value_cell("< 52.50")$flag, "<")
  expect_equal(.qv_parse_value_cell("> 7700.00")$value, 7700)
  expect_identical(.qv_parse_value_cell("> 7700.00")$flag, ">")
  expect_true(is.na(.qv_parse_value_cell("Incalculable High")$value))
  expect_identical(.qv_parse_value_cell("Incalculable High")$flag, "incalculable")
  expect_true(is.na(.qv_parse_value_cell("")$value))
})

test_that("a non-report file is rejected", {
  tmp <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("not,a,qview,report", "1,2,3,4"), tmp)
  expect_error(read_qview_report(tmp, verbose = FALSE),
               "not a recognisable Q-View report export")
})

test_that("read_qview_report() reads the xlsx path when openxlsx2 is available", {
  skip_if_not_installed("openxlsx2")
  # round-trip the CSV fixture through xlsx and confirm identical concentrations
  csv <- system.file("extdata", "example-report.csv", package = "qviewparsR")
  skip_if(csv == "", "fixture not installed")
  qv_csv <- read_qview_report(csv, verbose = FALSE)

  m <- do.call(rbind, lapply(readLines(csv), function(l)
    qviewparsR:::.qv_split_csv_row(l)))
  xlsx <- withr::local_tempfile(fileext = ".xlsx")
  openxlsx2::write_xlsx(as.data.frame(m), xlsx, col_names = FALSE)
  qv_xlsx <- read_qview_report(xlsx, verbose = FALSE)

  expect_equal(qv_xlsx$concentrations$concentration,
               qv_csv$concentrations$concentration)
  expect_equal(qv_xlsx$concentrations$flag, qv_csv$concentrations$flag)
})

test_that("only 'Reduced Concentration' is captured as the reduced estimate", {
  # Theoretical / Backfit concentration rows must be dropped, not relabelled
  # 'reduced' (regression: they used to be injected into concentrations).
  tmp <- withr::local_tempfile(fileext = ".csv")
  writeLines(c(
    "Well Group,Statistic,Well,Error Codes,Ba (ng/mL)",
    "Cal 1,Reduced Concentration,A1,,98.5",
    "Cal 1,Theoretical Concentration,A1,,100.0",
    "N123,Backfit Concentration,B2,,55.0"), tmp)
  qv <- read_qview_report(tmp, verbose = FALSE)
  expect_setequal(qv$concentrations$statistic, "reduced")
  expect_equal(nrow(qv$concentrations), 1L)
  expect_equal(qv$concentrations$concentration, 98.5)
})

test_that("a header-only (truncated) export does not crash", {
  tmp <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("Project: X", "",
               "Well Group,Statistic,Well,Error Codes,Ba (ng/mL)"), tmp)
  qv <- read_qview_report(tmp, verbose = FALSE)
  expect_s3_class(qv, "qview")
  expect_null(qv$concentrations)
  expect_identical(qv$metadata$project, "X")
})

test_that("all-parameters exports populate pixel intensities and summaries", {
  tmp <- withr::local_tempfile(fileext = ".csv")
  writeLines(c(
    "Well Group,Statistic,Well,Error Codes,Ba (ng/mL),Ref Spot (N/A)",
    "N999 (1:50),Pixel Intensity (Replicate 1),A5,,1000,50",
    "N999 (1:50),Pixel Intensity (Replicate 2),A6,,1100,52",
    "N999 (1:50),Pixel Intensity Average,\"A5, A6\",,1050,51",
    "N999 (1:50),Reduced Concentration,A5,,12.3,50"), tmp)
  qv <- read_qview_report(tmp, verbose = FALSE)
  expect_equal(nrow(qv$pixel_intensities), 2L)   # two replicates (Ref Spot excluded)
  expect_equal(sort(qv$pixel_intensities$pixel_intensity), c(1000, 1100))
  expect_equal(nrow(qv$summary_statistics), 1L)  # the Average row
  expect_equal(qv$summary_statistics$value, 1050)
})

test_that("a (1:NN) dilution suffix is split from the sample id", {
  tmp <- withr::local_tempfile(fileext = ".csv")
  writeLines(c(
    "Well Group,Statistic,Well,Error Codes,Ba (ng/mL)",
    "N999 (1:50),Reduced Concentration,A5,,12.3"), tmp)
  qv <- read_qview_report(tmp, verbose = FALSE)
  expect_equal(qv$concentrations$dilution, 50)
  expect_identical(qv$concentrations$sample_id, "N999")
  expect_identical(qv$concentrations$well_group, "N999 (1:50)")
})

test_that("strip_prefix rewrites sample ids", {
  path <- system.file("extdata", "example-report.csv", package = "qviewparsR")
  skip_if(path == "", "fixture not installed")
  plain    <- read_qview_report(path, strip_prefix = FALSE, verbose = FALSE)
  stripped <- read_qview_report(path, strip_prefix = TRUE,  verbose = FALSE)
  expect_false(identical(plain$concentrations$sample_id,
                         stripped$concentrations$sample_id))
  expect_equal(stripped$concentrations$sample_id,
               strip_qview_prefix(plain$concentrations$sample_id))
})

test_that("verbose prints a summary and quiet stays silent", {
  path <- system.file("extdata", "example-report.csv", package = "qviewparsR")
  skip_if(path == "", "fixture not installed")
  expect_message(read_qview_report(path, verbose = TRUE), "Parsed report export")
  expect_message(read_qview_report(path, verbose = FALSE), NA)
})

test_that("analyte limits and the assay-control range are extracted", {
  path <- system.file("extdata", "example-report.csv", package = "qviewparsR")
  skip_if(path == "", "fixture not installed")
  qv <- read_qview_report(path, verbose = FALSE)
  ba <- qv$analytes[qv$analytes$analyte == "Ba", ]
  expect_equal(ba$lod, 0.047)
  expect_equal(ba$lloq, 0.310)
  expect_equal(ba$uloq, 30.80)
  expect_true(is.na(ba$assay_control_low))  # CSV fixture has no control-range rows

  tmp <- withr::local_tempfile(fileext = ".csv")
  writeLines(c(
    "Well Group,Statistic,Well,Error Codes,Ba (ng/mL)",
    "Assay,Assay Control Range Low,,,1.5",
    "Assay,Assay Control Range High,,,25.0",
    "Cal 1,Reduced Concentration,A1,,10"), tmp)
  qc <- read_qview_report(tmp, verbose = FALSE)
  expect_equal(qc$analytes$assay_control_low, 1.5)
  expect_equal(qc$analytes$assay_control_high, 25.0)
})
