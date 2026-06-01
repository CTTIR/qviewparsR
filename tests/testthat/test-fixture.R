# End-to-end tests against the small synthetic .Q-View shipped in
# inst/extdata/. Unlike the .data-gated tests these run everywhere,
# including CRAN and CI, and back the runnable examples.

fixture <- system.file("extdata", "example.Q-View", package = "qviewparsR")

test_that("the bundled example parses into a complete qview object", {
  qv <- read_qview(fixture, verbose = FALSE)
  expect_s3_class(qv, "qview")
  expect_setequal(names(qv),
    c("metadata", "manifest", "segments", "analytes", "well_groups",
      "pixel_intensities", "summary_statistics", "concentrations",
      "curve_fit", "report_csv", "plate_layout"))
  expect_equal(qv$metadata$project, "Example ELISA project")
  expect_equal(qv$metadata$qview_version, "3.13")
  expect_equal(qv$metadata$template, "example-template")
})

test_that("analyte panel carries units and detection limits", {
  qv <- read_qview(fixture, verbose = FALSE)
  a <- qv$analytes
  expect_equal(a$analyte, c("Ba", "Bb", "Ref Spot"))
  expect_equal(a$unit, c("ng/ml", "ug/ml", "N/A"))
  ba <- a[a$analyte == "Ba", ]
  expect_equal(ba$uloq, 18.91)
  expect_equal(ba$lloq, 0.26)     # continuation rows must be captured ...
  expect_equal(ba$lod,  0.065)    # ... from the Lot section, not Assay
  bb <- a[a$analyte == "Bb", ]
  expect_equal(bb$lod, 0.00051)
  # assay control range sits on the Ref Spot column
  rs <- a[a$analyte == "Ref Spot", ]
  expect_equal(rs$assay_control_low, 5000)
  expect_equal(rs$assay_control_high, 65535)
})

test_that("well groups are classified by type", {
  qv <- read_qview(fixture, verbose = FALSE)
  wg <- qv$well_groups
  type <- function(g) as.character(wg$well_type[wg$well_group == g])
  expect_equal(type("ICal 1"), "standard")
  expect_equal(type("GLow"),   "negative")
  expect_equal(type("HHigh"),  "control")
  expect_equal(type("N12345"), "sample")
})

test_that("pixel intensities are long-format and well-keyed", {
  qv <- read_qview(fixture, verbose = FALSE)
  pi <- qv$pixel_intensities
  expect_equal(nrow(pi), 20L)          # 5 groups x 2 analytes x 2 reps
  expect_false("Ref Spot" %in% pi$analyte)
  v <- function(w, a) pi$pixel_intensity[pi$well == w & pi$analyte == a]
  expect_equal(v("A1", "Ba"), 8671)
  expect_equal(v("A2", "Bb"), 23848)
  expect_true(all(pi$pixel_intensity >= 0 & pi$pixel_intensity <= 65535))
})

test_that("concentrations and curve fit are recovered", {
  qv <- read_qview(fixture, verbose = FALSE)
  expect_false(is.null(qv$concentrations))
  expect_equal(qv$concentrations$concentration[
    qv$concentrations$well == "A3" & qv$concentrations$analyte == "Ba"], 2.5)
  expect_equal(qv$curve_fit$regression_model[qv$curve_fit$analyte == "Ba"],
               "4PL")
})

test_that("strip_prefix flows through read_qview", {
  qv <- read_qview(fixture, strip_prefix = TRUE, verbose = FALSE)
  ids <- unique(qv$well_groups$sample_id)
  expect_true("Cal 1" %in% ids)
  expect_true("Low" %in% ids)
  expect_true("High" %in% ids)
  expect_true("12345" %in% ids)
  expect_false(any(grepl("^ICal|^GLow|^HHigh|^N[0-9]", ids)))
})

test_that("plate_layout is one row per well with no duplicates", {
  qv <- read_qview(fixture, verbose = FALSE)
  expect_false(any(duplicated(qv$plate_layout$well)))
  expect_true(all(c("A1", "A2", "G1", "H2", "A3") %in% qv$plate_layout$well))
})

test_that("methods and exporters work on the bundled example", {
  skip_if_not_installed("ggplot2")
  qv <- read_qview(fixture, verbose = FALSE)
  expect_true(is_qview(qv))
  expect_s3_class(tibble::as_tibble(qv), "tbl_df")
  expect_s3_class(summary(qv), "qview_summary")
  for (ty in c("plate_map", "intensity_heatmap", "replicate_scatter")) {
    expect_s3_class(plot(qv, type = ty), "ggplot")
  }
  d <- withr::local_tempdir()
  expect_invisible(write_qview_rds(qv, file.path(d, "x.rds")))
  expect_invisible(write_qview_csv(qv, file.path(d, "csv")))
  expect_true(file.exists(file.path(d, "csv", "pixel_intensities.csv")))
})
