# Guard / empty / abort branches of the S3 methods and plot helpers in
# methods-qview.R that the populated-fixture tests do not reach.

.qview_with_pi <- function(pi, analytes = tibble::tibble(
                             spot_number = 1L, analyte = "Ba", unit = "ng/ml"),
                           well_groups = NULL) {
  if (is.null(well_groups)) {
    grp <- unique(pi$well_group)
    if (length(grp) == 0L) grp <- character()
    well_groups <- tibble::tibble(
      well_group = grp, sample_id = grp,
      is_standard = TRUE, is_negative = FALSE,
      is_sample = FALSE, is_control = FALSE,
      well_type = factor(rep("standard", length(grp)),
        levels = c("standard", "negative", "sample", "control")))
  }
  structure(list(
    metadata = list(project = "p", plate = "Plate 1", qview_version = "3.13"),
    analytes = analytes, well_groups = well_groups,
    pixel_intensities = pi, summary_statistics = tibble::tibble(),
    concentrations = NULL, curve_fit = NULL,
    plate_layout = tibble::tibble()), class = "qview")
}

.empty_pi <- function() {
  tibble::tibble(well_group = character(), sample_id = character(),
                 well = character(), replicate = integer(),
                 analyte = character(), unit = character(),
                 pixel_intensity = numeric(), dilution = numeric())
}

test_that("summary.qview returns an empty tibble when there is no data", {
  qv <- .qview_with_pi(.empty_pi())
  s <- summary(qv)
  # The no-data path returns a plain typed tibble (the qview_summary class
  # is only attached on the populated path -- snapshot the behaviour as-is).
  expect_s3_class(s, "tbl_df")
  expect_equal(nrow(s), 0L)
  expect_named(s, c("well_type", "analyte", "unit", "n",
                    "mean", "sd", "cv", "min", "max"))
})

test_that("print.qview_summary prints and returns invisibly", {
  pi <- tibble::tibble(
    well_group = "Cal 1", sample_id = "Cal 1", well = c("A1", "A2"),
    replicate = c(1L, 2L), analyte = "Ba", unit = "ng/ml",
    pixel_intensity = c(100, 110), dilution = NA_real_)
  s <- summary(.qview_with_pi(pi))
  expect_s3_class(s, "qview_summary")
  expect_invisible(print(s))                       # exercises print.qview_summary
  out <- utils::capture.output(print(s))
  expect_true(any(grepl("well_type", out)))        # the tibble body reaches stdout
})

test_that("plot.qview aborts cleanly when ggplot2 is unavailable", {
  pi <- tibble::tibble(
    well_group = "Cal 1", sample_id = "Cal 1", well = "A1",
    replicate = 1L, analyte = "Ba", unit = "ng/ml",
    pixel_intensity = 100, dilution = NA_real_)
  qv <- .qview_with_pi(pi)
  testthat::local_mocked_bindings(
    requireNamespace = function(package, ...) {
      if (identical(package, "ggplot2")) FALSE else TRUE
    }, .package = "base")
  expect_error(plot(qv), "requires the .*ggplot2.* package")
})

test_that("intensity heatmap aborts when no replicate-1 readings exist", {
  testthat::skip_if_not_installed("ggplot2")
  pi <- tibble::tibble(
    well_group = "Cal 1", sample_id = "Cal 1", well = "A1",
    replicate = 2L, analyte = "Ba", unit = "ng/ml",
    pixel_intensity = 100, dilution = NA_real_)
  expect_error(plot(.qview_with_pi(pi), type = "intensity_heatmap"),
               "No replicate-1")
})

test_that("replicate scatter aborts with no readings and with only one replicate", {
  testthat::skip_if_not_installed("ggplot2")
  expect_error(plot(.qview_with_pi(.empty_pi()), type = "replicate_scatter"),
               "No replicate")
  one_rep <- tibble::tibble(
    well_group = "Cal 1", sample_id = "Cal 1", well = "A1",
    replicate = 1L, analyte = "Ba", unit = "ng/ml",
    pixel_intensity = 100, dilution = NA_real_)
  expect_error(plot(.qview_with_pi(one_rep), type = "replicate_scatter"),
               "replicate 1 and replicate 2")
})

test_that(".qv_plot_summary returns NULL when the summary is empty", {
  testthat::skip_if_not_installed("ggplot2")
  expect_null(.qv_plot_summary(.qview_with_pi(.empty_pi())))
})

test_that(".qv_plot_distribution returns NULL when only Ref Spot remains", {
  testthat::skip_if_not_installed("ggplot2")
  pi <- tibble::tibble(
    well_group = "Cal 1", sample_id = "Cal 1", well = "A1",
    replicate = 1L, analyte = "Ref Spot", unit = "N/A",
    pixel_intensity = 100, dilution = NA_real_)
  expect_null(.qv_plot_distribution(.qview_with_pi(pi)))
})

test_that(".qv_plot_overview aborts without ggplot2 or patchwork", {
  qv <- .qview_with_pi(.empty_pi())
  testthat::local_mocked_bindings(
    requireNamespace = function(package, ...) FALSE, .package = "base")
  expect_error(.qv_plot_overview(qv), "ggplot2")
  testthat::local_mocked_bindings(
    requireNamespace = function(package, ...) identical(package, "ggplot2"),
    .package = "base")
  expect_error(.qv_plot_overview(qv), "patchwork")
})

test_that(".qv_blank_plot returns invisibly when ggplot2 is unavailable", {
  testthat::local_mocked_bindings(
    requireNamespace = function(package, ...) FALSE, .package = "base")
  expect_invisible(.qv_blank_plot("nothing"))
})

test_that(".qv_metadata_kv copes with zero-length metadata entries", {
  qv <- .qview_with_pi(.empty_pi())
  qv$metadata <- list(project = character(0), plate = "Plate 1")
  kv <- .qv_metadata_kv(qv)
  expect_s3_class(kv, "tbl_df")
  expect_true(is.na(kv$value[kv$field == "project"]))
})
