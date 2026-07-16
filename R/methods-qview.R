#' Test whether an object is a `qview`
#'
#' `r lifecycle::badge("experimental")`
#'
#' @param x An object to test.
#'
#' @return Logical scalar.
#'
#' @examples
#' path <- system.file("extdata", "example.Q-View", package = "qviewparsR")
#' is_qview(read_qview(path, verbose = FALSE))
#' is_qview(list())
#'
#' @family qview-methods
#' @export
is_qview <- function(x) inherits(x, "qview")


#' Print a Q-View object
#'
#' Compact summary of a parsed `qview` object: project / plate
#' identifiers, analyte panel, well-group counts by type, and whether
#' the embedded report carries quantitative concentrations or only
#' qualitative pixel intensities.
#'
#' @param x A `qview` object returned by [read_qview()].
#' @param ... Ignored.
#'
#' @return `x`, invisibly.
#'
#' @examples
#' qv <- read_qview(system.file("extdata", "example.Q-View",
#'                              package = "qviewparsR"), verbose = FALSE)
#' print(qv)
#'
#' @family qview-methods
#'
#' @export
print.qview <- function(x, ...) {
  rlang::check_dots_empty()
  md <- x$metadata
  cli::cli_h1("Q-View project: {.val {md$project %||% NA}}")
  cli::cli_bullets(c(
    "*" = "Plate:    {.val {md$plate %||% NA}}",
    "*" = "Image:    {.val {md$image %||% NA}}",
    "*" = "Imager:   {.val {md$imager %||% NA}}",
    "*" = "Product:  {.val {md$product %||% NA}}",
    "*" = "Software: v{.val {md$qview_version %||% NA}}",
    "*" = "Template: {.val {md$template %||% NA}}",
    "*" = "Created:  {.val {md$report_created %||% NA}}"
  ))

  cli::cli_h2("Analytes ({nrow(x$analytes)})")
  if (nrow(x$analytes) > 0L) {
    show <- x$analytes
    show$panel <- paste0(show$analyte,
                         ifelse(is.na(show$unit), "",
                                paste0(" (", show$unit, ")")))
    cli::cli_inform(paste(show$panel, collapse = ", "))
  }

  cli::cli_h2("Well groups ({nrow(x$well_groups)})")
  if (nrow(x$well_groups) > 0L) {
    cli::cli_bullets(c(
      "*" = "standard: {.val {sum(x$well_groups$is_standard)}}",
      "*" = "negative: {.val {sum(x$well_groups$is_negative)}}",
      "*" = "control:  {.val {sum(x$well_groups$is_control)}}",
      "*" = "sample:   {.val {sum(x$well_groups$is_sample)}}"
    ))
  }

  cli::cli_h2("Data")
  cli::cli_bullets(c(
    "*" = "replicate rows:    {.val {nrow(x$pixel_intensities)}}",
    "*" = "summary stat rows: {.val {nrow(x$summary_statistics)}}",
    "*" = "concentrations:    {if (is.null(x$concentrations)) 'qualitative only' else paste0(nrow(x$concentrations), ' rows')}",
    "*" = "curve fit:         {if (is.null(x$curve_fit)) 'not reported' else paste0(nrow(x$curve_fit), ' analytes')}"
  ))
  invisible(x)
}


#' Summary statistics for a Q-View object
#'
#' Per-analyte mean, standard deviation, and coefficient of variation
#' (`sd / mean`) of pixel intensities, by well-group type. Calibrator /
#' standard wells are reported separately so calibration variability is
#' easy to inspect.
#'
#' @param object A `qview` object returned by [read_qview()].
#' @param ... Unused; for S3 generic compatibility.
#'
#' @return A [tibble::tibble()] with one row per `well_type` x `analyte`
#'   combination, columns: `well_type`, `analyte`, `unit`, `n`, `mean`,
#'   `sd`, `cv`, `min`, `max`.
#'
#' @examples
#' path <- system.file("extdata", "example.Q-View", package = "qviewparsR")
#' qv <- read_qview(path, verbose = FALSE)
#' summary(qv)
#'
#' @family qview-methods
#' @export
summary.qview <- function(object, ...) {
  rlang::check_dots_empty()
  .check_qview(object)
  pi  <- object$pixel_intensities
  wg  <- object$well_groups[, c("well_group", "well_type"), drop = FALSE]
  if (nrow(pi) == 0L) {
    return(tibble::tibble(
      well_type = factor(character(),
        levels = c("standard", "negative", "sample", "control")),
      analyte = character(), unit = character(),
      n = integer(),
      mean = numeric(), sd = numeric(), cv = numeric(),
      min = numeric(), max = numeric()
    ))
  }
  d <- dplyr::left_join(pi, wg, by = "well_group")
  out <- d |>
    dplyr::group_by(.data$well_type, .data$analyte, .data$unit) |>
    dplyr::summarise(
      n    = dplyr::n(),
      mean = mean(.data$pixel_intensity, na.rm = TRUE),
      sd   = stats::sd(.data$pixel_intensity, na.rm = TRUE),
      min  = suppressWarnings(min(.data$pixel_intensity, na.rm = TRUE)),
      max  = suppressWarnings(max(.data$pixel_intensity, na.rm = TRUE)),
      .groups = "drop"
    )
  out$cv <- ifelse(out$mean > 0, out$sd / out$mean, NA_real_)
  out <- out[, c("well_type", "analyte", "unit", "n",
                 "mean", "sd", "cv", "min", "max")]
  structure(out, class = c("qview_summary", class(out)))
}


