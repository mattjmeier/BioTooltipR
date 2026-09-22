test_that("bt_plotly_gene_hover wraps a plotly widget with a gene anchor", {
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

  # Wrapper + hidden anchor
  expect_match(html, "bt-plotly-gene-hover", fixed = TRUE)
  expect_match(html, "bt-plotly-gene-hover-anchor", fixed = TRUE)
  expect_match(html, "bt-plotly-gene-target", fixed = TRUE)
  expect_match(html, "aria-hidden", fixed = TRUE)
  expect_match(html, "data-species", fixed = TRUE)

  # Plotly event wiring (hover on desktop, click for touch)
  expect_match(html, "plotly_hover", fixed = TRUE)
  expect_match(html, "plotly_unhover", fixed = TRUE)
  expect_match(html, "plotly_click", fixed = TRUE)
  expect_match(html, "el.addEventListener('click', onDomClick)", fixed = TRUE)
  expect_match(html, "removeListener('plotly_hover', onHover)", fixed = TRUE)
  expect_match(html, "removeEventListener('click', onDomClick)", fixed = TRUE)

  # Gene resolution from the hovered point
  expect_match(html, "geneSource", fixed = TRUE)
  expect_match(html, "point[config.geneSource]", fixed = TRUE)
  expect_match(html, "trace && trace.key", fixed = TRUE)
  expect_match(html, "point.pointNumber", fixed = TRUE)

  # Programmatic attach API (not the global init, no synthetic mouse events)
  expect_match(html, "window.GeneTooltip.attach", fixed = TRUE)
  expect_match(html, "handle.open({ focus: false })", fixed = TRUE)
  expect_match(html, "handle.close()", fixed = TRUE)
  expect_match(html, "handle.destroy()", fixed = TRUE)
  expect_match(html, "prefetch: 'none'", fixed = TRUE)
  expect_match(html, "state.anchor.setAttribute('tabindex', '-1')", fixed = TRUE)
  expect_false(grepl("GeneTooltip.init", html, fixed = TRUE))
  expect_false(grepl("new MouseEvent", html, fixed = TRUE))
  expect_false(grepl("_tippy", html, fixed = TRUE))

  # Touch handling: plotly_click + deferred DOM click, no unhover close for touch
  expect_match(html, "isTouchOrigin", fixed = TRUE)
  expect_match(html, "event.pointerType === 'touch'", fixed = TRUE)
  expect_match(html, "state.lastTouch", fixed = TRUE)
  expect_match(html, "el.addEventListener('touchstart', onTouchStart, { passive: true })", fixed = TRUE)
  expect_match(html, "el.removeEventListener('touchstart', onTouchStart)", fixed = TRUE)
  expect_match(html, "state.pendingTouch", fixed = TRUE)
  expect_match(html, "state.viaTouch", fixed = TRUE)
  expect_match(html, "if (!state.open || state.viaTouch) return;", fixed = TRUE)

  # Desktop: the card can be moused into; unhover defers the close
  expect_match(html, "state.pointerInsideTooltip", fixed = TRUE)
  expect_match(html, "state.root.addEventListener('mouseenter', onRootEnter)", fixed = TRUE)
  expect_match(html, "state.root.addEventListener('mouseleave', onRootLeave)", fixed = TRUE)
  expect_match(html, "state.root.removeEventListener('mouseenter', onRootEnter)", fixed = TRUE)
  expect_match(html, "state.root.removeEventListener('mouseleave', onRootLeave)", fixed = TRUE)
  expect_match(html, "if (state.pointerInsideTooltip) return;", fixed = TRUE)
  expect_match(html, "state.closeTimer = setTimeout", fixed = TRUE)

  # Re-render safety: state + cleanup stored on the element
  expect_match(html, "el.__btPlotlyGeneHover", fixed = TRUE)
  expect_match(html, "state.cleanup", fixed = TRUE)

  # Native Plotly hover labels are suppressed while events stay active
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

  expect_match(html, "window.BioTooltipsR.configs.gene", fixed = TRUE)
  expect_match(html, "GeneTooltip.init(configs.gene)", fixed = TRUE)
  expect_match(html, "bt-plotly-gene-hover-anchor", fixed = TRUE)
})

test_that("bt_plotly_gene_hover forwards the class argument to the anchor", {
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

  widget <- bt_plotly_gene_hover(plot, include_setup = FALSE, class = "my-class")
  html <- as.character(htmltools::renderTags(widget)$html)

  expect_match(html, "bt-plotly-gene-hover-anchor bt-plotly-gene-target my-class", fixed = TRUE)
})

test_that("bt_plotly_gene_hover keeps native hover labels when asked", {
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

  widget <- bt_plotly_gene_hover(plot, include_setup = FALSE, hide_plotly_hover = FALSE)
  html <- as.character(htmltools::renderTags(widget)$html)

  expect_false(grepl("\"hoverinfo\":\"none\"", html, fixed = TRUE))
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
