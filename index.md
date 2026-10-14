# qviewparsR

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.21395352.svg)](https://doi.org/10.5281/zenodo.21395352)

`qviewparsR` is a pure-R parser for the binary `.Q-View` project file
format used in chemiluminescent multiplex ELISA plate imaging and
quantification. It extracts the embedded report and returns it as tidy
tibbles.

No Java runtime, no H2 database driver, no system dependencies beyond a
working R installation.

## Installation

`qviewparsR` is **pure R** — no compiled code, no Java runtime, no H2
database driver, and no system libraries — so it installs the same way
on **Windows, macOS, and Linux**. The only hard prerequisite is **R \>=
4.1.0**.

Install the released version from
[CRAN](https://CRAN.R-project.org/package=qviewparsR):

``` r

install.packages("qviewparsR")
```

Or the development version from GitHub:

``` r

# install.packages("pak")
pak::pak("CTTIR/qviewparsR")
```

### Platform notes

- **Windows** — no *Rtools* required: `qviewparsR` itself compiles
  nothing, and its CRAN dependencies install as pre-built binaries.
- **macOS** — nothing beyond R (no XQuartz needed).
- **Linux** — the package is pure R, but a few dependencies (`dplyr`,
  `readr`, `tidyr`, `openxlsx2`) contain C++ and build from source
  unless you use a binary repository such as the [Posit Public Package
  Manager](https://packagemanager.posit.co) or
  [r2u](https://eddelbuettel.github.io/r2u/) — which avoids needing a
  compiler. Otherwise install a build toolchain (e.g. `build-essential`
  on Debian/Ubuntu).

Installing the package pulls in its required imports automatically. The
optional features need a few extra packages: plotting uses `ggplot2`
(plus `patchwork` for the overview figure), and the interactive app
([`qview_app()`](https://cttir.github.io/qviewparsR/reference/qview_app.md))
uses `shiny`, `bslib`, and `DT`.

## Quick start

``` r

library(qviewparsR)

qv <- read_qview("path/to/project.Q-View")
qv                                # compact summary
qv$analytes                       # spot_number, analyte, unit, lod, lloq, ...
qv$pixel_intensities              # long-format replicate readings
qv$plate_layout                   # one row per well

plot(qv, type = "plate_map")      # plate visualisation (needs ggplot2)
plot(qv, type = "intensity_heatmap")
plot(qv, type = "replicate_scatter")

# Export (pipe-friendly: each writer returns qv invisibly)
qv |>
  write_qview_xlsx("out.xlsx") |>
  write_qview_csv("out_csv/")  |>
  write_qview_rds("out.rds")

# Per-analyte mean / SD / CV per well-type group
summary(qv)

# Interactive front-end (upload, visualise, download)
qview_app()
```

## What is a `.Q-View` file?

A `.Q-View` file is a single-file **container** that bundles an embedded
**H2 SQL database** (Java, version `0.5/B`) with binary LOB files
holding the chemiluminescent plate images. The file is **not** a ZIP
archive, XML, or CSV — it is a proprietary binary container with a
plain-text manifest header followed by concatenated H2 segments.

### Container layout

    +-----------------------------------------+
    | Bytes 0 - ~290:  text manifest header   |
    |   - container version                   |
    |   - declared file entries (size + name) |
    +-----------------------------------------+
    | Segment 1: main H2 SQL database         |
    |   - 36 tables (see schema below)        |
    |   - the rendered CSV report (CLOB)      |
    +-----------------------------------------+
    | Segment 2: LOB file 1 (image data)      |
    +-----------------------------------------+
    | Segment 3: LOB file 2 (more LOB data)   |
    +-----------------------------------------+

Each H2 segment starts with a `-- H2 0.5/B --` triplet marker. The
database uses 2048-byte pages.

### Embedded H2 schema (key tables)

`qviewparsR` recovers data through the embedded CSV report; the table
diagram below documents the underlying schema for reference.

| Group | Table | Purpose |
|----|----|----|
| **Project / plate** | `PROJECT` | Project metadata (creator, version, timezone) |
|  | `PLATE` | Plate identifiers |
|  | `PLATEDEFINITION` | Plate geometry (rows, columns, well diameter) |
|  | `PRODUCT` | Product / lot identifiers, linked plate / plex definitions |
| **Well & spot layout** | `WELL` | Well coordinates (pixel + row/col) |
|  | `SPOT` | Per-spot pixel intensity (raw + negative-subtracted), masking flags |
|  | `PLEXDEFINITION` / `PLEXSPOT` | Spot layout per well |
| **Analytes / standards** | `ANALYTE` | Analyte names |
|  | `PRODUCTANALYTE` | Spot number -\> analyte mapping (key table) |
|  | `ANALYTESTANDARD` / `ANALYTESTANDARDANALYTE` | Standard curve concentrations |
| **Sample assignment** | `WELLGROUP` | Sample IDs and type flags (standard / negative / sample / control) |
|  | `WELLGROUPWELL` | Well-to-group mapping with dilution factors |
| **Pixel-intensity cache** | `SPOTPIXELINTENSITY` | Cached per-image spot intensity |
|  | `NEGATIVESPOTPIXELINTENSITY` | Negative-spot intensity before subtraction |
| **Curve fitting** | `CURVEFITOPTION` | Regression model settings (4PL, 5PL, HDR, weighting) |
|  | `REGRESSIONSOLUTION` | Fitted curve parameters |
| **Image / camera** | `IMAGE` / `IMAGEDETAILS` / `CAMERA` | Image and imager metadata |
| **Report** | `REPORTCONFIGURATION` | CSV report column flags |
|  | `REPORTHISTORY` | The fully rendered CSV report (CLOB) |
|  | `REPORTINFO` | Signatures and approval state |

### Naming convention

When Q-View imports a well-assignment template CSV it prefixes the
identifiers internally:

| Template value              | Q-View internal name         |
|-----------------------------|------------------------------|
| `Cal 1` … `Cal N`           | `ICal 1` … `ICal N`          |
| `Low`                       | `GLow`                       |
| `High`                      | `HHigh`                      |
| `FD24277364`, all-digit IDs | `NFD24277364`, `N1211498458` |

[`strip_qview_prefix()`](https://cttir.github.io/qviewparsR/reference/strip_qview_prefix.md)
reverses this transformation, and
`read_qview(path, strip_prefix = TRUE)` applies it across the whole
returned object.

## Output structure

[`read_qview()`](https://cttir.github.io/qviewparsR/reference/read_qview.md)
returns a list with class `qview`:

| Slot | Description |
|----|----|
| `metadata` | Project, plate, image, imager, product, user, software version, template name, container version, file path, parse timestamp |
| `manifest` | One row per declared file entry inside the container |
| `segments` | Byte ranges of the three H2 segments |
| `analytes` | `spot_number`, `analyte`, `unit`, `lod`, `lloq`, `uloq`, `assay_control_low/high` |
| `well_groups` | `well_group`, `sample_id`, type flags (`is_standard`, `is_negative`, `is_sample`, `is_control`), `well_type` factor |
| `pixel_intensities` | Long-format per-well replicate readings |
| `summary_statistics` | Per-group `average`, `std_dev`, `cv` rows |
| `concentrations` | Long-format concentrations, or `NULL` if the report is qualitative |
| `curve_fit` | Per-analyte regression model |
| `report_csv` | Raw CSV report lines |
| `plate_layout` | One row per plate well with sample assignment + well type |

## Function reference

| Category | Functions |
|----|----|
| Reader | [`read_qview()`](https://cttir.github.io/qviewparsR/reference/read_qview.md), [`read_qview_report()`](https://cttir.github.io/qviewparsR/reference/read_qview_report.md) |
| Helpers | [`strip_qview_prefix()`](https://cttir.github.io/qviewparsR/reference/strip_qview_prefix.md), [`well_label()`](https://cttir.github.io/qviewparsR/reference/well_label.md) |
| Optional | [`read_qview_template()`](https://cttir.github.io/qviewparsR/reference/read_qview_template.md) |
| Methods | [`print.qview()`](https://cttir.github.io/qviewparsR/reference/print.qview.md), [`plot.qview()`](https://cttir.github.io/qviewparsR/reference/plot.qview.md) |
| Export | [`write_qview_xlsx()`](https://cttir.github.io/qviewparsR/reference/write_qview.md), [`write_qview_csv()`](https://cttir.github.io/qviewparsR/reference/write_qview.md), [`write_qview_rds()`](https://cttir.github.io/qviewparsR/reference/write_qview.md) |
| Summary | [`summary.qview()`](https://cttir.github.io/qviewparsR/reference/summary.qview.md) (mean / SD / CV per analyte x well type) |
| Shiny app | [`qview_app()`](https://cttir.github.io/qviewparsR/reference/qview_app.md) |

## Citation

If you use `qviewparsR` in academic work, please cite the CRAN release:

> Heller R, Mannes M (2026). *qviewparsR: Read .Q-View Multiplex ELISA
> Project Files*.
> <doi:%5B10.32614/CRAN.package.qviewparsR>\](<https://doi.org/10.32614/CRAN.package.qviewparsR>).
> R package version 1.0.0,
> <https://CRAN.R-project.org/package=qviewparsR>.

BibTeX:

``` bibtex
@Manual{qviewparsR,
  title  = {qviewparsR: Read .Q-View Multiplex ELISA Project Files},
  author = {R. Heller and M. Mannes},
  year   = {2026},
  note   = {R package version 1.0.0},
  doi    = {10.32614/CRAN.package.qviewparsR},
  url    = {https://CRAN.R-project.org/package=qviewparsR},
}
```

To cite a specific archived source snapshot instead, use the Zenodo
software DOI:

``` bibtex
@software{heller_2026_21395352,
  author    = {Heller, Raban and Mannes, Marco},
  title     = {qviewparsR - Read .Q-View Multiplex ELISA Project Files},
  month     = jul,
  year      = 2026,
  publisher = {Zenodo},
  version   = {1.0.0},
  doi       = {10.5281/zenodo.21395352},
  url       = {https://doi.org/10.5281/zenodo.21395352},
}
```

You can always retrieve the up-to-date entry directly from R:

``` r

citation("qviewparsR")
```

## License

MIT (c) 2026 R. Heller and M. Mannes.

## Use of LLM tools

Where applicable, LLM tools were used for narrowly defined,
non-authorial tasks: copyediting, prose refinement, Markdown/LaTeX
formatting, boilerplate scaffolding (such as CI configurations and build
scripts), and code refactoring. Tools included [Chat
AI](https://kisski.gwdg.de/leistungen/2-02-llm-service/), the KISSKI
(GWDG) service, and self-hosted **Mistral Small (24B, Apache-2.0)**
served through a local **vLLM architecture** on an Ubuntu Linux
workstation with Intel processors and NVIDIA GPUs. The self-hosted model
ran locally, with no data sent to third parties.

All scientific claims, methodological choices, analyses, interpretations
and conclusions remain the authors’ own. Where applicable, LLM-generated
material must be reviewed and revised before inclusion, and references
must be verified against their DOI, arXiv ID or ISBN.

Local software setup: vLLM with Python/PyTorch, plus R and RStudio.
