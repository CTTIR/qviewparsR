test_that("strip_qview_prefix reverses Q-View internal naming", {
  expect_equal(strip_qview_prefix("ICal 1"), "Cal 1")
  expect_equal(strip_qview_prefix("ICal 6"), "Cal 6")
  expect_equal(strip_qview_prefix("GLow"),   "Low")
  expect_equal(strip_qview_prefix("HHigh"),  "High")
  expect_equal(strip_qview_prefix("NFD00000001"), "FD00000001")
  expect_equal(strip_qview_prefix("N1234567890"), "1234567890")
})

test_that("strip_qview_prefix passes unknown values through unchanged", {
  expect_equal(strip_qview_prefix("Plate 1"),   "Plate 1")
  expect_equal(strip_qview_prefix("Anything"),  "Anything")
  expect_equal(strip_qview_prefix(NA_character_), NA_character_)
})

test_that("strip_qview_prefix is vectorised", {
  inp <- c("ICal 1", "GLow", "NFD00000002", "Plate 1")
  out <- strip_qview_prefix(inp)
  expect_equal(out, c("Cal 1", "Low", "FD00000002", "Plate 1"))
})
