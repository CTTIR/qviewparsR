#' Launch the qviewparsR Q-View Shiny app
#'
#' `r lifecycle::badge("experimental")`
#'
#' Interactive front-end for [read_qview()]. Uploads a `.Q-View` file
#' (and optionally an accompanying well-assignment template CSV),
#' displays the parsed metadata, analytes, well groups, and replicate
#' tables, and lets the user download the parsed result as `xlsx`,
#' `rds`, or a zip of per-table CSV files.
#'
#' Requires the `shiny`, `bslib`, and `DT` packages (listed under
#' `Suggests`).
#'
#' @param max_upload_mb Numeric. Maximum upload size per request, in
#'   megabytes. Q-View project files routinely exceed Shiny's 5 MB
#'   default; this argument bumps the limit for the duration of the
#'   running app and restores the previous value on exit. Default
#'   `512` MB.
#' @param ... Forwarded to [shiny::runApp()].
#'
#' @return Invoked for its side effect of running the app.
#'
#' @examples
#' if (interactive()) {
#'   qview_app()
#' }
#'
#' @family qview-app
#' @export
qview_app <- function(max_upload_mb = 512, ...) {
  for (pkg in c("shiny", "bslib", "DT", "ggplot2", "withr")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      cli::cli_abort(c(
        "Package {.pkg {pkg}} is required to run {.fn qview_app}.",
        i = "Install it with {.code install.packages(\"{pkg}\")}."
      ))
    }
  }
  stopifnot(is.numeric(max_upload_mb), length(max_upload_mb) == 1L,
            max_upload_mb > 0)
  old <- options(shiny.maxRequestSize = max_upload_mb * 1024^2)
  on.exit(options(old), add = TRUE)
  app <- shiny::shinyApp(ui = .qv_app_ui(), server = .qv_app_server)
  shiny::runApp(app, ...)
}


.qv_theme <- function(dark = FALSE) {
  if (isTRUE(dark)) {
    bslib::bs_theme(
      version    = 5,
      bg         = "#212121",
      fg         = "#dadada",
      primary    = "#dadada",
      secondary  = "#9e9e9e",
      success    = "#dadada",
      info       = "#9e9e9e",
      warning    = "#9e9e9e",
      danger     = "#dadada",
      base_font  = bslib::font_collection(
        "system-ui", "-apple-system", "BlinkMacSystemFont",
        "Segoe UI", "Roboto", "Helvetica Neue", "Arial", "sans-serif"
      ),
      code_font  = bslib::font_collection(
        "SF Mono", "Consolas", "Liberation Mono", "Menlo", "monospace"
      ),
      "border-color"      = "#424242",
      "card-border-color" = "#424242",
      "card-cap-bg"       = "#2a2a2a",
      "body-bg"           = "#212121",
      "body-color"        = "#dadada",
      "link-color"        = "#dadada",
      "link-hover-color"  = "#ffffff",
      "border-radius"     = "0.25rem"
    )
  } else {
    bslib::bs_theme(
      version    = 5,
      bg         = "#fafafa",
      fg         = "#212121",
      primary    = "#212121",
      secondary  = "#424242",
      success    = "#212121",
      info       = "#424242",
      warning    = "#424242",
      danger     = "#212121",
      base_font  = bslib::font_collection(
        "system-ui", "-apple-system", "BlinkMacSystemFont",
        "Segoe UI", "Roboto", "Helvetica Neue", "Arial", "sans-serif"
      ),
      code_font  = bslib::font_collection(
        "SF Mono", "Consolas", "Liberation Mono", "Menlo", "monospace"
      ),
      "border-color"      = "#e0e0e0",
      "card-border-color" = "#e0e0e0",
      "card-cap-bg"       = "#f0f0f0",
      "body-bg"           = "#fafafa",
      "body-color"        = "#212121",
      "link-color"        = "#212121",
      "link-hover-color"  = "#000000",
      "border-radius"     = "0.25rem"
    )
  }
}

