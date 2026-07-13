# Read a Q-View report export (CSV or XLSX)

**\[experimental\]**

## Usage

``` r
read_qview_report(
  path,
  strip_prefix = FALSE,
  verbose = TRUE,
  call = rlang::caller_env()
)
```

## Arguments

- path:

  Character. Path to a Q-View report export (`.csv` or `.xlsx`).

- strip_prefix:

  Logical. If `TRUE`, reverse Q-View's internal naming convention via
  [`strip_qview_prefix()`](https://cttir.github.io/qviewparsR/reference/strip_qview_prefix.md).
  Default `FALSE`.

- verbose:

  Logical. Print a short summary after parsing. Default `TRUE`.

- call:

  The execution environment of the calling function. Used for error
  reporting; experts only.

## Value

A list with class `"qview"`, structured as the
[`read_qview()`](https://cttir.github.io/qviewparsR/reference/read_qview.md)
return value, with these deviations. Container-only slots (`manifest`,
`segments`) are zero-row tibbles; `metadata$container_version` is `NA`.
The `concentrations` tibble carries one extra column, `flag` (`NA` /
`"<"` / `">"` / `"incalculable"`), relative to
[`read_qview()`](https://cttir.github.io/qviewparsR/reference/read_qview.md).
`report_csv` echoes the full export in file order (metadata preamble,
blank spacer rows, the analyte header, then the data rows), whereas
[`read_qview()`](https://cttir.github.io/qviewparsR/reference/read_qview.md)'s
`report_csv` holds only the unique report data lines.

## Details

Parses one of the flat report files Q-View exports next to the native
`.Q-View` container – the `..._auto_report` or
`..._auto_all-parameters_report` export, as either `.csv` or `.xlsx` –
and returns the same
[`qview`](https://cttir.github.io/qviewparsR/reference/read_qview.md)
object
[`read_qview()`](https://cttir.github.io/qviewparsR/reference/read_qview.md)
builds from the binary container. Use it when only the exports were kept
and the original `.Q-View` project file is unavailable.

The export shares its report layout with the CLOB embedded in the binary
container, so the two readers agree on concentrations and pixel
intensities. Two behaviours differ from
[`read_qview()`](https://cttir.github.io/qviewparsR/reference/read_qview.md),
both to preserve information the study workflows rely on:

- The plain `"Reduced Concentration"` point estimate (one row per
  sample, the value the exports headline) is captured with
  `statistic == "reduced"`.
  [`read_qview()`](https://cttir.github.io/qviewparsR/reference/read_qview.md)
  currently keeps only the per-replicate / summary concentration rows.

- Out-of-range cells are **preserved, not dropped**: a `"< 52.50"` cell
  yields `concentration = 52.50` with `flag = "<"`, a `"> 7700"` cell
  `flag = ">"`, and an `"Incalculable ..."` cell `concentration = NA`
  with `flag = "incalculable"`. In-range cells carry `flag = NA`.

## See also

[`read_qview()`](https://cttir.github.io/qviewparsR/reference/read_qview.md),
[`read_qview_template()`](https://cttir.github.io/qviewparsR/reference/read_qview_template.md).

Other qview-reader:
[`read_qview()`](https://cttir.github.io/qviewparsR/reference/read_qview.md),
[`read_qview_template()`](https://cttir.github.io/qviewparsR/reference/read_qview_template.md)

## Examples

``` r
path <- system.file("extdata", "example-report.csv",
                    package = "qviewparsR")
if (nzchar(path)) {
  qv <- read_qview_report(path)
  qv$concentrations
}
#> ✔ Parsed report export example-report.csv: 3 well groups x 3 analytes (8
#>   concentration rows).
#> ℹ Q-View Version: "3.13"
#> # A tibble: 8 × 10
#>   well_group sample_id well  replicate statistic analyte unit  concentration
#>   <chr>      <chr>     <chr>     <int> <chr>     <chr>   <chr>         <dbl>
#> 1 Cal 1      Cal 1     A1            1 replicate Ba      ng/mL         28.0 
#> 2 Cal 1      Cal 1     A1            1 replicate Bb      ug/mL          0.41
#> 3 Cal 1      Cal 1     A2            2 replicate Ba      ng/mL         NA   
#> 4 Cal 1      Cal 1     A2            2 replicate Bb      ug/mL          0.47
#> 5 N12345     N12345    A3           NA reduced   Ba      ng/mL          2.5 
#> 6 N12345     N12345    A3           NA reduced   Bb      ug/mL          0.05
#> 7 N23456     N23456    A4           NA reduced   Ba      ng/mL          0.31
#> 8 N23456     N23456    A4           NA reduced   Bb      ug/mL          0.42
#> # ℹ 2 more variables: dilution <dbl>, flag <chr>
```
