#' Add Bio Tooltips gene hover behavior to a Plotly plot
#'
#' `bt_plotly_gene_hover()` lets a Plotly widget use Bio Tooltips for gene
#' hover cards. Map the gene symbol into Plotly's `key` aesthetic, then wrap the
#' widget with this helper.
#'
#' Hover over a point on desktop, or tap a point on mobile. On screens at or
#' below 600 CSS pixels wide, the tooltip opens as a persistent bottom drawer
#' that stays open until another point is selected, the user taps outside the
#' drawer, drags it closed, or activates its close button.
#'
#' The helper attaches one [bio-tooltips][bio_tooltips_dependency] anchor with
#' the programmatic `GeneTooltip.attach()` API and reuses it as the selected
#' point changes, so repeated renders of the widget do not accumulate listeners.
#'
#' @param plot A Plotly htmlwidget.
#' @param species Species alias or NCBI taxonomy ID passed through to the
#'   generated gene tooltip anchor.
#' @param gene_source Plotly point field containing the gene symbol. The default
#'   uses `key`, so build plots with `key = ~symbol`.
#' @param hide_plotly_hover Suppress Plotly's native hover labels while keeping
#'   hover and click events active.
#' @param include_setup Include [use_bio_tooltips()] before the widget. Set this
#'   to `FALSE` when the report already calls [use_bio_tooltips()] once.
#' @param class Optional additional CSS class added to the generated gene anchor.
#'
#' @return An HTML tag list containing the Plotly widget and a hidden,
#'   fixed-position Bio Tooltip anchor.
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
        class = paste(c("bt-plotly-gene-hover-anchor", "bt-plotly-gene-target", class), collapse = " "),
        `aria-hidden` = "true",
        `data-species` = species
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
      left: 0;
      top: 0;
      width: 1px;
      height: 1px;
      overflow: hidden;
      opacity: 0;
      pointer-events: none;
      z-index: 2147483647;
    }
    "
  ))
}

