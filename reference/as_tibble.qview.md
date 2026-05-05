# Coerce a Q-View object to a tibble

Returns the long-format `pixel_intensities` table — the primary tabular
data carried by a `qview` object. To access other slots (well groups,
analyte panel, summary statistics) use `qv$<slot>` directly.

## Usage

``` r
# S3 method for class 'qview'
as_tibble(x, ...)
```

## Arguments

- x:

  A `qview` object returned by
  [`read_qview()`](https://cttir.github.io/qviewparsR/reference/read_qview.md).

- ...:

  Unused; for S3 generic compatibility.

## Value

A
[`tibble::tibble()`](https://tibble.tidyverse.org/reference/tibble.html)
of replicate pixel-intensity readings.

## See also

Other qview-methods:
[`is_qview()`](https://cttir.github.io/qviewparsR/reference/is_qview.md),
[`plot.qview()`](https://cttir.github.io/qviewparsR/reference/plot.qview.md),
[`print.qview()`](https://cttir.github.io/qviewparsR/reference/print.qview.md),
[`summary.qview()`](https://cttir.github.io/qviewparsR/reference/summary.qview.md)
