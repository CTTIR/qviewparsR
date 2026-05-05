# Internal input-validation helpers. All take `arg` (the argument name
# as the user wrote it) and `call` (the user-facing call environment) so
# the resulting `cli::cli_abort()` message points at the user's code,
# not at this internal helper. Not exported.

.check_string <- function(x,
                          arg = rlang::caller_arg(x),
                          call = rlang::caller_env()) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    cli::cli_abort(
      c("{.arg {arg}} must be a single non-empty string.",
        "x" = "Got {.cls {class(x)[[1L]]}} of length {length(x)}."),
      call = call
    )
  }
  invisible(x)
}

.check_flag <- function(x,
                        arg = rlang::caller_arg(x),
                        call = rlang::caller_env()) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    cli::cli_abort(
      "{.arg {arg}} must be {.code TRUE} or {.code FALSE}.",
      call = call
    )
  }
  invisible(x)
}

.check_path <- function(path,
                        arg = rlang::caller_arg(path),
                        call = rlang::caller_env()) {
  .check_string(path, arg = arg, call = call)
  if (!file.exists(path)) {
    cli::cli_abort(
      c("{.arg {arg}} must be an existing file.",
        "x" = "{.path {path}} does not exist."),
      call = call
    )
  }
  invisible(path)
}

.check_qview <- function(x,
                         arg = rlang::caller_arg(x),
                         call = rlang::caller_env()) {
  if (!inherits(x, "qview")) {
    cli::cli_abort(
      c("{.arg {arg}} must be a {.cls qview} object.",
        "x" = "Got {.cls {class(x)[[1L]]}} instead.",
        "i" = "Build one with {.fn read_qview}."),
      call = call
    )
  }
  invisible(x)
}
