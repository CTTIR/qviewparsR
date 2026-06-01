# Unit tests for the report-row parser, exercised with small synthetic
# inputs so they run on CI without the (multi-MB) .Q-View fixtures.

test_that("complete replicate rows win over stale truncated duplicates", {
  # The H2 container retains superseded page versions of a well's row; a
  # version cut at a 2048-byte page boundary parses as a short row with a
  # stale group label. The current, intact row must win.
  analytes <- tibble::tibble(
    spot_number = 1:3,
    analyte = c("Ba", "Bb", "C3a"),
    unit = c("ng/ml", "ug/ml", "ng/ml")
  )
  lines <- c(
    # stale / truncated version of well D1 (only 2 of 3 analytes, Bb wrong)
    "Cal 4,Pixel Intensity (Replicate 1),D1,NA,913,31",
    # current, complete version of well D1 (all 3 analytes, Bb correct)
    "3738433602 (1:100),Pixel Intensity (Replicate 1),D1,NA,913,315,482"
  )
  rows <- .qv_parse_report_rows(lines, analytes)
  d1 <- rows$replicates[rows$replicates$well == "D1", , drop = FALSE]

  # exactly one reading per analyte for the physical well
  expect_equal(nrow(d1), 3L)
  expect_equal(sort(d1$analyte), c("Ba", "Bb", "C3a"))

  bb <- d1$pixel_intensity[d1$analyte == "Bb"]
  expect_equal(bb, 315)            # not the truncated 31
  # the surviving row carries the complete version's group label
  expect_equal(unique(d1$well_group), "3738433602 (1:100)")
})

test_that("the most frequent value wins across duplicate page copies", {
  # G1 in the wild: a truncated copy (Factor P = 6), two committed copies
  # of the correct row (Factor P = 64037), and one stale alternative
  # (Factor P = 1801). Majority across copies must pick 64037.
  analytes <- tibble::tibble(spot_number = 1:2,
                             analyte = c("C1q", "Factor P"),
                             unit = c("ug/ml", "ng/ml"))
  lines <- c(
    "Low,Pixel Intensity (Replicate 1),G1,NA,62397,6",        # truncated
    "Low,Pixel Intensity (Replicate 1),G1,NA,62397,64037",    # committed copy 1
    "Low,Pixel Intensity (Replicate 1),G1,NA,62397,64037",    # committed copy 2
    "Low,Pixel Intensity (Replicate 1),G1,NA,4424,1801"       # stale alternative
  )
  rows <- .qv_parse_report_rows(lines, analytes)
  fp <- rows$replicates$pixel_intensity[
    rows$replicates$well == "G1" & rows$replicates$analyte == "Factor P"]
  expect_equal(fp, 64037)
})

test_that("distinct physical wells are all retained", {
  analytes <- tibble::tibble(spot_number = 1:2,
                             analyte = c("Ba", "Bb"),
                             unit = c("ng/ml", "ug/ml"))
  lines <- c(
    "Cal 1,Pixel Intensity (Replicate 1),A1,NA,100,200",
    "Cal 1,Pixel Intensity (Replicate 2),A2,NA,110,210",
    "Cal 2,Pixel Intensity (Replicate 1),B1,NA,300,400"
  )
  rows <- .qv_parse_report_rows(lines, analytes)
  expect_setequal(unique(rows$replicates$well), c("A1", "A2", "B1"))
  expect_equal(nrow(rows$replicates), 6L)   # 3 wells x 2 analytes
})

test_that("summary rows for distinct groups are not collapsed", {
  analytes <- tibble::tibble(spot_number = 1:2,
                             analyte = c("Ba", "Bb"),
                             unit = c("ng/ml", "ug/ml"))
  lines <- c(
    'Cal 1,Pixel Intensity Average,"A1, A2",NA,100,200',
    'Cal 2,Pixel Intensity Average,"B1, B2",NA,300,400'
  )
  rows <- .qv_parse_report_rows(lines, analytes)
  expect_setequal(unique(rows$summaries$well_group), c("Cal 1", "Cal 2"))
})
