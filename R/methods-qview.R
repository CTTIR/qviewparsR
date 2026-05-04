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
#' @export
print.qview <- function(x, ...) {
  md <- x$metadata
  cli::cli_h1("Q-View project: {.val {md$project %||% NA}}")
  cli::cli_bullets(c(
    "*" = "Plate:    {.val {md$plate %||% NA}}",
    "*" = "Image:    {.val {md$image %||% NA}}",
    "*" = "Imager:   {.val {md$imager %||% NA}}",
    "*" = "Product:  {.val {md$product %||% NA}}",
    "*" = "Software: {.val Q-View} v{.val {md$qview_version %||% NA}}",
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
#' @param ... Ignored.
#'
#' @return A `ggplot` object.
#'
#' @export
plot.qview <- function(x, type = c("plate_map", "intensity_heatmap",
                                   "replicate_scatter"), ...) {
  type <- match.arg(type)
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg ggplot2} is required for plot.qview(). Install with {.code install.packages(\"ggplot2\")}.")
  }
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
    ggplot2::scale_fill_brewer(palette = "Set2", na.value = "grey95") +
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
  wide <- tidyr::pivot_wider(
    reps[, c("well_group", "analyte", "replicate", "pixel_intensity")],
    names_from = "replicate",
    values_from = "pixel_intensity",
    names_prefix = "rep_"
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


# null-coalescing helper local to this file (keeps R >= 4.1 compatibility).
`%||%` <- function(a, b) if (is.null(a) || (length(a) == 1L && is.na(a))) b else a
