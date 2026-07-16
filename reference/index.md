# Package index

## Reader

Parse a Q-View binary project file, or its flat report exports.

- [`read_qview()`](https://cttir.github.io/qviewparsR/reference/read_qview.md)
  **\[experimental\]** : Read a .Q-View project file
- [`read_qview_report()`](https://cttir.github.io/qviewparsR/reference/read_qview_report.md)
  **\[experimental\]** : Read a Q-View report export (CSV or XLSX)

## Helpers

Naming convention and plate-coordinate utilities.

- [`strip_qview_prefix()`](https://cttir.github.io/qviewparsR/reference/strip_qview_prefix.md)
  **\[experimental\]** : Reverse the Q-View internal naming convention
- [`well_label()`](https://cttir.github.io/qviewparsR/reference/well_label.md)
  **\[experimental\]** : Convert plate row / column to a well label
- [`read_qview_template()`](https://cttir.github.io/qviewparsR/reference/read_qview_template.md)
  **\[experimental\]** : Read a Q-View well-assignment template CSV

## Methods

Print, summarise, plot, and coerce a parsed `qview` object.

- [`is_qview()`](https://cttir.github.io/qviewparsR/reference/is_qview.md)
  **\[experimental\]** :

  Test whether an object is a `qview`

- [`print(`*`<qview>`*`)`](https://cttir.github.io/qviewparsR/reference/print.qview.md)
  : Print a Q-View object

- [`print(`*`<qview_summary>`*`)`](https://cttir.github.io/qviewparsR/reference/print.qview_summary.md)
  **\[experimental\]** : Print a qview_summary object

- [`summary(`*`<qview>`*`)`](https://cttir.github.io/qviewparsR/reference/summary.qview.md)
  : Summary statistics for a Q-View object

- [`plot(`*`<qview>`*`)`](https://cttir.github.io/qviewparsR/reference/plot.qview.md)
  : Plot a Q-View object

- [`as_tibble(`*`<qview>`*`)`](https://cttir.github.io/qviewparsR/reference/as_tibble.qview.md)
  : Coerce a Q-View object to a tibble

## Export

Write a parsed `qview` object to disk.

- [`write_qview_xlsx()`](https://cttir.github.io/qviewparsR/reference/write_qview.md)
  [`write_qview_csv()`](https://cttir.github.io/qviewparsR/reference/write_qview.md)
  [`write_qview_rds()`](https://cttir.github.io/qviewparsR/reference/write_qview.md)
  [`qview_to_xlsx()`](https://cttir.github.io/qviewparsR/reference/write_qview.md)
  [`qview_to_csv_dir()`](https://cttir.github.io/qviewparsR/reference/write_qview.md)
  **\[experimental\]** : Write a Q-View object to disk

## Shiny app

Upload, preview, visualise, and download a `.Q-View` file.

- [`qview_app()`](https://cttir.github.io/qviewparsR/reference/qview_app.md)
  **\[experimental\]** : Launch the qviewparsR Q-View Shiny app

## Package

- [`qviewparsR`](https://cttir.github.io/qviewparsR/reference/qviewparsR-package.md)
  [`qviewparsR-package`](https://cttir.github.io/qviewparsR/reference/qviewparsR-package.md)
  **\[experimental\]** : qviewparsR: Read .Q-View Multiplex ELISA
  Project Files
