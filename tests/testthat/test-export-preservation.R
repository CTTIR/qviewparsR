.export_preservation_qview <- function(project = "before") {
  structure(list(
    metadata = list(project = project, plate = "001"),
    analytes = tibble::tibble(analyte = "A", unit = "ng/ml"),
    pixel_intensities = tibble::tibble(well = "A1", value = 1.25),
    concentrations = tibble::tibble(well = "A1", value = 2.5),
    segments = tibble::tibble(segment = 1L, start = 1L, end = 2L)
  ), class = "qview")
}

.export_tree_hashes <- function(path) {
  files <- sort(list.files(path, all.files = TRUE, recursive = TRUE,
                           full.names = TRUE, no.. = TRUE))
  stats::setNames(unname(tools::md5sum(files)), substring(files, nchar(path) + 2L))
}

.export_bytes <- function(path) readBin(path, "raw", n = file.info(path)$size)

test_that("CSV replacement is explicit, coherent, and includes segments", {
  d <- withr::local_tempdir()
  out <- file.path(d, "bundle")
  qv <- .export_preservation_qview()
  template <- tibble::tibble(well = "A1", sample_id = "001")
  write_qview_csv(qv, out, template)
  before <- .export_tree_hashes(out)
  replacement <- .export_preservation_qview("after")
  replacement$concentrations <- NULL
  expect_error(write_qview_csv(replacement, out), "already exists")
  expect_identical(.export_tree_hashes(out), before)
  expect_invisible(write_qview_csv(replacement, out, overwrite = TRUE))
  expect_false(file.exists(file.path(out, "concentrations.csv")))
  expect_false(file.exists(file.path(out, "template.csv")))
  metadata <- readr::read_csv(file.path(out, "metadata.csv"),
                              col_types = readr::cols(.default = "c"))
  expect_identical(metadata$value[metadata$field == "project"], "after")
  segments <- readr::read_csv(file.path(out, "segments.csv"),
                              show_col_types = FALSE)
  expect_equal(segments, replacement$segments)
  xlsx <- file.path(d, "bundle.xlsx")
  write_qview_xlsx(replacement, xlsx)
  expect_equal(openxlsx2::read_xlsx(xlsx, sheet = "segments"),
                as.data.frame(replacement$segments), ignore_attr = TRUE)
  expect_identical(sort(list.files(d, all.files = TRUE, no.. = TRUE)),
                   c("bundle", "bundle.xlsx"))
})

test_that("CSV preserves positional call arguments and deprecated forwarding", {
  withr::local_options(lifecycle_verbosity = "warning")
  d <- withr::local_tempdir()
  out <- file.path(d, "bundle")
  dir.create(out)
  qv <- .export_preservation_qview()
  expect_invisible(write_qview_csv(qv, out, NULL, environment()))
  qv$concentrations <- NULL
  expect_invisible(write_qview_csv(qv, out, NULL, environment(), TRUE))
  expect_false(file.exists(file.path(out, "concentrations.csv")))
  qv$concentrations <- tibble::tibble(value = 7)
  expect_warning(qview_to_csv_dir(qv, out, NULL, environment(), TRUE),
                 "deprecated")
  expect_true(file.exists(file.path(out, "concentrations.csv")))
  expect_warning(expect_error(qview_to_csv_dir(qv, out, NULL, environment()),
                              "already exists"), "deprecated")
})

