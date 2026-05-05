# Convert plate row / column to a well label

**\[experimental\]**

## Usage

``` r
well_label(row, col, zero_based = FALSE)
```

## Arguments

- row:

  Integer or character. Either a 0/1-based row index or already a single
  letter (`"A"`...).

- col:

  Integer column index (1-based or 0-based; values \>= 1 are treated as
  1-based).

- zero_based:

  Logical. If `TRUE`, treat `row` and `col` as 0-based; if `FALSE`
  (default), treat them as 1-based.

## Value

Character vector of well labels (e.g. `"A1"`, `"H12"`), recycled to the
longer of `row` / `col`.

## Details

Converts 0-based or 1-based row and column indices to the standard
`"A1"` ... `"H12"` plate notation. Vectorised.

## See also

Other qview-helper:
[`strip_qview_prefix()`](https://cttir.github.io/qviewparsR/reference/strip_qview_prefix.md)

## Examples

``` r
well_label(0, 0, zero_based = TRUE)   # "A1"
#> [1] "A1"
well_label(7, 11, zero_based = TRUE)  # "H12"
#> [1] "H12"
well_label("C", 5)                    # "C5"
#> [1] "C5"
```
