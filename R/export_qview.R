#' Write a Q-View object to disk
#'
#' `r lifecycle::badge("stable")`
#'
#' Three writers, one for each common destination. All return the input
#' `qv` invisibly so they compose with the pipe.
#'
#' * [write_qview_xlsx()] -- one sheet per parsed table.
#' * [write_qview_csv()]  -- one CSV per parsed table inside a directory.
#' * [write_qview_rds()]  -- a single `.rds` containing the full `qview`
#'   object (lossless, the only round-trippable format).
#'
#' @param qv A `qview` object from [read_qview()].
#' @param path Output path. For [write_qview_xlsx()] / [write_qview_rds()]
#'   this is a single file path; for [write_qview_csv()] it is the output
#'   directory (created if it does not exist).
#' @param template Optional plate-template tibble (from
#'   [read_qview_template()]) to include as an extra sheet / file.
#' @param overwrite Logical. If `FALSE` (the default), an existing
#'   file or non-empty CSV directory triggers an error. An existing empty
#'   CSV directory is allowed. With `TRUE`, CSV replacement accepts only
#'   the managed table filenames listed below; unrelated entries, links,
#'   and non-regular files are refused. Tables absent from the new object
#'   are removed only during this explicit replacement.
#' @param call The execution environment of the calling function. Used
#'   for error reporting; experts only.
#'
#' @return `qv`, invisibly, to support pipelines.
#'
#' @details
#' Tables are checked and written into a private staging directory beside
#' the destination before publication. An existing destination is moved to
#' a backup during replacement and restored if publication fails. If that
#' restoration fails, the error names the retained backup. This is not a
#' crash-atomic transaction: process termination, filesystem failure, or
#' concurrent readers/writers can observe an absent destination or leave
#' recovery files. Concurrent writers are not synchronized.
#'
#' Replacement copies and verifies the existing filesystem permission mode
#' before publication, including the CSV directory and each managed CSV file
#' present in both bundles. A new CSV directory is created with mode `0700`.
#' Mode support depends on the operating system and filesystem; ownership
#' and access-control lists (ACLs) are not copied by these writers.
#'
#' CSV bundles contain only non-empty tables named `metadata`, `analytes`,
#' `well_groups`, `plate_layout`, `pixel_intensities`, `summary_statistics`,
#' `concentrations`, `curve_fit`, `manifest`, `segments`, and optional
#' `template`, each with a `.csv` suffix. Use a dedicated directory.
#' CSV and XLSX require one-dimensional atomic columns; RDS retains the
#' full object, including additional fields and list columns.
#'
#' @examples
#' path <- system.file("extdata", "example.Q-View", package = "qviewparsR")
#' qv <- read_qview(path, verbose = FALSE)
#'
#' out <- tempfile()
#' dir.create(out)
#' qv |>
#'   write_qview_rds(file.path(out, "plate.rds")) |>
#'   write_qview_csv(file.path(out, "plate_csv"))
#' list.files(out, recursive = TRUE)
#'
#' @family qview-export
#' @name write_qview
NULL


#' @rdname write_qview
#' @export
write_qview_xlsx <- function(qv,
                             path,
                             template = NULL,
                             overwrite = FALSE,
                             call = rlang::caller_env()) {
  rlang::check_required(qv)
  rlang::check_required(path)
  .check_qview(qv, call = call)
  .check_string(path, call = call)
  .check_flag(overwrite, call = call)
  tables <- .qv_export_tables(qv, template, call = call)
  .qv_export_staged(path, "file", overwrite, function(stage) {
    wb <- openxlsx2::wb_workbook()
    for (name in names(tables)) {
      df <- tables[[name]]
      if (is.null(df) || nrow(df) == 0L) next
      wb$add_worksheet(name)
      wb$add_data(sheet = name, x = df)
    }
    openxlsx2::wb_save(wb, file = stage, overwrite = FALSE)
  }, call = call)
  invisible(qv)
}


