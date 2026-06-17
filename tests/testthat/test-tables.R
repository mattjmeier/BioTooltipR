test_that("bt_datatable redraw callback uses BioTooltipsR lifecycle when available", {
  testthat::skip_if_not_installed("DT")

  widget <- bt_datatable(
    data.frame(name = chem_tt("aspirin", query = "2244", scope = "pubchem")),
    modules = "chemical"
  )
  html <- as.character(htmltools::renderTags(widget)$html)

  expect_match(html, "window.BioTooltipsR.init();", fixed = TRUE)
  expect_match(html, "window.ChemicalTooltip.init", fixed = TRUE)
})
