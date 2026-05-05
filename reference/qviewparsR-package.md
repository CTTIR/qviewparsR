# qviewparsR: Read .Q-View Multiplex ELISA Project Files

Pure-R parser for `.Q-View` binary project files used in
chemiluminescent multiplex ELISA plate imaging and quantification.
Extracts pixel intensities, analyte mappings, sample assignments, plate
layout, optional curve-fit parameters, and the embedded CSV report from
the H2 database container format. Returns tidy tibbles ready for
downstream statistical analysis.

## Main functions

- Reader:
  [`read_qview()`](https://r-heller.github.io/qviewparsR/reference/read_qview.md)
  – parse a `.Q-View` file.

- Helpers:
  [`strip_qview_prefix()`](https://r-heller.github.io/qviewparsR/reference/strip_qview_prefix.md)
  reverse the Q-View internal naming convention;
  [`well_label()`](https://r-heller.github.io/qviewparsR/reference/well_label.md)
  map (row, column) to plate notation.

- Optional:
  [`read_qview_template()`](https://r-heller.github.io/qviewparsR/reference/read_qview_template.md)
  parse a Q-View well-assignment template CSV.

- Methods:
  [`print.qview()`](https://r-heller.github.io/qviewparsR/reference/print.qview.md),
  [`plot.qview()`](https://r-heller.github.io/qviewparsR/reference/plot.qview.md).

- Shiny:
  [`qview_app()`](https://r-heller.github.io/qviewparsR/reference/qview_app.md)
  interactive upload / preview / download.

## See also

Useful links:

- <https://github.com/r-heller/qviewparsR>

- <https://r-heller.github.io/qviewparsR/>

- Report bugs at <https://github.com/r-heller/qviewparsR/issues>

## Author

**Maintainer**: Raban Heller <raban.heller@charite.de>
([ORCID](https://orcid.org/0000-0001-8006-9742)) \[copyright holder\]