.qv_css <- "
:root { --qv-fg:#212121; --qv-bg:#fafafa; --qv-line:#e0e0e0; --qv-mute:#666; }
body { background: var(--qv-bg); color: var(--qv-fg); }
.qv-brand {
  display:flex; align-items:center; gap:.75rem;
  padding:.6rem 1rem; border-bottom:1px solid var(--qv-line);
  background:#ffffff;
}
.qv-brand img.qv-hex { height:44px; width:auto; }
.qv-brand .qv-title { font-weight:600; letter-spacing:.02em; }
.qv-brand .qv-sub   { color:var(--qv-mute); font-size:.85rem; margin-left:.4rem; }

.bslib-sidebar-layout > .sidebar { background:#ffffff; border-right:1px solid var(--qv-line); }
.card { border:1px solid var(--qv-line); box-shadow:none; }
.card-header { background:#f0f0f0; border-bottom:1px solid var(--qv-line);
  font-weight:600; letter-spacing:.02em; }

.btn { border-radius:.25rem; font-weight:500; letter-spacing:.01em; }
.btn-primary, .btn-default {
  background:var(--qv-fg); border-color:var(--qv-fg); color:#ffffff;
}
.btn-primary:hover, .btn-default:hover {
  background:#000; border-color:#000; color:#ffffff;
}
.btn.btn-outline-secondary, .shiny-download-link {
  background:#ffffff; color:var(--qv-fg); border:1px solid var(--qv-fg);
}
.shiny-download-link:hover { background:var(--qv-fg); color:#ffffff; }

.nav-tabs .nav-link.active { color:var(--qv-fg); border-bottom-color:var(--qv-fg); }
.nav-tabs .nav-link { color:var(--qv-mute); }
.nav-tabs .nav-link:hover { color:var(--qv-fg); }

pre, code { background:#ffffff; border:1px solid var(--qv-line); color:var(--qv-fg); }
hr { border-top:1px solid var(--qv-line); }
.form-control:focus, .form-check-input:focus {
  border-color:var(--qv-fg); box-shadow:0 0 0 .15rem rgba(33,33,33,.15);
}
table.dataTable thead th { border-bottom:1px solid var(--qv-fg) !important; }
table.dataTable tbody tr:hover { background:#f0f0f0 !important; }

.qv-about { max-width: 760px; padding: 1rem 0.25rem; }
.qv-about h2 { letter-spacing:.02em; margin-bottom:.5rem; }
.qv-about h3 { margin-top:1.4rem; font-weight:600; }
.qv-about blockquote { border-left:3px solid var(--qv-fg); padding-left:.8rem;
  color:var(--qv-fg); margin:.5rem 0; }
.qv-about pre { padding:.75rem 1rem; }

[data-bs-theme=\"dark\"] {
  --qv-fg:#dadada; --qv-bg:#212121; --qv-line:#424242; --qv-mute:#9e9e9e;
}
[data-bs-theme=\"dark\"] body { background:var(--qv-bg); color:var(--qv-fg); }
[data-bs-theme=\"dark\"] .qv-brand { background:#2a2a2a; border-bottom-color:var(--qv-line); }
[data-bs-theme=\"dark\"] .bslib-sidebar-layout > .sidebar { background:#2a2a2a; border-right-color:var(--qv-line); }
[data-bs-theme=\"dark\"] .card { background:#2a2a2a; border-color:var(--qv-line); }
[data-bs-theme=\"dark\"] .card-header { background:#1a1a1a; border-bottom-color:var(--qv-line); }
[data-bs-theme=\"dark\"] .btn-primary, [data-bs-theme=\"dark\"] .btn-default {
  background:var(--qv-fg); border-color:var(--qv-fg); color:#1a1a1a;
}
[data-bs-theme=\"dark\"] .btn-primary:hover { background:#fff; border-color:#fff; color:#000; }
[data-bs-theme=\"dark\"] .shiny-download-link {
  background:transparent; color:var(--qv-fg); border:1px solid var(--qv-fg);
}
[data-bs-theme=\"dark\"] .shiny-download-link:hover { background:var(--qv-fg); color:#1a1a1a; }
[data-bs-theme=\"dark\"] pre, [data-bs-theme=\"dark\"] code {
  background:#1a1a1a; color:var(--qv-fg); border-color:var(--qv-line);
}
[data-bs-theme=\"dark\"] table.dataTable { color:var(--qv-fg) !important; }
[data-bs-theme=\"dark\"] table.dataTable thead th { border-bottom-color:var(--qv-fg) !important; }
[data-bs-theme=\"dark\"] table.dataTable tbody tr { background:#2a2a2a !important; }
[data-bs-theme=\"dark\"] table.dataTable tbody tr:hover { background:#3a3a3a !important; }
[data-bs-theme=\"dark\"] .nav-tabs .nav-link.active { color:var(--qv-fg); border-bottom-color:var(--qv-fg); }
"

.qv_table_panel <- function(tbl_id, dl_xlsx, label) {
  shiny::tagList(
    shiny::div(
      class = "d-flex justify-content-end mb-2",
      shiny::downloadButton(dl_xlsx, paste0("Download ", label, " (xlsx)"))
    ),
    DT::DTOutput(tbl_id)
  )
}

# Data panel: top toolbar (xlsx + plot PNG), table, divider, plot.
.qv_data_panel <- function(tbl_id, dl_xlsx, plot_id, dl_plot, label) {
  shiny::tagList(
    shiny::div(
      class = "d-flex justify-content-end gap-2 mb-2",
      shiny::downloadButton(dl_xlsx, paste0("Download ", label, " (xlsx)")),
      shiny::downloadButton(dl_plot, paste0("Download ", label, " plot (PNG)"))
    ),
    DT::DTOutput(tbl_id),
    shiny::tags$hr(),
    shiny::plotOutput(plot_id, height = "440px")
  )
}

.qv_app_ui <- function() {
  shiny::addResourcePath(
    "qv_www",
    system.file("shiny", "qview", "www", package = "qviewparsR")
  )
  bslib::page_sidebar(
    title = NULL,
    theme = .qv_theme(dark = FALSE),
    shiny::tags$head(shiny::tags$style(shiny::HTML(.qv_css))),
    shiny::div(
      class = "qv-brand",
      shiny::tags$img(src = "qv_www/logo_hex.svg",
                      alt = "qviewparsR hex", class = "qv-hex"),
      shiny::span(class = "qv-title", "qviewparsR"),
      shiny::span(class = "qv-sub", "Q-View parser"),
      shiny::div(
        class = "ms-auto",
        bslib::input_dark_mode(id = "dark_mode", mode = "light")
      )
    ),
    sidebar = bslib::sidebar(
      width = 360,
      shiny::tags$p(
        "Upload a Q-View project (.Q-View) file. Optionally also ",
        "upload the original plate-template CSV to cross-validate ",
        "sample identifiers."
      ),
      shiny::fileInput(
        "f_qview", "Q-View project (.Q-View)",
        accept = c(".Q-View", ".q-view", ".bin")
      ),
      shiny::fileInput(
        "f_template", "Plate template (csv, optional)",
        accept = c(".csv", ".tsv", ".txt")
      ),
      shiny::checkboxInput(
        "opt_strip", "Strip Q-View prefixes (ICal -> Cal, GLow -> Low ...)",
        value = FALSE
      ),
      shiny::actionButton("btn_parse", "Parse",
                          class = "btn-primary w-100"),
      shiny::hr(),
      shiny::tags$strong("Whole project"),
      shiny::downloadButton("dl_xlsx", "All tables (xlsx)",
                            class = "w-100 mt-1"),
      shiny::downloadButton("dl_rds",  "Full object (rds)",
                            class = "w-100 mt-1"),
      shiny::downloadButton("dl_zip",  "All tables (csv zip)",
                            class = "w-100 mt-1")
    ),
    bslib::card(
      bslib::card_header("Status"),
      shiny::verbatimTextOutput("status")
    ),
    bslib::navset_card_tab(
      id = "tabs",
      bslib::nav_panel("Metadata",
        shiny::tagList(
          shiny::div(
            class = "d-flex justify-content-end mb-2",
            shiny::downloadButton("dl_tbl_metadata", "Download metadata (xlsx)")
          ),
          DT::DTOutput("tbl_metadata")
        )
      ),
      bslib::nav_panel("Analytes",
        .qv_data_panel("tbl_analytes",    "dl_tbl_analytes",
                       "plt_analytes",    "dl_plt_analytes",    "analytes")),
      bslib::nav_panel("Well groups",
        .qv_data_panel("tbl_well_groups", "dl_tbl_well_groups",
                       "plt_well_groups", "dl_plt_well_groups", "well_groups")),
      bslib::nav_panel("Plate layout",
        .qv_data_panel("tbl_plate",       "dl_tbl_plate",
                       "plt_plate",       "dl_plt_plate",       "plate_layout")),
      bslib::nav_panel("Pixel intensities",
        .qv_data_panel("tbl_pi",          "dl_tbl_pi",
                       "plt_pi",          "dl_plt_pi",          "pixel_intensities")),
      bslib::nav_panel("Summaries",
        .qv_data_panel("tbl_summary",     "dl_tbl_summary",
                       "plt_summary",     "dl_plt_summary",     "summary_statistics")),
      bslib::nav_panel("Concentrations",
        .qv_data_panel("tbl_conc",        "dl_tbl_conc",
                       "plt_conc",        "dl_plt_conc",        "concentrations")),
      bslib::nav_panel("Curve fit",
        .qv_data_panel("tbl_curve",       "dl_tbl_curve",
                       "plt_curve",       "dl_plt_curve",       "curve_fit")),
      bslib::nav_panel("Plate template",
        .qv_data_panel("tbl_template",    "dl_tbl_template",
                       "plt_template",    "dl_plt_template",    "template")),
      bslib::nav_panel(
        "Visualise",
        shiny::fluidRow(
          shiny::column(4, shiny::selectInput(
            "plot_type", "Plot",
            choices = c("Plate map"         = "plate_map",
                        "Intensity heatmap" = "intensity_heatmap",
                        "Replicate scatter" = "replicate_scatter"),
            selected = "plate_map")),
          shiny::column(2, shiny::numericInput(
            "plot_dpi", "DPI", value = 600, min = 72, max = 1200, step = 50)),
          shiny::column(2, shiny::numericInput(
            "plot_w_in", "Width (in)", value = 10, min = 3, max = 30, step = 0.5)),
          shiny::column(2, shiny::numericInput(
            "plot_h_in", "Height (in)", value = 7, min = 3, max = 30, step = 0.5))
        ),
        shiny::plotOutput("qv_plot", height = "640px"),
        shiny::downloadButton("dl_plot", "Download plot (PNG, high-DPI)")
      ),
      bslib::nav_panel("About", .qv_about_panel())
    )
  )
}


.qv_about_panel <- function() {
  shiny::tagList(
    shiny::div(
      class = "qv-about",
      shiny::h2("qviewparsR"),
      shiny::p(shiny::tags$em(
        "Pure-R parser for the .Q-View binary project file format used in ",
        "chemiluminescent multiplex ELISA plate imaging and quantification."
      )),
      shiny::p(
        "qviewparsR reads .Q-View files end-to-end without a Java runtime ",
        "or H2 database driver. The package extracts project metadata, the ",
        "analyte panel with units and detection limits, sample well-group ",
        "assignments, per-well replicate pixel intensities, summary ",
        "statistics, optional back-calculated concentrations, the curve ",
        "fit, and a plate layout, all as tidy tibbles. Plot, summarise, ",
        "or pipe-export to xlsx, csv, or rds."
      ),
      shiny::h3("Authors"),
      shiny::tags$ul(
        shiny::tags$li("Raban Heller (aut, cre, cph)"),
        shiny::tags$li("Marco Mannes (aut)")
      ),
      shiny::h3("License"),
      shiny::p("MIT (c) 2026 Raban Heller. See ",
               shiny::tags$code("LICENSE"), " in the repository."),
      shiny::h3("Project links"),
      shiny::tags$ul(
        shiny::tags$li(shiny::tags$a(href = "https://github.com/CTTIR/qviewparsR",
                                     "GitHub repository", target = "_blank")),
        shiny::tags$li(shiny::tags$a(href = "https://cttir.github.io/qviewparsR/",
                                     "pkgdown documentation site",
                                     target = "_blank")),
        shiny::tags$li(shiny::tags$a(href = "https://github.com/CTTIR/qviewparsR/issues",
                                     "Issue tracker", target = "_blank"))
      ),
      shiny::h3("Acknowledgements"),
      shiny::p(
        "Built on the tidyverse stack (cli, dplyr, lifecycle, openxlsx2, ",
        "readr, rlang, tibble, tidyr) with bslib + DT for the interactive ",
        "front-end and ggplot2 for visualisation. The .Q-View container ",
        "format was reverse-engineered from public binary inspection of ",
        "exported project files."
      ),
      shiny::h3("How to cite"),
      shiny::p("If qviewparsR contributes to academic work, please cite:"),
      shiny::tags$blockquote(
        "Heller R, Mannes M (2026). ",
        shiny::tags$em("qviewparsR: Read .Q-View Multiplex ELISA Project Files. "),
        "R package version 1.0.0. https://github.com/CTTIR/qviewparsR"
      ),
      shiny::h4("BibTeX"),
      shiny::tags$pre(
"@Manual{qviewparsR,
  title  = {qviewparsR: Read .Q-View Multiplex ELISA Project Files},
  author = {Raban Heller and Marco Mannes},
  year   = {2026},
  note   = {R package version 1.0.0},
  url    = {https://github.com/CTTIR/qviewparsR}
}"
      ),
      shiny::p(shiny::tags$small(
        "You can always retrieve the up-to-date entry inside R with ",
        shiny::tags$code('citation("qviewparsR")'), "."
      ))
    )
  )
}


.qv_app_server <- function(input, output, session) {
  state <- shiny::reactiveValues(qv = NULL, template = NULL,
                                 log = character(0))

  log_msg <- function(...) {
    state$log <- c(state$log, paste0(format(Sys.time(), "%H:%M:%S"), "  ",
                                     paste0(..., collapse = "")))
  }

  shiny::observeEvent(input$btn_parse, {
    state$log <- character(0)
    state$qv <- NULL
    state$template <- NULL

    if (is.null(input$f_qview)) {
      log_msg("Upload a .Q-View project file to begin.")
      return()
    }
    qv <- tryCatch(
      read_qview(input$f_qview$datapath,
                 strip_prefix = isTRUE(input$opt_strip),
                 verbose = FALSE),
      error = function(e) {
        log_msg("Error parsing Q-View binary: ", conditionMessage(e))
        NULL
      }
    )
    if (is.null(qv)) return()
    state$qv <- qv
    log_msg(sprintf(
      "Parsed Q-View binary: %d well groups x %d analytes (%d replicate rows).",
      nrow(qv$well_groups), nrow(qv$analytes), nrow(qv$pixel_intensities)))

    if (!is.null(input$f_template)) {
      tmpl <- tryCatch(
        read_qview_template(input$f_template$datapath, verbose = FALSE),
        error = function(e) {
          log_msg("Could not parse template: ", conditionMessage(e))
          NULL
        }
      )
      if (!is.null(tmpl)) {
        state$template <- tmpl
        log_msg(sprintf("Parsed template: %d wells.", nrow(tmpl)))
      }
    }
  })

  output$status <- shiny::renderText({
    if (length(state$log) == 0L) {
      "Upload a .Q-View file and click 'Parse'."
    } else {
      paste(state$log, collapse = "\n")
    }
  })

  render_tbl <- function(provider) {
    DT::renderDT({
      d <- provider()
      if (is.null(d) || nrow(d) == 0L) return(NULL)
      DT::datatable(d, options = list(scrollX = TRUE, pageLength = 25),
                    rownames = FALSE)
    })
  }
  output$tbl_metadata    <- render_tbl(function() {
    if (is.null(state$qv)) NULL else .qv_metadata_kv(state$qv)
  })
  output$tbl_analytes    <- render_tbl(function() state$qv$analytes)
  output$tbl_well_groups <- render_tbl(function() state$qv$well_groups)
  output$tbl_plate       <- render_tbl(function() state$qv$plate_layout)
  output$tbl_pi          <- render_tbl(function() state$qv$pixel_intensities)
  output$tbl_summary     <- render_tbl(function() {
    if (is.null(state$qv)) NULL else summary(state$qv)
  })
  output$tbl_conc        <- render_tbl(function() state$qv$concentrations)
  output$tbl_curve       <- render_tbl(function() state$qv$curve_fit)
  output$tbl_template    <- render_tbl(function() state$template)

  # ---- Per-tab plots ------------------------------------------------
  plot_for <- function(builder) {
    shiny::reactive({
      shiny::req(state$qv)
      tryCatch(builder(state$qv),
               error = function(e) {
                 log_msg("Plot error: ", conditionMessage(e)); NULL
               })
    })
  }
  rx_plt_analytes    <- plot_for(.qv_plot_analytes)
  rx_plt_well_groups <- plot_for(.qv_plot_well_groups)
  rx_plt_plate       <- plot_for(.qv_plot_plate_map)
  rx_plt_pi          <- plot_for(.qv_plot_intensity_heatmap)
  rx_plt_summary     <- plot_for(.qv_plot_summary)
  rx_plt_conc        <- plot_for(.qv_plot_concentrations)
  rx_plt_curve       <- plot_for(.qv_plot_curve_fit)
  rx_plt_template    <- shiny::reactive({
    shiny::req(state$template)
    tryCatch(.qv_plot_template(state$template),
             error = function(e) { log_msg("Plot error: ", conditionMessage(e)); NULL })
  })

  show_plot <- function(rx, fallback) {
    shiny::renderPlot({
      p <- rx()
      if (is.null(p)) return(.qv_blank_plot(fallback))
      p
    })
  }
  output$plt_analytes    <- show_plot(rx_plt_analytes,    "Upload and parse a .Q-View file to see analyte panel.")
  output$plt_well_groups <- show_plot(rx_plt_well_groups, "Upload and parse a .Q-View file to see well groups.")
  output$plt_plate       <- show_plot(rx_plt_plate,       "Upload and parse a .Q-View file to see the plate layout.")
  output$plt_pi          <- show_plot(rx_plt_pi,          "Upload and parse a .Q-View file to see pixel intensities.")
  output$plt_summary     <- show_plot(rx_plt_summary,     "Upload and parse a .Q-View file to see summary statistics.")
  output$plt_conc        <- show_plot(rx_plt_conc,        "No quantitative concentrations: regression model is qualitative.")
  output$plt_curve       <- show_plot(rx_plt_curve,       "Upload and parse a .Q-View file to see curve fit.")
  output$plt_template    <- show_plot(rx_plt_template,    "Upload an optional plate-template CSV (sidebar) to populate this tab.")

  current_plot <- shiny::reactive({
    shiny::req(state$qv)
    tryCatch(
      plot(state$qv, type = input$plot_type),
      error = function(e) {
        log_msg("Plot error: ", conditionMessage(e))
        NULL
      }
    )
  })

  output$qv_plot <- shiny::renderPlot({
    p <- current_plot()
    shiny::req(p)
    p
  })

  output$dl_plot <- shiny::downloadHandler(
    filename = function() filename_stamp(paste0("_", input$plot_type, ".png")),
    content = function(file) {
      p <- current_plot()
      shiny::req(p)
      ggplot2::ggsave(
        file, p,
        width  = if (is.null(input$plot_w_in)) 10 else input$plot_w_in,
        height = if (is.null(input$plot_h_in)) 7  else input$plot_h_in,
        dpi    = if (is.null(input$plot_dpi))  600 else input$plot_dpi,
        units  = "in"
      )
    }
  )

  # ---- Per-table xlsx download handlers -----------------------------
  one_sheet_xlsx <- function(slot_fun, label) {
    shiny::downloadHandler(
      filename = function() filename_stamp(paste0("_", label, ".xlsx")),
      content  = function(file) {
        d <- slot_fun()
        shiny::req(!is.null(d), nrow(d) > 0L)
        wb <- openxlsx2::wb_workbook()
        wb$add_worksheet(label)
        wb$add_data(sheet = label, x = d)
        openxlsx2::wb_save(wb, file = file, overwrite = TRUE)
      }
    )
  }
  output$dl_tbl_metadata    <- one_sheet_xlsx(function() {
    if (is.null(state$qv)) NULL else .qv_metadata_kv(state$qv)
  }, "metadata")
  output$dl_tbl_analytes    <- one_sheet_xlsx(function() state$qv$analytes,           "analytes")
  output$dl_tbl_well_groups <- one_sheet_xlsx(function() state$qv$well_groups,        "well_groups")
  output$dl_tbl_plate       <- one_sheet_xlsx(function() state$qv$plate_layout,       "plate_layout")
  output$dl_tbl_pi          <- one_sheet_xlsx(function() state$qv$pixel_intensities,  "pixel_intensities")
  output$dl_tbl_summary     <- one_sheet_xlsx(function() {
    if (is.null(state$qv)) NULL else summary(state$qv)
  }, "summary_statistics")
  output$dl_tbl_conc        <- one_sheet_xlsx(function() state$qv$concentrations,     "concentrations")
  output$dl_tbl_curve       <- one_sheet_xlsx(function() state$qv$curve_fit,          "curve_fit")
  output$dl_tbl_template    <- one_sheet_xlsx(function() state$template,              "template")

  # ---- Per-tab plot PNG download handlers ---------------------------
  one_plot_png <- function(rx, label) {
    shiny::downloadHandler(
      filename = function() filename_stamp(paste0("_", label, ".png")),
      content  = function(file) {
        p <- rx(); shiny::req(p)
        ggplot2::ggsave(
          file, p,
          width  = if (is.null(input$plot_w_in)) 10 else input$plot_w_in,
          height = if (is.null(input$plot_h_in)) 7  else input$plot_h_in,
          dpi    = if (is.null(input$plot_dpi))  600 else input$plot_dpi,
          units  = "in"
        )
      }
    )
  }
  output$dl_plt_analytes    <- one_plot_png(rx_plt_analytes,    "analytes")
  output$dl_plt_well_groups <- one_plot_png(rx_plt_well_groups, "well_groups")
  output$dl_plt_plate       <- one_plot_png(rx_plt_plate,       "plate_layout")
  output$dl_plt_pi          <- one_plot_png(rx_plt_pi,          "pixel_intensities")
  output$dl_plt_summary     <- one_plot_png(rx_plt_summary,     "summary_statistics")
  output$dl_plt_conc        <- one_plot_png(rx_plt_conc,        "concentrations")
  output$dl_plt_curve       <- one_plot_png(rx_plt_curve,       "curve_fit")
  output$dl_plt_template    <- one_plot_png(rx_plt_template,    "template")

  filename_stamp <- function(ext) {
    paste0("qview_", format(Sys.time(), "%Y%m%d_%H%M%S"), ext)
  }

  output$dl_xlsx <- shiny::downloadHandler(
    filename = function() filename_stamp(".xlsx"),
    content  = function(file) {
      shiny::req(state$qv)
      write_qview_xlsx(state$qv, file, template = state$template,
                       overwrite = TRUE)
    }
  )

  output$dl_rds <- shiny::downloadHandler(
    filename = function() filename_stamp(".rds"),
    content  = function(file) {
      shiny::req(state$qv)
      saveRDS(state$qv, file)
    }
  )

  output$dl_zip <- shiny::downloadHandler(
    filename = function() filename_stamp("_csv.zip"),
    content  = function(file) {
      shiny::req(state$qv)
      tmp <- tempfile("qview_csv_")
      dir.create(tmp); on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
      write_qview_csv(state$qv, tmp, template = state$template)
      withr::with_dir(tmp, utils::zip(file, files = list.files(tmp)))
    }
  )
}