test_that("CSV refuses unrelated or nonregular destination contents", {
  d <- withr::local_tempdir()
  qv <- .export_preservation_qview()
  for (entry in c("notes.txt", ".hidden", "nested")) {
    out <- file.path(d, entry)
    dir.create(out)
    writeLines("unrelated", file.path(out, entry))
    before <- .export_tree_hashes(out)
    expect_error(write_qview_csv(qv, out, overwrite = TRUE), "unrelated")
    expect_identical(.export_tree_hashes(out), before)
  }
  out <- file.path(d, "directory-member")
  dir.create(out)
  dir.create(file.path(out, "metadata.csv"))
  writeLines("keep", file.path(out, "metadata.csv", "note"))
  before <- .export_tree_hashes(out)
  expect_error(write_qview_csv(qv, out, overwrite = TRUE), "non-regular")
  expect_identical(.export_tree_hashes(out), before)
  ordinary <- file.path(d, "ordinary")
  writeLines("keep", ordinary)
  expect_error(write_qview_csv(qv, ordinary, overwrite = TRUE), "regular directory")
  expect_identical(readLines(ordinary), "keep")
  expect_error(write_qview_rds(qv, out, overwrite = TRUE), "regular file")
  expect_error(write_qview_xlsx(qv, out, overwrite = TRUE), "regular file")
})

test_that("all flat tables are validated before any output is changed", {
  d <- withr::local_tempdir()
  out <- file.path(d, "bundle")
  qv <- .export_preservation_qview()
  write_qview_csv(qv, out)
  before <- .export_tree_hashes(out)
  qv$metadata$project <- "after"
  qv$segments <- "invalid late table"
  expect_error(write_qview_csv(qv, out, overwrite = TRUE), "segments.*data frame")
  expect_identical(.export_tree_hashes(out), before)
  qv$segments <- tibble::tibble(value = list(list(a = 1)))
  expect_error(write_qview_csv(qv, out, overwrite = TRUE), "atomic columns")
  expect_error(write_qview_xlsx(qv, file.path(d, "out.xlsx")), "atomic columns")
  expect_identical(.export_tree_hashes(out), before)
  qv$extra <- list(provenance = "retain", values = list(1, 2))
  rds <- file.path(d, "full.rds")
  write_qview_rds(qv, rds)
  expect_identical(readRDS(rds), qv)
  expect_error(write_qview_csv(.export_preservation_qview(), out,
                              template = "bad", overwrite = TRUE), "template.*data frame")
  expect_identical(.export_tree_hashes(out), before)
})

test_that("partial RDS and XLSX writer failures preserve existing bytes", {
  d <- withr::local_tempdir()
  qv <- .export_preservation_qview()
  rds <- file.path(d, "previous")
  write_qview_rds(qv, rds)
  before <- .export_bytes(rds)
  testthat::with_mocked_bindings({
    expect_error(write_qview_rds(qv, rds, overwrite = TRUE), "injected RDS")
    expect_error(write_qview_rds(qv, file.path(d, "new.rds")), "injected RDS")
  }, saveRDS = function(object, file, ...) {
    writeLines("partial", file)
    cli::cli_abort("injected RDS writer failure")
  }, .package = "base")
  expect_identical(.export_bytes(rds), before)
  expect_false(file.exists(file.path(d, "new.rds")))
  qv$metadata$project <- "replacement"
  write_qview_rds(qv, rds, overwrite = TRUE)
  expect_identical(readRDS(rds), qv)
  xlsx <- file.path(d, "workbook.xlsx")
  write_qview_xlsx(qv, xlsx)
  before <- .export_bytes(xlsx)
  testthat::with_mocked_bindings({
    expect_error(write_qview_xlsx(qv, xlsx, overwrite = TRUE), "injected XLSX")
    expect_error(write_qview_xlsx(qv, file.path(d, "new.xlsx")), "injected XLSX")
  }, wb_save = function(wb, file, ...) {
    writeLines("partial", file)
    cli::cli_abort("injected XLSX writer failure")
  }, .package = "openxlsx2")
  expect_identical(.export_bytes(xlsx), before)
  expect_false(file.exists(file.path(d, "new.xlsx")))
  expect_identical(sort(list.files(d, all.files = TRUE, no.. = TRUE)),
                   c("previous", "workbook.xlsx"))
})

