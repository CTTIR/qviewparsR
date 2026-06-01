# Method tests using small synthetic qview objects (CI-safe).

# Minimal qview carrying just enough for the method under test.
.make_qview <- function(pi,
                        analytes = tibble::tibble(
                          spot_number = 1L, analyte = "Ba", unit = "ng/ml"),
                        well_groups = NULL,
                        plate_layout = NULL) {
  if (is.null(well_groups)) {
    grp <- unique(pi$well_group)
    well_groups <- tibble::tibble(
      well_group = grp, sample_id = grp,
      is_standard = TRUE, is_negative = FALSE,
      is_sample = FALSE, is_control = FALSE,
      well_type = factor("standard",
        levels = c("standard", "negative", "sample", "control")))
  }
  structure(list(
    metadata = list(project = "p", plate = "Plate 1", image = NA,
                    imager = NA, product = NA, qview_version = "3.13",
                    template = NA, report_created = NA),
    analytes = analytes,
    well_groups = well_groups,
    pixel_intensities = pi,
    summary_statistics = tibble::tibble(),
    concentrations = NULL,
    curve_fit = NULL,
    plate_layout = plate_layout
  ), class = "qview")
}

test_that("replicate_scatter tolerates duplicate well-group readings", {
  skip_if_not_installed("ggplot2")
  # well_group 'Cal 3' appears on three wells (C1 + H1 replicate 1, H2
  # replicate 2): this drove a list-column crash in pivot_wider.
  pi <- tibble::tibble(
    well_group = "Cal 3", sample_id = "Cal 3",
    well = c("C1", "H1", "H2"),
    replicate = c(1L, 1L, 2L),
    analyte = "C1q", unit = "ug/ml",
    pixel_intensity = c(54850, 17639, 16710),
    dilution = NA_real_
  )
  qv <- .make_qview(pi, analytes = tibble::tibble(
    spot_number = 1L, analyte = "C1q", unit = "ug/ml"))
  p <- plot(qv, type = "replicate_scatter")
  expect_s3_class(p, "ggplot")
  expect_silent(ggplot2::ggplot_build(p))
})

test_that("all three plot types build without error", {
  skip_if_not_installed("ggplot2")
  pi <- tibble::tibble(
    well_group = c("Cal 1", "Cal 1"), sample_id = "Cal 1",
    well = c("A1", "A2"), replicate = c(1L, 2L),
    analyte = "Ba", unit = "ng/ml",
    pixel_intensity = c(1000, 1100), dilution = NA_real_
  )
  pl <- tibble::tibble(
    plate_row = "A", plate_col = 1:2, well = c("A1", "A2"),
    well_group = "Cal 1", sample_id = "Cal 1",
    well_type = factor("standard",
      levels = c("standard", "negative", "sample", "control")),
    dilution = NA_real_)
  qv <- .make_qview(pi, plate_layout = pl)
  for (ty in c("plate_map", "intensity_heatmap", "replicate_scatter")) {
    p <- plot(qv, type = ty)
    expect_s3_class(p, "ggplot")
  }
})

test_that("print.qview returns its input invisibly", {
  pi <- tibble::tibble(
    well_group = "Cal 1", sample_id = "Cal 1", well = "A1",
    replicate = 1L, analyte = "Ba", unit = "ng/ml",
    pixel_intensity = 100, dilution = NA_real_)
  qv <- .make_qview(pi)
  expect_invisible(print(qv))                  # prints via cli, returns invisibly
  out <- withVisible(suppressMessages(print(qv)))
  expect_false(out$visible)
  expect_identical(out$value, qv)
})

test_that("as_tibble.qview returns the pixel-intensity table", {
  pi <- tibble::tibble(
    well_group = "Cal 1", sample_id = "Cal 1", well = "A1",
    replicate = 1L, analyte = "Ba", unit = "ng/ml",
    pixel_intensity = 100, dilution = NA_real_)
  qv <- .make_qview(pi)
  tb <- tibble::as_tibble(qv)
  expect_s3_class(tb, "tbl_df")
  expect_equal(nrow(tb), 1L)
})
