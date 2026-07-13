# Read a Q-View well-assignment template CSV

**\[experimental\]**

## Usage

``` r
read_qview_template(path, verbose = TRUE, call = rlang::caller_env())
```

## Arguments

- path:

  Path to the template file (csv).

- verbose:

  Logical. Print a short summary after parsing. Default `TRUE`.

- call:

  The execution environment of the calling function. Used for error
  reporting; experts only.

## Value

A
[`tibble::tibble()`](https://tibble.tidyverse.org/reference/tibble.html)
with one row per well and columns `well` (character, e.g. `"A1"`),
`plate_row` (character, `"A"`..), `plate_col` (integer), `sample_id`
(character), `group_type` (character), `dilution` (numeric).

## Details

Parses the plate-template CSV that Q-View imports for sample assignment.
The file uses a multi-section layout: an `NxM` cell in the top-left
declares the plate dimensions, followed by sections labelled
`Group Name`, `Group Type`, and `Dilution Factor`. Each section is one
row per plate row and one column per plate column.

All template data is also embedded inside the `.Q-View` file itself (and
is recovered by
[`read_qview()`](https://cttir.github.io/qviewparsR/reference/read_qview.md));
this function exists for setting up new plates or cross-validating
Q-View imports against the original template.

## See also

Other qview-reader:
[`read_qview()`](https://cttir.github.io/qviewparsR/reference/read_qview.md),
[`read_qview_report()`](https://cttir.github.io/qviewparsR/reference/read_qview_report.md)

## Examples

``` r
path <- system.file("extdata", "example-template.csv",
                    package = "qviewparsR")
layout <- read_qview_template(path)
#> ✔ Parsed Q-View template: 96 wells, 19 unique samples from
#>   /home/runner/work/_temp/Library/qviewparsR/extdata/example-template.csv.
head(layout)
#> # A tibble: 6 × 6
#>   well  plate_row plate_col sample_id group_type dilution
#>   <chr> <chr>         <int> <chr>     <chr>         <dbl>
#> 1 A1    A                 1 Cal 1     calibrator       NA
#> 2 B1    B                 1 Cal 2     calibrator       NA
#> 3 C1    C                 1 Cal 3     calibrator       NA
#> 4 D1    D                 1 Cal 4     calibrator       NA
#> 5 E1    E                 1 Cal 5     calibrator       NA
#> 6 F1    F                 1 Cal 6     calibrator       NA
```
