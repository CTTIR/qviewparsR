# comparsR 1.0.0

Major restructure: the package is now exclusively a parser for `.Q-View`
binary project files produced by Quansys Biosciences Q-View Software.
All previous panel-specific readers, normalisation, derivation, and
build helpers have been removed.

## New

* `read_qview(path, strip_prefix = FALSE)`: pure-R parser for the
  `.Q-View` container format. Returns a list with class `qview`
  containing project metadata, the analyte panel with units and
  detection limits, well-group sample assignments, per-well
  replicate pixel intensities, summary statistics, optional
  back-calculated concentrations, curve fits, and a plate layout.
* `strip_qview_prefix()`: reverses Q-View's internal naming
  convention (`ICal N` -> `Cal N`, `GLow` -> `Low`, `HHigh` -> `High`,
  `NFD...` / `N1234...` -> the original ID).
* `read_qview_template()`: parser for the well-assignment template
  CSV (12x8 layout with `Group Name`, `Group Type`, `Dilution Factor`
  sections).
* `well_label()`: vectorised plate-coordinate helper.
* `print.qview()` and `plot.qview()`: compact summary and quick-look
  plots (plate map, per-analyte intensity heatmap, replicate scatter).
* `qview_to_xlsx()` and `qview_to_csv_dir()`: export a parsed `qview`
  object to a multi-sheet workbook or a directory of CSV files.
* `qview_app()`: Shiny front-end for upload, parsing, preview, and
  download.

## Removed

* `cp_read_complement()`, `cp_read_neuroaxonal()`, `cp_read_metadata()`,
  `cp_read_controls()`, `cp_read_auto()` and the panel-specific
  fixtures and tests.
* `cp_build()`, `cp_normalize()`, `cp_derive()`, `cp_validate()`,
  `cp_summary()`.
* `cp_export_xlsx()`, `cp_export_csv()`, `cp_export_rds()`.
* `cp_example_data()`, `cp_example_files()`, `cp_timepoint_map()`,
  `cp_analyte_info()`.
