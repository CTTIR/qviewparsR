# Summary statistics for a Q-View object

Per-analyte mean, standard deviation, and coefficient of variation
(`sd / mean`) of pixel intensities, by well-group type. Calibrator /
standard wells are reported separately so calibration variability is
easy to inspect.

## Usage

``` r
# S3 method for class 'qview'
summary(object, ...)
```

## Arguments

- object:

  A `qview` object returned by
  [`read_qview()`](https://cttir.github.io/qviewparsR/reference/read_qview.md).

- ...:

  Unused; for S3 generic compatibility.

## Value

A
[`tibble::tibble()`](https://tibble.tidyverse.org/reference/tibble.html)
with one row per `well_type` x `analyte` combination, columns:
`well_type`, `analyte`, `unit`, `n`, `mean`, `sd`, `cv`, `min`, `max`.

## See also

Other qview-methods:
[`as_tibble.qview()`](https://cttir.github.io/qviewparsR/reference/as_tibble.qview.md),
[`is_qview()`](https://cttir.github.io/qviewparsR/reference/is_qview.md),
[`plot.qview()`](https://cttir.github.io/qviewparsR/reference/plot.qview.md),
[`print.qview()`](https://cttir.github.io/qviewparsR/reference/print.qview.md)
