#' Add Bio Tooltip markup to a data-frame column
#'
#' Replaces a selected column with HTML tooltip spans. This is useful before
#' rendering with `knitr::kable(escape = FALSE)`, [bt_kable()], or another HTML
#' table system that can render unescaped HTML.
#'
#' @param data A data frame.
#' @param column Column to transform. May be unquoted or a single string.
#' @param type Tooltip type: `"gene"` or `"chemical"`.
#' @param species Species for gene tooltips.
#' @param query_col Optional column containing chemical lookup values.
#' @param scope Chemical scope or scalar value recycled over rows.
#' @param scope_col Optional column containing chemical scopes.
#' @param lookup Optional chemical lookup mode.
#' @param class Optional additional CSS class.
#'
#' @return `data`, with the selected column replaced by HTML strings.
#' @export
#'
#' @examples
#' top_genes <- data.frame(symbol = c("TP53", "BRCA1"), padj = c(0.001, 0.02))
#' tooltip_column(top_genes, symbol, type = "gene")
tooltip_column <- function(data,
                           column,
                           type = c("gene", "chemical"),
                           species = "human",
                           query_col = NULL,
                           scope = NULL,
                           scope_col = NULL,
                           lookup = NULL,
                           class = NULL) {
  stopifnot(is.data.frame(data))
  column_name <- bt_resolve_column(data, substitute(column), column)
  type <- match.arg(type)

  if (identical(type, "gene")) {
    data[[column_name]] <- gene_tt(data[[column_name]], species = species, class = class)
    return(data)
  }

  query_name <- bt_resolve_optional_column(data, query_col, "query_col")
  scope_name <- bt_resolve_optional_column(data, scope_col, "scope_col")

  query <- if (is.null(query_name)) NULL else data[[query_name]]
  scope_value <- if (is.null(scope_name)) scope else data[[scope_name]]

  data[[column_name]] <- chem_tt(
    data[[column_name]],
    query = query,
    scope = scope_value,
    lookup = lookup,
    class = class
  )

  data
}

#' Add gene tooltip markup to a data-frame column
#'
#' Convenience wrapper around [tooltip_column()] for gene symbols.
#'
#' @param data A data frame.
#' @param column Column to transform. May be unquoted or a single string.
#' @param species Species alias or NCBI taxonomy ID.
#' @param class Optional additional CSS class.
#'
#' @return `data`, with the selected column replaced by gene tooltip HTML.
#' @export
#'
#' @examples
#' top_genes <- data.frame(symbol = c("TP53", "BRCA1"))
#' gene_column(top_genes, symbol)
gene_column <- function(data, column, species = "human", class = NULL) {
  stopifnot(is.data.frame(data))
  column_name <- bt_resolve_column(data, substitute(column), column)
  data[[column_name]] <- gene_tt(data[[column_name]], species = species, class = class)
  data
}

#' Add chemical tooltip markup to a data-frame column
#'
#' Convenience wrapper around [tooltip_column()] for chemical labels.
#'
#' @param data A data frame.
#' @param column Column to transform. May be unquoted or a single string.
#' @param query_col Optional column containing stable lookup values.
#' @param scope Chemical scope or scalar value recycled over rows.
#' @param scope_col Optional column containing chemical scopes.
#' @param lookup Optional chemical lookup mode.
#' @param class Optional additional CSS class.
#'
#' @return `data`, with the selected column replaced by chemical tooltip HTML.
#' @export
#'
#' @examples
#' chemicals <- data.frame(name = "aspirin", cid = "2244")
#' chem_column(chemicals, name, query_col = "cid", scope = "pubchem")
chem_column <- function(data,
                        column,
                        query_col = NULL,
                        scope = NULL,
                        scope_col = NULL,
                        lookup = NULL,
                        class = NULL) {
  stopifnot(is.data.frame(data))
  column_name <- bt_resolve_column(data, substitute(column), column)
  query_name <- bt_resolve_optional_column(data, query_col, "query_col")
  scope_name <- bt_resolve_optional_column(data, scope_col, "scope_col")

  query <- if (is.null(query_name)) NULL else data[[query_name]]
  scope_value <- if (is.null(scope_name)) scope else data[[scope_name]]

  data[[column_name]] <- chem_tt(
    data[[column_name]],
    query = query,
    scope = scope_value,
    lookup = lookup,
    class = class
  )

  data
}
