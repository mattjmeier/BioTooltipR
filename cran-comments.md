# CRAN submission notes

## R CMD check results

* Windows, R 4.5.3, --as-cran with the PDF manual: 0 errors, 0 warnings, 0 notes.
* GitHub Actions on the development commit for this release: 0 errors,
  0 warnings, 0 notes on macOS (release), Windows (release), and Linux
  (devel, release, oldrel-1).

## Reverse dependencies

The CRAN source package index lists no reverse dependencies.

## Additional notes

This release updates the vendored browser runtime to bio-tooltips 2.4.2
and fixes interactions between pinned and hovered Plotly gene tooltips.
Pinned assets for bio-tooltips 2.4.2, D3 7.9.0, and Ideogram 1.53.0 ship
with their licenses and source metadata under inst/htmltools/.

Examples, tests, and vignettes use local browser assets. CDN use is opt-in.
