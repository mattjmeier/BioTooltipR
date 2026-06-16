#' Automatically wrap selected gene symbols in rendered HTML
#'
#' Experimental helper for reports where text has already been rendered. It
#' injects a small browser script that scans selected DOM nodes and wraps a
#' user-supplied vocabulary of gene symbols in Bio Tooltip spans.
#'
#' This is intentionally opt-in and vocabulary-limited because many gene symbols
#' are ambiguous in prose.
#'
#' @param genes Character vector of gene symbols to wrap.
#' @param species Species alias or NCBI taxonomy ID.
#' @param selector CSS selector limiting where wrapping occurs.
#' @param include_setup Include [use_bio_tooltips()] before the wrapping script.
#' @param class Optional additional CSS class for generated spans.
#'
#' @return An HTML tag list containing an optional setup tag and wrapping script.
#' @export
#'
#' @examples
#' auto_gene_tooltips(c("TP53", "BRCA1"), selector = ".results")
auto_gene_tooltips <- function(genes,
                               species = "human",
                               selector = "p, li, td",
                               include_setup = TRUE,
                               class = NULL) {
  genes <- unique(stats::na.omit(as.character(genes)))
  genes <- genes[nzchar(genes)]
  if (!length(genes)) {
    stop("`genes` must contain at least one non-empty gene symbol.", call. = FALSE)
  }

  css_class <- if (is.null(class)) "gene-tooltip" else paste("gene-tooltip", class)

  js <- sprintf(
    paste(
      "(function () {",
      "  var terms = %s;",
      "  var species = %s;",
      "  var selector = %s;",
      "  var cssClass = %s;",
      "  terms = terms.sort(function (a, b) { return b.length - a.length; });",
      "  function escapeRegExp(value) { return value.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&'); }",
      "  var pattern = new RegExp('\\\\b(' + terms.map(escapeRegExp).join('|') + ')\\\\b', 'g');",
      "  function shouldSkip(node) {",
      "    if (!node || !node.parentNode) return true;",
      "    var parent = node.parentNode;",
      "    if (parent.closest && parent.closest('.gene-tooltip, .chemical-tooltip, script, style, pre, code, a')) return true;",
      "    return false;",
      "  }",
      "  function wrapTextNode(node) {",
      "    if (shouldSkip(node) || !pattern.test(node.nodeValue)) return;",
      "    pattern.lastIndex = 0;",
      "    var frag = document.createDocumentFragment();",
      "    var text = node.nodeValue;",
      "    var last = 0;",
      "    text.replace(pattern, function (match, term, offset) {",
      "      if (offset > last) frag.appendChild(document.createTextNode(text.slice(last, offset)));",
      "      var span = document.createElement('span');",
      "      span.className = cssClass;",
      "      span.setAttribute('data-species', species);",
      "      span.textContent = match;",
      "      frag.appendChild(span);",
      "      last = offset + match.length;",
      "    });",
      "    if (last < text.length) frag.appendChild(document.createTextNode(text.slice(last)));",
      "    node.parentNode.replaceChild(frag, node);",
      "  }",
      "  function walk(root) {",
      "    var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);",
      "    var nodes = [];",
      "    while (walker.nextNode()) nodes.push(walker.currentNode);",
      "    nodes.forEach(wrapTextNode);",
      "  }",
      "  function run() {",
      "    document.querySelectorAll(selector).forEach(walk);",
      "    if (window.BioTooltipsR && window.BioTooltipsR.init) window.BioTooltipsR.init();",
      "  }",
      "  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', run); else run();",
      "})();",
      sep = "\n"
    ),
    bt_json(genes),
    bt_json(species),
    bt_json(selector),
    bt_json(css_class)
  )

  tags <- list(htmltools::tags$script(htmltools::HTML(js)))
  if (isTRUE(include_setup)) {
    tags <- c(list(use_bio_tooltips(modules = "gene")), tags)
  }

  htmltools::tagList(tags)
}
