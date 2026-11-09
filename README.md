# qviewparsR <picture class="cttir-readme-logo"><source class="cttir-logo-dark-source" media="(prefers-color-scheme: dark)" srcset="man/figures/logo-with-name-dark.png" /><img src="man/figures/logo-with-name.png" align="right" alt="qviewparsR logo" width="120" height="139" /></picture>

[![Zenodo DOI: 10.5281/zenodo.21395352](man/figures/doi-zenodo.svg)](https://doi.org/10.5281/zenodo.21395352)

<!-- badges: start -->
[![CRAN status](https://www.r-pkg.org/badges/version/qviewparsR)](https://CRAN.R-project.org/package=qviewparsR)
[![CRAN downloads](https://cranlogs.r-pkg.org/badges/grand-total/qviewparsR)](https://CRAN.R-project.org/package=qviewparsR)
[![R-CMD-check](https://github.com/CTTIR/qviewparsR/actions/workflows/R-CMD-check.yaml/badge.svg?branch=main&event=push)](https://github.com/CTTIR/qviewparsR/actions/workflows/R-CMD-check.yaml)
[![pkgdown](https://github.com/CTTIR/qviewparsR/actions/workflows/pkgdown.yaml/badge.svg?branch=main&event=push)](https://github.com/CTTIR/qviewparsR/actions/workflows/pkgdown.yaml)
[![Codecov test coverage](https://codecov.io/gh/CTTIR/qviewparsR/branch/main/graph/badge.svg)](https://app.codecov.io/gh/CTTIR/qviewparsR?branch=main)
[![Lifecycle: stable](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://lifecycle.r-lib.org/articles/stages.html#stable)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![CRAN DOI](https://img.shields.io/badge/DOI-10.32614%2FCRAN.package.qviewparsR-1f6feb.svg)](https://doi.org/10.32614/CRAN.package.qviewparsR)
<!-- badges: end -->

`qviewparsR` is a pure-R parser for the binary `.Q-View` project file
format used in chemiluminescent multiplex ELISA plate imaging and
quantification. It extracts the embedded report and returns it as tidy
tibbles.

No Java runtime or H2 database driver is needed. Required R dependencies
are installed with the package; source installations may need a compiler
for those dependencies (see the platform notes below).

## Installation

`qviewparsR` is **pure R** — no compiled code, no Java runtime, no H2
database driver, and no system libraries — so it installs the same way on
**Windows, macOS, and Linux**. The package requires **R >= 4.1.0** and its declared R dependencies.

The 1.1.0 reliability changes described here are not yet on CRAN. Use the
GitHub installation below until CRAN lists version 1.1.0 or later.

Install the released version from
[CRAN](https://CRAN.R-project.org/package=qviewparsR):

```r
install.packages("qviewparsR")
```

Or the development version from GitHub:

```r
if (!requireNamespace("pak", quietly = TRUE)) install.packages("pak")
pak::pak("CTTIR/qviewparsR")
```

### Platform notes

* **Windows** — no *Rtools* required: `qviewparsR` itself compiles
  nothing, and its CRAN dependencies install as pre-built binaries.
* **macOS** — nothing beyond R (no XQuartz needed).
* **Linux** — the package is pure R, but a few dependencies (`dplyr`,
  `readr`, `tidyr`, `openxlsx2`) contain C++ and build from source unless
  you use a binary repository such as the
  [Posit Public Package Manager](https://packagemanager.posit.co) or
  [r2u](https://eddelbuettel.github.io/r2u/) — which avoids needing a
  compiler. Otherwise install a build toolchain (e.g. `build-essential`
  on Debian/Ubuntu).

Installing the package pulls in its required imports automatically. The
optional features need a few extra packages: plotting uses `ggplot2`
(plus `patchwork` for the overview figure), and the interactive app
(`qview_app()`) uses `shiny`, `bslib`, and `DT`.

## Quick start

```r
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

### Try the bundled example

This path needs no instrument files or optional plotting packages:

```r
library(qviewparsR)
project <- system.file("extdata", "example.Q-View", package = "qviewparsR")
qv <- read_qview(project, verbose = FALSE)
summary(qv)
out <- tempfile("qview-example-")
dir.create(out)
write_qview_csv(qv, file.path(out, "tables"))
write_qview_rds(qv, file.path(out, "project.rds"))
stopifnot(identical(readRDS(file.path(out, "project.rds")), qv))
list.files(out, recursive = TRUE)
```

CSV exports retain exact text. Spreadsheet applications can interpret text
starting with formula characters; import such columns explicitly as text.
Use RDS for a lossless R round trip. Replacing an existing export requires
`overwrite = TRUE`; use a dedicated directory for CSV bundles.

### Interpretation and recovery

The binary reader extracts embedded reports; it does not reconstruct H2
transactions or establish which conflicting database record is current.
Version 1.1.0 refuses conflicting observations instead of selecting the most
frequent value. Export a fresh CSV or XLSX report from Q-View and use
`read_qview_report()` when a binary report is ambiguous. Keep the original
container and producer export for provenance.

Reports currently support wells A1–H12. Malformed numeric values, ambiguous
analyte identities, invalid wells and malformed template geometry are errors.
Recognized missing and censored measurements retain their original decoded
text and flags. A `<` or `>` concentration is a bound, not an exact observation;
summary estimates and numeric plots exclude censored and missing values.
Summary counts distinguish observed, missing and censored records. Flat text
reports use UTF-8 when valid and otherwise fall back to Latin-1; XLSX text is
already decoded. The selected flat-file encoding is recorded in metadata.
Binary report text outside the supported printable representation is refused
rather than silently stripped; use the producer flat export instead. No step
imputes zero or independently validates the producer's calibration.

These changes make some formerly accepted inputs fail deliberately. Do not
remove conflicting records merely to obtain a successful import; reconcile
them with the producer export. The bundled examples are synthetic. Checks
against private instrument exports remain unperformed when those files are
unavailable.

### App results and graphics

Changing an upload or parsing option clears the previous results; parse again
before downloading. Exported metadata records the original upload name and
parsing settings. PNG downloads accept dimensions of 3–30 inches and 72–1200
DPI, with a total limit of 50 million pixels. Reduce dimensions or DPI when the
limit is exceeded, or use the vector PDF download.

## What is a `.Q-View` file?

A `.Q-View` file is a single-file **container** that bundles an embedded
**H2 SQL database** (Java, version `0.5/B`) with binary LOB files
holding the chemiluminescent plate images. The file is **not** a ZIP
archive, XML, or CSV — it is a proprietary binary container with a
plain-text manifest header followed by concatenated H2 segments.

### Container layout

```
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
```

Each H2 segment starts with a `-- H2 0.5/B --` triplet marker. The
database uses 2048-byte pages.

### Embedded H2 schema (key tables)

`qviewparsR` recovers data through the embedded CSV report; the table
diagram below documents the underlying schema for reference.

| Group | Table | Purpose |
|-------|-------|---------|
| **Project / plate** | `PROJECT` | Project metadata (creator, version, timezone) |
|  | `PLATE` | Plate identifiers |
|  | `PLATEDEFINITION` | Plate geometry (rows, columns, well diameter) |
|  | `PRODUCT` | Product / lot identifiers, linked plate / plex definitions |
| **Well & spot layout** | `WELL` | Well coordinates (pixel + row/col) |
|  | `SPOT` | Per-spot pixel intensity (raw + negative-subtracted), masking flags |
|  | `PLEXDEFINITION` / `PLEXSPOT` | Spot layout per well |
| **Analytes / standards** | `ANALYTE` | Analyte names |
|  | `PRODUCTANALYTE` | Spot number -> analyte mapping (key table) |
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

| Template value | Q-View internal name |
|---|---|
| `Cal 1` ... `Cal N` | `ICal 1` ... `ICal N` |
| `Low` | `GLow` |
| `High` | `HHigh` |
| `FD24277364`, all-digit IDs | `NFD24277364`, `N1211498458` |

`strip_qview_prefix()` reverses this transformation, and
`read_qview(path, strip_prefix = TRUE)` applies it across the whole
returned object.

## Output structure

`read_qview()` returns a list with class `qview`:

| Slot | Description |
|------|-------------|
| `metadata` | Project, plate, image, imager, product, user, software version, template name, container version, file path, parse timestamp |
| `manifest` | One row per declared file entry inside the container |
| `segments` | Byte ranges of the three H2 segments |
| `analytes` | `spot_number`, `analyte`, `unit`, `lod`, `lloq`, `uloq`, `assay_control_low/high` |
| `well_groups` | `well_group`, `sample_id`, type flags (`is_standard`, `is_negative`, `is_sample`, `is_control`), `well_type` factor |
| `pixel_intensities` | Long-format per-well replicate readings |
| `summary_statistics` | Per-group `average`, `std_dev`, `cv` rows |
| `concentrations` | Long-format concentrations, or `NULL` if no concentration rows were recovered |
| `curve_fit` | Per-analyte regression model |
| `report_csv` | Raw CSV report lines |
| `plate_layout` | One row per plate well with sample assignment + well type |

## Function reference

| Category | Functions |
|----------|-----------|
| Reader | `read_qview()`, `read_qview_report()` |
| Helpers | `strip_qview_prefix()`, `well_label()` |
| Optional | `read_qview_template()` |
| Methods | `print.qview()`, `plot.qview()` |
| Export | `write_qview_xlsx()`, `write_qview_csv()`, `write_qview_rds()` |
| Summary | `summary.qview()` (mean / SD / CV per analyte x well type) |
| Shiny app | `qview_app()` |

## Citation

If you use `qviewparsR` in academic work, please cite the CRAN release.
`CITATION.cff` uses the Zenodo concept DOI, which always resolves to the
latest archived release; the archived 1.0.0 snapshot keeps its own version DOI
(below). For an unreleased source snapshot, also record its Git commit.

> Heller R, Mannes M (2026). _qviewparsR: Read .Q-View Multiplex ELISA
> Project Files_.
> doi:[10.32614/CRAN.package.qviewparsR](https://doi.org/10.32614/CRAN.package.qviewparsR).
> R package version 1.1.0,
> <https://CRAN.R-project.org/package=qviewparsR>.

BibTeX:

```bibtex
@Manual{qviewparsR,
  title  = {qviewparsR: Read .Q-View Multiplex ELISA Project Files},
  author = {R. Heller and M. Mannes},
  year   = {2026},
  note   = {R package version 1.1.0},
  doi    = {10.32614/CRAN.package.qviewparsR},
  url    = {https://CRAN.R-project.org/package=qviewparsR},
}
```

To cite a specific archived source snapshot instead, use the Zenodo
software DOI:

```bibtex
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

```r
citation("qviewparsR")
```

## License

MIT (c) 2026 R. Heller and M. Mannes.

## Use of LLM tools

Where applicable, LLM tools were used for narrowly defined, non-authorial tasks:
copyediting, prose refinement, Markdown/LaTeX formatting, boilerplate scaffolding
(such as CI configurations and build scripts), and code refactoring. Tools included
[Chat AI](https://kisski.gwdg.de/leistungen/2-02-llm-service/), the KISSKI
(GWDG) service, and self-hosted **Mistral Small (24B, Apache-2.0)** served through
a local **vLLM architecture** on an Ubuntu Linux workstation with Intel
processors and NVIDIA GPUs. Self-hosted use also includes models that were
further trained (fine-tuned) or weight-edited in-house for specific tasks.
All self-hosted models ran locally, with no data sent to third parties.

All scientific claims, methodological choices, analyses, interpretations and
conclusions remain the authors' own. Where applicable, LLM-generated material
must be reviewed and revised before inclusion, and references must be verified
against their DOI, arXiv ID or ISBN.

Local software setup: vLLM with Python/PyTorch, plus R and RStudio.

## Branding

Editable R artwork and regeneration instructions are in [tools/branding](https://github.com/CTTIR/qviewparsR/blob/main/tools/branding/README.md).
