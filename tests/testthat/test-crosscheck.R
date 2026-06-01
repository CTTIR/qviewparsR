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
    } else i <- i + 1L
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

test_that("parsed pixel intensities match grid exports at 1e-6", {
  pairs <- .grid_pairs()
  skip_if(length(pairs) == 0L, "no .Q-View + grid-export pairs available")
  for (pr in pairs) {
    qv <- read_qview(pr$qview, verbose = FALSE)
    grid <- .parse_grid(pr$grid)
    pi <- qv$pixel_intensities
    pi <- pi[!is.na(pi$well) & !is.na(pi$pixel_intensity), , drop = FALSE]
    pi <- pi[!duplicated(pi[c("well", "analyte")]), , drop = FALSE]
    j <- merge(pi[c("well", "analyte", "pixel_intensity")], grid,
               by = c("well", "analyte"))
    expect_gt(nrow(j), 0L)
    rel <- ifelse(j$grid != 0,
                  abs(j$pixel_intensity - j$grid) / abs(j$grid),
                  abs(j$pixel_intensity - j$grid))
    expect_true(all(rel <= 1e-6),
                info = paste(basename(pr$qview),
                  "mismatches:",
                  paste(utils::head(sprintf("%s/%s p=%s g=%s",
                    j$well[rel > 1e-6], j$analyte[rel > 1e-6],
                    j$pixel_intensity[rel > 1e-6], j$grid[rel > 1e-6]), 3),
                    collapse = "; ")))
  }
})
