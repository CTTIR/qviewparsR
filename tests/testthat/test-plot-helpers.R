# Tests for the internal per-slot plot helpers used by the Shiny app, plus
# the publication overview. Synthetic qview, so CI-safe (ggplot2 gated).

.plot_qview <- function() {
  lv <- c("standard", "negative", "sample", "control")
  analytes <- tibble::tibble(
    spot_number = 1:2, analyte = c("Ba", "Bb"), unit = c("ng/ml", "ug/ml"))
  pi <- tibble::tibble(
    well_group = rep(c("Cal 1", "S1"), each = 4L),
    sample_id  = rep(c("Cal 1", "S1"), each = 4L),
    well       = c("A1", "A1", "A2", "A2", "A3", "A3", "A4", "A4"),
    replicate  = rep(c(1L, 1L, 2L, 2L), 2L),
    analyte    = rep(c("Ba", "Bb"), 4L),
    unit       = rep(c("ng/ml", "ug/ml"), 4L),
    pixel_intensity = c(1000, 2000, 1100, 2100, 500, 600, 550, 650),
    dilution   = NA_real_)
  wg <- tibble::tibble(
    well_group = c("Cal 1", "S1"), sample_id = c("Cal 1", "S1"),
    is_standard = c(TRUE, FALSE), is_negative = FALSE,
    is_sample = c(FALSE, TRUE), is_control = FALSE,
    well_type = factor(c("standard", "sample"), levels = lv))
  pl <- tibble::tibble(
    plate_row = "A", plate_col = 1:4,
    well = c("A1", "A2", "A3", "A4"),
    well_group = c("Cal 1", "Cal 1", "S1", "S1"),
    sample_id = c("Cal 1", "Cal 1", "S1", "S1"),
    well_type = factor(c("standard", "standard", "sample", "sample"),
                       levels = lv),
    dilution = NA_real_)
  conc <- tibble::tibble(
    well_group = "S1", sample_id = "S1", well = "A3", replicate = 1L,
    statistic = "replicate", analyte = c("Ba", "Bb"),
    unit = c("ng/ml", "ug/ml"), concentration = c(12.3, 0.45),
    dilution = NA_real_)
  cf <- tibble::tibble(spot_number = 1:2, analyte = c("Ba", "Bb"),
                       regression_model = c("4PL", "Qualitative"))
  structure(list(
    metadata = list(project = "p", plate = "Plate 1",
                    image = "img (1 Jan 2023)", qview_version = "3.13"),
    analytes = analytes, well_groups = wg, pixel_intensities = pi,
    summary_statistics = tibble::tibble(), concentrations = conc,
    curve_fit = cf, plate_layout = pl), class = "qview")
}

test_that("per-slot plot helpers return ggplot objects when populated", {
  skip_if_not_installed("ggplot2")
  qv <- .plot_qview()
  helpers <- list(
    .qv_plot_analytes, .qv_plot_well_groups, .qv_plot_summary,
    .qv_plot_concentrations, .qv_plot_curve_fit, .qv_plot_distribution)
  for (h in helpers) {
    p <- h(qv)
    expect_s3_class(p, "ggplot")
    expect_silent(ggplot2::ggplot_build(p))
  }
  tmpl <- tibble::tibble(well = c("A1", "A2"), plate_row = "A",
                         plate_col = 1:2, sample_id = c("Cal 1", "Cal 1"),
                         group_type = "calibrator", dilution = NA_real_)
  expect_s3_class(.qv_plot_template(tmpl), "ggplot")
})

test_that("per-slot plot helpers return NULL on empty input", {
  skip_if_not_installed("ggplot2")
  empty <- structure(list(
    analytes = tibble::tibble(), well_groups = tibble::tibble(),
    pixel_intensities = tibble::tibble(), concentrations = NULL,
    curve_fit = NULL), class = "qview")
  expect_null(.qv_plot_analytes(empty))
  expect_null(.qv_plot_well_groups(empty))
  expect_null(.qv_plot_concentrations(empty))
  expect_null(.qv_plot_curve_fit(empty))
  expect_null(.qv_plot_distribution(empty))
  expect_null(.qv_plot_template(NULL))
})

test_that("the publication overview assembles a patchwork", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("patchwork")
  qv <- .plot_qview()
  p <- .qv_plot_overview(qv)
  expect_s3_class(p, "patchwork")
  grDevices::pdf(NULL)                       # render to a null device, no Rplots.pdf
  withr::defer(grDevices::dev.off())
  expect_silent(print(p))
})

test_that(".qv_blank_plot and .qv_metadata_kv behave", {
  skip_if_not_installed("ggplot2")
  expect_s3_class(.qv_blank_plot("nothing here"), "ggplot")
  kv <- .qv_metadata_kv(.plot_qview())
  expect_s3_class(kv, "tbl_df")
  expect_named(kv, c("field", "value"))
  expect_true("project" %in% kv$field)
})
