test_that("bio_tooltips_dependency uses CDN paths", {
  dep <- bio_tooltips_dependency(version = "1.0.1")
  expect_equal(dep$name, "bio-tooltips")
  expect_equal(dep$version, "1.0.1")
  expect_true(grepl("cdn.jsdelivr.net", dep$src$href, fixed = TRUE))
})

test_that("use_bio_tooltips emits init script", {
  tags <- use_bio_tooltips(modules = c("gene", "chemical"), version = "1.0.1")
  html <- as.character(htmltools::renderTags(tags)$html)
  expect_match(html, "GeneTooltip.init", fixed = TRUE)
  expect_match(html, "ChemicalTooltip.init", fixed = TRUE)
})
