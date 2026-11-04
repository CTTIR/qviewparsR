test_that("printing treats report text as data rather than expressions", {
  qv <- read_qview(system.file("extdata", "example.Q-View",
                              package = "qviewparsR"), verbose = FALSE)
  sentinel <- tempfile("qview-print-sentinel-")
  on.exit(unlink(sentinel), add = TRUE)
  expression <- paste0("{file.create('", sentinel, "')}")
  qv$analytes$analyte[1:3] <- c("Marker {1 + 1}", expression, "{unclosed")
  qv$analytes$unit[[1]] <- "{2 + 2}"
  qv$metadata$project <- expression
  before <- serialize(qv, NULL)
  output <- capture.output(result <- print(qv), type = "message")
  text <- paste(output, collapse = "\n")
  expect_match(text, "Marker {1 + 1} ({2 + 2})", fixed = TRUE)
  expect_match(text, expression, fixed = TRUE)
  expect_match(text, "{unclosed", fixed = TRUE)
  expect_false(file.exists(sentinel))
  expect_identical(result, qv)
  expect_identical(serialize(qv, NULL), before)
})
