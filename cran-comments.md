## R CMD check results

0 errors | 0 warnings | 0 notes

(Local builds occasionally surface a single transient
"unable to verify current time" NOTE driven by the build host's network
posture. It is not raised by the package itself.)

## Test environments

* Local: Windows 11 Pro for Workstations, R 4.5.2
* GitHub Actions: ubuntu-latest (release, devel, oldrel-1),
  macos-latest (release), windows-latest (release)

## This is a new submission.

## Notes

* This is the initial CRAN release of qviewparsR.
* The package is a lean parser and export pipeline with no compiled
  code. Vignette and tests skip cleanly when no Q-View fixture is
  available. No examples access the network.
