# Value cross-check: parsed pixel intensities must match Q-View's own
# per-well grid CSV exports at 1e-6.  These exports are large and live in
# the gitignored .data tree, so the test skips cleanly when absent (CI).

# Parse a per-well plate-grid export ("Ba (spot 1),1..12" blocks).
.parse_grid <- function(path) {
  lines <- readLines(path, warn = FALSE)
  rows <- list()
  i <- 1L
  while (i <= length(lines)) {
    f1 <- sub(",.*$", "", lines[i])
    m <- regmatches(f1, regexec("^(.+?) \\(spot ([0-9]+)\\)$", f1))[[1L]]
    if (length(m) == 3L && (i + 8L) <= length(lines)) {
      analyte <- trimws(m[2L])
      for (r in 1:8) {
        cells <- strsplit(lines[i + r], ",", fixed = TRUE)[[1L]]
        if (length(cells) < 13L) next
        for (cc in 1:12) {
          rows[[length(rows) + 1L]] <- list(
            well = paste0(trimws(cells[1L]), cc),
            analyte = analyte,
            grid = suppressWarnings(as.numeric(trimws(cells[cc + 1L]))))
        }
      }
      i <- i + 9L
    } else {
      i <- i + 1L
    }
  }
  out <- do.call(rbind.data.frame, c(rows, stringsAsFactors = FALSE))
  out[!is.na(out$grid), , drop = FALSE]
}

.grid_pairs <- function() {
  roots <- c(".data/qview", file.path("..", "..", ".data", "qview"))
  root <- roots[dir.exists(roots)][1]
  if (is.na(root) || !length(root)) return(list())
  qv <- list.files(root, pattern = "\\.Q-View$", recursive = TRUE,
                   full.names = TRUE)
  pairs <- list()
  for (f in qv) {
    g <- list.files(dirname(f), full.names = TRUE,
                    pattern = "(raw-data-pixel|data-analysis-data)\\.csv$")
    if (length(g)) pairs[[length(pairs) + 1L]] <- list(qview = f, grid = g[1])
  }
  pairs
}

.grid_agreement <- function(pi, grid) {
  keys <- c("well", "analyte")
  parsed_keys <- sort(paste(pi$well, pi$analyte, sep = "\r"))
  reference_keys <- sort(paste(grid$well, grid$analyte, sep = "\r"))
  j <- merge(pi[c("well", "analyte", "pixel_intensity")], grid, by = keys)
  rel <- ifelse(j$grid != 0,
                abs(j$pixel_intensity - j$grid) / abs(j$grid),
                abs(j$pixel_intensity - j$grid))
  c(unique_parsed = !anyDuplicated(pi[keys]),
    unique_reference = !anyDuplicated(grid[keys]),
    complete_keys = identical(parsed_keys, reference_keys),
    complete_join = nrow(j) == nrow(grid),
    numeric_agreement = all(is.finite(rel) & rel <= 1e-6))
}

.expect_grid_agreement <- function(pi, grid) {
  checks <- .grid_agreement(pi, grid)
  expect_true(all(checks), info = paste(names(checks)[!checks], collapse = ", "))
}

test_that("synthetic independent grid checks require complete key coverage", {
  reference <- data.frame(well = c("A1", "A2", "B1"),
                          analyte = c("X", "X", "X"), grid = c(0, 2, 300))
  parsed <- data.frame(well = c("B1", "A1", "A2"), analyte = "X",
                       pixel_intensity = c(300, 0, 2))
  .expect_grid_agreement(parsed, reference)
  expect_failure(.expect_grid_agreement(parsed[-1L, ], reference))
  expect_failure(.expect_grid_agreement(rbind(parsed, parsed[1L, ]), reference))
  wrong <- parsed; wrong$pixel_intensity[1L] <- 30
  expect_failure(.expect_grid_agreement(wrong, reference))
})

test_that("parsed pixel intensities match grid exports at 1e-6", {
  pairs <- .grid_pairs()
  skip_if(length(pairs) == 0L, "no .Q-View + grid-export pairs available")
  for (pr in pairs) {
    qv <- read_qview(pr$qview, verbose = FALSE)
    grid <- .parse_grid(pr$grid)
    pi <- qv$pixel_intensities
    pi <- pi[!is.na(pi$well) & !is.na(pi$pixel_intensity), , drop = FALSE]
    # Compare the declared scientific panel only; Ref Spot is explicitly not
    # returned as a quantified analyte. No matching-key subset is sufficient.
    panel <- setdiff(qv$analytes$analyte, "Ref Spot")
    grid <- grid[grid$analyte %in% panel, , drop = FALSE]
    .expect_grid_agreement(pi, grid)
  }
})
