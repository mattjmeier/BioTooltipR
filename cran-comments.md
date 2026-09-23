# CRAN submission notes

## Test environments

* local Windows, R 4.5.3

## R CMD check results

0 errors | 0 warnings | 0 notes

Checked on:
* Windows, R 4.5.3, --as-cran: 0 errors, 0 warnings, 0 notes

## Reverse dependencies

There are no reverse dependencies.

## Additional notes

This package vendors pinned browser runtime assets for `bio-tooltips` 2.3.2,
D3 7.9.0, and Ideogram 1.53.0 under `inst/htmltools/`. The corresponding
license and source metadata files are included with the vendored assets.

By default, examples, tests, and vignettes use local vendored assets and do not
download external JavaScript assets during `R CMD check`. CDN use is available
only when users explicitly request it.
