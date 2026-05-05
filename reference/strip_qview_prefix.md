# Reverse the Q-View internal naming convention

On import, the producing software prefixes well-assignment template
names with single-letter codes:

## Usage

``` r
strip_qview_prefix(x)
```

## Arguments

- x:

  Character vector of Q-View internal names.

## Value

Character vector of the same length, with prefixes stripped.

## Details

- `"Cal 1"` ... `"Cal N"` -\> `"ICal 1"` ... `"ICal N"` (Internal
  calibrator)

- `"Low"` -\> `"GLow"`

- `"High"` -\> `"HHigh"`

- `"FD..."` and any all-digit ID -\> `"N..."` (sample prefix)

`strip_qview_prefix()` reverses this transformation so that downstream
code sees the identifiers exactly as they appear in the original
template CSV. Strings that do not match a known prefix pattern are
returned unchanged.

## Examples

``` r
strip_qview_prefix(c("ICal 1", "GLow", "HHigh",
                     "NFD24277364", "N1211498458", "Plate 1"))
#> [1] "Cal 1"      "Low"        "High"       "FD24277364" "1211498458"
#> [6] "Plate 1"   
```
