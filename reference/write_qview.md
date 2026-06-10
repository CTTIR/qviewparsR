# Write a Q-View object to disk

**\[experimental\]**

## Usage

``` r
write_qview_xlsx(
  qv,
  path,
  template = NULL,
  overwrite = FALSE,
  call = rlang::caller_env()
)

write_qview_csv(qv, path, template = NULL, call = rlang::caller_env())

write_qview_rds(qv, path, overwrite = FALSE, call = rlang::caller_env())

qview_to_xlsx(
  qv,
  path,
  template = NULL,
  overwrite = FALSE,
  call = rlang::caller_env()
)

qview_to_csv_dir(qv, dir, template = NULL, call = rlang::caller_env())
```

## Arguments

- qv:

  A `qview` object from
  [`read_qview()`](https://cttir.github.io/qviewparsR/reference/read_qview.md).

- path:

  Output path. For `write_qview_xlsx()` / `write_qview_rds()` this is a
  single file path; for `write_qview_csv()` it is the output directory
  (created if it does not exist).

- template:

  Optional plate-template tibble (from
  [`read_qview_template()`](https://cttir.github.io/qviewparsR/reference/read_qview_template.md))
  to include as an extra sheet / file.

- overwrite:

  Logical. If `FALSE` (the default), an existing destination triggers an
  error; set to `TRUE` to replace it. Ignored by `write_qview_csv()` (it
  only adds files).

- call:

  The execution environment of the calling function. Used for error
  reporting; experts only.

- dir:

  Deprecated alias for `path` accepted by `qview_to_csv_dir()`. Use
  `path` instead.

## Value

`qv`, invisibly, to support pipelines.

## Details

Three writers, one for each common destination. All return the input
`qv` invisibly so they compose with the pipe.

- `write_qview_xlsx()` – one sheet per parsed table.

- `write_qview_csv()` – one CSV per parsed table inside a directory.

- `write_qview_rds()` – a single `.rds` containing the full `qview`
  object (lossless, the only round-trippable format).

## Examples

``` r
path <- system.file("extdata", "example.Q-View", package = "qviewparsR")
qv <- read_qview(path, verbose = FALSE)

out <- tempfile()
dir.create(out)
qv |>
  write_qview_rds(file.path(out, "plate.rds")) |>
  write_qview_csv(file.path(out, "plate_csv"))
list.files(out, recursive = TRUE)
#> [1] "plate.rds"                       "plate_csv/analytes.csv"         
#> [3] "plate_csv/concentrations.csv"    "plate_csv/curve_fit.csv"        
#> [5] "plate_csv/manifest.csv"          "plate_csv/metadata.csv"         
#> [7] "plate_csv/pixel_intensities.csv" "plate_csv/plate_layout.csv"     
#> [9] "plate_csv/well_groups.csv"      
```
