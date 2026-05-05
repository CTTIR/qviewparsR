# Read a Q-View well-assignment template CSV

Parses the plate-template CSV that Q-View imports for sample assignment.
The file uses a multi-section layout: an `NxM` cell in the top-left
declares the plate dimensions, followed by sections labelled
`Group Name`, `Group Type`, and `Dilution Factor`. Each section is one
row per plate row and one column per plate column.

## Usage

``` r
read_qview_template(path, verbose = TRUE)
```

## Arguments

- path:

  Path to the template file (csv or xlsx).

- verbose:

  Logical. Print a short summary after parsing. Default `TRUE`.

## Value

A tibble with one row per well: `well`, `plate_row`, `plate_col`,
`sample_id`, `group_type`, `dilution`.

## Details

All template data is also embedded inside the `.Q-View` file itself (and
is recovered by
[`read_qview()`](https://r-heller.github.io/qviewparsR/reference/read_qview.md));
this function exists for setting up new plates or cross-validating
Q-View imports against the original template.

## Examples

``` r
if (FALSE) { # \dontrun{
  layout <- read_qview_template("plate-template.csv")
} # }
```
