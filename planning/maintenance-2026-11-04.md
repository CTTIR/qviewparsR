# Reliability qualification, 2026-11-04

## Purpose and baseline

qviewparsR extracts reported multiplex ELISA measurements from embedded
Q-View reports or producer-exported CSV/XLSX files. It does not execute H2
transactions, recover a database commit state, or independently validate the
producer's calibration or scientific conclusions. Preserve both authors and
ORCIDs, original source fixtures, supported outputs, and private data exclusions.

Baseline: d8d4d15725919f17f17cffa966a1522fac7306fe, version 1.0.0.
The baseline installed successfully on macOS ARM with R 4.6.1. Full-suite and
application observations are recorded separately from installation success.

## Confirmed findings and strategy

1. Essential scientific repairs: conflicting embedded records can produce a
   majority-vote hybrid absent from every complete source row; malformed numbers
   can disappear; quoting/encoding and dilution handling can change sample IDs.
   Refuse ambiguous records, preserve recognized missing/censored observations,
   and retain decoded identities and raw provenance. Validate well/analyte keys.
   Verify with adversarial synthetic records and unchanged public examples.
2. Dependable import: malformed template geometry can duplicate assignments.
   Require complete unique geometry and positive finite dilution factors.
   Keep reports within the current A1-H12 scope; do not infer additional plate
   support. Verify malformed, empty, duplicate and valid inputs explicitly.
3. Dependable interaction: plotting failures can repeatedly invalidate their own
   reactive state; changed uploads/settings can leave older results available;
   image settings can request billions of pixels. Bound rendering, clear stale
   results, preserve original upload names/settings, and demonstrate recovery.
4. Dependable output: CSV exports can retain stale tables and a later failed
   write can leave a mixed bundle. Stage output, require explicit replacement,
   preserve unrelated files, and exercise failure paths against existing data.
5. Qualification: review integrations, full and minimal package checks,
   installed first-use paths, app behavior, documentation/examples, package
   contents and hosted checks. Record actual outcomes and exceptions below.

## Finding evidence and impact

| Confirmed defect | Location | Impact / priority | Repair and validation |
| --- | --- | --- | --- |
| Per-analyte majority voting returns a hybrid absent from complete candidate rows | `R/read_qview.R` | High: fabricated scientific record | Refuse conflicting keys; test complete contradictory rows and exact duplicates |
| Malformed/nonfinite cells disappear or survive as invalid measurements | Report readers | High: wrong values and sample coverage | Strict value grammar; retain recognized missing/censored rows; compare complete keys |
| CSV quoting, XLSX decoding and binary ASCII fragments change identities | Report readers and text extraction | High: sample misidentification | Preserve decoded strings or refuse unsupported fragments; Unicode/quote regressions |
| Duplicate template rows expand the output geometry | `R/read_qview_template.R` | High: misassigned wells | Validate dimensions, complete unique row/column assignments and dilution |
| Plot-error logging repeatedly triggers its own reactive computation | `R/app.R` | High: unresponsive application | Isolated bounded logging; actual failure and recovery tests |
| Changed inputs retain older downloadable results | `R/app.R` | High: wrong dataset exported | Invalidate results and retain upload/settings provenance |
| Valid UI settings request 1.296 billion raster pixels | `R/app.R` | High: excessive memory use | Explicit pixel budget checked before rendering |
| CSV replacement retains stale tables; later failed writes change earlier output | `R/export_qview.R` | High: mixed or damaged export | Stage, validate and explicitly replace; injected and real filesystem failures |
| Missing summaries yield NaN/infinities; plots treat censor bounds as observations | `R/methods-qview.R` | High: misleading numerical interpretation | Count categories separately, use NA estimates and exclude bounds from numeric plots |
| Imported analyte text is evaluated as CLI formatting expressions when printed | `R/methods-qview.R` | High: imported text can execute R expressions | Interpolate a literal value; arithmetic, malformed braces and temporary-file sentinel regressions |
| Installed browser tests try to reload an installed lazy namespace as source | `tests/testthat/apps/qview/app.R` | Medium: installed workflow not exercised | Select actual installed namespace; run bundled upload through the browser |

The unchanged installed baseline recorded 365 passing assertions, two browser
harness errors and one private-fixture skip. Baseline failure probes are separate
from candidate regression results. The baseline fixture override pointed to the bundled synthetic container.
That exercises generic parsing and is not private instrument validation.
Candidate checks keep unavailable private-fixture checks explicitly skipped.

## Acceptance criteria

No expression evaluation from imported diagnostic text, fabricated scientific record, silently lost malformed measurement, changed
sample identity, stale app download, or partially replaced export in the tested
workflows. Errors must identify the affected input and a usable recovery path.
Existing valid public examples must remain usable. Missing observations must
not yield infinite summary statistics. Tests must cover independent expected
values and complete key coverage, rather than merely agree with the parser.

## Deferred scope and evidence limits

General H2 transaction reconstruction, additional plate geometries, instrument
qualification, private producer-export comparison, physical-device testing and
scientific validation are outside this patch. Private reference files are not
available and their checks must remain explicitly skipped. No CRAN submission,
release tag or production deployment is implied by source publication.

## Verification and completed work

