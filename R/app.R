#' Launch the qviewparsR Q-View Shiny app
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
#' @param ... Forwarded to [shiny::runApp()].
#'
#' @return Invoked for its side effect of running the app.
#'
#' @examples
#' if (interactive()) {
#'   qview_app()
#' }
#'
#' @export
qview_app <- function(...) {
  for (pkg in c("shiny", "bslib", "DT", "ggplot2")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      cli::cli_abort(c(
        "Package {.pkg {pkg}} is required to run {.fn qview_app}.",
        i = "Install it with {.code install.packages(\"{pkg}\")}."
      ))
    }
  }
  app <- shiny::shinyApp(ui = .qv_app_ui(), server = .qv_app_server)
  shiny::runApp(app, ...)
}


.qv_app_ui <- function() {
  bslib::page_sidebar(
    title = "qviewparsR — Q-View parser",
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
                          class = "btn-primary"),
      shiny::hr(),
      shiny::tags$strong("Download"),
      shiny::downloadButton("dl_xlsx", "xlsx"),
      shiny::downloadButton("dl_rds",  "rds"),
      shiny::downloadButton("dl_zip",  "csv (zip)")
    ),
    bslib::card(
      bslib::card_header("Status"),
      shiny::verbatimTextOutput("status")
    ),
    bslib::navset_card_tab(
      id = "tabs",
      bslib::nav_panel("Metadata",        shiny::verbatimTextOutput("md")),
      bslib::nav_panel("Analytes",        DT::DTOutput("tbl_analytes")),
      bslib::nav_panel("Well groups",     DT::DTOutput("tbl_well_groups")),
      bslib::nav_panel("Plate layout",    DT::DTOutput("tbl_plate")),
      bslib::nav_panel("Pixel intensities", DT::DTOutput("tbl_pi")),
      bslib::nav_panel("Summaries",       DT::DTOutput("tbl_summary")),
      bslib::nav_panel("Concentrations",  DT::DTOutput("tbl_conc")),
      bslib::nav_panel("Curve fit",       DT::DTOutput("tbl_curve")),
      bslib::nav_panel("Plate template",  DT::DTOutput("tbl_template")),
      bslib::nav_panel(
        "Visualise",
        shiny::fluidRow(
          shiny::column(4, shiny::selectInput(
            "plot_type", "Plot",
            choices = c("Plate map"         = "plate_map",
                        "Intensity heatmap" = "intensity_heatmap",
                        "Replicate scatter" = "replicate_scatter"),
            selected = "plate_map"))
        ),
        shiny::plotOutput("qv_plot", height = "640px"),
        shiny::downloadButton("dl_plot", "Download plot (PNG)")
      )
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

  output$md <- shiny::renderPrint({
    if (is.null(state$qv)) return(invisible())
    print(state$qv)
  })

  render_tbl <- function(slot) {
    DT::renderDT({
      if (is.null(state$qv)) return(NULL)
      d <- state$qv[[slot]]
      if (is.null(d) || nrow(d) == 0L) return(NULL)
      DT::datatable(d, options = list(scrollX = TRUE, pageLength = 25),
                    rownames = FALSE)
    })
  }
  output$tbl_analytes    <- render_tbl("analytes")
  output$tbl_well_groups <- render_tbl("well_groups")
  output$tbl_plate       <- render_tbl("plate_layout")
  output$tbl_pi          <- render_tbl("pixel_intensities")
  output$tbl_summary     <- render_tbl("summary_statistics")
  output$tbl_conc        <- render_tbl("concentrations")
  output$tbl_curve       <- render_tbl("curve_fit")

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
      ggplot2::ggsave(file, p, width = 10, height = 7, dpi = 150)
    }
  )

  output$tbl_template <- DT::renderDT({
    if (is.null(state$template)) return(NULL)
    DT::datatable(state$template,
                  options = list(scrollX = TRUE, pageLength = 25),
                  rownames = FALSE)
  })

  filename_stamp <- function(ext) {
    paste0("qview_", format(Sys.time(), "%Y%m%d_%H%M%S"), ext)
  }

  output$dl_xlsx <- shiny::downloadHandler(
    filename = function() filename_stamp(".xlsx"),
    content  = function(file) {
      shiny::req(state$qv)
      qview_to_xlsx(state$qv, file, template = state$template)
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
      qview_to_csv_dir(state$qv, tmp, template = state$template)
      old <- setwd(tmp); on.exit(setwd(old), add = TRUE)
      utils::zip(file, files = list.files(tmp))
    }
  )
}