#' @rdname write_qview
#' @export
write_qview_csv <- function(qv,
                            path,
                            template = NULL,
                            call = rlang::caller_env(),
                            overwrite = FALSE) {
  rlang::check_required(qv)
  rlang::check_required(path)
  .check_qview(qv, call = call)
  .check_string(path, call = call)
  .check_flag(overwrite, call = call)
  tables <- .qv_export_tables(qv, template, call = call)
  .qv_export_staged(path, "directory", overwrite, function(stage) {
    for (name in names(tables)) {
      df <- tables[[name]]
      if (is.null(df) || nrow(df) == 0L) next
      readr::write_csv(df, file.path(stage, paste0(name, ".csv")))
    }
  }, call = call)
  invisible(qv)
}


#' @rdname write_qview
#' @export
write_qview_rds <- function(qv,
                            path,
                            overwrite = FALSE,
                            call = rlang::caller_env()) {
  rlang::check_required(qv)
  rlang::check_required(path)
  .check_qview(qv, call = call)
  .check_string(path, call = call)
  .check_flag(overwrite, call = call)
  .qv_export_tables(qv, flat = FALSE, call = call)
  .qv_export_staged(path, "file", overwrite, function(stage) {
    saveRDS(qv, stage)
  }, call = call)
  invisible(qv)
}


.qv_metadata_tibble <- function(qv) {
  tibble::tibble(
    field = names(qv$metadata),
    value = vapply(qv$metadata, function(v) {
      if (length(v) == 0L) return(NA_character_)
      paste(format(v), collapse = "; ")
    }, character(1L))
  )
}


.qv_export_table_names <- function() {
  c("metadata", "analytes", "well_groups", "plate_layout",
    "pixel_intensities", "summary_statistics", "concentrations",
    "curve_fit", "manifest", "segments", "template")
}


.qv_export_tables <- function(qv, template = NULL, flat = TRUE,
                              call = rlang::caller_env()) {
  valid_names <- function(x) {
    !is.null(x) && !anyNA(x) && all(nzchar(x)) && !anyDuplicated(x)
  }
  if (!is.list(qv) || !valid_names(names(qv))) {
    cli::cli_abort("{.arg qv} must be a named list with unique fields.",
                   call = call)
  }
  metadata <- qv[["metadata", exact = TRUE]]
  if (!is.list(metadata) ||
      (length(metadata) > 0L && !valid_names(names(metadata)))) {
    cli::cli_abort("The {.field metadata} field must be a named list.",
                   call = call)
  }
  atomic_column <- function(x) is.atomic(x) && is.null(dim(x))
  if (flat && !all(vapply(metadata, function(x) {
    is.null(x) || atomic_column(x)
  }, logical(1L)))) {
    cli::cli_abort("Metadata values must be atomic for CSV or XLSX export.",
                   call = call)
  }
  fields <- setdiff(.qv_export_table_names(), c("metadata", "template"))
  tables <- stats::setNames(lapply(fields, function(name) {
    qv[[name, exact = TRUE]]
  }), fields)
  if (!is.null(template)) tables$template <- template
  for (name in names(tables)) {
    df <- tables[[name]]
    if (is.null(df)) next
    if (!is.data.frame(df) ||
        (ncol(df) > 0L && !valid_names(names(df)))) {
      cli::cli_abort(
        "Export table {.field {name}} must be a data frame with unique column names.",
        call = call
      )
    }
    if (flat && ((nrow(df) > 0L && ncol(df) == 0L) ||
                 !all(vapply(df, atomic_column, logical(1L))))) {
      cli::cli_abort(
        c("Export table {.field {name}} must have one-dimensional atomic columns.",
          "i" = "Use {.fn write_qview_rds} to retain list or matrix columns."),
        call = call
      )
    }
  }
  if (flat) tables <- c(list(metadata = .qv_metadata_tibble(qv)), tables)
  tables
}


