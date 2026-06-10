# Plot a Q-View object

Quick-look plots for a parsed `qview` object.

## Usage

``` r
# S3 method for class 'qview'
plot(x, type = c("plate_map", "intensity_heatmap", "replicate_scatter"), ...)
```

## Arguments

- x:

  A `qview` object returned by
  [`read_qview()`](https://cttir.github.io/qviewparsR/reference/read_qview.md).

- type:

  One of `"plate_map"`, `"intensity_heatmap"`, `"replicate_scatter"`.
  Default `"plate_map"`.

- ...:

  Unused; for S3 generic compatibility.

## Value

A `ggplot` object.

## Details

- `"plate_map"` – heat-coloured plate map, one cell per well, fill by
  well type (standard / negative / sample / control).

- `"intensity_heatmap"` – per-analyte facet, fill by replicate-1 pixel
  intensity per well.

- `"replicate_scatter"` – replicate 1 vs replicate 2 pixel intensity per
  analyte.

Requires the `ggplot2` package (Suggested).

## See also

Other qview-methods:
[`as_tibble.qview()`](https://cttir.github.io/qviewparsR/reference/as_tibble.qview.md),
[`is_qview()`](https://cttir.github.io/qviewparsR/reference/is_qview.md),
[`print.qview()`](https://cttir.github.io/qviewparsR/reference/print.qview.md),
[`summary.qview()`](https://cttir.github.io/qviewparsR/reference/summary.qview.md)

## Examples

``` r
path <- system.file("extdata", "example.Q-View", package = "qviewparsR")
qv <- read_qview(path, verbose = FALSE)
plot(qv, type = "plate_map")

plot(qv, type = "replicate_scatter")
```
