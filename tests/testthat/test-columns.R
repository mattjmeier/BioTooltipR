test_that("gene_column transforms selected column", {
  x <- data.frame(symbol = c("TP53", "BRCA1"), padj = c(0.01, 0.02))
  y <- gene_column(x, symbol)
  expect_s3_class(y$symbol, "html")
  expect_match(as.character(y$symbol[[1]]), "gene-tooltip", fixed = TRUE)
})

test_that("gene_column accepts string column", {
  x <- data.frame(symbol = c("TP53", "BRCA1"))
  y <- gene_column(x, "symbol")
  expect_match(as.character(y$symbol[[1]]), "TP53", fixed = TRUE)
})

test_that("chem_column can use a query column", {
  x <- data.frame(name = "aspirin", cid = "2244")
  y <- chem_column(x, name, query_col = "cid", scope = "pubchem")
  expect_match(as.character(y$name[[1]]), "data-query=\"2244\"", fixed = TRUE)
})
