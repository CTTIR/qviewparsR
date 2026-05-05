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
  [`read_qview()`](https://r-heller.github.io/qviewparsR/reference/read_qview.md).

- type:

  One of `"plate_map"`, `"intensity_heatmap"`, `"replicate_scatter"`.
  Default `"plate_map"`.

- ...:

  Ignored.

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
