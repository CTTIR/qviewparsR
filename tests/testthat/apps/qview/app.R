# shinytest2 harness: returns the qviewparsR Shiny app object (not run).
# Driven by tests/testthat/test-shiny.R via shinytest2::AppDriver.
library(qviewparsR)
# .Q-View uploads routinely exceed Shiny's 5 MB default; lift the cap as
# qview_app() does at runtime.
options(shiny.maxRequestSize = 1024 * 1024^2)
qviewparsR:::.qv_app()