.qv_export_type <- function(path) {
  if (isTRUE(fs::is_link(path))) return("symlink")
  as.character(fs::file_info(path, fail = TRUE, follow = FALSE)$type[[1L]])
}


.qv_export_guard <- function(path, kind, overwrite, call) {
  type <- .qv_export_type(path)
  if (is.na(type)) return(FALSE)
  if (!identical(type, kind)) {
    cli::cli_abort(
      "Export destination {.path {path}} must be a regular {kind}, not {type}.",
      call = call
    )
  }
  entries <- if (kind == "directory") {
    fs::dir_ls(path, all = TRUE, recurse = FALSE)
  } else {
    path
  }
  if (length(entries) > 0L && !overwrite) {
    cli::cli_abort(
      c("{.path {path}} already exists and is not an empty CSV directory.",
        "i" = "Set {.code overwrite = TRUE} to replace managed output."),
      call = call
    )
  }
  if (kind == "directory" && length(entries) > 0L) {
    managed <- paste0(.qv_export_table_names(), ".csv")
    if (any(!basename(entries) %in% managed)) {
      cli::cli_abort(
        "CSV destination {.path {path}} contains unrelated entries; use a dedicated directory.",
        call = call
      )
    }
    if (any(vapply(entries, function(x) {
      !identical(.qv_export_type(x), "file")
    }, logical(1L)))) {
      cli::cli_abort(
        "CSV destination {.path {path}} contains links or non-regular files.",
        call = call
      )
    }
  }
  TRUE
}


.qv_export_rename <- function(from, to) file.rename(from, to)


.qv_export_permissions <- function(stage, path, kind, call) {
  previous <- path
  replacement <- stage
  if (kind == "directory") {
    # Copy file modes first, then the directory mode: a restrictive directory
    # mode must not prevent preparing its own staged member files.
    common <- intersect(basename(fs::dir_ls(path, all = TRUE)),
                        basename(fs::dir_ls(stage, all = TRUE)))
    previous <- c(file.path(path, common), path)
    replacement <- c(file.path(stage, common), stage)
  }
  modes <- fs::file_info(previous, follow = FALSE)$permissions
  if (anyNA(modes)) {
    cli::cli_abort("Could not read the existing export permission modes.",
                   call = call)
  }
  for (i in seq_along(previous)) {
    fs::file_chmod(replacement[[i]], modes[i])
    copied <- fs::file_info(replacement[[i]], follow = FALSE)$permissions
    if (!identical(as.integer(copied), as.integer(modes[i]))) {
      cli::cli_abort(
        "Could not preserve the permission mode of {.path {previous[[i]]}}; export was not published.",
        call = call
      )
    }
  }
  invisible(NULL)
}


.qv_export_publish <- function(stage, path, kind, overwrite, state, call) {
  exists <- .qv_export_guard(path, kind, overwrite, call)
  if (exists) .qv_export_permissions(stage, path, kind, call)
  backup <- file.path(state$root, "previous")
  attempt <- function(from, to) {
    tryCatch(.qv_export_rename(from, to), error = identity)
  }
  if (exists) {
    # Once a backup may exist, every unexpected error must retain it until
    # publication or restoration has positively succeeded.
    state$keep <- TRUE
    moved <- attempt(path, backup)
    if (!isTRUE(moved)) {
      state$keep <- !is.na(.qv_export_type(backup))
      cli::cli_abort(
        c("Could not back up {.path {path}}; export was not published.",
          "i" = if (state$keep) "Recovery files remain at {.path {state$root}}."),
        parent = if (inherits(moved, "condition")) moved,
        call = call
      )
    }
  }
  moved <- attempt(stage, path)
  if (!isTRUE(moved)) {
    restored <- !exists || (is.na(.qv_export_type(path)) &&
                              isTRUE(attempt(backup, path)))
    if (!restored) {
      state$keep <- TRUE
      cli::cli_abort(
        c("Could not publish the export or restore its previous destination.",
          "i" = "The previous output is retained at {.path {backup}}."),
        parent = if (inherits(moved, "condition")) moved,
        class = "qview_export_recovery_error", call = call
      )
    }
    state$keep <- FALSE
    cli::cli_abort("Could not publish the export; the previous destination was preserved.",
                   parent = if (inherits(moved, "condition")) moved,
                   call = call)
  }
  state$keep <- FALSE
  invisible(path)
}


