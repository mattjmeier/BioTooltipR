# CRAN submission notes

This is a development draft and has not yet been submitted to CRAN.

## Reverse dependencies

None.

## Notes for future submission

- Decide whether to rely on jsDelivr CDN by default, vendor the `bio-tooltips` browser assets under `inst/htmltools/`, or support both.
- Confirm JavaScript asset licenses and package them in `inst/` if vendoring.
- Run `devtools::check()` or `rcmdcheck::rcmdcheck()` on Linux, macOS, and Windows before submission.
- Avoid examples that require live external API calls during `R CMD check`; Bio Tooltips fetches data client-side only when the rendered HTML is viewed.
