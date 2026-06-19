test_that("bt_plotly_gene_hover wraps a plotly widget with cursor anchor", {
  testthat::skip_if_not_installed("plotly")
  testthat::skip_if_not_installed("htmlwidgets")

  genes <- data.frame(
    symbol = c("TP53", "BRCA1"),
    x = c(1, 2),
    y = c(2, 3)
  )
  plot <- plotly::plot_ly(
    genes,
    x = ~x,
    y = ~y,
    key = ~symbol,
    type = "scatter",
    mode = "markers"
  )

  widget <- bt_plotly_gene_hover(plot, include_setup = FALSE)
  html <- as.character(htmltools::renderTags(widget)$html)

  expect_match(html, "bt-plotly-gene-hover-anchor", fixed = TRUE)
  expect_match(html, "plotly_hover", fixed = TRUE)
  expect_match(html, "plotly_unhover", fixed = TRUE)
  expect_match(html, "geneSource", fixed = TRUE)
  expect_match(html, "point[config.geneSource]", fixed = TRUE)
  expect_match(html, "\"hoverinfo\":\"none\"", fixed = TRUE)
})

test_that("bt_plotly_gene_hover can include Bio Tooltips setup", {
  testthat::skip_if_not_installed("plotly")
  testthat::skip_if_not_installed("htmlwidgets")

  plot <- plotly::plot_ly(
    data.frame(symbol = "TP53", x = 1, y = 2),
    x = ~x,
    y = ~y,
    key = ~symbol,
    type = "scatter",
    mode = "markers"
  )

  widget <- bt_plotly_gene_hover(plot, include_setup = TRUE)
  html <- as.character(htmltools::renderTags(widget)$html)

  expect_match(html, "GeneTooltip.init", fixed = TRUE)
  expect_match(html, "bt-plotly-gene-hover-anchor", fixed = TRUE)
})

test_that("bt_plotly_gene_hover validates gene source", {
  testthat::skip_if_not_installed("plotly")
  testthat::skip_if_not_installed("htmlwidgets")

  plot <- plotly::plot_ly(
    data.frame(symbol = "TP53", x = 1, y = 2),
    x = ~x,
    y = ~y,
    key = ~symbol,
    type = "scatter",
    mode = "markers"
  )

  expect_error(
    bt_plotly_gene_hover(plot, gene_source = "hovertext"),
    "'arg' should be one of",
    fixed = TRUE
  )
})
