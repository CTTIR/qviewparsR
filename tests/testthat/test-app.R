# Tests for the Shiny front-end in R/app.R, driven entirely in-process with
# shiny::testServer() and direct calls to the UI builders. Unlike the
# shinytest2 suite in test-shiny.R these need no browser, so they run under
# coverage and on CI. They assert real behaviour: parsing state transitions,
# status text, per-table renderers, empty-state messages, and that every
# download handler writes a non-empty file of the right kind.

.app_skips <- function() {
  testthat::skip_if_not_installed("shiny")
  testthat::skip_if_not_installed("bslib")
  testthat::skip_if_not_installed("DT")
  testthat::skip_if_not_installed("ggplot2")
}

.qv_fixture <- function() {
  system.file("extdata", "example.Q-View", package = "qviewparsR")
}
.tmpl_fixture <- function() {
  system.file("extdata", "example-template.csv", package = "qviewparsR")
}


# ---- UI builders (no browser) ----------------------------------------

test_that(".qv_theme() builds light and dark bslib themes", {
  testthat::skip_if_not_installed("bslib")
  light <- .qv_theme(dark = FALSE)
  dark  <- .qv_theme(dark = TRUE)
  expect_s3_class(light, "bs_theme")
  expect_s3_class(dark,  "bs_theme")
  # The two themes differ (distinct background colours).
  expect_false(identical(light, dark))
})

test_that(".qv_table_panel() assembles a tagList with and without a message slot", {
  testthat::skip_if_not_installed("DT")
  plain <- .qv_table_panel("tbl_x", "dl_x", "x")
  withmsg <- .qv_table_panel("tbl_y", "dl_y", "y", msg_id = "msg_y")
  expect_s3_class(plain, "shiny.tag.list")
  expect_s3_class(withmsg, "shiny.tag.list")
  html <- as.character(withmsg)
  expect_match(html, "msg_y")
  expect_match(html, "Download y \\(xlsx\\)")
})

test_that(".qv_app_ui() and .qv_about_panel() render to tag structures", {
  .app_skips()
  ui <- .qv_app_ui()
  expect_s3_class(ui, "bslib_page")
  about <- .qv_about_panel()
  expect_s3_class(about, "shiny.tag.list")
  expect_match(as.character(about), "qviewparsR", fixed = TRUE)
})

test_that(".qv_app() builds a runnable shinyApp object without launching it", {
  .app_skips()
  app <- .qv_app()
  expect_s3_class(app, "shiny.appobj")
})


# ---- qview_app() launcher guards -------------------------------------

test_that("qview_app() rejects an invalid max_upload_mb", {
  .app_skips()
  expect_error(qview_app(max_upload_mb = -1))
  expect_error(qview_app(max_upload_mb = c(1, 2)))
})

test_that("qview_app() aborts when a required Suggests package is missing", {
  .app_skips()
  testthat::local_mocked_bindings(
    requireNamespace = function(package, ...) FALSE, .package = "base")
  expect_error(qview_app(), "is required to run")
})

test_that("qview_app() sets the upload limit and runs the app", {
  .app_skips()
  ran <- NULL
  testthat::local_mocked_bindings(
    runApp = function(appDir, ...) { ran <<- getOption("shiny.maxRequestSize"); invisible() },
    .package = "shiny")
  before <- getOption("shiny.maxRequestSize")
  qview_app(max_upload_mb = 64)
  expect_equal(ran, 64 * 1024^2)             # limit was bumped during the run
  expect_identical(getOption("shiny.maxRequestSize"), before)  # and restored
})


# ---- server: parse state machine -------------------------------------

test_that("server logs a prompt when Parse is clicked with no file", {
  .app_skips()
  shiny::testServer(.qv_app_server, {
    session$setInputs(opt_strip = FALSE, btn_parse = 1)
    expect_match(output$status, "Upload a .Q-View")
    expect_null(state$qv)
  })
})

test_that("server parses an uploaded .Q-View and reports the counts", {
  .app_skips()
  path <- .qv_fixture()
  shiny::testServer(.qv_app_server, {
    session$setInputs(
      f_qview = data.frame(name = "example.Q-View", datapath = path),
      opt_strip = FALSE, btn_parse = 1)
    expect_false(is.null(state$qv))
    expect_match(output$status, "Parsed Q-View binary")
    expect_match(output$status, "well groups")
  })
})

test_that("server parses an optional template alongside the .Q-View", {
  .app_skips()
  qv_path <- .qv_fixture()
  tmpl <- .tmpl_fixture()
  shiny::testServer(.qv_app_server, {
    session$setInputs(
      f_qview   = data.frame(name = "example.Q-View", datapath = qv_path),
      f_template = data.frame(name = "example-template.csv", datapath = tmpl),
      opt_strip = TRUE, btn_parse = 1)
    expect_false(is.null(state$qv))
    expect_false(is.null(state$template))
    expect_match(output$status, "Parsed template")
  })
})

test_that("server reports a clear error on an unparseable .Q-View upload", {
  .app_skips()
  bad <- withr::local_tempfile(fileext = ".Q-View")
  writeBin(charToRaw("not a q-view container"), bad)
  shiny::testServer(.qv_app_server, {
    session$setInputs(
      f_qview = data.frame(name = "bad.Q-View", datapath = bad),
      opt_strip = FALSE, btn_parse = 1)
    expect_null(state$qv)
    expect_match(output$status, "Error parsing Q-View binary")
  })
})