bt_plotly_gene_hover_js <- function(species, gene_source, class = NULL) {
  config <- bt_json(list(
    species = species,
    geneSource = gene_source
  ))

  paste(
    "function(el) {",
    sprintf("  var config = %s;", config),
    "",
    "  // Repeated htmlwidgets renders must not accumulate Plotly or DOM",
    "  // listeners, so any previous instance on this element is torn down",
    "  // before this one is set up.",
    "  if (el.__btPlotlyGeneHover && typeof el.__btPlotlyGeneHover.cleanup === 'function') {",
    "    el.__btPlotlyGeneHover.cleanup();",
    "  }",
    "",
  "  var state = {",
  "    handle: null,",
  "    anchor: null,",
  "    root: null,",
  "    openSymbol: null,",
  "    open: false,",
  "    viaTouch: false,",
  "    pendingTouch: null,",
  "    lastTouch: 0,",
  "    pointerInsideTooltip: false,",
  "    closeTimer: null,",
  "    seq: 0,",
  "    coords: { x: 0, y: 0 }",
  "  };",
    "  el.__btPlotlyGeneHover = state;",
    "",
    "  var wrapper = el.closest ? el.closest('.bt-plotly-gene-hover') : null;",
    "  state.anchor = wrapper ? wrapper.querySelector('.bt-plotly-gene-hover-anchor') : null;",
    "",
    "  function baseConfig() {",
    "    return window.BioTooltipsR && window.BioTooltipsR.configs",
    "      ? window.BioTooltipsR.configs.gene || {}",
    "      : {};",
    "  }",
    "",
    "  function getHandle() {",
    "    if (state.handle) return state.handle;",
    "    if (!state.anchor || !window.GeneTooltip || typeof window.GeneTooltip.attach !== 'function') return null;",
    "    state.handle = window.GeneTooltip.attach(",
    "      state.anchor,",
    "      Object.assign({}, baseConfig(), { prefetch: 'none' })",
    "    );",
  "    // The anchor is a hidden implementation detail; keep it out of the",
  "    // tab order so selecting chart points never moves keyboard focus.",
  "    state.anchor.setAttribute('tabindex', '-1');",
  "    // Pointer tracking for the tooltip card is bound in bindRoot() after",
  "    // the first open, when the card is appended to the document.",
  "    return state.handle;",
  "  }",
  "  ",
  "  // Track pointer entry into the tooltip card so plotly_unhover does not",
  "  // close a card the user is actively exploring. The controller keeps the",
  "  // card alive while the pointer is inside and closes it on its own when",
  "  // the pointer leaves the card.",
  "  function bindRoot() {",
  "    if (state.root) return;",
  "    state.root = tooltipRoot();",
  "    if (!state.root) return;",
  "    state.root.addEventListener('mouseenter', onRootEnter);",
  "    state.root.addEventListener('mouseleave', onRootLeave);",
  "  }",
  "  ",
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
    "  function eventCoords(eventData, domEvent) {",
    "    var candidates = [];",
    "    if (eventData && eventData.event) candidates.push(eventData.event);",
    "    if (domEvent) candidates.push(domEvent);",
    "    for (var i = 0; i < candidates.length; i++) {",
    "      var ev = candidates[i];",
    "      if (!ev) continue;",
    "      if (typeof ev.clientX === 'number' && isFinite(ev.clientX) &&",
    "          typeof ev.clientY === 'number' && isFinite(ev.clientY)) {",
    "        return { x: ev.clientX, y: ev.clientY };",
    "      }",
    "      var touch = ev.touches && ev.touches.length",
    "        ? ev.touches[0]",
    "        : ev.changedTouches && ev.changedTouches.length",
    "          ? ev.changedTouches[0]",
    "          : null;",
    "      if (touch && typeof touch.clientX === 'number' && isFinite(touch.clientX)) {",
    "        return { x: touch.clientX, y: touch.clientY };",
    "      }",
    "    }",
    "    return null;",
    "  }",
    "",
    "  function positionAnchor() {",
    "    if (!state.anchor) return;",
    "    state.anchor.style.left = state.coords.x + 'px';",
    "    state.anchor.style.top = state.coords.y + 'px';",
    "  }",
    "",
  "  function isTouchOrigin(event) {",
  "    if (!event) return false;",
  "    if (event.pointerType === 'touch') return true;",
  "    if (String(event.type || '').indexOf('touch') === 0) return true;",
  "    // A tap fires a synthetic 'click' event with no pointerType, so treat",
  "    // clicks that follow a recent touch as touch-originated.",
  "    return Date.now() - state.lastTouch < 500;",
  "  }",
    "",
    "  function tooltipRoot() {",
    "    var id = state.anchor && state.anchor.getAttribute('aria-controls');",
    "    if (!id) return null;",
    "    var box = document.getElementById(id);",
    "    if (!box) return null;",
    "    return box.closest ? box.closest('[data-gt-tooltip-root]') || box : box;",
    "  }",
    "",
    "  function isTooltipHidden() {",
    "    var root = tooltipRoot();",
    "    if (!root) return true;",
    "    return root.style.visibility === 'hidden';",
    "  }",
    "",
    "  function showGene(symbol, coords, viaTouch) {",
    "    var handle = getHandle();",
    "    if (!handle) return;",
    "    if (coords) {",
    "      state.coords = coords;",
    "      positionAnchor();",
    "    }",
    "    state.anchor.textContent = symbol;",
    "    state.anchor.setAttribute('data-query', symbol);",
    "    state.anchor.setAttribute('data-species', config.species);",
    "",
  "    var same = state.openSymbol === symbol;",
  "    state.openSymbol = symbol;",
  "    state.open = true;",
  "    state.viaTouch = viaTouch;",
  "    var seq = ++state.seq;",
  "    if (state.closeTimer) {",
  "      clearTimeout(state.closeTimer);",
  "      state.closeTimer = null;",
  "    }",
    "",
  "    if (same) {",
  "      handle.open({ focus: false });",
  "      bindRoot();",
  "      return;",
  "    }",
    "",
    "    // A changed gene requires the previous tooltip to be fully closed",
    "    // before re-opening, otherwise the controller re-shows the old",
    "    // content instead of re-reading the anchor.",
    "    handle.close();",
    "    var deadline = Date.now() + 1200;",
    "    var tick = function () {",
    "      if (state.seq !== seq || state.openSymbol !== symbol || !state.open) return;",
  "      if (isTooltipHidden() || Date.now() > deadline) {",
  "        handle.open({ focus: false });",
  "        bindRoot();",
  "        return;",
  "      }",
    "      setTimeout(tick, 40);",
    "    };",
    "    setTimeout(tick, 40);",
    "  }",
    "",
    "  function onHover(eventData) {",
    "    var point = eventData && eventData.points && eventData.points[0];",
    "    var symbol = pointGene(point);",
    "    if (!symbol) return;",
    "    state.pendingTouch = null;",
    "    showGene(symbol, eventCoords(eventData, null), false);",
    "  }",
    "",
  "  function onRootEnter() {",
  "    state.pointerInsideTooltip = true;",
  "    if (state.closeTimer) {",
  "      clearTimeout(state.closeTimer);",
  "      state.closeTimer = null;",
  "    }",
  "  }",
  "",
  "  function onRootLeave() {",
  "    state.pointerInsideTooltip = false;",
  "  }",
  "",
  "  function onUnhover() {",
  "    // Touch selections open a persistent drawer; only desktop hovers",
  "    // close on unhover.",
  "    if (!state.open || state.viaTouch) return;",
  "    bindRoot();",
  "    // The user is on the card (or moving onto it); the controller keeps it",
  "    // alive and closes it on its own when the pointer leaves the card.",
  "    if (state.pointerInsideTooltip) return;",
  "    // Brief grace period so a fast move from the point onto the card is",
  "    // not interrupted by the close.",
  "    if (state.closeTimer) clearTimeout(state.closeTimer);",
  "    state.closeTimer = setTimeout(function () {",
  "      state.closeTimer = null;",
  "      if (!state.open || state.viaTouch || state.pointerInsideTooltip) return;",
  "      if (state.handle) state.handle.close();",
  "      state.open = false;",
  "    }, 120);",
  "  }",
    "",
    "  function onClick(eventData) {",
    "    var event = eventData && eventData.event;",
    "    if (!isTouchOrigin(event)) return;",
    "    var point = eventData.points && eventData.points[0];",
    "    var symbol = pointGene(point);",
    "    if (!symbol) return;",
    "    // Store the selection now, but consume it in the DOM click listener",
    "    // so the open happens after the document-level capture listener has",
    "    // run. Opening earlier would let the same tap dismiss the drawer.",
    "    state.pendingTouch = { symbol: symbol, coords: eventCoords(eventData, null) };",
    "  }",
    "",
    "  function onDomClick(event) {",
    "    if (!state.pendingTouch) return;",
    "    var pending = state.pendingTouch;",
    "    state.pendingTouch = null;",
    "    showGene(pending.symbol, eventCoords(null, event) || pending.coords, true);",
    "  }",
    "",
    "  function onTouchStart() {",
    "    state.lastTouch = Date.now();",
    "  }",
    "",
    "  if (typeof el.on === 'function') {",
    "    el.on('plotly_hover', onHover);",
    "    el.on('plotly_unhover', onUnhover);",
    "    el.on('plotly_click', onClick);",
    "  }",
    "  el.addEventListener('click', onDomClick);",
    "  el.addEventListener('touchstart', onTouchStart, { passive: true });",
    "",
    "  state.cleanup = function () {",
    "    if (typeof el.removeListener === 'function') {",
    "      el.removeListener('plotly_hover', onHover);",
    "      el.removeListener('plotly_unhover', onUnhover);",
    "      el.removeListener('plotly_click', onClick);",
    "    }",
  "    el.removeEventListener('click', onDomClick);",
  "    el.removeEventListener('touchstart', onTouchStart);",
  "    if (state.root) {",
  "      state.root.removeEventListener('mouseenter', onRootEnter);",
  "      state.root.removeEventListener('mouseleave', onRootLeave);",
  "    }",
  "    if (state.closeTimer) {",
  "      clearTimeout(state.closeTimer);",
  "      state.closeTimer = null;",
  "    }",
  "    if (state.handle) {",
  "      state.handle.destroy();",
  "      state.handle = null;",
  "    }",
  "    state.openSymbol = null;",
  "    state.open = false;",
  "    state.viaTouch = false;",
  "    state.pendingTouch = null;",
  "    state.pointerInsideTooltip = false;",
    "    if (el.__btPlotlyGeneHover === state) el.__btPlotlyGeneHover = null;",
    "  };",
    "}",
    sep = "\n"
  )
}
