# qviewparsR: Read .Q-View Multiplex ELISA Project Files

**\[experimental\]**

Pure-R parser for `.Q-View` binary project files used in
chemiluminescent multiplex ELISA plate imaging and quantification.
Extracts pixel intensities, analyte mappings, sample assignments, plate
layout, optional curve-fit parameters, and the embedded CSV report from
the H2 database container format. Returns tidy tibbles ready for
downstream statistical analysis.

## Main functions

- Reader:
  [`read_qview()`](https://cttir.github.io/qviewparsR/reference/read_qview.md)
  – parse a `.Q-View` file.

- Helpers:
  [`strip_qview_prefix()`](https://cttir.github.io/qviewparsR/reference/strip_qview_prefix.md)
  reverse the Q-View internal naming convention;
  [`well_label()`](https://cttir.github.io/qviewparsR/reference/well_label.md)
  map (row, column) to plate notation.

- Optional:
  [`read_qview_template()`](https://cttir.github.io/qviewparsR/reference/read_qview_template.md)
  parse a Q-View well-assignment template CSV.

- Methods:
  [`is_qview()`](https://cttir.github.io/qviewparsR/reference/is_qview.md),
  [`print.qview()`](https://cttir.github.io/qviewparsR/reference/print.qview.md),
  [`plot.qview()`](https://cttir.github.io/qviewparsR/reference/plot.qview.md),
  [`as_tibble.qview()`](https://cttir.github.io/qviewparsR/reference/as_tibble.qview.md).

- Shiny:
  [`qview_app()`](https://cttir.github.io/qviewparsR/reference/qview_app.md)
  interactive upload / preview / download.

## See also

Useful links:

- <https://github.com/CTTIR/qviewparsR>

- <https://cttir.github.io/qviewparsR/>

- Report bugs at <https://github.com/CTTIR/qviewparsR/issues>

## Author

**Maintainer**: R. Heller <raban.heller@uni-ulm.de>
([ORCID](https://orcid.org/0000-0001-8006-9742)) \[copyright holder\]

Authors:

- R. Heller <raban.heller@uni-ulm.de>
  ([ORCID](https://orcid.org/0000-0001-8006-9742)) \[copyright holder\]

- M. Mannes ([ORCID](https://orcid.org/0009-0003-4875-8275)) \[copyright
  holder\]
