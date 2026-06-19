#' Add Bio Tooltips gene hover behavior to a Plotly plot
#'
#' `bt_plotly_gene_hover()` lets a Plotly widget use Bio Tooltips for gene
#' hover cards. Map the gene symbol into Plotly's `key` aesthetic, then wrap the
#' widget with this helper.
#'
#' @param plot A Plotly htmlwidget.
#' @param species Species alias or NCBI taxonomy ID passed through to the
#'   generated gene tooltip span.
#' @param gene_source Plotly point field containing the gene symbol. The default
#'   uses `key`, so build plots with `key = ~symbol`.
#' @param hide_plotly_hover Suppress Plotly's native hover labels while keeping
#'   hover events active.
#' @param include_setup Include [use_bio_tooltips()] before the widget. Set this
#'   to `FALSE` when the report already calls [use_bio_tooltips()] once.
#' @param class Optional additional CSS class added to the generated gene span.
#'
#' @return An HTML tag list containing the Plotly widget and a cursor-following
#'   Bio Tooltip anchor.
#' @export
#'
#' @examples
#' if (requireNamespace("plotly", quietly = TRUE)) {
#'   genes <- data.frame(symbol = c("TP53", "BRCA1"), x = 1:2, y = 2:3)
#'   plot <- plotly::plot_ly(
#'     genes,
#'     x = ~x,
#'     y = ~y,
#'     key = ~symbol,
#'     type = "scatter",
#'     mode = "markers"
#'   )
#'   bt_plotly_gene_hover(plot, include_setup = FALSE)
#' }
bt_plotly_gene_hover <- function(plot,
                                 species = "human",
                                 gene_source = c("key", "customdata"),
                                 hide_plotly_hover = TRUE,
                                 include_setup = TRUE,
                                 class = NULL) {
  if (!requireNamespace("plotly", quietly = TRUE)) {
    stop("Package `plotly` is required for `bt_plotly_gene_hover()`.", call. = FALSE)
  }
  if (!requireNamespace("htmlwidgets", quietly = TRUE)) {
    stop("Package `htmlwidgets` is required for `bt_plotly_gene_hover()`.", call. = FALSE)
  }

  gene_source <- match.arg(gene_source)
  species <- bt_recycle(species, 1L, "species")

  if (!is.null(class)) {
    class <- paste(as.character(class), collapse = " ")
  }

  if (isTRUE(hide_plotly_hover)) {
    plot <- plotly::style(plot, hoverinfo = "none")
  }

  widget <- htmlwidgets::onRender(
    plot,
    bt_plotly_gene_hover_js(
      species = species,
      gene_source = gene_source,
      class = class
    )
  )

  out <- htmltools::tagList(
    bt_plotly_gene_hover_style(),
    htmltools::tags$div(
      class = "bt-plotly-gene-hover",
      widget,
      htmltools::tags$span(
        class = "bt-plotly-gene-hover-anchor",
        `aria-hidden` = "true",
        htmltools::tags$span(
          class = paste(c("bt-plotly-gene-target", class), collapse = " "),
          `data-species` = species
        )
      )
    )
  )

  if (!isTRUE(include_setup)) {
    return(out)
  }

  htmltools::tagList(
    use_bio_tooltips(modules = "gene"),
    out
  )
}

bt_plotly_gene_hover_style <- function() {
  htmltools::tags$style(htmltools::HTML(
    "
    .bt-plotly-gene-hover .bt-plotly-gene-hover-anchor {
      position: fixed;
      width: 1px;
      height: 1px;
      overflow: hidden;
      pointer-events: none;
      z-index: 2147483647;
    }

    .bt-plotly-gene-hover .bt-plotly-gene-hover-anchor .gene-tooltip {
      display: inline-block;
      width: 1px;
      height: 1px;
      overflow: hidden;
      opacity: 0;
    }
    "
  ))
}

