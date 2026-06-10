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

## Examples

``` r
path <- system.file("extdata", "example.Q-View", package = "qviewparsR")
qv <- read_qview(path, verbose = FALSE)
tibble::as_tibble(qv)
#> # A tibble: 20 × 8
#>    well_group sample_id well  replicate analyte unit  pixel_intensity dilution
#>    <chr>      <chr>     <chr>     <int> <chr>   <chr>           <dbl>    <dbl>
#>  1 ICal 1     ICal 1    A1            1 Ba      ng/ml            8671       NA
#>  2 ICal 1     ICal 1    A1            1 Bb      ug/ml           19982       NA
#>  3 ICal 1     ICal 1    A2            2 Ba      ng/ml           17838       NA
#>  4 ICal 1     ICal 1    A2            2 Bb      ug/ml           23848       NA
#>  5 N12345     N12345    A3            1 Ba      ng/ml            1200       NA
#>  6 N12345     N12345    A3            1 Bb      ug/ml            1300       NA
#>  7 N12345     N12345    A4            2 Ba      ng/ml            1250       NA
#>  8 N12345     N12345    A4            2 Bb      ug/ml            1350       NA
#>  9 ICal 2     ICal 2    B1            1 Ba      ng/ml            4000       NA
#> 10 ICal 2     ICal 2    B1            1 Bb      ug/ml            5000       NA
#> 11 ICal 2     ICal 2    B2            2 Ba      ng/ml            4100       NA
#> 12 ICal 2     ICal 2    B2            2 Bb      ug/ml            5100       NA
#> 13 GLow       GLow      G1            1 Ba      ng/ml             300       NA
#> 14 GLow       GLow      G1            1 Bb      ug/ml             400       NA
#> 15 GLow       GLow      G2            2 Ba      ng/ml             310       NA
#> 16 GLow       GLow      G2            2 Bb      ug/ml             410       NA
#> 17 HHigh      HHigh     H1            1 Ba      ng/ml           12000       NA
#> 18 HHigh      HHigh     H1            1 Bb      ug/ml           15000       NA
#> 19 HHigh      HHigh     H2            2 Ba      ng/ml           12100       NA
#> 20 HHigh      HHigh     H2            2 Bb      ug/ml           15100       NA
```
