test_that("well_label converts 0-based indices to plate notation", {
  expect_equal(well_label(0L,  0L,  zero_based = TRUE), "A1")
  expect_equal(well_label(7L, 11L, zero_based = TRUE), "H12")
  expect_equal(well_label(2L,  4L, zero_based = TRUE), "C5")
})

test_that("well_label converts 1-based indices to plate notation", {
  expect_equal(well_label(1L, 1L), "A1")
  expect_equal(well_label(8L, 12L), "H12")
})

test_that("well_label accepts a row letter directly", {
  expect_equal(well_label("c", 5), "C5")
  expect_equal(well_label("H", 12), "H12")
})

test_that("well_label is vectorised", {
  expect_equal(well_label(c(1L, 8L), c(1L, 12L)), c("A1", "H12"))
})
