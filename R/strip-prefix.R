#' Reverse the Q-View internal naming convention
#'
#' `r lifecycle::badge("stable")`
#'
#' On import, the producing software prefixes well-assignment template names
#' with single-letter codes:
#'
#' * `"Cal 1"` ... `"Cal N"` -> `"ICal 1"` ... `"ICal N"` (Internal calibrator)
#' * `"Low"` -> `"GLow"`
#' * `"High"` -> `"HHigh"`
#' * `"FD..."` and any all-digit ID -> `"N..."` (sample prefix)
#'
#' `strip_qview_prefix()` reverses this transformation so that downstream
#' code sees the identifiers exactly as they appear in the original
#' template CSV. Strings that do not match a known prefix pattern are
#' returned unchanged.
#'
#' @param x Character vector of Q-View internal names.
#'
#' @return Character vector of the same length as `x`, with prefixes
#'   stripped. NAs and unrecognised values pass through unchanged.
#'
#' @examples
#' strip_qview_prefix(c("ICal 1", "GLow", "HHigh",
#'                      "NFD24277364", "N1211498458", "Plate 1"))
#'
#' @family qview-helper
#' @export
strip_qview_prefix <- function(x) {
  x <- as.character(x)
  out <- x
  ical <- grepl("^ICal\\b", x)
  out[ical] <- sub("^ICal\\b", "Cal", x[ical])
  out[x == "GLow"]   <- "Low"
  out[x == "HHigh"]  <- "High"
  nfd <- grepl("^NFD[0-9]", x)
  out[nfd] <- sub("^N", "", x[nfd])
  ndig <- grepl("^N[0-9]+$", x)
  out[ndig] <- sub("^N", "", x[ndig])
  out
}
# Version 1.0.0
