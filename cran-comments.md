# CRAN submission notes

This is a development draft and has not yet been submitted to CRAN.

## Reverse dependencies

None.

## Notes for future submission

- The `bio-tooltips` 1.0.0 browser assets are vendored under `inst/htmltools/`.
- CDN assets are supported only when users explicitly request them.
- Run `devtools::check()` or `rcmdcheck::rcmdcheck()` on Linux, macOS, and Windows before submission.
- Avoid examples that require live external API calls during `R CMD check`; Bio Tooltips fetches data client-side only when the rendered HTML is viewed.
