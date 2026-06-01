# End-to-end Shiny tests via shinytest2. These need a Chromium browser and
# are skipped on CRAN and wherever Chrome / shinytest2 is unavailable.

.shiny_skips <- function() {
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

# Locate a real .Q-View file for the upload test (skips cleanly if absent).
.find_qview_fixture <- function() {
  candidates <- c(
    file.path(".data", "20230316_ELISA-plate-7_panel-1.Q-View"),
    file.path("..", "..", ".data", "20230316_ELISA-plate-7_panel-1.Q-View"),
    file.path("..", "..", ".data", "20230316_ELISA-plate-7_panel-1",
              "20230316_ELISA-plate-7_panel-1.Q-View"),
    Sys.getenv("QVIEWPARSR_QVIEW_FIXTURE", unset = "")
  )
  for (p in candidates) if (nzchar(p) && file.exists(p)) return(normalizePath(p))
  NA_character_
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
  testthat::skip_if(is.na(fx), "no .Q-View fixture available")

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
  ov <- app$get_value(output = "plt_overview")
  expect_false(is.null(ov))

  # The Visualise tab renders once active (outputs on hidden tabs are
  # suspended by Shiny, so navigate there first).
  app$set_inputs(tabs = "Visualise")
  app$set_inputs(plot_type = "intensity_heatmap")
  app$wait_for_idle(timeout = 20000)
  expect_false(is.null(app$get_value(output = "qv_plot")))
})
