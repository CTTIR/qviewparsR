# Malformed / non-conforming inputs must fail gracefully with a clear,
# file-naming message -- never an uninformative crash or a silent parse.

test_that("read_qview rejects a plain CSV report (not a binary container)", {
  p <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("Project: 20230321_ELISA-plate-8_panel-1,,,",
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
