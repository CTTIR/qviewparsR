# Export writers, exercised with a small synthetic qview (CI-safe).

.export_qview <- function() {
  pi <- tibble::tibble(
    well_group = c("Cal 1", "Cal 1"), sample_id = "Cal 1",
    well = c("A1", "A2"), replicate = c(1L, 2L),
    analyte = "Ba", unit = "ng/ml",
    pixel_intensity = c(1000, 1100), dilution = NA_real_)
  structure(list(
    metadata = list(project = "p", plate = "Plate 1", image = NA_character_,
                    imager = NA, product = NA, user = NA,
                    report_created = NA, qview_version = "3.13",
                    template = NA, container_version = "1",
                    file_path = "x", parsed_at = "t"),
    manifest = tibble::tibble(name = "a", size_bytes = 1L, parent = NA_character_),
    segments = tibble::tibble(segment = 1L, start = 1L, end = 2L, size = 2L),
    analytes = tibble::tibble(spot_number = 1L, analyte = "Ba", unit = "ng/ml",
                              lod = NA_real_, lloq = NA_real_, uloq = NA_real_,
                              assay_control_low = NA_real_,
                              assay_control_high = NA_real_),
    well_groups = tibble::tibble(
      well_group = "Cal 1", sample_id = "Cal 1", is_standard = TRUE,
      is_negative = FALSE, is_sample = FALSE, is_control = FALSE,
      well_type = factor("standard",
        levels = c("standard", "negative", "sample", "control"))),
    pixel_intensities = pi,
    summary_statistics = tibble::tibble(
      well_group = "Cal 1", sample_id = "Cal 1", statistic = "average",
      analyte = "Ba", value = 1050, unit = "ng/ml"),
    concentrations = NULL,
    curve_fit = tibble::tibble(spot_number = 1L, analyte = "Ba",
                               regression_model = "Qualitative"),
    report_csv = c("a,b", "c,d"),
    plate_layout = tibble::tibble(
      plate_row = "A", plate_col = 1:2, well = c("A1", "A2"),
      well_group = "Cal 1", sample_id = "Cal 1",
      well_type = factor("standard",
        levels = c("standard", "negative", "sample", "control")),
      dilution = NA_real_)
  ), class = "qview")
}

test_that("write_qview_rds round-trips losslessly", {
  qv <- .export_qview()
  d <- withr::local_tempdir()
  out <- file.path(d, "x.rds")
  expect_invisible(write_qview_rds(qv, out))
  qv2 <- readRDS(out)
  expect_true(is_qview(qv2))
  expect_equal(qv2$pixel_intensities, qv$pixel_intensities)
})

test_that("write_qview_rds refuses to overwrite unless asked", {
  qv <- .export_qview()
  d <- withr::local_tempdir()
  out <- file.path(d, "x.rds")
  write_qview_rds(qv, out)
  expect_error(write_qview_rds(qv, out), "already exists")
  expect_invisible(write_qview_rds(qv, out, overwrite = TRUE))
})

test_that("write_qview_csv writes one CSV per non-empty table", {
  qv <- .export_qview()
  d <- withr::local_tempdir()
  expect_invisible(write_qview_csv(qv, d))
  files <- list.files(d, pattern = "\\.csv$")
  expect_true(all(c("metadata.csv", "analytes.csv", "well_groups.csv",
                    "plate_layout.csv", "pixel_intensities.csv",
                    "summary_statistics.csv", "curve_fit.csv",
                    "manifest.csv") %in% files))
  # concentrations is NULL -> no file
  expect_false("concentrations.csv" %in% files)
  pi <- readr::read_csv(file.path(d, "pixel_intensities.csv"),
                        show_col_types = FALSE)
  expect_equal(nrow(pi), 2L)
})

test_that("write_qview_csv includes a template when supplied", {
  qv <- .export_qview()
  tmpl <- tibble::tibble(well = "A1", plate_row = "A", plate_col = 1L,
                         sample_id = "Cal 1", group_type = "calibrator",
                         dilution = NA_real_)
  d <- withr::local_tempdir()
  write_qview_csv(qv, d, template = tmpl)
  expect_true(file.exists(file.path(d, "template.csv")))
})

test_that("write_qview_xlsx writes a workbook and guards overwrite", {
  skip_if_not_installed("openxlsx2")
  qv <- .export_qview()
  d <- withr::local_tempdir()
  out <- file.path(d, "x.xlsx")
  expect_invisible(write_qview_xlsx(qv, out))
  expect_true(file.exists(out))
  expect_error(write_qview_xlsx(qv, out), "already exists")
  expect_invisible(write_qview_xlsx(qv, out, overwrite = TRUE))
  sheets <- openxlsx2::wb_get_sheet_names(openxlsx2::wb_load(out))
  expect_true(all(c("metadata", "analytes", "pixel_intensities") %in% sheets))
})

test_that("deprecated writers warn but still produce output", {
  qv <- .export_qview()
  d <- withr::local_tempdir()
  expect_warning(qview_to_xlsx(qv, file.path(d, "d.xlsx")), "deprecated")
  expect_true(file.exists(file.path(d, "d.xlsx")))
  expect_warning(qview_to_csv_dir(qv, file.path(d, "depcsv")), "deprecated")
  expect_true(file.exists(file.path(d, "depcsv", "analytes.csv")))
})

test_that("export writers reject non-qview input", {
  d <- withr::local_tempdir()
  expect_error(write_qview_rds(list(), file.path(d, "x.rds")),
               "must be a .*qview")
  expect_error(write_qview_csv(list(), d), "must be a .*qview")
  expect_error(write_qview_xlsx(list(), file.path(d, "x.xlsx")),
               "must be a .*qview")
})
