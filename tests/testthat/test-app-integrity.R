.app_integrity_skips <- function() {
  for (pkg in c("shiny", "bslib", "DT", "ggplot2", "patchwork", "withr")) {
    testthat::skip_if_not_installed(pkg)
  }
}

.app_integrity_fixture <- function() {
  system.file("extdata", "example.Q-View", package = "qviewparsR",
              mustWork = TRUE)
}

test_that("upload limits refuse nonfinite sizes before changing options", {
  skip_if_not_installed("shiny")
  local_mocked_bindings(runApp = function(...) stop("Unexpected app launch"),
                        .package = "shiny")
  before <- getOption("shiny.maxRequestSize")
  for (value in list(Inf, NA_real_, NaN, .Machine$double.xmax, 0, -1,
                    numeric(), c(1, 2), "512", 1 + 1i)) {
    expect_error(qview_app(value), "max_upload_mb")
    expect_identical(getOption("shiny.maxRequestSize"), before)
  }
  .app_integrity_skips()
  seen <- NULL
  local_mocked_bindings(runApp = function(...) {
    seen <<- getOption("shiny.maxRequestSize")
    stop("startup failure")
  }, .package = "shiny")
  expect_error(qview_app(64), "startup failure")
  expect_equal(seen, 64 * 1024^2)
  expect_identical(getOption("shiny.maxRequestSize"), before)
})

test_that("plot errors remain bounded and the same session recovers", {
  .app_integrity_skips()
  qv <- read_qview(.app_integrity_fixture(), verbose = FALSE)
  original <- .qv_plot_overview
  calls <- 0L
  fail <- TRUE
  local_mocked_bindings(.qv_plot_overview = function(qv) {
    calls <<- calls + 1L
    # Bound the baseline countercheck: a reactive loop cannot hang this test.
    if (fail && calls <= 3L) stop("overview dependency unavailable")
    original(qv)
  })
  shiny::testServer(.qv_app_server, {
    state$qv <- qv
    session$setInputs(plot_type = "plate_map")
    expect_null(rx_overview())
    session$flushReact()
    expect_equal(calls, 1L)
    expect_equal(sum(grepl("overview dependency unavailable", state$log)), 1L)
    expect_match(output$status, "Overview plot error")
    for (i in seq_len(105)) log_msg("bounded status event ", i)
    expect_lte(length(state$log), 100L)
    expect_match(tail(state$log, 1), "105$")
    fail <<- FALSE
    recovered <- qv
    recovered$metadata$project <- "Recovered synthetic project"
    state$qv <- recovered
    session$flushReact()
    expect_false(is.null(rx_overview()))
    expect_equal(calls, 2L)
  })
})

test_that("changed parsing inputs invalidate old downloads and retain provenance", {
  .app_integrity_skips()
  path <- .app_integrity_fixture()
  bad <- withr::local_tempfile(fileext = ".Q-View")
  writeBin(charToRaw("not a Q-View container"), bad)
  template <- system.file("extdata", "example-template.csv", package = "qviewparsR")
  shiny::testServer(.qv_app_server, {
    session$setInputs(f_qview = data.frame(name = "source-A.Q-View", datapath = path),
                      opt_strip = FALSE, btn_parse = 1)
    expect_identical(state$qv$metadata$upload_file, "source-A.Q-View")
    expect_identical(state$qv$metadata$strip_prefix, FALSE)
    expect_identical(state$qv$metadata$file_path, normalizePath(path))
    expect_match(output$status, "source-A.Q-View", fixed = TRUE)
    session$setInputs(opt_strip = TRUE)
    expect_null(state$qv)
    expect_match(output$status, "Inputs changed")
    expect_error(output$dl_rds, class = "shiny.silent.error")
    session$setInputs(btn_parse = 2)
    saved <- readRDS(output$dl_rds)
    expect_identical(saved$metadata$strip_prefix, TRUE)
    expect_true("Cal 1" %in% saved$well_groups$sample_id)
    session$setInputs(f_template = data.frame(name = "source-template.csv", datapath = template))
    expect_null(state$qv)
    session$setInputs(btn_parse = 3)
    expect_identical(state$qv$metadata$upload_template, "source-template.csv")
    expect_identical(state$qv$metadata$template_status, "parsed")
    expect_false(is.null(state$template))
    session$setInputs(f_qview = data.frame(name = "source-B.Q-View", datapath = bad))
    expect_null(state$qv)
    expect_null(state$template)
    expect_error(output$dl_rds, class = "shiny.silent.error")
    session$setInputs(btn_parse = 4)
    expect_null(state$qv)
    expect_match(output$status, "Error parsing Q-View binary")
    # A file update and Parse in one flush must not clear the new result afterward.
    session$setInputs(f_qview = data.frame(name = "recovered.Q-View", datapath = path),
                      btn_parse = 5)
    expect_identical(state$qv$metadata$upload_file, "recovered.Q-View")
    expect_identical(readRDS(output$dl_rds)$metadata$upload_file, "recovered.Q-View")
  })
  shiny::testServer(.qv_app_server, {
    expect_null(state$qv)
    expect_null(state$template)
  })
})

test_that("plot downloads reject invalid dimensions before calling a device", {
  .app_integrity_skips()
  writes <- list()
  local_mocked_bindings(ggsave = function(filename, plot, ...) {
    writes[[length(writes) + 1L]] <<- list(...)
    writeBin(as.raw(1), filename)
  }, .package = "ggplot2")
  qv <- read_qview(.app_integrity_fixture(), verbose = FALSE)
  shiny::testServer(.qv_app_server, {
    state$qv <- qv
    session$setInputs(plot_type = "plate_map", plot_w_in = 30,
                      plot_h_in = 30, plot_dpi = 1200)
    expect_error(output$dl_plot, class = "shiny.silent.error")
    expect_error(output$dl_overview_png, class = "shiny.silent.error")
    expect_length(writes, 0)
    session$flushReact()
    expect_match(output$status, "50 million pixels")
    for (value in list(Inf, NA_real_, -1, c(3, 4))) {
      session$setInputs(plot_w_in = value)
      expect_error(output$dl_overview_pdf, class = "shiny.silent.error")
    }
    expect_length(writes, 0)
    session$setInputs(plot_w_in = 10, plot_h_in = 7, plot_dpi = 600)
    expect_true(file.exists(output$dl_plot))
    expect_equal(writes[[1]][c("width", "height", "dpi")],
                 list(width = 10, height = 7, dpi = 600))
    session$setInputs(plot_w_in = 30, plot_h_in = 30, plot_dpi = 1200)
    expect_true(file.exists(output$dl_overview_pdf))
    expect_identical(writes[[2]]$device, grDevices::pdf)
  })
  for (value in list(NA_real_, Inf, 0, 1201, "600", c(72, 144))) {
    expect_error(.qv_plot_export_size(10, 7, value), "DPI")
  }
  expect_equal(.qv_plot_export_size(10, 7, 600)$dpi, 600)
  expect_error(.qv_plot_export_size(30, 30, 1200), "50 million")
})
