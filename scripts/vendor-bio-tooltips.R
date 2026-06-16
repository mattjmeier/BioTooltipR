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
file.copy(file.path(src, required), dest, overwrite = TRUE)
message("Copied Bio Tooltips assets to ", dest)