#' Print a qview_summary object
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' @param x A `qview_summary` object returned by [summary.qview()].
#' @param ... Unused; for S3 generic compatibility.
#'
#' @return `x`, invisibly.
#'
#' @examples
#' path <- system.file("extdata", "example.Q-View", package = "qviewparsR")
#' qv <- read_qview(path, verbose = FALSE)
#' summary(qv)
#'
#' @family qview-methods
#' @export
print.qview_summary <- function(x, ...) {
  rlang::check_dots_empty()
  cli::cli_h1("Q-View summary")
  cli::cli_text("Mean / SD / CV of pixel intensities, grouped by well type:")
  print(tibble::as_tibble(x))
  invisible(x)
}


#' Coerce a Q-View object to a tibble
#'
#' Returns the long-format `pixel_intensities` table — the primary
#' tabular data carried by a `qview` object. To access other slots
#' (well groups, analyte panel, summary statistics) use `qv$<slot>`
#' directly.
#'
#' @param x A `qview` object returned by [read_qview()].
#' @param ... Unused; for S3 generic compatibility.
#'
#' @return A [tibble::tibble()] of replicate pixel-intensity readings.
#'
#' @examples
#' path <- system.file("extdata", "example.Q-View", package = "qviewparsR")
#' qv <- read_qview(path, verbose = FALSE)
#' tibble::as_tibble(qv)
#'
#' @family qview-methods
#'
#' @importFrom tibble as_tibble
#' @method as_tibble qview
#' @export
as_tibble.qview <- function(x, ...) {
  rlang::check_dots_empty()
  tibble::as_tibble(x$pixel_intensities)
}


#' Plot a Q-View object
#'
#' Quick-look plots for a parsed `qview` object.
#'
#' * `"plate_map"` -- heat-coloured plate map, one cell per well, fill
#'   by well type (standard / negative / sample / control).
#' * `"intensity_heatmap"` -- per-analyte facet, fill by replicate-1
#'   pixel intensity per well.
#' * `"replicate_scatter"` -- replicate 1 vs replicate 2 pixel
#'   intensity per analyte.
#'
#' Requires the `ggplot2` package (Suggested).
#'
#' @param x A `qview` object returned by [read_qview()].
#' @param type One of `"plate_map"`, `"intensity_heatmap"`,
#'   `"replicate_scatter"`. Default `"plate_map"`.
#' @param ... Unused; for S3 generic compatibility.
#'
#' @return A `ggplot` object.
#'
#' @examplesIf requireNamespace("ggplot2", quietly = TRUE)
#' path <- system.file("extdata", "example.Q-View", package = "qviewparsR")
#' qv <- read_qview(path, verbose = FALSE)
#' plot(qv, type = "plate_map")
#' plot(qv, type = "replicate_scatter")
#'
#' @family qview-methods
#'
#' @export
plot.qview <- function(x, type = c("plate_map", "intensity_heatmap",
                                   "replicate_scatter"), ...) {
  rlang::check_dots_empty()
  .check_qview(x)
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort(c(
      "Plotting a {.cls qview} object requires the {.pkg ggplot2} package.",
      "i" = 'Install it with {.code install.packages("ggplot2")}.'
    ))
  }
  type <- match.arg(type)
  switch(type,
    plate_map         = .qv_plot_plate_map(x),
    intensity_heatmap = .qv_plot_intensity_heatmap(x),
    replicate_scatter = .qv_plot_replicate_scatter(x)
  )
}


