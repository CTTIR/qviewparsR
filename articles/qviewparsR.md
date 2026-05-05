# Reading Q-View project files with qviewparsR

`qviewparsR` is a pure-R parser for `.Q-View` binary project files. The
file format is a single-file container that bundles an embedded H2 SQL
database with binary plate-image data; the rendered CSV report is stored
as a CLOB inside the database.
[`read_qview()`](https://r-heller.github.io/qviewparsR/reference/read_qview.md)
extracts that report without needing a Java runtime or H2 driver.

## Reading a project file

``` r

qv <- read_qview("path/to/project.Q-View")
qv
```

The returned object has class `qview` and contains:

``` r

str(qv, max.level = 1)
#> List of 11
#>  $ metadata          :List of 12
#>  $ manifest          : tibble [4 x 3]
#>  $ segments          : tibble [3 x 4]
#>  $ analytes          : tibble [<n_analytes> x 8]
#>  $ well_groups       : tibble [<n_groups> x 7]
#>  $ pixel_intensities : tibble [<n_rows> x 8]
#>  $ summary_statistics: tibble [<n_rows> x 6]
#>  $ concentrations    : NULL or tibble
#>  $ curve_fit         : NULL or tibble
#>  $ report_csv        : character vector
#>  $ plate_layout      : tibble [96 x 7]
#>  - attr(*, "class") = "qview"
```

## The naming convention

When Q-View imports a plate-template CSV it rewrites the identifiers:

- `Cal 1` -\> `ICal 1`
- `Low` -\> `GLow`
- `High` -\> `HHigh`
- `FD...` and any all-digit ID -\> a single `N` prefix.

Pass `strip_prefix = TRUE` to undo the rewrite:

``` r

qv <- read_qview("path/to/project.Q-View", strip_prefix = TRUE)
qv$well_groups$sample_id
```

## Plotting

``` r

plot(qv, type = "plate_map")
plot(qv, type = "intensity_heatmap")
plot(qv, type = "replicate_scatter")
```

[`plot.qview()`](https://r-heller.github.io/qviewparsR/reference/plot.qview.md)
requires `ggplot2`.

## Exporting

``` r

qview_to_xlsx(qv, "out.xlsx")
qview_to_csv_dir(qv, "out_csv/")
saveRDS(qv, "out.rds")
```

## Interactive front-end

``` r

qview_app()
```

Launches a Shiny app: upload a `.Q-View` file (and optionally a
plate-template CSV), preview each parsed table, visualise the plate map,
intensity heatmap, and replicate scatter, and download the result as
`xlsx`, `rds`, or a zip of CSVs.
