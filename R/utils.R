# Internal utilities ---------------------------------------------------------

bt_compact <- function(x) {
  x[!vapply(x, is.null, logical(1))]
}

bt_escape_text <- function(x) {
  htmltools::htmlEscape(as.character(x), attribute = FALSE)
}

bt_escape_attr <- function(x) {
  htmltools::htmlEscape(as.character(x), attribute = TRUE)
}

bt_recycle <- function(x, n, arg = "value") {
  if (is.null(x)) {
    return(rep(NA_character_, n))
  }
  x <- as.character(x)
  if (length(x) == n) {
    return(x)
  }
  if (length(x) == 1L) {
    return(rep(x, n))
  }
  stop(sprintf("`%s` must have length 1 or length %d.", arg, n), call. = FALSE)
}

bt_attrs_to_string <- function(attrs) {
  attrs <- attrs[!vapply(attrs, function(x) is.null(x) || length(x) == 0L || is.na(x) || !nzchar(x), logical(1))]
  if (!length(attrs)) {
    return("")
  }
  paste0(
    " ",
    names(attrs),
    "=\"",
    vapply(attrs, bt_escape_attr, character(1)),
    "\"",
    collapse = ""
  )
}

bt_make_span <- function(label, class, attrs = list()) {
  label <- as.character(label)
  n <- length(label)
  if (n == 0L) {
    return(htmltools::HTML(character()))
  }

  attrs <- lapply(names(attrs), function(name) bt_recycle(attrs[[name]], n, name)) |>
    stats::setNames(names(attrs))

  out <- character(n)
  for (i in seq_len(n)) {
    if (is.na(label[[i]])) {
      out[[i]] <- NA_character_
      next
    }

    attrs_i <- lapply(attrs, `[[`, i)
    attrs_i$class <- class
    attrs_i <- attrs_i[c("class", setdiff(names(attrs_i), "class"))]

    out[[i]] <- paste0(
      "<span",
      bt_attrs_to_string(attrs_i),
      ">",
      bt_escape_text(label[[i]]),
      "</span>"
    )
  }

  htmltools::HTML(out)
}

bt_resolve_column <- function(data, expr, value, arg = "column") {
  expr_text <- paste(deparse(expr), collapse = "")

  if (expr_text %in% names(data)) {
    return(expr_text)
  }

  value <- tryCatch(force(value), error = function(e) NULL)
  if (is.character(value) && length(value) == 1L && value %in% names(data)) {
    return(value)
  }

  stop(sprintf("`%s` must name a column in `data`.", arg), call. = FALSE)
}

bt_resolve_optional_column <- function(data, value, arg = "column") {
  if (is.null(value)) {
    return(NULL)
  }
  if (is.character(value) && length(value) == 1L && value %in% names(data)) {
    return(value)
  }
  stop(sprintf("`%s` must be NULL or a single column name in `data`.", arg), call. = FALSE)
}

bt_json <- function(x) {
  jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", na = "null")
}

bt_module_match <- function(modules) {
  modules <- match.arg(modules, choices = c("gene", "chemical"), several.ok = TRUE)
  unique(modules)
}

bt_js_bool <- function(x) {
  if (isTRUE(x)) "true" else "false"
}
