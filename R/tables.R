#' Render a kable table with Bio Tooltips support
#'
#' Wrapper around [knitr::kable()] that defaults to HTML output with escaping
#' disabled and optionally prepends [use_bio_tooltips()].
#'
#' @param data A data frame or object accepted by [knitr::kable()].
#' @param ... Passed to [knitr::kable()].
#' @param modules Tooltip modules to initialize when `include_setup = TRUE`.
#' @param include_setup Include [use_bio_tooltips()] before the table.
#' @param format Table format. Defaults to `"html"`.
#' @param escape Escape HTML? Defaults to `FALSE` so tooltip spans render.
#'
#' @return An HTML tag list when setup is included; otherwise the result of
#'   [knitr::kable()].
#' @export
#'
#' @examples
#' top_genes <- data.frame(symbol = c("TP53", "BRCA1"))
#' top_genes <- gene_column(top_genes, symbol)
#' bt_kable(top_genes)
bt_kable <- function(data,
                     ...,
                     modules = c("gene", "chemical"),
                     include_setup = TRUE,
                     format = "html",
                     escape = FALSE) {
  table <- knitr::kable(data, ..., format = format, escape = escape)

  if (!isTRUE(include_setup) || !identical(format, "html")) {
    return(table)
  }

  htmltools::tagList(
    use_bio_tooltips(modules = modules),
    htmltools::HTML(table)
  )
}

#' Render a DT table with Bio Tooltips support
#'
#' Optional wrapper around [DT::datatable()] that disables HTML escaping by
#' default and re-initializes tooltips when the table redraws.
#'
#' @param data A data frame.
#' @param ... Passed to [DT::datatable()]. If `callback` is supplied, this
#'   helper will not override it.
#' @param modules Tooltip modules to initialize.
#' @param include_setup Include [use_bio_tooltips()] before the widget.
#' @param escape Passed to [DT::datatable()]. Defaults to `FALSE`.
#'
#' @return A `DT` widget, optionally wrapped in an HTML tag list.
#' @export
bt_datatable <- function(data,
                         ...,
                         modules = c("gene", "chemical"),
                         include_setup = TRUE,
                         escape = FALSE) {
  if (!requireNamespace("DT", quietly = TRUE)) {
    stop("Package `DT` is required for `bt_datatable()`.", call. = FALSE)
  }

  modules <- bt_module_match(modules)
  dots <- list(...)

  if (is.null(dots$callback)) {
    js_lines <- c(
      "function initBioTooltipsRTable() {",
      if ("gene" %in% modules) "  if (window.GeneTooltip) window.GeneTooltip.init({ selector: '.gene-tooltip' });" else NULL,
      if ("chemical" %in% modules) "  if (window.ChemicalTooltip) window.ChemicalTooltip.init({ selector: '.chemical-tooltip' });" else NULL,
      "}",
      "setTimeout(initBioTooltipsRTable, 0);",
      "table.on('draw.dt', initBioTooltipsRTable);"
    )
    dots$callback <- DT::JS(paste(js_lines, collapse = "\n"))
  }

  widget <- do.call(
    DT::datatable,
    c(list(data = data, escape = escape), dots)
  )

  if (!isTRUE(include_setup)) {
    return(widget)
  }

  htmltools::tagList(
    use_bio_tooltips(modules = modules),
    widget
  )
}

#' Render a simple differential-expression style table
#'
#' Convenience helper for common omics reports. It optionally sorts and truncates
#' a results data frame, annotates the gene column, and renders an HTML table.
#'
#' @param data A data frame containing differential-expression results.
#' @param gene_col Gene-symbol column name.
#' @param species Species alias or NCBI taxonomy ID.
#' @param sort_by Optional column name used for sorting.
#' @param decreasing Sort direction.
#' @param n Optional number of rows to keep after sorting.
#' @param ... Passed to [bt_kable()].
#'
#' @return An HTML table with gene tooltip spans.
#' @export
bt_deg_table <- function(data,
                         gene_col = "symbol",
                         species = "human",
                         sort_by = NULL,
                         decreasing = FALSE,
                         n = NULL,
                         ...) {
  stopifnot(is.data.frame(data))

  if (!is.null(sort_by)) {
    if (!is.character(sort_by) || length(sort_by) != 1L || !sort_by %in% names(data)) {
      stop("`sort_by` must be NULL or a single column name in `data`.", call. = FALSE)
    }
    data <- data[order(data[[sort_by]], decreasing = decreasing, na.last = TRUE), , drop = FALSE]
  }

  if (!is.null(n)) {
    data <- utils::head(data, n)
  }

  data <- gene_column(data, gene_col, species = species)
  bt_kable(data, modules = "gene", ...)
}
