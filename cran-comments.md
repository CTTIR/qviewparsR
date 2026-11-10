## Update submission

This is an update of qviewparsR from version 1.0.0 (on CRAN since
2026-07-23) to version 1.1.0. It is a reliability release: the binary
reader now refuses conflicting embedded records instead of choosing the
most frequent copy, report and template readers validate malformed input,
missing/censored values are retained and summarised separately, and the
CSV/XLSX/RDS exporters stage output and require explicit overwriting. See
NEWS.md for details. The DESCRIPTION text now quotes software names.

## R CMD check results

0 errors | 0 warnings | 0 notes

* The title-case check may suggest `.q-View`; `.Q-View` is the proper name
  of the binary file format the package reads (the capital "Q" is part of
  the format name), so the title keeps the correct spelling. This is
  unchanged from the accepted 1.0.0 release.

## Test environments

* Local: macOS (aarch64-apple-darwin), R 4.6.1,
  `R CMD check --as-cran --no-manual`. The PDF manual was built locally
  with TinyTeX (TeX Live 2026) via `R CMD Rd2pdf` without errors; the check
  run itself used `--no-manual`.
* GitHub Actions (r-lib/actions v2, `--as-cran`): macos-latest (release),
  windows-latest (release), ubuntu-latest (devel, release, oldrel-1),
  ubuntu-22.04 (R 4.1, the minimum supported version).

## Reverse dependencies

There are currently no reverse dependencies on CRAN
(`tools::package_dependencies("qviewparsR", reverse = TRUE, which = "all")`
returns none).

## Notes

* The package is pure R with no compiled code. Examples and the vignette
  use only small synthetic fixtures shipped in `inst/extdata/`; they do not
  access the network and write only to `tempdir()`.
* End-to-end Shiny tests (shinytest2/chromote) are skipped on CRAN.
