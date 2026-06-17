test_that("bio_tooltips_dependency uses CDN paths", {
  dep <- bio_tooltips_dependency(version = "1.0.1")
  expect_equal(dep$name, "bio-tooltips")
  expect_equal(dep$version, "1.0.1")
  expect_true(grepl("cdn.jsdelivr.net", dep$src$href, fixed = TRUE))
})

test_that("bio_tooltips_dependency accepts latest CDN specifier", {
  dep <- bio_tooltips_dependency(version = "latest")
  expect_equal(dep$version, as.character(utils::packageVersion("biotooltips")))
  expect_match(dep$src$href, "@latest", fixed = TRUE)
})

test_that("use_bio_tooltips emits init script", {
  tags <- use_bio_tooltips(modules = c("gene", "chemical"), version = "1.0.1")
  html <- as.character(htmltools::renderTags(tags)$html)
  expect_match(html, "GeneTooltip.init", fixed = TRUE)
  expect_match(html, "ChemicalTooltip.init", fixed = TRUE)
})

test_that("use_bio_tooltips includes gene visual peer dependencies automatically", {
  tags <- use_bio_tooltips(modules = "gene", version = "1.0.1")
  deps <- htmltools::findDependencies(tags)
  dep_names <- vapply(deps, `[[`, character(1), "name")

  expect_true("bio-tooltips" %in% dep_names)
  expect_true("d3" %in% dep_names)
  expect_true("ideogram" %in% dep_names)
})

test_that("use_bio_tooltips does not include gene visual peer dependencies for chemical-only output", {
  tags <- use_bio_tooltips(modules = "chemical", version = "1.0.1")
  deps <- htmltools::findDependencies(tags)
  dep_names <- vapply(deps, `[[`, character(1), "name")

  expect_true("bio-tooltips" %in% dep_names)
  expect_false("d3" %in% dep_names)
  expect_false("ideogram" %in% dep_names)
})

test_that("use_bio_tooltips can opt out of gene visual peer dependencies", {
  tags <- use_bio_tooltips(
    modules = "gene",
    version = "1.0.1",
    include_optional_visual_deps = FALSE
  )
  deps <- htmltools::findDependencies(tags)
  dep_names <- vapply(deps, `[[`, character(1), "name")

  expect_false("d3" %in% dep_names)
  expect_false("ideogram" %in% dep_names)
})

test_that("use_bio_tooltips validates optional visual dependency mode", {
  expect_error(
    use_bio_tooltips(include_optional_visual_deps = "sometimes"),
    "must be TRUE, FALSE, or \"auto\"",
    fixed = TRUE
  )
})