Final diagnostic review confirmed that imported brace expressions could be
evaluated by `print.qview()`. A safe temporary-file probe demonstrated the
effect, and the replacement now inserts the panel as a literal value. Six
installed regressions preserve braces, reject evaluation and retain the input
object. All other diagnostic call sites use source-literal templates; independent
probes and source review are recorded separately. Earlier candidate5 evidence
is retained; final archive checks follow the security repair.

Implemented the reader, template, summary, app-state and export repairs above.
Independent review additionally caught equivalent replicate-label conflicts,
conflicting later flat-report limits, inherited sample names across opaque
binary spans, and replacement changing private file permissions; all have
regression coverage. Source fixtures and both original authors/ORCIDs remain
unchanged. Dependency metadata now declares `fs` and the stable testthat mocking
API minimum (3.2.0). Public exports are preserved; CSV adds explicit overwrite
control after the existing positional arguments.

The final 1.0.1 source archive is 1,252,922 bytes, SHA-256
`a0bfff3c8ad08035261ccda2935031e9bfec0dd6a69cc26f0fcaf728ff886588`.
This identifies the observed build; build metadata can differ on another system.

| Executed validation | Result |
| --- | --- |
| Full macOS ARM, R 4.6.1, `R CMD check --as-cran` | 0 errors, 0 warnings, 0 NOTEs; 676 assertions pass; 15 unavailable private-fixture skips |
| Required dependencies plus testthat, optional app/plot/vignette packages absent | 0 errors, 0 warnings, 0 NOTEs with `--no-manual --ignore-vignettes`; 472 assertions pass; 52 optional/private skips |
| Fresh installed minimal first use | 21 checks pass, including CSV/XLSX/RDS readback, ambiguity errors, permissions and missing optional dependencies |
| Installed Chrome app | 17 assertions pass; actual downloads, recovery, plot height, scrolling, fullscreen and resizing observed |
| Exact-archive coverage | 97.23% (2071/2130 covr line tally); 659 assertions pass; 18 private/browser-under-coverage skips |
| Unchanged lint policy and workflow syntax | 0 findings |
| Source archive | 107 payload files; no worktree/private metadata or local path leakage; original three fixtures byte-identical |
| Local website | 29 pages, 1090 local references, 0 broken links; 15 browser states; scientific plot pixels preserved between themes |

Independent probes exercised concrete ambiguity, Unicode, recovery and permission
counterexamples. Charts retain their intended heights instead of shrinking to
unreadable strips. Local website tests covered desktop and 390-pixel layouts,
not a full accessibility certification.

All 14 final Rd inputs match the independently reviewed manual inputs. The
17-page reading PDF was converged with extra TeX/index passes; its 14 contents
entries, index and 98 numerical links were verified. The stock local
TeX-emulation output's two stale printed contents references remain recorded
separately. Stock check output was not overwritten or called visually correct.

Hosted checks are separate: this record captures local qualification before
source publication. See repository Actions for the exact published head;
local checks do not constitute CRAN acceptance or instrument validation.

The website now keeps scientific plot colours unchanged in dark mode, supplies
plot descriptions, resolves missing lifecycle images, and corrects measured
text contrast. The bundled lifecycle SVG retains its upstream MIT notice in
`inst/NOTICE`. The executable scientific vignette chunks and original branding
assets are unchanged by these presentation fixes. Worktree `.git` metadata is
excluded from source packages.

CI actions use verified immutable commits, read-only default permissions and
non-persistent checkout credentials; the existing Pages deployment permission
is preserved. An explicit R 4.1 row checks the declared minimum. Hosted results
and external release acceptance remain separate from local checks.

## Runnable first use

Prerequisites: R >= 4.1.0 and the declared R dependencies. Linux source installs
of compiled dependencies need an R build toolchain; compatible binary packages
avoid that requirement. In a fresh R session, after source publication:

```r
if (!requireNamespace("pak", quietly = TRUE)) install.packages("pak")
pak::pak("CTTIR/qviewparsR")
library(qviewparsR)
qv <- read_qview(system.file("extdata", "example.Q-View", package = "qviewparsR"),
                 verbose = FALSE)
summary(qv)
out <- tempfile("qview-first-use-")
dir.create(out)
write_qview_csv(qv, file.path(out, "tables"))
write_qview_rds(qv, file.path(out, "project.rds"))
stopifnot(identical(qv, readRDS(file.path(out, "project.rds"))))
```

Optional app prerequisites are `shiny`, `bslib`, `DT`, `ggplot2`, `withr` and
`patchwork` for the overview;
then run `qview_app()`. The app accepts binary projects; use
`read_qview_report()` in R for the producer-export fallback. Changing an input
clears earlier results. Censored numeric bounds remain in tables and are
excluded from numerical estimates/plots.

## Release boundaries

Source publication is authorized; CRAN submission, release tags and a new
Zenodo deposition are not performed by this maintenance pass. The existing
citation/deposition metadata intentionally describes the archived 1.0.0 record.
A formal release must update that metadata against the actual new deposition,
then submit the qualified source archive through the maintainer account.
POSIX-style filesystem modes are checked during export replacement; ACLs and
ownership are not copied. Staging/rollback is not a concurrent-writer protocol
or a crash-atomic filesystem transaction.
