#!/usr/bin/env Rscript

# Render the browser regression fixture for the Plotly adapter.
#
# Usage (from the package root):
#   Rscript tests/browser/render-fixture.R
#
# Output:
#   tests/browser/fixture/index.html
#
# The fixture is a self-contained HTML page with one trace per gene so the
# Playwright suite can target individual points. It also exposes small test
# hooks (window.__bt*) used by run-tests.mjs.

if (!file.exists("DESCRIPTION") || !identical(read.dcf("DESCRIPTION")[[1L, "Package"]], "BioTooltipR")) {
  stop("Run this script from the BioTooltipR package root.", call. = FALSE)
}

fixture_dir <- file.path("tests", "browser", "fixture")
dir.create(fixture_dir, recursive = TRUE, showWarnings = FALSE)

symbols <- c("TP53", "BRCA1", "GADD45A", "EGFR", "MYC")
lfc <- c(-2.2, -1.4, 1.4, 2.2, 0.8)
padj <- c(0.001, 0.002, 0.002, 0.001, 0.01)

r_literal <- function(x) {
  if (is.character(x)) {
    return(paste0("c(", paste0("\"", x, "\"", collapse = ", "), ")"))
  }
  paste0("c(", paste(deparse(x), collapse = ", "), ")")
}

rmd <- c(
  "---",
  "title: \"BioTooltipR browser fixture\"",
  "output:",
  "  html_document:",
  "    self_contained: true",
  "    theme: null",
  "---",
  "",
  "```{r setup, include = FALSE}",
  "knitr::opts_chunk$set(message = FALSE, warning = FALSE)",
  "library(BioTooltipR)",
  "library(plotly)",
  "```",
  "",
  "```{r fixture-plot, message = FALSE, warning = FALSE}",
  "fixture_genes <- data.frame(",
  sprintf("  symbol = %s,", r_literal(symbols)),
  sprintf("  lfc = %s,", r_literal(lfc)),
  sprintf("  padj = %s", r_literal(padj)),
  ")",
  "fixture_genes$neg_log10_padj <- -log10(fixture_genes$padj)",
  "",
  "fixture_plot <- plotly::plot_ly()",
  "for (i in seq_len(nrow(fixture_genes))) {",
  "  fixture_plot <- plotly::add_markers(",
  "    fixture_plot,",
  "    data = fixture_genes[i, , drop = FALSE],",
  "    x = ~lfc,",
  "    y = ~neg_log10_padj,",
  "    key = ~symbol,",
  "    type = \"scatter\",",
  "    marker = list(size = 14)",
  "  )",
  "}",
  "fixture_plot <- plotly::layout(",
  "  fixture_plot,",
  "  xaxis = list(visible = FALSE),",
  "  yaxis = list(visible = FALSE),",
  "  showlegend = FALSE,",
  "  margin = list(t = 10, r = 10, b = 10, l = 10)",
  ")",
  "",
  "bt_plotly_gene_hover(fixture_plot, species = \"human\")",
  "```",
  "",
  "```{r fixture-hooks, echo = FALSE, results = \"asis\"}",
  "hooks <- c(",
  "  \"<script>\",",
  "  \"(function () {\",",
  "  \"  window.__bt = { attachCalls: 0, destroyCalls: 0, domClickCount: 0, eventLog: [] };\",",
  "  \"\",",
  "  \"  function plotEl() {\",",
  "  \"    var wrap = document.querySelector('.bt-plotly-gene-hover');\",",
  "  \"    return wrap ? wrap.querySelector('.html-widget') : null;\",",
  "  \"  }\",",
  "  \"\",",
  "  \"  // Wrap the plot element's add/removeEventListener while it still has\",",
  "  \"  // no listeners so the suite can count the DOM click listeners.\",",
  "  \"  var el = plotEl();\",",
  "  \"  if (el) {\",",
  "  \"    var origAdd = el.addEventListener.bind(el);\",",
  "  \"    var origRem = el.removeEventListener.bind(el);\",",
  "  \"    el.addEventListener = function (type, fn, opts) {\",",
  "  \"      if (type === 'click') window.__bt.domClickCount++;\",",
  "  \"      return origAdd(type, fn, opts);\",",
  "  \"    };\",",
  "  \"    el.removeEventListener = function (type, fn, opts) {\",",
  "  \"      if (type === 'click') window.__bt.domClickCount--;\",",
  "  \"      return origRem(type, fn, opts);\",",
  "  \"    };\",",
  "  \"  }\",",
  "  \"\",",
  "  \"  if (window.GeneTooltip) {\",",
  "  \"    var origAttach = window.GeneTooltip.attach;\",",
  "  \"    window.GeneTooltip.attach = function (anchor, cfg) {\",",
  "  \"      var handle = origAttach.apply(window.GeneTooltip, arguments);\",",
  "  \"      window.__bt.attachCalls++;\",",
  "  \"      var origDestroy = handle.destroy;\",",
  "  \"      handle.destroy = function () {\",",
  "  \"        window.__bt.destroyCalls++;\",",
  "  \"        return origDestroy.call(handle);\",",
  "  \"      };\",",
  "  \"      return handle;\",",
  "  \"    };\",",
  "  \"  }\",",
  "  \"\",",
  "  \"  window.__btLogEvents = function () {\",",
  "  \"    var target = plotEl();\",",
  "  \"    if (!target || target.__btLogInstalled) return;\",",
  "  \"    target.__btLogInstalled = true;\",",
  "  \"    target.on('plotly_hover', function () { window.__bt.eventLog.push('plotly_hover'); });\",",
  "  \"    target.on('plotly_unhover', function () { window.__bt.eventLog.push('plotly_unhover'); });\",",
  "  \"    target.on('plotly_click', function () { window.__bt.eventLog.push('plotly_click'); });\",",
  "  \"  };\",",
  "  \"\",",
  "  \"  window.__btPointCenter = function (index) {\",",
  "  \"    var paths = document.querySelectorAll('.bt-plotly-gene-hover .html-widget .trace .points');\",",
  "  \"    var p = paths[index];\",",
  "  \"    if (!p) return null;\",",
  "  \"    var b = p.getBoundingClientRect();\",",
  "  \"    return { x: b.left + b.width / 2, y: b.top + b.height / 2 };\",",
  "  \"  };\",",
  "  \"\",",
  "  \"  // Simulate the htmlwidgets/Plotly re-render path: re-run the widget's\",",
  "  \"  // onRender hook on the same element, like a Shiny update does.\",",
  "  \"  window.__btRerender = function () {\",",
  "  \"    var target = plotEl();\",",
  "  \"    if (!target) return false;\",",
  "  \"    var script = Array.prototype.find.call(document.scripts, function (s) { return s.getAttribute('data-for') === target.id; });\",",
  "  \"    if (!script) return false;\",",
  "  \"    var data = JSON.parse(script.textContent);\",",
  "  \"    var hooks = (data.jsHooks && data.jsHooks.render) || [];\",",
  "  \"    for (var i = 0; i < hooks.length; i++) {\",",
  "  \"      (0, eval)('(' + hooks[i].code + ')').call(target, target, data.x);\",",
  "  \"    }\",",
  "  \"    return true;\",",
  "  \"  };\",",
  "  \"\",",
  "  \"  window.__btCleanup = function () {\",",
  "  \"    var target = plotEl();\",",
  "  \"    if (target && target.__btPlotlyGeneHover && typeof target.__btPlotlyGeneHover.cleanup === 'function') {\",",
  "  \"      target.__btPlotlyGeneHover.cleanup();\",",
  "  \"      return true;\",",
  "  \"    }\",",
  "  \"    return false;\",",
  "  \"  };\",",
  "  \"\",",
  "  \"  window.__btListenerCounts = function () {\",",
  "  \"    var target = plotEl();\",",
  "  \"    if (!target || !target._ev) return null;\",",
  "  \"    return {\",",
  "  \"      plotlyHover: target._ev.listenerCount('plotly_hover'),\",",
  "  \"      plotlyUnhover: target._ev.listenerCount('plotly_unhover'),\",",
  "  \"      plotlyClick: target._ev.listenerCount('plotly_click'),\",",
  "  \"      domClick: window.__bt.domClickCount\",",
  "  \"    };\",",
  "  \"  };\",",
  "  \"  window.__btAnchorAttrs = function () {\",",
  "  \"    var anchor = document.querySelector('.bt-plotly-gene-hover-anchor');\",",
  "  \"    if (!anchor) return null;\",",
  "  \"    return {\",",
  "  \"      tabindex: anchor.getAttribute('tabindex'),\",",
  "  \"      role: anchor.getAttribute('role'),\",",
  "  \"      ariaExpanded: anchor.getAttribute('aria-expanded'),\",",
  "  \"      ariaControls: anchor.getAttribute('aria-controls')\",",
  "  \"    };\",",
  "  \"  };\",",
  "  \"})();\",",
  "  \"</script>\"",
  ")",
  "cat(paste(hooks, collapse = \"\\n\"))",
  "```"
)

rmd_file <- file.path(fixture_dir, "fixture.Rmd")
writeLines(rmd, rmd_file)

# Render against the current source tree (not a stale installed copy).
suppressMessages(pkgload::load_all(".", quiet = TRUE, helpers = FALSE, attach_testthat = FALSE))

message("Rendering browser fixture...")
rmarkdown::render(
  rmd_file,
  output_file = "index.html",
  quiet = TRUE
)

out <- file.path(fixture_dir, "index.html")
if (!file.exists(out)) {
  stop("Fixture rendering did not produce ", out, call. = FALSE)
}
message("Wrote ", normalizePath(out))