test_that("late CSV writer failure preserves the complete previous bundle", {
  d <- withr::local_tempdir()
  out <- file.path(d, "bundle")
  qv <- .export_preservation_qview()
  write_qview_csv(qv, out)
  before <- .export_tree_hashes(out)
  original <- readr::write_csv
  qv$metadata$project <- "after"
  testthat::local_mocked_bindings(write_csv = function(x, file, ...) {
    if (basename(file) == "analytes.csv") {
      writeLines("partial", file)
      cli::cli_abort("injected late CSV failure")
    }
    original(x, file, ...)
  }, .package = "readr")
  expect_error(write_qview_csv(qv, out, overwrite = TRUE), "injected late CSV")
  expect_identical(.export_tree_hashes(out), before)
  expect_error(write_qview_csv(qv, file.path(d, "new")), "injected late CSV")
  expect_false(dir.exists(file.path(d, "new")))
  expect_identical(list.files(d, all.files = TRUE, no.. = TRUE), "bundle")
})

test_that("failed promotion restores the entire prior file or bundle", {
  d <- withr::local_tempdir()
  for (kind in c("rds", "csv")) {
    out <- file.path(d, kind)
    writer <- if (kind == "rds") write_qview_rds else write_qview_csv
    qv <- .export_preservation_qview()
    writer(qv, out)
    before <- if (kind == "rds") .export_bytes(out) else .export_tree_hashes(out)
    qv$metadata$project <- "after"
    calls <- 0L
    testthat::with_mocked_bindings({
      expect_error(writer(qv, out, overwrite = TRUE), "previous destination was preserved")
    }, .qv_export_rename = function(from, to) {
      calls <<- calls + 1L
      if (calls == 2L) return(FALSE)
      file.rename(from, to)
    })
    after <- if (kind == "rds") .export_bytes(out) else .export_tree_hashes(out)
    expect_identical(after, before)
    expect_identical(calls, 3L)
  }
  expect_identical(sort(list.files(d, all.files = TRUE, no.. = TRUE)), c("csv", "rds"))
})

test_that("failed restoration retains a discoverable intact backup", {
  d <- withr::local_tempdir()
  out <- file.path(d, "bundle")
  qv <- .export_preservation_qview()
  write_qview_csv(qv, out)
  before <- .export_tree_hashes(out)
  calls <- 0L
  testthat::local_mocked_bindings(.qv_export_rename = function(from, to) {
    calls <<- calls + 1L
    if (calls > 1L) return(FALSE)
    file.rename(from, to)
  })
  error <- tryCatch(write_qview_csv(qv, out, overwrite = TRUE), error = identity)
  expect_s3_class(error, "qview_export_recovery_error")
  backup <- file.path(list.files(d, pattern = "^\\.qview-export-",
                                 all.files = TRUE, full.names = TRUE), "previous")
  expect_length(backup, 1L)
  expect_match(gsub("\\", "/", conditionMessage(error), fixed = TRUE),
               normalizePath(backup, winslash = "/"), fixed = TRUE)
  expect_identical(.export_tree_hashes(backup), before)
  expect_false(dir.exists(out))
})

test_that("failed backup and output-free writers preserve prior data", {
  d <- withr::local_tempdir()
  out <- file.path(d, "saved.rds")
  qv <- .export_preservation_qview()
  write_qview_rds(qv, out)
  before <- .export_bytes(out)
  testthat::with_mocked_bindings({
    expect_error(write_qview_rds(qv, out, overwrite = TRUE), "Could not back up")
  }, .qv_export_rename = function(from, to) FALSE)
  expect_identical(.export_bytes(out), before)
  for (empty in c(FALSE, TRUE)) {
    testthat::with_mocked_bindings({
      expect_error(write_qview_rds(qv, out, overwrite = TRUE), "complete, non-empty")
    }, saveRDS = function(object, file, ...) {
      if (empty) file.create(file)
      invisible(NULL)
    }, .package = "base")
    expect_identical(.export_bytes(out), before)
  }
  expect_identical(list.files(d, all.files = TRUE, no.. = TRUE), "saved.rds")
})

