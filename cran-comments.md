# CRAN submission notes

## Test environments

* local Windows 11, R 4.5.3
* GitHub Actions ubuntu-latest, R release
* GitHub Actions macos-latest, R release
* GitHub Actions windows-latest, R release
* win-builder, R-devel

## R CMD check results

0 errors | 0 warnings | 0 notes

Checked on:
* GitHub Actions macos-latest, R release
* GitHub Actions windows-latest, R release
* GitHub Actions ubuntu-latest, R devel
* GitHub Actions ubuntu-latest, R release
* GitHub Actions ubuntu-latest, R oldrel-1

Additional local check:
* Windows, R 4.5.0, --as-cran: 0 errors, 0 warnings, 2 notes
  * New submission.
  * Local-only note: "checking for future file timestamps ... unable to verify current time".
    No files with future timestamps were reported, and GitHub Actions reports
    "checking for future file timestamps ... OK".

## Reverse dependencies

This is a new submission. There are no reverse dependencies.

## Additional notes

This package vendors pinned browser runtime assets for `bio-tooltips` 1.1.1,
D3 7.9.0, and Ideogram 1.53.0 under `inst/htmltools/`. The corresponding
license and source metadata files are included with the vendored assets.

By default, examples, tests, and vignettes use local vendored assets and do not
download external JavaScript assets during `R CMD check`. CDN use is available
only when users explicitly request it.
