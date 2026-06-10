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

## Examples

``` r
path <- system.file("extdata", "example.Q-View", package = "qviewparsR")
qv <- read_qview(path, verbose = FALSE)
summary(qv)
#> 
#> ── Q-View summary ──────────────────────────────────────────────────────────────
#> Mean / SD / CV of pixel intensities, grouped by well type:
#> # A tibble: 8 × 9
#>   well_type analyte unit      n   mean      sd      cv   min   max
#>   <fct>     <chr>   <chr> <int>  <dbl>   <dbl>   <dbl> <dbl> <dbl>
#> 1 standard  Ba      ng/ml     4  8652. 6500.   0.751    4000 17838
#> 2 standard  Bb      ug/ml     4 13482. 9864.   0.732    5000 23848
#> 3 negative  Ba      ng/ml     2   305     7.07 0.0232    300   310
#> 4 negative  Bb      ug/ml     2   405     7.07 0.0175    400   410
#> 5 sample    Ba      ng/ml     2  1225    35.4  0.0289   1200  1250
#> 6 sample    Bb      ug/ml     2  1325    35.4  0.0267   1300  1350
#> 7 control   Ba      ng/ml     2 12050    70.7  0.00587 12000 12100
#> 8 control   Bb      ug/ml     2 15050    70.7  0.00470 15000 15100
```
