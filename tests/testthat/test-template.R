# read_qview_template() tests with small in-line CSVs (CI-safe).

.comma_template <- c(
  "12x8,,,,,,,,,,,,,",
  ",1,2,3,4,5,6,7,8,9,10,11,12,Group Name",
  "A,Cal 1,Cal 1,S1,S2,S3,S4,S5,S6,S7,S8,S9,S10,",
  "B,Cal 2,Cal 2,S1,S2,S3,S4,S5,S6,S7,S8,S9,S10,",
  "C,Cal 3,Cal 3,S1,S2,S3,S4,S5,S6,S7,S8,S9,S10,",
  "D,Cal 4,Cal 4,S1,S2,S3,S4,S5,S6,S7,S8,S9,S10,",
  "E,Cal 5,Cal 5,S1,S2,S3,S4,S5,S6,S7,S8,S9,S10,",
  "F,Cal 6,Cal 6,S1,S2,S3,S4,S5,S6,S7,S8,S9,S10,",
  "G,Low,Low,S1,S2,S3,S4,S5,S6,S7,S8,S9,S10,",
  "H,High,High,S1,S2,S3,S4,S5,S6,S7,S8,S9,S10,",
  ",,,,,,,,,,,,,",
  ",1,2,3,4,5,6,7,8,9,10,11,12,Group Type (i.e. calibrator negative sample control)",
  "A,calibrator,calibrator,sample,sample,sample,sample,sample,sample,sample,sample,sample,sample,",
  "B,calibrator,calibrator,sample,sample,sample,sample,sample,sample,sample,sample,sample,sample,",
  "C,calibrator,calibrator,sample,sample,sample,sample,sample,sample,sample,sample,sample,sample,",
  "D,calibrator,calibrator,sample,sample,sample,sample,sample,sample,sample,sample,sample,sample,",
  "E,calibrator,calibrator,sample,sample,sample,sample,sample,sample,sample,sample,sample,sample,",
  "F,calibrator,calibrator,sample,sample,sample,sample,sample,sample,sample,sample,sample,sample,",
  "G,control,control,sample,sample,sample,sample,sample,sample,sample,sample,sample,sample,",
  "H,control,control,sample,sample,sample,sample,sample,sample,sample,sample,sample,sample,",
  ",,,,,,,,,,,,,",
  ",1,2,3,4,5,6,7,8,9,10,11,12,Dilution Factor (total/part)",
  "A,,,100,100,100,100,100,100,100,100,100,100,",
  "B,,,100,100,100,100,100,100,100,100,100,100,",
  "C,,,100,100,100,100,100,100,100,100,100,100,",
  "D,,,100,100,100,100,100,100,100,100,100,100,",
  "E,,,100,100,100,100,100,100,100,100,100,100,",
  "F,,,100,100,100,100,100,100,100,100,100,100,",
  "G,,,100,100,100,100,100,100,100,100,100,100,",
  "H,,,100,100,100,100,100,100,100,100,100,100,"
)

write_tmp <- function(lines, sep = ",") {
  p <- withr::local_tempfile(fileext = ".csv", .local_envir = parent.frame())
  if (sep != ",") lines <- gsub(",", sep, lines, fixed = TRUE)
  writeLines(lines, p)
  p
}

test_that("comma-delimited template parses to one row per well", {
  p <- write_tmp(.comma_template)
  out <- read_qview_template(p, verbose = FALSE)
  expect_equal(nrow(out), 96L)
  expect_named(out, c("well", "plate_row", "plate_col", "sample_id",
                      "group_type", "dilution"))
  expect_equal(out$sample_id[out$well == "A1"], "Cal 1")
  expect_equal(out$group_type[out$well == "A1"], "calibrator")
  expect_equal(out$dilution[out$well == "A3"], 100)
})

test_that("semicolon-delimited (EU locale) template parses identically", {
  p_comma <- write_tmp(.comma_template)
  p_semi  <- write_tmp(.comma_template, sep = ";")
  out_comma <- read_qview_template(p_comma, verbose = FALSE)
  out_semi  <- read_qview_template(p_semi,  verbose = FALSE)
  expect_equal(out_semi, out_comma)
  expect_equal(out_semi$sample_id[out_semi$well == "A1"], "Cal 1")
})

test_that("read_qview_template rejects Excel workbooks", {
  p <- withr::local_tempfile(fileext = ".xlsx")
  writeLines("not really xlsx", p)
  expect_error(read_qview_template(p, verbose = FALSE),
               "must be a CSV template")
})

test_that("read_qview_template rejects a non-template CSV", {
  p <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("Project: something,,,", "Plate: Plate 1,,,"), p)
  expect_error(read_qview_template(p, verbose = FALSE),
               "not a recognisable")
})
