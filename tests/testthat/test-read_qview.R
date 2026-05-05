# Tests for read_qview() rely on the reference fixture if present;
# otherwise they skip cleanly so CI without the file still passes.
.find_fixture <- function() {
  candidates <- c(
    file.path(".data", "20230316_ELISA-plate-7_panel-1.Q-View"),
    file.path("..", "..", ".data", "20230316_ELISA-plate-7_panel-1.Q-View"),
    file.path(".data", "20230316_ELISA-plate-7_panel-1",
              "20230316_ELISA-plate-7_panel-1.Q-View"),
    file.path("..", "..", ".data", "20230316_ELISA-plate-7_panel-1",
              "20230316_ELISA-plate-7_panel-1.Q-View"),
    Sys.getenv("QVIEWPARSR_QVIEW_FIXTURE",
               unset = Sys.getenv("COMPARSR_QVIEW_FIXTURE", unset = ""))
  )
  for (p in candidates) if (nzchar(p) && file.exists(p)) return(p)
  NA_character_
}
fixture <- .find_fixture()
fixture_available <- !is.na(fixture)


test_that("read_qview returns a structured qview object", {
  skip_if_not(fixture_available, "no Q-View fixture available")
  qv <- read_qview(fixture, verbose = FALSE)
  expect_s3_class(qv, "qview")
  expect_setequal(names(qv),
    c("metadata", "manifest", "segments", "analytes", "well_groups",
      "pixel_intensities", "summary_statistics", "concentrations",
      "curve_fit", "report_csv", "plate_layout"))
})

test_that("metadata is populated", {
  skip_if_not(fixture_available, "no Q-View fixture available")
  qv <- read_qview(fixture, verbose = FALSE)
  expect_true(nzchar(qv$metadata$project))
  expect_true(nzchar(qv$metadata$plate))
  expect_true(nzchar(qv$metadata$qview_version))
})

test_that("analyte panel parses dynamically with units", {
  skip_if_not(fixture_available, "no Q-View fixture available")
  qv <- read_qview(fixture, verbose = FALSE)
  expect_true(nrow(qv$analytes) >= 1L)
  expect_true(all(c("spot_number", "analyte", "unit") %in%
                  colnames(qv$analytes)))
  expect_type(qv$analytes$analyte, "character")
})

test_that("well_groups carry boolean type flags", {
  skip_if_not(fixture_available, "no Q-View fixture available")
  qv <- read_qview(fixture, verbose = FALSE)
  expect_true(all(c("is_standard", "is_negative", "is_sample",
                    "is_control") %in% colnames(qv$well_groups)))
  expect_true(any(qv$well_groups$is_sample))
})

test_that("pixel intensities live in the 16-bit range", {
  skip_if_not(fixture_available, "no Q-View fixture available")
  qv <- read_qview(fixture, verbose = FALSE)
  if (nrow(qv$pixel_intensities) > 0L) {
    expect_true(all(qv$pixel_intensities$pixel_intensity >= 0,
                    na.rm = TRUE))
    expect_true(all(qv$pixel_intensities$pixel_intensity <= 65535,
                    na.rm = TRUE))
  }
})

test_that("strip_prefix never produces ICal / GLow / HHigh / N-prefixed IDs", {
  skip_if_not(fixture_available, "no Q-View fixture available")
  qv <- read_qview(fixture, strip_prefix = TRUE, verbose = FALSE)
  ids <- qv$well_groups$sample_id
  expect_false(any(grepl("^ICal\\b", ids)))
  expect_false(any(ids %in% c("GLow", "HHigh")))
  # Synthetic vector roundtrip is the exhaustive check; this just
  # confirms the option flows through read_qview.
  expect_equal(strip_qview_prefix(c("ICal 1", "GLow", "HHigh", "NFD1")),
               c("Cal 1", "Low", "High", "FD1"))
})

test_that("plate_layout covers a full plate of wells", {
  skip_if_not(fixture_available, "no Q-View fixture available")
  qv <- read_qview(fixture, verbose = FALSE)
  expect_true(nrow(qv$plate_layout) >= 96L)
  expect_true(all(c("well", "plate_row", "plate_col") %in%
                  colnames(qv$plate_layout)))
})

test_that("read_qview rejects non-Q-View files", {
  bad <- tempfile(fileext = ".bin")
  writeBin(charToRaw("Not a Q-View file."), bad)
  expect_error(read_qview(bad, verbose = FALSE),
               "not a valid Q-View")
})

test_that("read_qview detects the magic header on the fixture", {
  skip_if_not(fixture_available, "no Q-View fixture available")
  expect_true(.qv_is_qview_binary(fixture))
})
