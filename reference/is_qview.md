# Test whether an object is a `qview`

**\[experimental\]**

## Usage

``` r
is_qview(x)
```

## Arguments

- x:

  An object to test.

## Value

Logical scalar.

## See also

Other qview-methods:
[`as_tibble.qview()`](https://cttir.github.io/qviewparsR/reference/as_tibble.qview.md),
[`plot.qview()`](https://cttir.github.io/qviewparsR/reference/plot.qview.md),
[`print.qview()`](https://cttir.github.io/qviewparsR/reference/print.qview.md),
[`summary.qview()`](https://cttir.github.io/qviewparsR/reference/summary.qview.md)

## Examples

``` r
path <- system.file("extdata", "example.Q-View", package = "qviewparsR")
is_qview(read_qview(path, verbose = FALSE))
#> [1] TRUE
is_qview(list())
#> [1] FALSE
```
