# Write a Q-View object as a directory of CSV files

Write a Q-View object as a directory of CSV files

## Usage

``` r
qview_to_csv_dir(qv, dir, template = NULL)
```

## Arguments

- qv:

  A `qview` object from
  [`read_qview()`](https://r-heller.github.io/qviewparsR/reference/read_qview.md).

- dir:

  Output directory (created if it does not exist).

- template:

  Optional plate-template tibble to include.

## Value

Vector of file paths written, invisibly.
