# Read a Quansys Q-View project file

Parses a `.Q-View` binary container (a Q-View Software v3.x project file
holding an embedded H2 database plus binary LOB segments) and extracts
ELISA / multiplex assay data: project metadata, analyte panel with
units, well-group sample assignments, per-well replicate pixel
intensities, summary statistics, and (when present) the embedded CSV
report.

## Usage

``` r
read_qview(path, strip_prefix = FALSE, verbose = TRUE)
```

## Arguments

- path:

  Character. Path to the `.Q-View` file.

- strip_prefix:

  Logical. If `TRUE`, reverse Q-View's internal naming convention via
  [`strip_qview_prefix()`](https://r-heller.github.io/qviewparsR/reference/strip_qview_prefix.md)
  so identifiers match the original well-assignment template. Default
  `FALSE`.

- verbose:

  Logical. Print a short summary after parsing. Default `TRUE`.

## Value

A list with class `"qview"` containing:

- `metadata`:

  Named list: `project`, `plate`, `image`, `imager`, `product`, `user`,
  `report_created`, `qview_version`, `template`, `container_version`,
  `file_path`, `parsed_at`.

- `manifest`:

  Tibble with one row per declared file entry (`name`, `size_bytes`,
  `parent`).

- `segments`:

  Tibble of H2 segment byte ranges (`segment`, `start`, `end`, `size`).

- `analytes`:

  Tibble: `spot_number`, `analyte`, `unit`, plus `lod`, `lloq`, `uloq`,
  `assay_control_low`, `assay_control_high` when reported.

- `well_groups`:

  Tibble: `well_group`, `sample_id`, `is_standard`, `is_negative`,
  `is_sample`, `is_control`, `well_type`.

- `pixel_intensities`:

  Long-format tibble of replicate readings: `well_group`, `sample_id`,
  `well`, `replicate`, `analyte`, `unit`, `pixel_intensity`, `dilution`.

- `summary_statistics`:

  Long-format tibble of per-group averages, std-dev, and CV statistics:
  `well_group`, `sample_id`, `statistic`, `analyte`, `value`, `unit`.

- `concentrations`:

  Long-format concentration tibble or `NULL` if the regression model is
  `"Qualitative"`.

- `curve_fit`:

  Tibble with `analyte`, `regression_model`, or `NULL` if not reported.

- `report_csv`:

  Character vector of the raw CSV report lines, or `NULL` if no report
  was generated.

- `plate_layout`:

  Tibble with one row per well: `well`, `plate_row`, `plate_col`,
  `well_group`, `sample_id`, `well_type`, `dilution`.

## Details

The file format is reverse-engineered from public binary inspection: it
begins with a plain-text manifest, followed by three concatenated H2
database segments. The fully-formatted report Q-View renders for the
user is stored as a CLOB inside the main H2 segment. This parser scans
the binary for that CLOB, reassembles it across H2 page boundaries
(2048-byte pages), and parses it as CSV.

Parsing is done in pure R: no Java runtime, no H2 database driver, no
system dependencies beyond a working R installation.

## See also

[`strip_qview_prefix()`](https://r-heller.github.io/qviewparsR/reference/strip_qview_prefix.md),
[`read_qview_template()`](https://r-heller.github.io/qviewparsR/reference/read_qview_template.md),
[`print.qview()`](https://r-heller.github.io/qviewparsR/reference/print.qview.md),
[`plot.qview()`](https://r-heller.github.io/qviewparsR/reference/plot.qview.md).

## Examples

``` r
if (FALSE) { # \dontrun{
  qv <- read_qview("plate.Q-View")
  qv
  qv$analytes
  qv$pixel_intensities
  plot(qv, type = "plate_map")
} # }
```
