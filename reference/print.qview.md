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
[`print.qview_summary()`](https://cttir.github.io/qviewparsR/reference/print.qview_summary.md),
[`summary.qview()`](https://cttir.github.io/qviewparsR/reference/summary.qview.md)

## Examples

``` r
qv <- read_qview(system.file("extdata", "example.Q-View",
                             package = "qviewparsR"), verbose = FALSE)
print(qv)
#> 
#> ── Q-View project: "Example ELISA project" ─────────────────────────────────────
#> • Plate: "Plate 1"
#> • Image: "example-plate (01 Jan 2024 12:00)"
#> • Imager: "#000000 (00000)"
#> • Product: "EXAMPLE-LOT"
#> • Software: v"3.13"
#> • Template: "example-template"
#> • Created: "01 Jan 2024 12:05"
#> 
#> ── Analytes (3) ──
#> 
#> Ba (ng/ml), Bb (ug/ml), Ref Spot (N/A)
#> 
#> ── Well groups (5) ──
#> 
#> • standard: 2
#> • negative: 1
#> • control: 1
#> • sample: 1
#> 
#> ── Data ──
#> 
#> • replicate rows: 20
#> • summary stat rows: 0
#> • concentrations: 4 rows
#> • curve fit: 3 analytes
```
