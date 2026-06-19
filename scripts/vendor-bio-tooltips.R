#!/usr/bin/env Rscript

# Copy browser assets from a local bio-tooltips JavaScript repository.
# Usage:
#   Rscript scripts/vendor-bio-tooltips.R /path/to/bio-tooltips
#
# This script intentionally does not download anything. Build the JS package
# first with `npm run build`, then copy the dist artifacts into this R package.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) {
  stop("Usage: Rscript scripts/vendor-bio-tooltips.R /path/to/bio-tooltips", call. = FALSE)
}

src_root <- normalizePath(args[[1]], mustWork = TRUE)
src <- file.path(src_root, "dist")
required <- c("bio-tooltips.css", "bio-tooltips.global.js")
missing <- required[!file.exists(file.path(src, required))]
if (length(missing)) {
  stop("Missing built assets: ", paste(missing, collapse = ", "), call. = FALSE)
}

dest <- file.path("inst", "htmltools", "bio-tooltips")
dir.create(dest, recursive = TRUE, showWarnings = FALSE)
copied <- file.copy(file.path(src, required), dest, overwrite = TRUE)
if (!all(copied)) {
  stop("Failed to copy one or more Bio Tooltips assets.", call. = FALSE)
}

license <- file.path(src_root, "LICENSE")
if (file.exists(license)) {
  copied_license <- file.copy(license, file.path(dest, "LICENSE"), overwrite = TRUE)
  if (!copied_license) {
    stop("Failed to copy Bio Tooltips LICENSE.", call. = FALSE)
  }
}

package_json <- file.path(src_root, "package.json")
version <- "unknown"
if (file.exists(package_json)) {
  metadata <- jsonlite::fromJSON(package_json)
  if (!is.null(metadata$version) && nzchar(metadata$version)) {
    version <- metadata$version
  }
}

writeLines(
  c(
    "These files were copied from the published npm package:",
    "",
    sprintf("  bio-tooltips@%s", version),
    "",
    "Source package:",
    "",
    sprintf("  https://www.npmjs.com/package/bio-tooltips/v/%s", version),
    "",
    "Original source repository:",
    "",
    "  https://github.com/mattjmeier/bio-tooltips",
    "",
    "Copied files:",
    "",
    "  bio-tooltips.css",
    "  bio-tooltips.global.js",
    "  LICENSE"
  ),
  file.path(dest, "SOURCE")
)
message("Copied Bio Tooltips assets to ", dest)
