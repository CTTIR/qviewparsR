# Malformed / non-conforming inputs must fail gracefully with a clear,
# file-naming message -- never an uninformative crash or a silent parse.

test_that("read_qview rejects a plain CSV report (not a binary container)", {
  p <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("Project: 20000102_SYN-PLATE-08_panel-1,,,",
               "Plate: Plate 1,,,",
               "Well Group,Statistic,Well,Error Codes,Ba (ng/ml)"), p)
  expect_error(read_qview(p, verbose = FALSE), "not a valid .*Q-View")
})

test_that("read_qview rejects an empty file gracefully", {
  p <- withr::local_tempfile(fileext = ".Q-View")
  file.create(p)
  expect_error(read_qview(p, verbose = FALSE), "not a valid .*Q-View")
})

test_that("malformed-input error messages are stable", {
  p <- withr::local_tempfile(fileext = ".csv")
  writeLines("Project: not a q-view binary,,,", p)
  expect_snapshot(read_qview(p, verbose = FALSE), error = TRUE,
                  transform = function(x) sub(p, "<tmp>.csv", x, fixed = TRUE))

  q <- withr::local_tempfile(fileext = ".csv")
  writeLines("just,some,values", q)
  expect_snapshot(read_qview_template(q, verbose = FALSE), error = TRUE,
                  transform = function(x) sub(q, "<tmp>.csv", x, fixed = TRUE))
})

test_that("readers refuse a directory path before opening it", {
  d <- withr::local_tempdir()
  for (reader in list(read_qview, read_qview_report, read_qview_template)) {
    expect_no_warning(expect_error(reader(d, verbose = FALSE), "is a directory"))
  }
})