bt_plotly_gene_hover_js <- function(species, gene_source, class = NULL) {
  gene_class <- paste(c("gene-tooltip", "bt-plotly-gene-target", class), collapse = " ")
  config <- bt_json(list(
    species = species,
    geneSource = gene_source,
    geneClass = gene_class
  ))

  paste(
    "function(el) {",
    sprintf("  var config = %s;", config),
    "  var cursor = { x: 0, y: 0 };",
    "",
    "  function activeTarget() {",
    "    var wrapper = el.closest('.bt-plotly-gene-hover');",
    "    return wrapper ? wrapper.querySelector('.bt-plotly-gene-hover-anchor') : null;",
    "  }",
    "",
    "  function updateCursor(event) {",
    "    if (!event || typeof event.clientX !== 'number') return;",
    "    cursor.x = event.clientX;",
    "    cursor.y = event.clientY;",
    "    positionTarget();",
    "  }",
    "",
    "  function positionTarget() {",
    "    var target = activeTarget();",
    "    if (!target) return;",
    "    target.style.left = cursor.x + 'px';",
    "    target.style.top = cursor.y + 'px';",
    "  }",
    "",
    "  var plotCleanup = null;",
    "",
    "  function pointGene(point) {",
    "    if (!point) return null;",
    "    var value = point[config.geneSource];",
    "    if ((value === null || typeof value === 'undefined') && config.geneSource === 'key') {",
    "      var trace = point.data || (el.data && el.data[point.curveNumber]);",
    "      value = trace && trace.key;",
    "      if (Array.isArray(value) && typeof point.pointNumber === 'number') value = value[point.pointNumber];",
    "    }",
    "    if (Array.isArray(value)) value = value[0];",
    "    if (value === null || typeof value === 'undefined' || value === '') return null;",
    "    return String(value);",
    "  }",
    "",
    "  function setGene(target, label) {",
    "    var gene = target.querySelector('.bt-plotly-gene-target');",
    "    if (!gene) return null;",
    "    gene.className = config.geneClass;",
    "    gene.setAttribute('data-species', config.species);",
    "    gene.textContent = label;",
    "    gene.setAttribute('data-query', label);",
    "    return gene;",
    "  }",
    "",
    "  function initializePlotTooltip(gene) {",
    "    if (!gene || !window.GeneTooltip || typeof window.GeneTooltip.init !== 'function') return;",
    "    if (typeof plotCleanup === 'function') plotCleanup();",
    "    gene.id = el.id + '-bio-tooltip-anchor';",
    "    var base = window.BioTooltipsR && window.BioTooltipsR.configs",
    "      ? window.BioTooltipsR.configs.gene || {}",
    "      : {};",
    "    var selector = '#' + (window.CSS && CSS.escape ? CSS.escape(gene.id) : gene.id);",
    "    plotCleanup = window.GeneTooltip.init(Object.assign({}, base, { selector: selector, prefetch: 'none' }));",
    "  }",
    "",
    "  el.addEventListener('mousemove', updateCursor);",
    "",
    "  el.on('plotly_hover', function(eventData) {",
    "    var target = activeTarget();",
    "    var point = eventData && eventData.points && eventData.points[0];",
    "    var label = pointGene(point);",
    "    updateCursor(eventData && eventData.event);",
    "    if (!target || !label) return;",
    "",
    "    var gene = setGene(target, label);",
    "    target.classList.add('is-active');",
    "    initializePlotTooltip(gene);",
    "    if (gene._tippy && typeof gene._tippy.show === 'function') gene._tippy.show();",
    "  });",
    "",
    "  el.on('plotly_unhover', function() {",
    "    var target = activeTarget();",
    "    if (!target) return;",
    "",
    "    var gene = target.querySelector('.bt-plotly-gene-target');",
    "    if (gene) gene.dispatchEvent(new MouseEvent('mouseleave', {",
    "      bubbles: false, view: window, clientX: cursor.x, clientY: cursor.y",
    "    }));",
    "    target.classList.remove('is-active');",
    "  });",
    "}",
    sep = "\n"
  )
}