test_that("server logs a template parse failure but keeps the parsed qv", {
  .app_skips()
  qv_path <- .qv_fixture()
  bad_tmpl <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("just,some,values", "a,b,c"), bad_tmpl)
  shiny::testServer(.qv_app_server, {
    session$setInputs(
      f_qview    = data.frame(name = "example.Q-View", datapath = qv_path),
      f_template = data.frame(name = "bad.csv", datapath = bad_tmpl),
      opt_strip  = FALSE, btn_parse = 1)
    expect_false(is.null(state$qv))
    expect_null(state$template)
    expect_match(output$status, "Could not parse template")
  })
})


# ---- server: table renderers and empty-state messages ----------------

test_that("table renderers are empty before parse and populated after", {
  .app_skips()
  path <- .qv_fixture()
  shiny::testServer(.qv_app_server, {
    # Before any parse, the providers see NULL state and exercise the
    # empty-data branch of render_tbl(); evaluating them is what matters.
    invisible(output$tbl_analytes)
    invisible(output$tbl_metadata)
    invisible(output$tbl_summary)
    # Status default text (empty log branch).
    expect_match(output$status, "click 'Parse'")

    session$setInputs(
      f_qview = data.frame(name = "example.Q-View", datapath = path),
      opt_strip = FALSE, btn_parse = 1)

    expect_false(is.null(output$tbl_analytes))
    expect_false(is.null(output$tbl_metadata))
    expect_false(is.null(output$tbl_well_groups))
    expect_false(is.null(output$tbl_plate))
    expect_false(is.null(output$tbl_pi))
    expect_false(is.null(output$tbl_summary))
    expect_false(is.null(output$tbl_curve))
  })
})

test_that("empty-state messages appear when slots are missing", {
  .app_skips()
  qv <- read_qview(.qv_fixture(), verbose = FALSE)
  qv_noconc <- qv; qv_noconc$concentrations <- NULL
  shiny::testServer(.qv_app_server, {
    # No qv yet: both messages prompt for an upload.
    expect_match(as.character(output$msg_conc), "Upload and parse", all = FALSE)
    expect_match(as.character(output$msg_template), "cross-validate", all = FALSE)

    # Parsed qv with no concentrations: the qualitative-only notice shows.
    state$qv <- qv_noconc
    session$flushReact()
    expect_match(as.character(output$msg_conc), "No quantitative concentrations",
                 all = FALSE)
  })
})


# ---- server: plots ---------------------------------------------------

test_that("overview and visualise plots render once a qv is present", {
  .app_skips()
  qv <- read_qview(.qv_fixture(), verbose = FALSE)
  shiny::testServer(.qv_app_server, {
    state$qv <- qv
    session$setInputs(plot_type = "plate_map")
    session$flushReact()
    expect_false(is.null(output$plt_overview))
    expect_false(is.null(output$qv_plot))
    # Switch plot type to exercise the reactive again.
    session$setInputs(plot_type = "replicate_scatter")
    session$flushReact()
    expect_false(is.null(output$qv_plot))
  })
})


# ---- server: download handlers ---------------------------------------

test_that("download handlers write non-empty files for a parsed qv", {
  .app_skips()
  qv <- read_qview(.qv_fixture(), verbose = FALSE)
  tmpl <- read_qview_template(.tmpl_fixture(), verbose = FALSE)
  shiny::testServer(.qv_app_server, {
    state$qv <- qv
    state$template <- tmpl
    session$setInputs(plot_type = "plate_map", plot_w_in = 6, plot_h_in = 4,
                      plot_dpi = 72)
    session$flushReact()

    rds <- output$dl_rds
    expect_true(file.exists(rds) && file.size(rds) > 0)
    expect_true(is_qview(readRDS(rds)))

    xlsx <- output$dl_xlsx
    expect_true(file.exists(xlsx) && file.size(xlsx) > 0)

    zip <- output$dl_zip
    expect_true(file.exists(zip) && file.size(zip) > 0)

    # Per-table single-sheet xlsx handlers.
    for (id in c("dl_tbl_metadata", "dl_tbl_analytes", "dl_tbl_well_groups",
                 "dl_tbl_plate", "dl_tbl_pi", "dl_tbl_summary",
                 "dl_tbl_curve", "dl_tbl_template")) {
      f <- output[[id]]
      expect_true(file.exists(f) && file.size(f) > 0,
                  info = id)
    }
  })
})

test_that("plot download handlers produce image files", {
  .app_skips()
  qv <- read_qview(.qv_fixture(), verbose = FALSE)
  shiny::testServer(.qv_app_server, {
    state$qv <- qv
    session$setInputs(plot_type = "plate_map", plot_w_in = 6, plot_h_in = 4,
                      plot_dpi = 72)
    session$flushReact()

    png <- output$dl_plot
    expect_true(file.exists(png) && file.size(png) > 0)

    ov_png <- output$dl_overview_png
    expect_true(file.exists(ov_png) && file.size(ov_png) > 0)

    ov_pdf <- output$dl_overview_pdf
    expect_true(file.exists(ov_pdf) && file.size(ov_pdf) > 0)
  })
})
