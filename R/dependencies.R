#' Bio Tooltips HTML dependency
#'
#' Creates the `htmltools` dependency for the browser-side Bio Tooltips bundle.
#'
#' @param cdn Use jsDelivr CDN assets instead of the vendored package assets.
#'   If `FALSE`, the package looks for local assets under
#'   `inst/htmltools/bio-tooltips/` or `local_path`.
#' @param version JavaScript package version. Use a pinned version for
#'   reproducible reports.
#' @param local_path Optional path containing `bio-tooltips.css` and
#'   `bio-tooltips.global.js`.
#'
#' @return An `htmltools::htmlDependency` object.
#' @export
bio_tooltips_dependency <- function(cdn = FALSE,
                                    version = "1.0.2",
                                    local_path = NULL) {
  version <- as.character(version)
  dependency_version <- bt_dependency_version(version)

  if (isTRUE(cdn)) {
    return(htmltools::htmlDependency(
      name = "bio-tooltips",
      version = dependency_version,
      src = c(href = sprintf("https://cdn.jsdelivr.net/npm/bio-tooltips@%s", version)),
      script = "dist/bio-tooltips.global.js",
      stylesheet = "dist/bio-tooltips.css",
      all_files = FALSE
    ))
  }

  path <- local_path %||% system.file("htmltools", "bio-tooltips", package = "BioTooltipR")
  js <- file.path(path, "bio-tooltips.global.js")
  css <- file.path(path, "bio-tooltips.css")

  if (!file.exists(js) || !file.exists(css)) {
    stop(
      "Local Bio Tooltips assets were not found. ",
      "Use `cdn = TRUE`, pass `local_path`, or vendor assets under ",
      "inst/htmltools/bio-tooltips/.",
      call. = FALSE
    )
  }

  htmltools::htmlDependency(
    name = "bio-tooltips",
    version = dependency_version,
    src = path,
    script = "bio-tooltips.global.js",
    stylesheet = "bio-tooltips.css",
    all_files = FALSE
  )
}

