#' Create a Bio Tooltip span
#'
#' Low-level helper used by [gene_tt()] and [chem_tt()]. It emits an HTML
#' `<span>` with the classes and `data-*` attributes expected by the
#' JavaScript Bio Tooltips library.
#'
#' @param label Character vector of visible labels.
#' @param type Tooltip type. One of `"gene"` or `"chemical"`.
#' @param query Optional lookup query. Mostly useful for chemical identifiers.
#' @param species Gene species alias or NCBI taxonomy ID.
#' @param scope Chemical lookup scope, such as `"pubchem"`, `"chembl"`,
#'   `"chebi"`, `"drugbank"`, `"unii"`, `"inchikey"`, or `"name"`.
#' @param lookup Optional chemical lookup mode, such as `"id"` or
#'   `"best-guess"`.
#' @param class Optional additional CSS class or full class string. If `NULL`,
#'   the default module class is used.
#'
#' @return An HTML character vector with class `html`.
#' @export
#'
#' @examples
#' bio_tooltip_span("TP53", type = "gene", species = "human")
#' bio_tooltip_span("aspirin", type = "chemical", query = "2244", scope = "pubchem")
bio_tooltip_span <- function(label,
                             type = c("gene", "chemical"),
                             query = NULL,
                             species = NULL,
                             scope = NULL,
                             lookup = NULL,
                             class = NULL) {
  type <- match.arg(type)

  default_class <- switch(
    type,
    gene = "gene-tooltip",
    chemical = "chemical-tooltip"
  )

  class <- if (is.null(class)) default_class else paste(default_class, class)

  attrs <- switch(
    type,
    gene = list("data-species" = species),
    chemical = list(
      "data-query" = query,
      "data-scope" = scope,
      "data-lookup" = lookup
    )
  )

  bt_make_span(label, class = class, attrs = attrs)
}

#' Create gene tooltip spans
#'
#' `gene_tt()` vectorizes over gene symbols and emits HTML spans understood by
#' the Bio Tooltips MyGene.info module.
#'
#' @param x Character vector of gene symbols or labels.
#' @param species Species alias such as `"human"`, `"mouse"`, or a numeric
#'   NCBI taxonomy ID. Recycled over `x`.
#' @param class Optional additional CSS class.
#'
#' @return An HTML character vector with class `html`.
#' @export
#'
#' @examples
#' gene_tt("TP53")
#' gene_tt(c("TP53", "BRCA1"), species = "human")
gene_tt <- function(x, species = "human", class = NULL) {
  bio_tooltip_span(x, type = "gene", species = species, class = class)
}

#' @rdname gene_tt
#' @export
gene_tooltip <- gene_tt

#' Create chemical tooltip spans
#'
#' `chem_tt()` vectorizes over chemical labels and emits HTML spans understood
#' by the Bio Tooltips MyChem.info module.
#'
#' @param x Character vector of visible chemical labels.
#' @param query Optional stable lookup value. For example, use a PubChem CID
#'   with `scope = "pubchem"`.
#' @param scope Optional lookup scope, such as `"pubchem"`, `"chembl"`,
#'   `"chebi"`, `"drugbank"`, `"unii"`, `"inchikey"`, or `"name"`.
#' @param lookup Optional lookup mode, such as `"id"` or `"best-guess"`.
#' @param class Optional additional CSS class.
#'
#' @return An HTML character vector with class `html`.
#' @export
#'
#' @examples
#' chem_tt("aspirin", query = "2244", scope = "pubchem")
#' chem_tt("caffeine", lookup = "best-guess")
chem_tt <- function(x, query = NULL, scope = NULL, lookup = NULL, class = NULL) {
  bio_tooltip_span(
    x,
    type = "chemical",
    query = query,
    scope = scope,
    lookup = lookup,
    class = class
  )
}

#' @rdname chem_tt
#' @export
chemical_tt <- chem_tt

#' @rdname chem_tt
#' @export
chemical_tooltip <- chem_tt
