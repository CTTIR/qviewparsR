# Write a Q-View object to a multi-sheet Excel workbook

Write a Q-View object to a multi-sheet Excel workbook

## Usage

``` r
qview_to_xlsx(qv, path, template = NULL)
```

## Arguments

- qv:

  A `qview` object from
  [`read_qview()`](https://r-heller.github.io/qviewparsR/reference/read_qview.md).

- path:

  Output `.xlsx` path.

- template:

  Optional plate-template tibble (from
  [`read_qview_template()`](https://r-heller.github.io/qviewparsR/reference/read_qview_template.md))
  to include as an extra sheet.

## Value

`path`, invisibly.
