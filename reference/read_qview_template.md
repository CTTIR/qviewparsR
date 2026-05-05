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
[`read_qview()`](https://cttir.github.io/qviewparsR/reference/read_qview.md)

## Examples

``` r
if (FALSE) { # \dontrun{
  layout <- read_qview_template("plate-template.csv")
} # }
```
