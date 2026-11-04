# Explicit namespace selection supports source and installed test contexts.
package_path <- Sys.getenv("QVIEWPARSR_TEST_PACKAGE_PATH", unset = "")
if (nzchar(package_path) && file.exists(file.path(package_path, "R", "app.R"))) {
  pkgload::load_all(package_path, export_all = FALSE, attach_testthat = FALSE)
} else {
  base::loadNamespace("qviewparsR",
                      lib.loc = if (nzchar(package_path)) dirname(package_path) else NULL)
}
options(shiny.maxRequestSize = 1024 * 1024^2)
get(".qv_app", envir = asNamespace("qviewparsR"))()