test_that("unexpected inspection failure after backup retains recovery data", {
  d <- withr::local_tempdir()
  out <- file.path(d, "saved.rds")
  qv <- .export_preservation_qview()
  write_qview_rds(qv, out)
  before <- .export_bytes(out)
  original_type <- .qv_export_type
  backed_up <- FALSE
  testthat::local_mocked_bindings(
    .qv_export_rename = function(from, to) {
      if (backed_up) return(FALSE)
      answer <- file.rename(from, to)
      backed_up <<- isTRUE(answer)
      answer
    },
    .qv_export_type = function(path) {
      if (backed_up) cli::cli_abort("injected inspection failure")
      original_type(path)
    }
  )
  error <- tryCatch(write_qview_rds(qv, out, overwrite = TRUE), error = identity)
  expect_s3_class(error, "qview_export_recovery_error")
  expect_match(conditionMessage(error), "injected inspection")
  backup <- file.path(list.files(d, pattern = "^\\.qview-export-",
                                 all.files = TRUE, full.names = TRUE), "previous")
  expect_length(backup, 1L)
  expect_match(gsub("\\", "/", conditionMessage(error), fixed = TRUE),
               normalizePath(dirname(backup), winslash = "/"), fixed = TRUE)
  expect_identical(.export_bytes(backup), before)
})

test_that("file and bundle links are refused without touching their targets", {
  d <- withr::local_tempdir()
  target <- file.path(d, "target")
  writeLines("keep", target)
  link <- file.path(d, "link")
  if (!isTRUE(suppressWarnings(file.symlink(target, link)))) {
    skip("This account/filesystem cannot create file symbolic links.")
  }
  qv <- .export_preservation_qview()
  expect_error(write_qview_rds(qv, link, overwrite = TRUE), "symlink")
  expect_error(write_qview_xlsx(qv, link, overwrite = TRUE), "symlink")
  dangling <- file.path(d, "dangling")
  expect_true(file.symlink(file.path(d, "absent"), dangling))
  expect_error(write_qview_rds(qv, dangling, overwrite = TRUE), "symlink")
  bundle <- file.path(d, "bundle")
  dir.create(bundle)
  expect_true(file.symlink(target, file.path(bundle, "metadata.csv")))
  expect_error(write_qview_csv(qv, bundle, overwrite = TRUE), "non-regular")
  bundle_link <- file.path(d, "bundle-link")
  fs::link_create(bundle, bundle_link)
  expect_error(write_qview_csv(qv, bundle_link, overwrite = TRUE), "symlink")
  expect_identical(readLines(target), "keep")
  expect_true(fs::is_link(link))
  expect_true(fs::is_link(dangling))
})

test_that("POSIX named pipes are refused as export files and bundle members", {
  skip_on_os("windows") # Windows R does not expose MSYS FIFOs as native files.
  skip_if(!nzchar(Sys.which("mkfifo")), "mkfifo is unavailable")
  d <- withr::local_tempdir()
  pipe <- file.path(d, "pipe")
  expect_identical(system2("mkfifo", shQuote(pipe)), 0L)
  qv <- .export_preservation_qview()
  expect_error(write_qview_rds(qv, pipe, overwrite = TRUE), "not FIFO")
  bundle <- file.path(d, "bundle")
  dir.create(bundle)
  expect_identical(system2("mkfifo", shQuote(file.path(bundle, "metadata.csv"))), 0L)
  expect_error(write_qview_csv(qv, bundle, overwrite = TRUE), "non-regular")
  expect_identical(as.character(fs::file_info(pipe)$type), "FIFO")
})

test_that("replacement preserves the filesystem's observed destination mode", {
  d <- withr::local_tempdir()
  qv <- .export_preservation_qview()
  out <- file.path(d, "saved.rds")
  write_qview_rds(qv, out)
  mode <- fs::file_info(out)$permissions
  qv$metadata$project <- "replacement"
  write_qview_rds(qv, out, overwrite = TRUE)
  expect_identical(fs::file_info(out)$permissions, mode)
  expect_identical(readRDS(out), qv)
})

