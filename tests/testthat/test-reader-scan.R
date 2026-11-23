# The container scan classifies bytes in chunks and inspects line starts only
# at candidate positions. These tests pin that it reports exactly the runs a
# whole-vector rle() would, and that binary padding cannot change the result.

test_that("chunked text-run detection matches rle() at every chunk size", {
  set.seed(20261123)
  bytes <- as.raw(sample(c(0L, 9L, 10L, 13L, 31L, 32L, 65L, 126L, 127L, 200L),
                         997L, replace = TRUE))
  bytes[100:180] <- charToRaw(strrep("x", 81L))
  reference <- rle(.qv_is_text_byte(bytes))
  ends <- cumsum(reference$lengths)
  for (chunk in c(1L, 2L, 3L, 7L, 64L, 500L, 997L, 4096L)) {
    runs <- .qv_text_runs(bytes, chunk = chunk)
    expect_identical(runs$ends, as.integer(ends), info = paste("chunk", chunk))
    expect_identical(runs$starts, as.integer(ends - reference$lengths + 1L))
    expect_identical(runs$text, reference$values)
  }
  empty <- .qv_text_runs(raw())
  expect_identical(lengths(empty), c(starts = 0L, ends = 0L, text = 0L))
  expect_identical(.qv_text_runs(as.raw(65L))$ends, 1L)
})

test_that("line-start detection inspects only the candidate positions", {
  bytes <- charToRaw("ab\ncd\r\nef")
  expect_identical(.qv_at_line_start(bytes, c(1L, 2L, 4L, 5L, 8L, 9L)),
                   c(TRUE, FALSE, TRUE, FALSE, TRUE, FALSE))
  expect_identical(.qv_at_line_start(bytes, integer()), logical())
})

test_that("binary padding around the embedded report does not change the parse", {
  fixture <- system.file("extdata", "example.Q-View", package = "qviewparsR")
  bytes <- readBin(fixture, "raw", n = file.info(fixture)$size)
  set.seed(1)
  padding <- as.raw(sample(c(0L, 128:255), 3L * 8388608L + 17L, replace = TRUE))
  padded <- withr::local_tempfile(fileext = ".Q-View")
  writeBin(c(bytes, padding), padded)
  expected <- read_qview(fixture, verbose = FALSE)
  actual <- expect_no_warning(read_qview(padded, verbose = FALSE))
  for (slot in c("analytes", "well_groups", "pixel_intensities",
                 "summary_statistics", "concentrations", "curve_fit",
                 "report_csv", "plate_layout", "manifest")) {
    expect_identical(actual[[slot]], expected[[slot]], info = slot)
  }
})

test_that("non-UTF-8 header bytes neither warn nor hide a valid container", {
  manifest <- c(charToRaw("1\nQ-View Project.lobs.db\n\n125\nQ-View Project.h2.db\n"),
                as.raw(c(0xFFL, 0xFEL)), charToRaw("\n-- H2 0.5/B --\n"),
                as.raw(200:255),
                charToRaw("\nWell Group,Statistic,Well,Error Codes,X (ng/mL)\n"),
                charToRaw("S1,Pixel Intensity (Replicate 1),A1,,100\n"))
  path <- withr::local_tempfile(fileext = ".Q-View")
  writeBin(manifest, path)
  qv <- expect_no_warning(read_qview(path, verbose = FALSE))
  expect_identical(qv$metadata$container_version, "1")
  expect_identical(qv$manifest$name,
                   c("Q-View Project.lobs.db", "Q-View Project.h2.db"))
  expect_identical(qv$manifest$size_bytes, c(1L, 125L))
  expect_identical(qv$pixel_intensities$pixel_intensity, 100)

  image <- withr::local_tempfile(fileext = ".png")
  writeBin(as.raw(c(0x89L, 0x50L, 0x4EL, 0x47L, 0x0DL, 0x0AL, 0x1AL, 0x0AL,
                    200:255)), image)
  expect_no_warning(expect_error(read_qview(image, verbose = FALSE),
                                 "not a valid .Q-View project file"))
})