.qv_plot_plate_map <- function(x) {
  d <- x$plate_layout
  d$plate_col <- factor(d$plate_col, levels = sort(unique(d$plate_col)))
  d$plate_row <- factor(d$plate_row,
                        levels = rev(sort(unique(d$plate_row))))
  ggplot2::ggplot(d, ggplot2::aes(.data$plate_col, .data$plate_row,
                                  fill = .data$well_type)) +
    ggplot2::geom_tile(colour = "grey30") +
    ggplot2::geom_text(ggplot2::aes(label = .data$sample_id),
                       size = 2.5, na.rm = TRUE) +
    ggplot2::scale_fill_viridis_d(option = "D", begin = 0.2, end = 0.85,
                                  na.value = "grey90") +
    ggplot2::labs(title = paste0("Plate map: ", x$metadata$plate %||% ""),
                  x = NULL, y = NULL, fill = "well type") +
    ggplot2::theme_minimal()
}


.qv_plot_intensity_heatmap <- function(x) {
  d <- x$pixel_intensities[x$pixel_intensities$replicate == 1L, ,
                           drop = FALSE]
  if (nrow(d) == 0L) {
    cli::cli_abort("No replicate-1 pixel intensities are available to plot.")
  }
  d$plate_row <- factor(substr(d$well, 1L, 1L),
                        levels = rev(LETTERS[1:8]))
  d$plate_col <- factor(as.integer(substring(d$well, 2L)),
                        levels = 1:12)
  ggplot2::ggplot(d, ggplot2::aes(.data$plate_col, .data$plate_row,
                                  fill = .data$pixel_intensity)) +
    ggplot2::geom_tile() +
    ggplot2::facet_wrap(~ .data$analyte) +
    ggplot2::scale_fill_viridis_c(option = "C", na.value = "grey95") +
    ggplot2::labs(title = "Pixel intensity (Replicate 1) per analyte",
                  x = NULL, y = NULL, fill = "PI") +
    ggplot2::theme_minimal() +
    ggplot2::theme(panel.grid = ggplot2::element_blank())
}


.qv_plot_replicate_scatter <- function(x) {
  reps <- x$pixel_intensities
  if (nrow(reps) == 0L) {
    cli::cli_abort("No replicate pixel intensities are available to plot.")
  }
  # A well-group label can attach to more than one well (e.g. a re-used
  # calibrator position), so a (well_group, analyte, replicate) key may
  # hold several readings; average them rather than letting pivot_wider
  # emit list-columns that downstream ggplot cannot render.
  wide <- tidyr::pivot_wider(
    reps[, c("well_group", "analyte", "replicate", "pixel_intensity")],
    names_from = "replicate",
    values_from = "pixel_intensity",
    names_prefix = "rep_",
    values_fn = function(v) mean(v, na.rm = TRUE)
  )
  if (!all(c("rep_1", "rep_2") %in% colnames(wide))) {
    cli::cli_abort("Need replicate 1 and replicate 2 readings to draw the scatter.")
  }
  ggplot2::ggplot(wide, ggplot2::aes(.data$rep_1, .data$rep_2)) +
    ggplot2::geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
    ggplot2::geom_point(alpha = 0.6) +
    ggplot2::facet_wrap(~ .data$analyte, scales = "free") +
    ggplot2::labs(title = "Replicate concordance",
                  x = "Replicate 1 (PI)",
                  y = "Replicate 2 (PI)") +
    ggplot2::theme_minimal()
}


# --- Per-slot plot helpers used by the Shiny app ----------------------
# Each returns a ggplot object or NULL when the slot has no data.

.qv_plot_analytes <- function(qv) {
  d <- qv$analytes
  if (is.null(d) || nrow(d) == 0L) return(NULL)
  d <- d[!is.na(d$analyte), , drop = FALSE]
  d$label <- factor(d$analyte, levels = d$analyte[order(d$spot_number)])
  ggplot2::ggplot(d, ggplot2::aes(x = .data$label, y = .data$spot_number,
                                  fill = .data$unit)) +
    ggplot2::geom_col() +
    ggplot2::scale_fill_viridis_d(option = "D", begin = 0.2, end = 0.85,
                                  na.value = "grey80") +
    ggplot2::coord_flip() +
    ggplot2::labs(title = "Analyte panel", x = NULL,
                  y = "Spot number", fill = "Unit") +
    ggplot2::theme_minimal()
}

