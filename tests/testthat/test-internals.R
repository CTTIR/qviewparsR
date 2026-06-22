# Direct unit tests for the internal parser helpers and their empty / guard
# branches. These are reached with crafted raw vectors and tiny inputs that
# the bundled fixture cannot express, mirroring the existing internal tests
# in test-parse-report.R.

test_that(".qv_check_magic accepts a valid header and rejects others", {
  good <- charToRaw("123 Q-View Project file")
  expect_true(.qv_check_magic(good, "x"))
  expect_error(.qv_check_magic(charToRaw("garbage header"), "bad.bin"),
               "not a valid")
})

test_that(".qv_parse_manifest returns an empty tibble for content-free input", {
  # Fewer than two lines -> empty manifest.
  e1 <- .qv_parse_manifest(charToRaw("1"))
  expect_s3_class(e1, "tbl_df")
  expect_equal(nrow(e1), 0L)
  # Two lines but no (numeric, name) pair -> still empty.
  e2 <- .qv_parse_manifest(charToRaw("alpha\nbeta\n"))
  expect_equal(nrow(e2), 0L)
})

test_that(".qv_parse_manifest extracts (size, name[, parent]) triplets", {
  raw <- charToRaw("3\n42\nreport.csv\n\\\\parent\n7\nother.bin\n")
  m <- .qv_parse_manifest(raw)
  expect_s3_class(m, "tbl_df")
  expect_true(all(c("name", "size_bytes", "parent") %in% names(m)))
  expect_true("report.csv" %in% m$name)
  expect_true(42L %in% m$size_bytes)
})

test_that(".qv_find_h2_segments returns empty when fewer than 3 markers", {
  seg <- .qv_find_h2_segments(charToRaw("no h2 markers here"))
  expect_s3_class(seg, "tbl_df")
  expect_equal(nrow(seg), 0L)
})

test_that(".qv_extract_metadata fills NA when no metadata block is present", {
  md <- .qv_extract_metadata(charToRaw("123 Q-View Project"), "some/path.Q-View")
  expect_true(is.na(md$project))
  expect_equal(md$container_version, "123")
  expect_false(is.null(md$parsed_at))
})

test_that(".qv_extract_analyte_panel returns the empty panel without a marker", {
  empty <- .qv_extract_analyte_panel(charToRaw("nothing to see"))
  expect_s3_class(empty, "tbl_df")
  expect_equal(nrow(empty), 0L)
  expect_true(all(c("spot_number", "analyte", "unit", "lod", "lloq", "uloq")
                  %in% names(empty)))
})

test_that(".qv_extract_analyte_panel with a header but <=4 fields is empty", {
  raw <- charToRaw("Well Group,Statistic,Well,Error Codes\n")
  expect_equal(nrow(.qv_extract_analyte_panel(raw)), 0L)
})

test_that(".qv_extract_report_lines returns NULL when no report rows match", {
  expect_null(.qv_extract_report_lines(charToRaw(strrep("x", 100L))))
})

test_that(".qv_parse_report_rows returns the empty bundle for trivial input", {
  analytes <- tibble::tibble(spot_number = 1L, analyte = "Ba", unit = "ng/ml")
  out <- .qv_parse_report_rows(NULL, analytes)
  expect_s3_class(out$replicates, "tbl_df")
  expect_equal(nrow(out$replicates), 0L)
  expect_null(out$concentrations)
  # Empty analyte panel short-circuits too.
  out2 <- .qv_parse_report_rows(c("a,b,c,d,1"), tibble::tibble(
    spot_number = integer(), analyte = character(), unit = character()))
  expect_equal(nrow(out2$summaries), 0L)
})

test_that(".qv_extract_curve_fit returns NULL when no regression row exists", {
  analytes <- tibble::tibble(spot_number = 1L, analyte = "Ba", unit = "ng/ml")
  expect_null(.qv_extract_curve_fit(NULL, analytes))
  expect_null(.qv_extract_curve_fit("Cal 1,Pixel Intensity Average,A1,NA,1",
                                    analytes))
})

test_that(".qv_build_well_groups returns the typed empty tibble with no groups", {
  wg <- .qv_build_well_groups(.qv_empty_replicates(), .qv_empty_summaries())
  expect_s3_class(wg, "tbl_df")
  expect_equal(nrow(wg), 0L)
  expect_s3_class(wg$well_type, "factor")
})

test_that(".qv_build_well_groups classifies the four well types", {
  reps <- tibble::tibble(
    well_group = c("ICal 1", "GLow", "HHigh", "N123 (1:5)"),
    sample_id = NA_character_)
  summ <- .qv_empty_summaries()
  wg <- .qv_build_well_groups(reps, summ)
  type <- function(g) as.character(wg$well_type[wg$well_group == g])
  expect_equal(type("ICal 1"), "standard")
  expect_equal(type("GLow"),   "negative")
  expect_equal(type("HHigh"),  "control")
  expect_equal(type("N123 (1:5)"), "sample")
})

test_that(".qv_build_plate_layout fills NA columns when there are no replicates", {
  wg <- .qv_build_well_groups(.qv_empty_replicates(), .qv_empty_summaries())
  pl <- .qv_build_plate_layout(.qv_empty_replicates(), wg)
  expect_equal(nrow(pl), 96L)            # full 8x12 grid
  expect_true(all(is.na(pl$well_group)))
  expect_true(all(is.na(pl$dilution)))
})

test_that(".qv_is_qview_binary handles missing files, content, and empties", {
  expect_false(.qv_is_qview_binary(file.path(tempdir(), "nope-not-here.xyz")))
  # Recognised by the content signature regardless of extension.
  by_content <- withr::local_tempfile(fileext = ".bin")
  writeBin(charToRaw("0 Q-View Project header bytes"), by_content)
  expect_true(.qv_is_qview_binary(by_content))
  # A .Q-View file is also recognised, via the same content sniff (the
  # `tools::file_ext()` shortcut never fires because the hyphen in the
  # extension is not alphanumeric).
  qv_ext <- withr::local_tempfile(fileext = ".Q-View")
  writeBin(charToRaw("17 Q-View Project"), qv_ext)
  expect_true(.qv_is_qview_binary(qv_ext))
  # No signature -> FALSE.
  neither <- withr::local_tempfile(fileext = ".bin")
  writeBin(charToRaw("plain bytes only"), neither)
  expect_false(.qv_is_qview_binary(neither))
  # Empty file -> FALSE (zero-length read branch).
  empty <- withr::local_tempfile(fileext = ".bin")
  file.create(empty)
  expect_false(.qv_is_qview_binary(empty))
})

test_that(".qv_metadata_tibble copes with zero-length metadata entries", {
  qv <- structure(list(
    metadata = list(project = character(0), plate = "Plate 1")),
    class = "qview")
  mt <- .qv_metadata_tibble(qv)
  expect_s3_class(mt, "tbl_df")
  expect_named(mt, c("field", "value"))
  expect_true(is.na(mt$value[mt$field == "project"]))
})

test_that("read_qview(verbose = TRUE) prints a parse summary", {
  path <- system.file("extdata", "example.Q-View", package = "qviewparsR")
  expect_message(quiet <- read_qview(path, verbose = FALSE), NA)
  expect_message(loud <- read_qview(path, verbose = TRUE), "Parsed")
  # The chatter does not change the returned object.
  loud$metadata$parsed_at <- quiet$metadata$parsed_at
  expect_identical(quiet, loud)
})
