## Status

Version 1.0.0 was accepted on CRAN and published 2026-07-23
(doi:10.32614/CRAN.package.qviewparsR). The notes below are retained for
reference; they will be replaced at the next submission.

## R CMD check results

0 errors | 0 warnings | 1 note

The one NOTE is the expected new-submission note, plus a title-case
false positive:

* "New submission" — this was the first CRAN release of qviewparsR.
* The title-case check suggests `.q-View`, but `.Q-View` is the proper
  name of the binary file format the package reads (the capital "Q" is
  part of the format name, not a title-case error). The title is left as
  the correct proper noun.

(Local builds occasionally surface a single transient "unable to verify
current time" NOTE driven by the build host's network posture; it is not
raised by the package itself.)

## Test environments

* Local: Ubuntu Linux, R 4.6.1
* GitHub Actions: ubuntu-latest (release, devel, oldrel-1),
  macos-latest (release), windows-latest (release)

## Notes

* The package is a lean parser and export pipeline with no compiled
  code. Vignette and tests skip cleanly when no Q-View fixture is
  available. No examples access the network.
* `read_qview_report()` reads the flat report exports Q-View writes
  alongside the binary container; a small synthetic
  `example-report.csv` fixture ships in `inst/extdata/`.
