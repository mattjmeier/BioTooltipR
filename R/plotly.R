#' Add Bio Tooltips gene hover behavior to a Plotly plot
#'
#' `bt_plotly_gene_hover()` lets a Plotly widget use Bio Tooltips for gene
#' hover cards. Map the gene symbol into Plotly's `key` aesthetic, then wrap the
#' widget with this helper.
#'
#' Hover over a point on desktop, or tap a point on mobile. On screens at or
#' below 600 CSS pixels wide, the tooltip opens as a persistent bottom drawer
#' that stays open until another point is selected, the user taps outside the
#' drawer, drags it closed, or activates its close button. On desktop, pinned
#' tooltips stay open while you hover over or pin other points.
#'
#' The helper uses the [bio-tooltips][bio_tooltips_dependency] `GeneTooltip.attach()`
#' API to reuse a hover anchor and retain a separate anchor for each pinned
#' tooltip. Repeated widget renders clean up the anchors and listeners.
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
    "  var wrapper = el.closest ? el.closest('.bt-plotly-gene-hover') : null;",
    "  var originalAnchor = wrapper ? wrapper.querySelector('.bt-plotly-gene-hover-anchor') : null;",
    "  var anchorTemplate = originalAnchor && originalAnchor.cloneNode(false);",
    "  var retainedPins = new Set();",
    "  var state = {",
    "    handle: null,",
    "    anchor: originalAnchor,",
    "    root: null,",
    "    openSymbol: null,",
    "    pointKey: null,",
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
    "  function baseConfig() {",
    "    return window.BioTooltipsR && window.BioTooltipsR.configs",
    "      ? window.BioTooltipsR.configs.gene || {}",
    "      : {};",
    "  }",
    "",
    "  function getHandle() {",
    "    if (state.handle) return state.handle;",
    "    if (!anchorTemplate || !window.GeneTooltip || typeof window.GeneTooltip.attach !== 'function') return null;",
    "    if (!state.anchor) {",
    "      state.anchor = anchorTemplate.cloneNode(false);",
    "      wrapper.appendChild(state.anchor);",
    "    }",
    "    state.handle = window.GeneTooltip.attach(",
    "      state.anchor,",
    "      Object.assign({}, baseConfig(), { prefetch: 'none' })",
    "    );",
    "    // Keep the hidden anchor out of the tab order.",
    "    state.anchor.setAttribute('tabindex', '-1');",
    "    return state.handle;",
    "  }",
    "",
    "  // Track pointer entry so plotly_unhover leaves the card open while the",
    "  // user is exploring it. The controller handles leaving the card.",
    "  function bindRoot() {",
    "    if (state.root) return;",
    "    state.root = tooltipRoot();",
    "    if (!state.root) return;",
    "    state.root.addEventListener('mouseenter', onRootEnter);",
    "    state.root.addEventListener('mouseleave', onRootLeave);",
    "  }",
    "",
    "  function unbindRoot() {",
    "    if (!state.root) return;",
    "    state.root.removeEventListener('mouseenter', onRootEnter);",
    "    state.root.removeEventListener('mouseleave', onRootLeave);",
    "    state.root = null;",
    "    state.pointerInsideTooltip = false;",
    "  }",
    "",
    "  function isPinned(root) {",
    "    return root && root.dataset.pinned === 'true';",
    "  }",
    "",
    "  function destroyTooltip(handle, anchor) {",
    "    handle.destroy();",
    "    if (anchor !== originalAnchor) anchor.remove();",
    "  }",
    "",
    "  function retainPin() {",
    "    var handle = state.handle;",
    "    var anchor = state.anchor;",
    "    var root = state.root;",
    "    var pin = { pointKey: state.pointKey, root: root, release: release };",
    "    // Let the controller finish closing the card before releasing its anchor.",
    "    var observer = new MutationObserver(function () {",
    "      if (root.style.visibility === 'hidden') release();",
    "    });",
    "    function release() {",
    "      observer.disconnect();",
    "      retainedPins.delete(pin);",
    "      destroyTooltip(handle, anchor);",
    "    }",
    "    observer.observe(root, { attributes: true, attributeFilter: ['style'] });",
    "    retainedPins.add(pin);",
    "    unbindRoot();",
    "    state.handle = null;",
    "    state.anchor = null;",
    "    state.openSymbol = null;",
    "  }",
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
    "  function plotPointKey(point, symbol) {",
    "    return JSON.stringify([point.curveNumber, point.pointNumber, symbol]);",
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
    "  function showGene(symbol, pointKey, coords, viaTouch) {",
    "    if (state.pointKey === pointKey && isPinned(state.root)) return;",
    "    for (var pin of retainedPins) {",
    "      if (pin.pointKey === pointKey && isPinned(pin.root)) {",
    "        onUnhover();",
    "        return;",
    "      }",
    "    }",
    "    if (isPinned(state.root)) retainPin();",
    "",
    "    var handle = getHandle();",
    "    if (!handle) return;",
    "    if (coords) state.coords = coords;",
    "    positionAnchor();",
    "",
    "    state.pointKey = pointKey;",
    "    state.open = true;",
    "    state.viaTouch = viaTouch;",
    "    var seq = ++state.seq;",
    "    clearCloseTimer();",
    "",
    "    function openGene() {",
    "      state.anchor.textContent = symbol;",
    "      state.anchor.setAttribute('data-query', symbol);",
    "      state.anchor.setAttribute('data-species', config.species);",
    "      state.openSymbol = symbol;",
    "      handle.open({ focus: false });",
    "      bindRoot();",
    "    }",
    "",
    "    if (state.openSymbol === null || state.openSymbol === symbol) {",
    "      openGene();",
    "      return;",
    "    }",
    "",
    "    // A changed gene requires the previous tooltip to be fully closed",
    "    // before re-opening, otherwise the controller re-shows the old",
    "    // content instead of re-reading the anchor.",
    "    handle.close();",
    "    var deadline = Date.now() + 1200;",
    "    var tick = function () {",
    "      if (state.seq !== seq || !state.open) return;",
    "      if (isTooltipHidden() || Date.now() > deadline) {",
    "        openGene();",
    "        return;",
    "      }",
    "      setTimeout(tick, 40);",
    "    };",
    "    tick();",
    "  }",
    "",
    "  function onHover(eventData) {",
    "    var point = eventData && eventData.points && eventData.points[0];",
    "    var symbol = pointGene(point);",
    "    if (!symbol) return;",
    "    state.pendingTouch = null;",
    "    showGene(symbol, plotPointKey(point, symbol), eventCoords(eventData, null), false);",
    "  }",
    "",
    "  function clearCloseTimer() {",
    "    clearTimeout(state.closeTimer);",
    "    state.closeTimer = null;",
    "  }",
    "",
    "  function onRootEnter() {",
    "    state.pointerInsideTooltip = true;",
    "    clearCloseTimer();",
    "  }",
    "",
    "  function onRootLeave() {",
    "    state.pointerInsideTooltip = false;",
    "  }",
    "",
    "  function onUnhover() {",
    "    if (!state.open || state.viaTouch) return;",
    "    bindRoot();",
    "    if (state.pointerInsideTooltip || isPinned(state.root)) return;",
    "    // Give the pointer time to move from the point onto the card.",
    "    clearCloseTimer();",
    "    state.closeTimer = setTimeout(function () {",
    "      state.closeTimer = null;",
    "      if (state.pointerInsideTooltip || isPinned(state.root)) return;",
    "      state.handle.close();",
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
    "    state.pendingTouch = {",
    "      symbol: symbol,",
    "      pointKey: plotPointKey(point, symbol),",
    "      coords: eventCoords(eventData, null)",
    "    };",
    "  }",
    "",
    "  function onDomClick(event) {",
    "    if (!state.pendingTouch) return;",
    "    var pending = state.pendingTouch;",
    "    state.pendingTouch = null;",
    "    showGene(pending.symbol, pending.pointKey, eventCoords(null, event) || pending.coords, true);",
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
    "    state.seq++;",
    "    clearCloseTimer();",
    "    unbindRoot();",
    "    retainedPins.forEach(function (pin) { pin.release(); });",
    "    if (state.handle) {",
    "      destroyTooltip(state.handle, state.anchor);",
    "      state.handle = null;",
    "    }",
    "    if (el.__btPlotlyGeneHover === state) el.__btPlotlyGeneHover = null;",
    "  };",
    "}",
    sep = "\n"
  )
}