test_that("POSIX private file and shared CSV directory modes survive replacement", {
  skip_on_os("windows") # Native Windows modes do not model POSIX group bits.
  d <- withr::local_tempdir()
  qv <- .export_preservation_qview()
  for (format in c("rds", "xlsx")) {
    writer <- if (format == "rds") write_qview_rds else write_qview_xlsx
    out <- file.path(d, paste0("private.", format))
    writer(qv, out)
    fs::file_chmod(out, "0600")
    expect_identical(as.character(file.info(out)$mode), "600")
    writer(.export_preservation_qview("replacement"), out, overwrite = TRUE)
    expect_identical(as.character(file.info(out)$mode), "600")
  }
  out <- file.path(d, "bundle")
  write_qview_csv(qv, out)
  expect_identical(as.character(file.info(out)$mode), "700")
  fs::file_chmod(out, "0750")
  fs::file_chmod(file.path(out, "metadata.csv"), "0640")
  fs::file_chmod(file.path(out, "analytes.csv"), "0600")
  replacement <- .export_preservation_qview("replacement")
  replacement$concentrations <- NULL
  write_qview_csv(replacement, out, overwrite = TRUE)
  expect_identical(as.character(file.info(out)$mode), "750")
  expect_identical(as.character(file.info(file.path(out, "metadata.csv"))$mode), "640")
  expect_identical(as.character(file.info(file.path(out, "analytes.csv"))$mode), "600")
  expect_false(file.exists(file.path(out, "concentrations.csv")))
  metadata <- readr::read_csv(file.path(out, "metadata.csv"),
                              col_types = readr::cols(.default = "c"))
  expect_identical(metadata$value[metadata$field == "project"], "replacement")
})

test_that("permission-setting failure occurs before any prior output is moved", {
  d <- withr::local_tempdir()
  qv <- .export_preservation_qview()
  rds <- file.path(d, "saved.rds")
  xlsx <- file.path(d, "saved.xlsx")
  csv <- file.path(d, "bundle")
  write_qview_rds(qv, rds)
  write_qview_xlsx(qv, xlsx)
  write_qview_csv(qv, csv)
  before <- .export_tree_hashes(d)
  modes <- fs::file_info(c(rds, xlsx, csv))$permissions
  moves <- 0L
  local_mocked_bindings(.qv_export_rename = function(from, to) {
    moves <<- moves + 1L
    file.rename(from, to)
  })
  testthat::with_mocked_bindings({
    expect_error(write_qview_rds(qv, rds, overwrite = TRUE), "injected chmod")
    expect_error(write_qview_xlsx(qv, xlsx, overwrite = TRUE), "injected chmod")
    expect_error(write_qview_csv(qv, csv, overwrite = TRUE), "injected chmod")
  }, file_chmod = function(path, mode) cli::cli_abort("injected chmod failure"),
  .package = "fs")
  expect_identical(moves, 0L)
  expect_identical(.export_tree_hashes(d), before)
  expect_identical(fs::file_info(c(rds, xlsx, csv))$permissions, modes)
})

test_that("an unapplied permission mode cannot silently publish wider access", {
  skip_on_os("windows") # Native Windows modes do not model POSIX group bits.
  previous_umask <- Sys.umask("0022")
  withr::defer(Sys.umask(previous_umask))
  d <- withr::local_tempdir()
  out <- file.path(d, "private.rds")
  qv <- .export_preservation_qview()
  write_qview_rds(qv, out)
  fs::file_chmod(out, "0600")
  before <- .export_bytes(out)
  testthat::local_mocked_bindings(file_chmod = function(path, mode) invisible(path),
                                  .package = "fs")
  expect_error(write_qview_rds(qv, out, overwrite = TRUE), "preserve the permission mode")
  expect_identical(.export_bytes(out), before)
  expect_identical(as.character(file.info(out)$mode), "600")
  expect_identical(list.files(d, all.files = TRUE, no.. = TRUE), "private.rds")
})