.qv_plot_well_groups <- function(qv) {
  d <- qv$well_groups
  if (is.null(d) || nrow(d) == 0L) return(NULL)
  ggplot2::ggplot(d, ggplot2::aes(x = .data$well_type, fill = .data$well_type)) +
    ggplot2::geom_bar() +
    ggplot2::scale_fill_viridis_d(option = "D", begin = 0.2, end = 0.85) +
    ggplot2::labs(title = "Well groups by type", x = NULL,
                  y = "Number of groups", fill = "Well type") +
    ggplot2::theme_minimal()
}

.qv_plot_summary <- function(qv) {
  s <- summary(qv)
  if (nrow(s) == 0L) return(NULL)
  ggplot2::ggplot(s, ggplot2::aes(x = .data$analyte, y = .data$mean,
                                  fill = .data$well_type)) +
    ggplot2::geom_col(position = "dodge") +
    ggplot2::geom_errorbar(
      ggplot2::aes(ymin = pmax(.data$mean - .data$sd, 0),
                   ymax = .data$mean + .data$sd),
      position = ggplot2::position_dodge(width = 0.9), width = 0.25,
      na.rm = TRUE
    ) +
    ggplot2::scale_fill_viridis_d(option = "D", begin = 0.2, end = 0.85) +
    ggplot2::labs(title = "Mean pixel intensity (+/- SD) by well type",
                  x = NULL, y = "Mean PI", fill = "Well type") +
    ggplot2::theme_minimal() +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 30, hjust = 1))
}

.qv_plot_concentrations <- function(qv) {
  d <- qv$concentrations
  if (is.null(d) || nrow(d) == 0L) return(NULL)
  ggplot2::ggplot(d, ggplot2::aes(x = .data$well_group, y = .data$concentration,
                                  fill = .data$analyte)) +
    ggplot2::geom_col(position = "dodge") +
    ggplot2::scale_fill_viridis_d(option = "D", begin = 0.2, end = 0.85) +
    ggplot2::labs(title = "Back-calculated concentrations",
                  x = NULL, y = "Concentration", fill = "Analyte") +
    ggplot2::theme_minimal() +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 90, hjust = 1, vjust = 0.5))
}

.qv_plot_curve_fit <- function(qv) {
  d <- qv$curve_fit
  if (is.null(d) || nrow(d) == 0L) return(NULL)
  d$model <- factor(ifelse(is.na(d$regression_model) | !nzchar(d$regression_model),
                           "(none)", d$regression_model))
  ggplot2::ggplot(d, ggplot2::aes(x = stats::reorder(.data$analyte, .data$spot_number),
                                  y = 1, fill = .data$model)) +
    ggplot2::geom_tile(colour = "grey30") +
    ggplot2::geom_text(ggplot2::aes(label = .data$model), size = 3) +
    ggplot2::scale_fill_viridis_d(option = "D", begin = 0.2, end = 0.85) +
    ggplot2::coord_flip() +
    ggplot2::labs(title = "Regression model per analyte",
                  x = NULL, y = NULL, fill = "Model") +
    ggplot2::theme_minimal() +
    ggplot2::theme(axis.text.x = ggplot2::element_blank(),
                   axis.ticks.x = ggplot2::element_blank())
}

.qv_plot_template <- function(template) {
  if (is.null(template) || nrow(template) == 0L) return(NULL)
  d <- template
  d$plate_col <- factor(d$plate_col, levels = sort(unique(d$plate_col)))
  d$plate_row <- factor(d$plate_row, levels = rev(sort(unique(d$plate_row))))
  ggplot2::ggplot(d, ggplot2::aes(.data$plate_col, .data$plate_row,
                                  fill = .data$group_type)) +
    ggplot2::geom_tile(colour = "grey30") +
    ggplot2::geom_text(ggplot2::aes(label = .data$sample_id),
                       size = 2.5, na.rm = TRUE) +
    ggplot2::scale_fill_viridis_d(option = "D", begin = 0.2, end = 0.85,
                                  na.value = "grey90") +
    ggplot2::labs(title = "Plate template", x = NULL, y = NULL,
                  fill = "Group type") +
    ggplot2::theme_minimal()
}

