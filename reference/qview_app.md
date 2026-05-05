# Launch the qviewparsR Q-View Shiny app

**\[experimental\]**

## Usage

``` r
qview_app(...)
```

## Arguments

- ...:

  Forwarded to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).

## Value

Invoked for its side effect of running the app.

## Details

Interactive front-end for
[`read_qview()`](https://cttir.github.io/qviewparsR/reference/read_qview.md).
Uploads a `.Q-View` file (and optionally an accompanying well-assignment
template CSV), displays the parsed metadata, analytes, well groups, and
replicate tables, and lets the user download the parsed result as
`xlsx`, `rds`, or a zip of per-table CSV files.

Requires the `shiny`, `bslib`, and `DT` packages (listed under
`Suggests`).

## Examples

``` r
if (interactive()) {
  qview_app()
}
```