.qv_export_staged <- function(path, kind, overwrite, writer, call) {
  path <- path.expand(path)
  if (basename(path) %in% c("", ".", "..") ||
      (kind == "file" && grepl("[/\\\\]$", path))) {
    cli::cli_abort("{.arg path} must name an export destination.", call = call)
  }
  parent <- dirname(path)
  if (kind == "directory") fs::dir_create(parent)
  if (!dir.exists(parent)) {
    cli::cli_abort("Parent directory {.path {parent}} does not exist.", call = call)
  }
  path <- file.path(normalizePath(parent, winslash = "/", mustWork = TRUE),
                    basename(path))
  .qv_export_guard(path, kind, overwrite, call)
  state <- new.env(parent = emptyenv())
  state$root <- tempfile(".qview-export-", tmpdir = dirname(path))
  state$keep <- FALSE
  if (!dir.create(state$root, mode = "0700", showWarnings = FALSE)) {
    cli::cli_abort("Could not create an export staging directory.", call = call)
  }
  on.exit({
    if (!state$keep && unlink(state$root, recursive = TRUE, force = TRUE) != 0L) {
      cli::cli_warn("Could not remove export staging directory {.path {state$root}}.")
    }
  }, add = TRUE)
  stage <- file.path(state$root, if (kind == "directory") {
    "new"
  } else {
    paste0("new-", basename(path))
  })
  if (kind == "directory" && !dir.create(stage, mode = "0700")) {
    cli::cli_abort("Could not create a staged CSV directory.", call = call)
  }
  writer(stage)
  .qv_export_guard(stage, kind, TRUE, call)
  outputs <- if (kind == "directory") fs::dir_ls(stage, all = TRUE) else stage
  sizes <- fs::file_info(outputs)$size
  if (!identical(.qv_export_type(stage), kind) ||
      any(is.na(sizes) | sizes == 0)) {
    cli::cli_abort("The export writer did not produce complete, non-empty output files.",
                   call = call)
  }
  tryCatch(.qv_export_publish(stage, path, kind, overwrite, state, call),
    error = function(error) {
      if (state$keep && !inherits(error, "qview_export_recovery_error")) {
        cli::cli_abort(
          c("Export failed; recovery files were retained.",
            "i" = "Inspect {.path {state$root}} before retrying."),
          parent = error, class = "qview_export_recovery_error", call = call
        )
      }
      rlang::cnd_signal(error)
    }
  )
  invisible(path)
}


# ---- Deprecated names ----------------------------------------------

#' @rdname write_qview
#' @param dir Deprecated alias for `path` accepted by `qview_to_csv_dir()`.
#'   Use `path` instead.
#' @export
qview_to_xlsx <- function(qv,
                          path,
                          template = NULL,
                          overwrite = FALSE,
                          call = rlang::caller_env()) {
  lifecycle::deprecate_warn(
    "1.0.0", "qview_to_xlsx()", "write_qview_xlsx()"
  )
  write_qview_xlsx(qv, path, template = template,
                   overwrite = overwrite, call = call)
}


#' @rdname write_qview
#' @export
qview_to_csv_dir <- function(qv,
                             dir,
                             template = NULL,
                             call = rlang::caller_env(),
                             overwrite = FALSE) {
  lifecycle::deprecate_warn(
    "1.0.0", "qview_to_csv_dir()", "write_qview_csv()"
  )
  write_qview_csv(qv, path = dir, template = template, call = call,
                  overwrite = overwrite)
}
# Version 1.0.0