.qv_plot_distribution <- function(qv) {
  d <- qv$pixel_intensities
  if (is.null(d) || nrow(d) == 0L) return(NULL)
  d <- d[!is.na(d$pixel_intensity) & d$analyte != "Ref Spot", , drop = FALSE]
  if (nrow(d) == 0L) return(NULL)
  d$analyte <- factor(d$analyte, levels = unique(d$analyte))
  ggplot2::ggplot(d, ggplot2::aes(x = .data$analyte,
                                  y = .data$pixel_intensity,
                                  fill = .data$analyte)) +
    ggplot2::geom_boxplot(outlier.size = 0.6, alpha = 0.85,
                          colour = "grey20") +
    ggplot2::scale_fill_viridis_d(option = "D", begin = 0.2, end = 0.85,
                                  guide = "none") +
    ggplot2::labs(x = NULL, y = "Pixel intensity") +
    ggplot2::theme_minimal(base_size = 10) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 30, hjust = 1))
}


.qv_plot_overview <- function(qv) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort('Package {.pkg ggplot2} is required. Install with {.code install.packages("ggplot2")}.')
  }
  if (!requireNamespace("patchwork", quietly = TRUE)) {
    cli::cli_abort(c(
      "Package {.pkg patchwork} is required for the overview figure.",
      "i" = 'Install with {.code install.packages("patchwork")}.'
    ))
  }
  base_thm <- ggplot2::theme_minimal(base_size = 10) +
    ggplot2::theme(plot.title = ggplot2::element_text(face = "bold", size = 11),
                   plot.tag   = ggplot2::element_text(face = "bold", size = 12),
                   legend.position = "right")

  p1 <- .qv_plot_plate_map(qv)
  if (!is.null(p1)) p1 <- p1 +
    ggplot2::labs(title = "Plate layout", subtitle = NULL) +
    base_thm +
    ggplot2::theme(axis.text = ggplot2::element_text(size = 7))

  p2 <- .qv_plot_distribution(qv)
  if (!is.null(p2)) p2 <- p2 +
    ggplot2::labs(title = "Pixel-intensity distribution") + base_thm +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 30, hjust = 1))

  p3 <- .qv_plot_replicate_scatter(qv)
  if (!is.null(p3)) p3 <- p3 +
    ggplot2::labs(title = "Replicate concordance",
                  x = "Replicate 1 (PI)", y = "Replicate 2 (PI)") + base_thm

  p4 <- .qv_plot_summary(qv)
  if (!is.null(p4)) p4 <- p4 +
    ggplot2::labs(title = "Mean PI (+/- SD) by well type") + base_thm

  fallback <- function(label) {
    ggplot2::ggplot() +
      ggplot2::annotate("text", x = 0.5, y = 0.5,
                        label = label, size = 4, colour = "grey50") +
      ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1) +
      ggplot2::theme_void()
  }
  if (is.null(p1)) p1 <- fallback("Plate layout unavailable")
  if (is.null(p2)) p2 <- fallback("No pixel intensities to plot")
  if (is.null(p3)) p3 <- fallback("Replicate scatter requires rep 1 & 2")
  if (is.null(p4)) p4 <- fallback("No summary statistics available")

  md <- qv$metadata
  hdr <- paste0(
    md$project %||% "Q-View project",
    if (!is.null(md$plate) && !is.na(md$plate)) paste0(" - ", md$plate) else "",
    if (!is.null(md$image) && !is.na(md$image)) paste0(" (", md$image, ")") else ""
  )

  patchwork::wrap_plots(p1, p2, p3, p4, ncol = 2L, nrow = 2L) +
    patchwork::plot_annotation(
      title    = hdr,
      subtitle = "Publication overview: layout, distribution, replicate concordance, group means",
      tag_levels = "A",
      theme = ggplot2::theme(
        plot.title    = ggplot2::element_text(face = "bold", size = 13),
        plot.subtitle = ggplot2::element_text(colour = "grey30", size = 10)
      )
    )
}


.qv_blank_plot <- function(text) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) return(invisible())
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0.5, y = 0.5, label = text,
                      size = 4, colour = "grey40", lineheight = 1.1) +
    ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1) +
    ggplot2::theme_void()
}


.qv_metadata_kv <- function(qv) {
  md <- qv$metadata
  tibble::tibble(
    field = names(md),
    value = vapply(md, function(v) {
      if (length(v) == 0L) return(NA_character_)
      paste(format(v), collapse = "; ")
    }, character(1L))
  )
}


# null-coalescing helper local to this file (keeps R >= 4.1 compatibility).
`%||%` <- function(a, b) if (is.null(a) || (length(a) == 1L && is.na(a))) b else a
