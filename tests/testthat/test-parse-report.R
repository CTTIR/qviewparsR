# Unit tests for the report-row parser, exercised with small synthetic
# inputs so they run on CI without the (multi-MB) .Q-View fixtures.

test_that("conflicting complete or truncated page candidates are refused", {
  analytes <- tibble::tibble(spot_number = 1:3,
    analyte = c("Ba", "Bb", "C3a"), unit = c("ng/ml", "ug/ml", "ng/ml"))
  lines <- c(
    "Cal 4,Pixel Intensity (Replicate 1),D1,NA,913,31",
    "3738433602 (1:100),Pixel Intensity (Replicate 1),D1,NA,913,315,482")
  expect_error(.qv_parse_report_rows(lines, analytes), "Incomplete or extra")
})

test_that("copy counts do not establish the current committed value", {
  analytes <- tibble::tibble(spot_number = 1:2,
    analyte = c("C1q", "Factor P"), unit = c("ug/ml", "ng/ml"))
  lines <- c(
    "Low,Pixel Intensity (Replicate 1),G1,NA,62397,6",
    "Low,Pixel Intensity (Replicate 1),G1,NA,62397,64037",
    "Low,Pixel Intensity (Replicate 1),G1,NA,62397,64037",
    "Low,Pixel Intensity (Replicate 1),G1,NA,4424,1801")
  expect_error(.qv_parse_report_rows(lines, analytes), "Ambiguous conflicting")
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
