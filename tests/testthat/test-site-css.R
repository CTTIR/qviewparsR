# The site stylesheet is not part of the built package, so this check runs
# only from a source checkout.

test_that("example plots keep their colours and full opacity in dark mode", {
  css <- test_path("..", "..", "pkgdown", "extra.css")
  skip_if_not(file.exists(css), "pkgdown/extra.css is only in the source tree")
  text <- paste(readLines(css, warn = FALSE), collapse = "\n")
  rules <- regmatches(text, gregexpr("[^{}]+\\{[^}]*\\}", text))[[1L]]
  rule <- rules[grepl("pre .r-plt.img img", rules, fixed = TRUE)]
  expect_length(rule, 1L)
  expect_match(rule, "img.r-plt", fixed = TRUE)
  expect_match(rule, "filter: none !important;", fixed = TRUE)
  # pkgdown sets `[data-bs-theme="dark"] pre img { opacity: 0.66 }`.
  expect_match(rule, "opacity: 1 !important;", fixed = TRUE)
})
