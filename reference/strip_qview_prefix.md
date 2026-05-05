# Reverse the Q-View internal naming convention

**\[experimental\]**

## Usage

``` r
strip_qview_prefix(x)
```

## Arguments

- x:

  Character vector of Q-View internal names.

## Value

Character vector of the same length as `x`, with prefixes stripped. NAs
and unrecognised values pass through unchanged.

## Details

On import, the producing software prefixes well-assignment template
names with single-letter codes:

- `"Cal 1"` ... `"Cal N"` -\> `"ICal 1"` ... `"ICal N"` (Internal
  calibrator)

- `"Low"` -\> `"GLow"`

- `"High"` -\> `"HHigh"`

- `"FD..."` and any all-digit ID -\> `"N..."` (sample prefix)

`strip_qview_prefix()` reverses this transformation so that downstream
code sees the identifiers exactly as they appear in the original
template CSV. Strings that do not match a known prefix pattern are
returned unchanged.

## See also

Other qview-helper:
[`well_label()`](https://cttir.github.io/qviewparsR/reference/well_label.md)

## Examples

``` r
strip_qview_prefix(c("ICal 1", "GLow", "HHigh",
                     "NFD24277364", "N1211498458", "Plate 1"))
#> [1] "Cal 1"      "Low"        "High"       "FD24277364" "1211498458"
#> [6] "Plate 1"   
```