#' Attach and initialize Bio Tooltips
#'
#' Use this once in an R Markdown, Quarto, Shiny UI, or other HTML-producing
#' context. It attaches the Bio Tooltips CSS/JS dependency and initializes the
#' selected modules after the DOM is ready.
#'
#' @param modules Character vector containing `"gene"`, `"chemical"`, or both.
#' @param cdn Use jsDelivr CDN assets instead of the vendored package assets.
#'   See [bio_tooltips_dependency()].
#' @param version JavaScript package version. Use a pinned version for
#'   reproducibility.
#' @param theme Tooltip theme passed to Bio Tooltips.
#' @param prefetch Prefetch strategy passed to Bio Tooltips.
#' @param gene_selector CSS selector for gene tooltip elements.
#' @param chemical_selector CSS selector for chemical tooltip elements.
#' @param visual_preload Optional visual dependency warmup strategy for gene
#'   visuals. Passed as `visualPreload`.
#' @param debug_timings Log Bio Tooltips timing diagnostics in the browser.
#' @param tooltip_width,tooltip_height Optional tooltip dimensions.
#' @param include_optional_visual_deps Include dependencies for D3 and
#'   Ideogram. The default, `"auto"`, includes them when the gene module is
#'   initialized because Bio Tooltips gene visuals use these peer dependencies.
#'   Vendored files are used by default and CDN files are used when `cdn = TRUE`.
#'   Use `FALSE` to opt out, for example when gene visuals are disabled.
#' @param d3_version,ideogram_version Versions used when optional visual
#'   dependencies are included.
#' @param local_path Optional local path for vendored Bio Tooltips assets.
#'
#' @return An HTML tag list containing dependencies and an initialization script.
#' @export
#'
#' @examples
#' use_bio_tooltips()
#' use_bio_tooltips(modules = "gene", theme = "light")
use_bio_tooltips <- function(modules = c("gene", "chemical"),
                             cdn = FALSE,
                             version = "1.0.2",
                             theme = "auto",
                             prefetch = "smart",
                             gene_selector = ".gene-tooltip",
                             chemical_selector = ".chemical-tooltip",
                             visual_preload = NULL,
                             debug_timings = FALSE,
                             tooltip_width = NULL,
                             tooltip_height = NULL,
                             include_optional_visual_deps = "auto",
                             d3_version = "7.9.0",
                             ideogram_version = "1.53.0",
                             local_path = NULL) {
  modules <- bt_module_match(modules)

  gene_config <- bt_compact(list(
    selector = gene_selector,
    theme = theme,
    prefetch = prefetch,
    visualPreload = visual_preload,
    debugTimings = isTRUE(debug_timings),
    tooltipWidth = tooltip_width,
    tooltipHeight = tooltip_height
  ))

  chemical_config <- bt_compact(list(
    selector = chemical_selector,
    theme = theme,
    prefetch = prefetch,
    debugTimings = isTRUE(debug_timings),
    tooltipWidth = tooltip_width,
    tooltipHeight = tooltip_height
  ))

  init_lines <- c(
    "(function () {",
    "  window.BioTooltipsR = window.BioTooltipsR || {};",
    "  window.BioTooltipsR.configs = window.BioTooltipsR.configs || {};",
    "  window.BioTooltipsR.cleanups = window.BioTooltipsR.cleanups || [];",
    "  window.BioTooltipsR.cleanup = function () {",
    "    window.BioTooltipsR.cleanups.forEach(function (cleanup) {",
    "      if (typeof cleanup === 'function') cleanup();",
    "    });",
    "    window.BioTooltipsR.cleanups = [];",
    "  };",
    "  window.BioTooltipsR.init = function () {",
    "    var configs = window.BioTooltipsR.configs;",
    "    window.BioTooltipsR.cleanup();"
  )

  if ("gene" %in% modules) {
    init_lines <- c(
      init_lines,
      sprintf(
        "  window.BioTooltipsR.configs.gene = %s;",
        bt_json(gene_config)
      )
    )
  }

  if ("chemical" %in% modules) {
    init_lines <- c(
      init_lines,
      sprintf(
        "  window.BioTooltipsR.configs.chemical = %s;",
        bt_json(chemical_config)
      )
    )
  }

  init_lines <- c(
    init_lines,
    "    if (configs.gene && window.GeneTooltip && typeof window.GeneTooltip.init === 'function') window.BioTooltipsR.cleanups.push(window.GeneTooltip.init(configs.gene));",
    "    if (configs.chemical && window.ChemicalTooltip && typeof window.ChemicalTooltip.init === 'function') window.BioTooltipsR.cleanups.push(window.ChemicalTooltip.init(configs.chemical));",
    "  };",
    "  if (document.readyState === 'loading') {",
    "    document.addEventListener('DOMContentLoaded', window.BioTooltipsR.init);",
    "  } else {",
    "    window.BioTooltipsR.init();",
    "  }",
    "})();"
  )

  deps <- list()
  include_visual_deps <- bt_include_visual_deps(include_optional_visual_deps, modules)

  if (include_visual_deps) {
    deps <- c(deps, list(
      bt_visual_dependency(
        name = "d3",
        version = d3_version,
        cdn = cdn,
        cdn_path = "dist",
        script = "d3.min.js"
      ),
      bt_visual_dependency(
        name = "ideogram",
        version = ideogram_version,
        cdn = cdn,
        cdn_path = "dist/js",
        script = "ideogram.min.js"
      )
    ))
  }

  # Load globals used by the Bio Tooltips bundle before the bundle itself.
  deps <- c(deps, list(
    bio_tooltips_dependency(cdn = cdn, version = version, local_path = local_path)
  ))

  htmltools::singleton(htmltools::tagList(
    deps,
    htmltools::tags$script(htmltools::HTML(paste(init_lines, collapse = "\n")))
  ))
}

bt_visual_dependency <- function(name, version, cdn, cdn_path, script) {
  if (isTRUE(cdn)) {
    src <- c(href = sprintf(
      "https://cdn.jsdelivr.net/npm/%s@%s/%s",
      name,
      version,
      cdn_path
    ))
  } else {
    src <- system.file("htmltools", name, package = "BioTooltipR")
    asset <- file.path(src, script)
    if (!nzchar(src) || !file.exists(asset)) {
      stop(
        "Local ", name, " assets were not found under inst/htmltools/", name,
        ". Use `cdn = TRUE` or vendor the pinned visual dependencies.",
        call. = FALSE
      )
    }
  }

  htmltools::htmlDependency(
    name = name,
    version = version,
    src = src,
    script = script,
    all_files = FALSE
  )
}

bt_include_visual_deps <- function(include_optional_visual_deps, modules) {
  if (identical(include_optional_visual_deps, "auto")) {
    return("gene" %in% modules)
  }

  if (is.logical(include_optional_visual_deps) && length(include_optional_visual_deps) == 1L && !is.na(include_optional_visual_deps)) {
    return(isTRUE(include_optional_visual_deps))
  }

  stop(
    "`include_optional_visual_deps` must be TRUE, FALSE, or \"auto\".",
    call. = FALSE
  )
}

`%||%` <- function(x, y) {
  if (is.null(x) || identical(x, "")) y else x
}

bt_dependency_version <- function(version) {
  if (length(version) != 1L || is.na(version) || !nzchar(version)) {
    stop("`version` must be a single non-empty string.", call. = FALSE)
  }

  if (identical(version, "latest")) {
    return(as.character(utils::packageVersion("BioTooltipR")))
  }

  version
}
