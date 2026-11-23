# CRAN submission notes

## R CMD check results

* The submitted tarball passed `R CMD check --as-cran` on Windows with
  R 4.6.2, including the PDF and HTML manuals, with 0 errors, 0 warnings,
  and 0 notes.
* The release commit passed `R CMD check --as-cran` on GitHub Actions
  with R-devel on Linux and R 4.6.2 on Linux and Windows. The preceding
  development commit also passed the macOS release and Linux oldrel-1 jobs.

## Reverse dependencies

The CRAN source package index lists no reverse dependencies.

## Additional notes

This release updates the vendored browser runtime to bio-tooltips 2.4.2
and fixes interactions between pinned and hovered Plotly gene tooltips.
Pinned assets for bio-tooltips 2.4.2, D3 7.9.2, and Ideogram 1.53.0 ship
with their licenses and source metadata under inst/htmltools/.

Examples, tests, and vignettes use local browser assets. CDN use is opt-in.

This submission is on behalf of the maintainer, who will confirm it by email.
