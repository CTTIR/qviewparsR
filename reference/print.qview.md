# Print a Q-View object

Compact summary of a parsed `qview` object: project / plate identifiers,
analyte panel, well-group counts by type, and whether the embedded
report carries quantitative concentrations or only qualitative pixel
intensities.

## Usage

``` r
# S3 method for class 'qview'
print(x, ...)
```

## Arguments

- x:

  A `qview` object returned by
  [`read_qview()`](https://cttir.github.io/qviewparsR/reference/read_qview.md).

- ...:

  Ignored.

## Value

`x`, invisibly.

## See also

Other qview-methods:
[`as_tibble.qview()`](https://cttir.github.io/qviewparsR/reference/as_tibble.qview.md),
[`is_qview()`](https://cttir.github.io/qviewparsR/reference/is_qview.md),
[`plot.qview()`](https://cttir.github.io/qviewparsR/reference/plot.qview.md),
[`summary.qview()`](https://cttir.github.io/qviewparsR/reference/summary.qview.md)
