## ----setup, include = FALSE---------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  eval = FALSE
)
library(qviewparsR)


## -----------------------------------------------------------------------------
# install.packages("pak")
pak::pak("CTTIR/qviewparsR")


## -----------------------------------------------------------------------------
library(qviewparsR)

qv <- read_qview("path/to/plate.Q-View")
qv                          # one-screen summary

qv$analytes                 # spot_number, analyte, unit, lod, lloq, uloq
qv$well_groups              # one row per sample/calibrator/control
qv$pixel_intensities        # long-format replicate readings
qv$summary_statistics       # per-group mean / std-dev / CV rows
qv$plate_layout             # one row per plate well

summary(qv)                 # mean / SD / CV per well type x analyte


## -----------------------------------------------------------------------------
qv <- read_qview("path/to/plate.Q-View", strip_prefix = TRUE)
unique(qv$well_groups$sample_id)


## -----------------------------------------------------------------------------
strip_qview_prefix(c("ICal 1", "GLow", "HHigh", "NFD24277364"))
#> [1] "Cal 1"      "Low"        "High"       "FD24277364"


## -----------------------------------------------------------------------------
library(dplyr)
library(tibble)

qv |>
  as_tibble() |>
  filter(replicate == 1L) |>
  group_by(analyte, unit) |>
  summarise(median_pi = median(pixel_intensity, na.rm = TRUE),
            .groups = "drop")


## -----------------------------------------------------------------------------
is_qview(qv)      # TRUE
is_qview(list())  # FALSE


## -----------------------------------------------------------------------------
plot(qv, type = "plate_map")          # 96-well plate, fill = well type
plot(qv, type = "intensity_heatmap")  # facet per analyte, fill = PI
plot(qv, type = "replicate_scatter")  # rep 1 vs rep 2 per analyte


## -----------------------------------------------------------------------------
library(ggplot2)
plot(qv, type = "plate_map") +
  theme_bw(base_size = 12) +
  labs(title = NULL, subtitle = "QC overview")


## -----------------------------------------------------------------------------
qv |>
  write_qview_xlsx("plate.xlsx") |>      # one sheet per parsed table
  write_qview_csv ("plate_csv/") |>      # one CSV file per parsed table
  write_qview_rds ("plate.rds")          # full lossless R round-trip


## -----------------------------------------------------------------------------
tmpl <- read_qview_template("path/to/template.csv")

qv$plate_layout |>
  dplyr::left_join(tmpl, by = "well", suffix = c("_qview", "_template")) |>
  dplyr::filter(sample_id_qview != sample_id_template)


## -----------------------------------------------------------------------------
qview_app()

