test_that("gene_tt emits gene tooltip spans", {
  html <- as.character(gene_tt("TP53", species = "human"))
  expect_match(html, "class=\"gene-tooltip\"", fixed = TRUE)
  expect_match(html, "data-species=\"human\"", fixed = TRUE)
  expect_match(html, ">TP53</span>", fixed = TRUE)
})

test_that("chem_tt emits chemical tooltip spans", {
  html <- as.character(chem_tt("aspirin", query = "2244", scope = "pubchem"))
  expect_match(html, "class=\"chemical-tooltip\"", fixed = TRUE)
  expect_match(html, "data-query=\"2244\"", fixed = TRUE)
  expect_match(html, "data-scope=\"pubchem\"", fixed = TRUE)
})

test_that("span helpers escape text and attributes", {
  html <- as.character(gene_tt("TP<53>", species = "human\"x"))
  expect_match(html, "TP&lt;53&gt;", fixed = TRUE)
  expect_match(html, "human&quot;x", fixed = TRUE)
})

test_that("span helpers vectorize", {
  html <- as.character(gene_tt(c("TP53", "BRCA1"), species = "human"))
  expect_length(html, 2)
  expect_match(html[[2]], "BRCA1", fixed = TRUE)
})
