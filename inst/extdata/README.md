# Example inputs

These are small synthetic demonstration inputs distributed with the package:

- `example.Q-View`: embedded-report container used by the public end-to-end
  regression tests.
- `example-report.csv`: a flat report with example project/user identifiers and
  concentration cells, including censor flags.
- `example-template.csv`: a 12-column by 8-row plate assignment template.

They exercise different features and are not a matched instrument-validation
set. In particular, comparing the template and container can show assignment
differences. Their numerical values must not be interpreted as experimental
measurements or evidence of assay performance. Tests against private producer
exports are separate and require the corresponding files supplied locally.

The maintenance patch preserves the original three input files unchanged.
