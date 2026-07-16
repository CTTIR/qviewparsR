# qviewparsR 0.1.8

## New features

* `read_qview_report()` reads the **flat report exports** Q-View writes next
  to the binary container -- the `..._auto_report` and
  `..._auto_all-parameters_report` files, as either `.csv` or `.xlsx` -- and
  returns the same `qview` object `read_qview()` builds. Use it when only the
  exports were kept and the original `.Q-View` project file is unavailable.
  It differs from `read_qview()` in two deliberate ways:
    * it captures the plain `"Reduced Concentration"` **point estimate**
      (one row per sample) with `statistic == "reduced"`; and
    * it **preserves out-of-range cells** instead of dropping them: a
      `"< 52.50"` cell yields `concentration = 52.50` with a new `flag`
      column set to `"<"` (`">"` for upper bound, `"incalculable"` for
      `Incalculable`), so limit-of-quantification information survives import.
  A small `example-report.csv` fixture ships in `inst/extdata/`.

# qviewparsR 0.1.8

Initial release. Pure-R parser for `.Q-View` binary project files
(chemiluminescent multiplex ELISA plate imaging and quantification).
No Java runtime, no H2 database driver, no compiled code.

## Reliability

* `read_qview()` now resolves the superseded MVCC page versions that the
  embedded H2 container retains. A version truncated at a 2048-byte page
  boundary (fewer analytes, or a number cut mid-digit) is no longer
  mistaken for the current reading: for each physical
  (well, replicate, analyte) the value occurring most often across the
  committed page copies wins, breaking ties toward the most complete
  source row. Per-well pixel intensities now match Q-View's own grid
  exports to 1e-6, and each well appears once in `plate_layout`.
* `read_qview_template()` auto-detects the field separator, so
  semicolon-delimited (European-locale) and tab-delimited templates
  parse the same as comma-delimited ones.
* `plot(type = "replicate_scatter")` no longer errors when a well-group
  label maps to more than one well; duplicate readings are averaged.

## Reader

* `read_qview(path, strip_prefix = FALSE)`: parses a `.Q-View` container
  and returns a list of class `qview` with project metadata, the
  analyte panel (units, LOD / LLOQ / ULOQ, assay-control range),
  well-group sample assignments, per-well replicate pixel intensities,
  summary statistics, optional back-calculated concentrations, curve
  fits, and a plate layout (all tidy tibbles).
* `read_qview_template()`: parses the companion well-assignment
  template CSV (NxM layout with Group Name / Group Type /
  Dilution Factor sections).

## Helpers

* `strip_qview_prefix()`: reverses the producer-side naming convention
  (`ICal N` -> `Cal N`, `GLow` -> `Low`, `HHigh` -> `High`,
  `NFD...` / `N1234...` -> original sample ID).
* `well_label()`: vectorised plate-coordinate helper.

## Methods

* `is_qview()`: predicate for the S3 class.
* `print.qview()`: compact one-screen summary.
* `summary.qview()`: per-analyte mean / SD / CV / min / max grouped by
  well type, returned as a `qview_summary` tibble with its own print
  method.
* `plot.qview(type = ...)`: quick-look plate map, per-analyte intensity
  heatmap, and replicate-1-vs-2 scatter; viridis throughout.
* `as_tibble.qview()`: long-format pixel-intensity tibble.

## Export

* `write_qview_xlsx()`, `write_qview_csv()`, `write_qview_rds()`:
  pipe-friendly writers that return the parsed object invisibly.
  `qview_to_xlsx()` / `qview_to_csv_dir()` are kept as
  `lifecycle::deprecate_warn()` aliases for back-compatibility.

## Interactive front-end

* `qview_app()`: monochrome bslib Shiny app with built-in dark/light
  toggle, hex-sticker brand, large upload cap (default 512 MB),
  per-table xlsx download, and a publication-ready 2x2 Overview tab
  (plate layout / pixel-intensity distribution / replicate concordance
  / mean PI by well type) with high-DPI PNG and vector PDF export.
