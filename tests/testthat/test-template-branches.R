# Guard / edge branches of read_qview_template() and its delimiter sniffer.

.mini_template <- c(
  "2x2,,,",
  ",1,2,Group Name",
  "A,Cal 1,S1,",
  "B,Cal 2,S2,",
  ",1,2,Group Type",
  "A,calibrator,sample,",
  "B,calibrator,sample,",
  ",1,2,Dilution Factor",
  "A,,100,",
  "B,,100,",
  ",1,2,Notes (ignored section)",
  "A,note1,note2,",
  "B,note3,note4,"
)

test_that("an unrecognised section label is skipped, recognised ones kept", {
  p <- withr::local_tempfile(fileext = ".csv")
  writeLines(.mini_template, p)
  out <- read_qview_template(p, verbose = FALSE)
  expect_equal(nrow(out), 4L)                       # A1,A2,B1,B2
  expect_named(out, c("well", "plate_row", "plate_col", "sample_id",
                      "group_type", "dilution"))
  expect_equal(out$sample_id[out$well == "A1"], "Cal 1")
  expect_equal(out$group_type[out$well == "B1"], "calibrator")
  expect_equal(out$dilution[out$well == "A2"], 100)
  expect_false("notes" %in% names(out))             # the bogus section dropped
})

test_that("read_qview_template(verbose = TRUE) prints a parse summary", {
  p <- withr::local_tempfile(fileext = ".csv")
  writeLines(.mini_template, p)
  expect_message(loud  <- read_qview_template(p, verbose = TRUE), "Parsed Q-View template")
  expect_message(quiet <- read_qview_template(p, verbose = FALSE), NA)
  expect_identical(quiet, loud)
})

test_that("read_qview_template errors when section headers are missing", {
  p <- withr::local_tempfile(fileext = ".csv")
  # Valid NxM cell, but no row with a blank first cell and a '1' second cell.
  writeLines(c("2x2,foo,bar", "data,a,b", "more,c,d"), p)
  expect_error(read_qview_template(p, verbose = FALSE),
               "no recognisable section headers")
})

test_that(".qv_sniff_delim falls back to comma for empty and delimiter-free input", {
  empty <- withr::local_tempfile(fileext = ".csv"); file.create(empty)
  expect_equal(.qv_sniff_delim(empty), ",")
  none <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("abc", "def"), none)
  expect_equal(.qv_sniff_delim(none), ",")
  semi <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("a;b;c", "d;e;f"), semi)
  expect_equal(.qv_sniff_delim(semi), ";")
})
