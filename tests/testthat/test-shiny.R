# End-to-end Shiny tests via shinytest2. These need a Chromium browser and
# are skipped on CRAN and wherever Chrome / shinytest2 is unavailable.

.shiny_skips <- function() {
  withr::local_envvar(c(
    QVIEWPARSR_TEST_PACKAGE_PATH = getNamespaceInfo(asNamespace("qviewparsR"), "path")
  ), .local_envir = parent.frame())
  testthat::skip_on_cran()
  # shinytest2 runs the app in a subprocess covr cannot instrument and the
  # added latency makes it flaky under coverage; skip there.
  testthat::skip_if(identical(Sys.getenv("R_COVR"), "true"),
                    "shinytest2 not run under covr")
  testthat::skip_if_not_installed("shinytest2")
  testthat::skip_if_not_installed("chromote")
  testthat::skip_if_not_installed("shiny")
  testthat::skip_if_not_installed("bslib")
  testthat::skip_if_not_installed("DT")
  chrome <- tryCatch(chromote::find_chrome(), error = function(e) NULL)
  testthat::skip_if(is.null(chrome) || !nzchar(chrome),
                    "no Chrome/Chromium available for chromote")
}

# Public synthetic fixture by default; an explicit caller-supplied integration
# fixture remains supported, without automatically scanning private .data paths.
.find_qview_fixture <- function() {
  supplied <- Sys.getenv("QVIEWPARSR_QVIEW_FIXTURE", unset = "")
  if (nzchar(supplied)) {
    if (!file.exists(supplied)) stop("QVIEWPARSR_QVIEW_FIXTURE does not exist.")
    return(normalizePath(supplied))
  }
  system.file("extdata", "example.Q-View", package = "qviewparsR", mustWork = TRUE)
}


test_that("qview_app launches and shows the initial prompt", {
  .shiny_skips()
  app <- shinytest2::AppDriver$new(
    testthat::test_path("apps", "qview"),
    name = "qview-init", width = 1400, height = 900,
    load_timeout = 30000, timeout = 20000)
  withr::defer(app$stop())
  app$wait_for_idle(timeout = 20000)
  expect_match(app$get_value(output = "status"),
               "Upload a .Q-View file", fixed = TRUE)
})

test_that("qview_app parses an uploaded .Q-View and renders outputs", {
  .shiny_skips()
  fx <- .find_qview_fixture()

  app <- shinytest2::AppDriver$new(
    testthat::test_path("apps", "qview"),
    name = "qview-parse", width = 1400, height = 900,
    load_timeout = 30000, timeout = 30000)
  withr::defer(app$stop())

  app$upload_file(f_qview = fx)
  app$click("btn_parse")
  app$wait_for_idle(timeout = 30000)

  status <- app$get_value(output = "status")
  expect_match(status, "Parsed Q-View binary", fixed = TRUE)

  # The publication overview renders once a file is parsed.
  app$wait_for_value(output = "plt_overview", timeout = 20000)
  ov <- app$get_value(output = "plt_overview")
  expect_false(is.null(ov))
  expect_gte(app$get_js("document.getElementById('plt_overview').getBoundingClientRect().height"), 780)

  # The Visualise tab renders once active (outputs on hidden tabs are
  # suspended by Shiny, so navigate there first).
  app$set_inputs(tabs = "Visualise")
  app$set_inputs(plot_type = "intensity_heatmap")
  app$wait_for_idle(timeout = 20000)
  app$wait_for_value(output = "qv_plot", timeout = 20000)
  expect_false(is.null(app$get_value(output = "qv_plot")))
  expect_gte(app$get_js("document.getElementById('qv_plot').getBoundingClientRect().height"), 640)
  app$wait_for_js(
    "(() => { const img = document.querySelector('#qv_plot img'); return !!img && img.complete && img.naturalHeight > 0; })()",
    timeout = 20000)
  expect_gte(app$get_js(
    "document.querySelector('#qv_plot img').naturalHeight / window.devicePixelRatio"), 639)
})

test_that("browser downloads retain source settings and recover after input changes", {
  .shiny_skips()
  fx <- .find_qview_fixture()
  bad <- withr::local_tempfile(fileext = ".Q-View")
  writeBin(charToRaw("invalid synthetic project"), bad)
  app <- shinytest2::AppDriver$new(
    testthat::test_path("apps", "qview"),
    name = "qview-recovery", width = 1400, height = 900,
    load_timeout = 30000, timeout = 30000)
  withr::defer(app$stop())
  app$upload_file(f_qview = fx)
  app$click("btn_parse")
  app$wait_for_idle(timeout = 30000)
  first <- readRDS(app$get_download("dl_rds"))
  expect_identical(first$metadata$upload_file, basename(fx))
  expect_identical(first$metadata$strip_prefix, FALSE)

  app$set_inputs(opt_strip = TRUE)
  app$wait_for_idle(timeout = 20000)
  expect_match(app$get_value(output = "status"), "Inputs changed")
  expect_identical(app$get_js("document.getElementById('plt_overview').childElementCount"), 0L)
  app$click("btn_parse")
  app$wait_for_idle(timeout = 30000)
  second <- readRDS(app$get_download("dl_rds"))
  expect_identical(second$metadata$strip_prefix, TRUE)
  expect_true("Cal 1" %in% second$well_groups$sample_id)

  app$upload_file(f_qview = bad)
  app$click("btn_parse")
  app$wait_for_idle(timeout = 20000)
  expect_match(app$get_value(output = "status"), "Error parsing Q-View binary")
  app$upload_file(f_qview = fx)
  app$click("btn_parse")
  app$wait_for_idle(timeout = 30000)
  expect_match(app$get_value(output = "status"), "Parsed Q-View binary")
  recovered <- readRDS(app$get_download("dl_rds"))
  expect_identical(recovered$metadata$upload_file, basename(fx))
  app$set_inputs(tabs = "Visualise", plot_type = "plate_map",
                  plot_w_in = 6, plot_h_in = 4, plot_dpi = 72)
  app$wait_for_idle(timeout = 20000)
  picture <- app$get_download("dl_plot")
  expect_identical(as.integer(readBin(picture, "raw", 8L)),
                   c(137L, 80L, 78L, 71L, 13L, 10L, 26L, 10L))
})
