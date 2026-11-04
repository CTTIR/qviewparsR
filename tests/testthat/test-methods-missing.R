.method_measurements <- function() {
  qv <- read_qview(system.file("extdata", "example.Q-View",
                              package = "qviewparsR"), verbose = FALSE)
  qv$pixel_intensities <- tibble::tibble(
    well_group = "S1", sample_id = "S1", well = "A1", replicate = 1L,
    analyte = "A", unit = "u", pixel_intensity = c(2, 4, 100, NA, NA),
    flag = c(NA, NA, "<", "missing", "incalculable")
  )
  qv$well_groups <- tibble::tibble(well_group = "S1", well_type = "sample")
  qv
}

test_that("summary distinguishes observations from bounds and missing values", {
  qv <- .method_measurements()
  before <- qv
  s <- summary(qv)
  expect_equal(s$n, 5L)
  expect_equal(s$n_observed, 2L)
  expect_equal(s$n_missing, 1L)
  expect_equal(s$n_censored, 2L)
  expect_equal(s$mean, 3)
  expect_equal(s$sd, sqrt(2))
  expect_equal(s$cv, sqrt(2) / 3)
  expect_equal(c(s$min, s$max), c(2, 4))
  expect_identical(qv, before)
})

test_that("all missing and single observed groups have defined statistics", {
  qv <- .method_measurements()
  qv$pixel_intensities <- qv$pixel_intensities[3:5, ]
  s <- summary(qv)
  expect_equal(s$n_observed, 0L)
  expect_true(all(is.na(unlist(s[c("mean", "sd", "cv", "min", "max")]))))
  expect_false(any(is.nan(unlist(s[c("mean", "sd", "cv", "min", "max")]))))
  qv$pixel_intensities <- .method_measurements()$pixel_intensities[1, ]
  s <- summary(qv)
  expect_equal(s$mean, 2)
  expect_true(is.na(s$sd))
  expect_true(is.na(s$cv))
  qv$well_groups <- rbind(qv$well_groups, qv$well_groups)
  expect_error(summary(qv), "identities must be unique")
})

test_that("numeric plots exclude censored bounds without changing source data", {
  skip_if_not_installed("ggplot2")
  qv <- .method_measurements()
  before <- qv
  p <- .qv_plot_distribution(qv)
  expect_equal(sort(p$data$pixel_intensity), c(2, 4))
  p <- .qv_plot_intensity_heatmap(qv)
  expect_equal(p$data$pixel_intensity, c(2, 4, NA, NA, NA))
  qv$concentrations <- tibble::tibble(
    well_group = "S1", analyte = "A", concentration = c(5, 6),
    flag = c("<", NA_character_)
  )
  expect_equal(.qv_plot_concentrations(qv)$data$concentration, 6)
  qv$concentrations <- qv$concentrations[1, ]
  expect_null(.qv_plot_concentrations(qv))
  expect_identical(qv$pixel_intensities, before$pixel_intensities)
})


test_that("overview can fall back when no observed replicate pair exists", {
  qv <- .method_measurements()
  qv$pixel_intensities <- qv$pixel_intensities[3:5, ]
  expect_null(.qv_plot_replicate_scatter(qv, allow_empty = TRUE))
  expect_error(.qv_plot_replicate_scatter(qv), "No replicate")
  qv$pixel_intensities <- .method_measurements()$pixel_intensities[1, ]
  expect_null(.qv_plot_replicate_scatter(qv, allow_empty = TRUE))
  expect_error(.qv_plot_replicate_scatter(qv), "Need replicate")
})


test_that("overview panels omit groups without observations or complete pairs", {
  skip_if_not_installed("ggplot2")
  qv <- .method_measurements()
  qv$pixel_intensities <- qv$pixel_intensities[3:5, ]
  expect_null(.qv_plot_summary(qv))
  qv$pixel_intensities <- .method_measurements()$pixel_intensities[1:2, ]
  qv$pixel_intensities$well_group <- c("S1", "S2")
  qv$pixel_intensities$replicate <- 1:2
  expect_null(.qv_plot_replicate_scatter(qv, allow_empty = TRUE))
  expect_error(.qv_plot_replicate_scatter(qv), "No complete observed replicate pairs")
  pair <- qv$pixel_intensities[1, ]
  pair$replicate <- 2L
  pair$pixel_intensity <- 3
  qv$pixel_intensities <- rbind(qv$pixel_intensities, pair)
  p <- .qv_plot_replicate_scatter(qv)
  expect_equal(nrow(p$data), 1L)
  expect_equal(c(p$data$rep_1, p$data$rep_2), c(2, 3))
  expect_warning(ggplot2::ggplot_build(p), NA)
})
