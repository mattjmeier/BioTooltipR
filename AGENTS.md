# Agent Notes for `biotooltips`

This repository is an R package that provides a lightweight R Markdown / Quarto / HTML reporting layer around the JavaScript package `bio-tooltips`.

## Core design constraints

- Do not reimplement MyGene.info or MyChem.info lookup logic in R for the core package. The browser-side `bio-tooltips` library owns entity lookup, caching, rendering, and tooltip behavior.
- Keep this package small and boring. Its job is to emit correct HTML, attach JS/CSS dependencies, and make report/table use pleasant.
- Prefer `htmltools` primitives over `htmlwidgets` unless a future feature truly needs a widget lifecycle.
- Keep helpers vectorized. `gene_tt()` and `chem_tt()` must work for both inline prose and data-frame columns.
- Avoid mandatory dependencies on table ecosystems. `knitr` and `htmltools` are core; packages such as `DT`, `gt`, `flextable`, or `reactable` should remain optional integrations.

## JavaScript asset strategy

The current draft uses CDN assets by default:

- `https://cdn.jsdelivr.net/npm/bio-tooltips@<version>/dist/bio-tooltips.css`
- `https://cdn.jsdelivr.net/npm/bio-tooltips@<version>/dist/bio-tooltips.global.js`

Before CRAN submission, decide whether to vendor assets under:

```text
inst/htmltools/bio-tooltips/
  bio-tooltips.css
  bio-tooltips.global.js
```

If vendoring assets, verify:

1. the JS package version is pinned;
2. licenses are compatible and included;
3. generated files are copied from a clean `npm run build` of `bio-tooltips`;
4. no source maps, dev-only files, or large optional assets are accidentally included.

Use `scripts/vendor-bio-tooltips.R` as the intended starting point for local asset copying. Do not download external assets at install time.

## API rules

- `use_bio_tooltips()` should be called once per document. It attaches dependencies and initializes selected modules.
- `gene_tt()` should emit spans with class `gene-tooltip` and `data-species`.
- `chem_tt()` should emit spans with class `chemical-tooltip` and optional `data-query`, `data-scope`, and `data-lookup`.
- `tooltip_column()`, `gene_column()`, and `chem_column()` should return the original data frame with the selected column replaced by HTML strings.
- `bt_kable()` should set `escape = FALSE` by default and include setup tags unless the caller opts out.
- Experimental auto-linking must remain opt-in and vocabulary-limited. Never scan a whole report blindly by default.

## Testing

Run these before finishing a meaningful change:

```r
pak::pak(c("local::.", "testthat"))
testthat::test_local()
```

Before release/submission:

```r
devtools::document()
devtools::check()
```

If `roxygen2` rewrites `NAMESPACE` or `man/`, review the changes. Do not hand-edit generated `.Rd` files after documentation is generated unless this package intentionally stops using roxygen.

## Development environment

Dependencies for development are managed by Pixi. You can add and run dependencies like this:

```bash
pixi add r-base
pixi run R
```

## R CMD check discipline

- Examples must not require internet access.
- Tests must not fetch MyGene.info, MyChem.info, jsDelivr, or npm.
- Do not write to the user's home directory in tests or examples.
- Keep vignettes renderable without contacting external APIs. The rendered HTML may contact APIs later in a browser; that is acceptable and should be documented.

## Future integration ideas

Good next steps:

- `bt_gt()` helper for `gt` tables.
- `bt_reactable()` helper for `reactable` tables.
- Quarto shortcode/filter documentation.
- Shiny module or helper that reinitializes tooltips after dynamic UI updates.
- Optional helper for DESeq2/edgeR/limma-style result tables.

Non-goals for the initial CRAN release:

- Server-side MyGene/MyChem querying.
- Heavy dependency stacks.
- Browser automation in tests.
- Automatic wrapping of arbitrary gene-like words without a user-supplied vocabulary.
