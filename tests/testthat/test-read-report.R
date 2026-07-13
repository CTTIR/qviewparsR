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
