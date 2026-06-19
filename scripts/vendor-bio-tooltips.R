#!/usr/bin/env Rscript

# Vendor browser assets from either a local bio-tooltips checkout or an exact
# published npm version.
#
# Usage:
#   Rscript scripts/vendor-bio-tooltips.R /path/to/bio-tooltips
#   Rscript scripts/vendor-bio-tooltips.R --npm-version 1.0.1

args <- commandArgs(trailingOnly = TRUE)
usage <- paste(
  "Usage:",
  "  Rscript scripts/vendor-bio-tooltips.R /path/to/bio-tooltips",
  "  Rscript scripts/vendor-bio-tooltips.R --npm-version 1.0.1",
  sep = "\n"
)

if (!file.exists("DESCRIPTION") || !identical(read.dcf("DESCRIPTION")[[1L, "Package"]], "BioTooltipR")) {
  stop("Run this script from the BioTooltipR package root.", call. = FALSE)
}

is_npm <- identical(args[[1L]], "--npm-version")
if ((is_npm && length(args) != 2L) || (!is_npm && length(args) != 1L)) {
  stop(usage, call. = FALSE)
}

validate_version <- function(version) {
  pattern <- "^[0-9]+\\.[0-9]+\\.[0-9]+(?:-[0-9A-Za-z.-]+)?$"
  if (length(version) != 1L || is.na(version) || !grepl(pattern, version)) {
    stop("The npm version must be an exact semantic version such as 1.0.1.", call. = FALSE)
  }
  version
}

pack_npm_version <- function(version) {
  npm <- Sys.which("npm")
  if (!nzchar(npm) && .Platform$OS.type == "windows") {
    npm <- Sys.which("npm.cmd")
  }
  if (!nzchar(npm)) {
    stop("npm was not found on PATH.", call. = FALSE)
  }

  work <- tempfile("bio-tooltips-npm-")
  dir.create(work)
  stderr_file <- tempfile("npm-pack-stderr-")
  output <- system2(
    npm,
    c(
      "pack",
      sprintf("bio-tooltips@%s", version),
      "--json",
      "--pack-destination",
      shQuote(work)
    ),
    stdout = TRUE,
    stderr = stderr_file
  )
  status <- attr(output, "status")
  if (!is.null(status) && status != 0L) {
    details <- if (file.exists(stderr_file)) readLines(stderr_file, warn = FALSE) else character()
    stop("npm pack failed.\n", paste(details, collapse = "\n"), call. = FALSE)
  }

  metadata <- jsonlite::fromJSON(paste(output, collapse = "\n"))
  if (!is.data.frame(metadata) || nrow(metadata) != 1L) {
    stop("npm pack returned unexpected metadata.", call. = FALSE)
  }

  tarball <- file.path(work, metadata$filename[[1L]])
  if (!file.exists(tarball)) {
    stop("npm pack did not create the expected tarball.", call. = FALSE)
  }

  extract_dir <- file.path(work, "unpacked")
  dir.create(extract_dir)
  utils::untar(tarball, exdir = extract_dir)

  list(
    path = file.path(extract_dir, "package"),
    shasum = metadata$shasum[[1L]],
    integrity = metadata$integrity[[1L]]
  )
}

if (is_npm) {
  requested_version <- validate_version(args[[2L]])
  packed <- pack_npm_version(requested_version)
  src_root <- normalizePath(packed$path, mustWork = TRUE)
  shasum <- packed$shasum
  integrity <- packed$integrity
} else {
  requested_version <- NULL
  src_root <- normalizePath(args[[1L]], mustWork = TRUE)
  shasum <- NULL
  integrity <- NULL
}

package_json <- file.path(src_root, "package.json")
if (!file.exists(package_json)) {
  stop("The source package does not contain package.json.", call. = FALSE)
}
metadata <- jsonlite::fromJSON(package_json)
if (!identical(metadata$name, "bio-tooltips")) {
  stop("The source package is not bio-tooltips.", call. = FALSE)
}
version <- validate_version(metadata$version)
if (!is.null(requested_version) && !identical(version, requested_version)) {
  stop("The downloaded package version does not match the requested version.", call. = FALSE)
}

src <- file.path(src_root, "dist")
required <- c("bio-tooltips.css", "bio-tooltips.global.js")
missing <- required[!file.exists(file.path(src, required))]
if (length(missing)) {
  stop("Missing built assets: ", paste(missing, collapse = ", "), call. = FALSE)
}

license <- file.path(src_root, "LICENSE")
if (!file.exists(license)) {
  stop("The source package does not contain LICENSE.", call. = FALSE)
}

dest <- file.path("inst", "htmltools", "bio-tooltips")
dir.create(dest, recursive = TRUE, showWarnings = FALSE)
copied <- file.copy(file.path(src, required), dest, overwrite = TRUE)
if (!all(copied)) {
  stop("Failed to copy one or more Bio Tooltips assets.", call. = FALSE)
}
if (!file.copy(license, file.path(dest, "LICENSE"), overwrite = TRUE)) {
  stop("Failed to copy Bio Tooltips LICENSE.", call. = FALSE)
}

source_lines <- c(
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
  "  https://github.com/mattjmeier/bio-tooltips"
)
if (!is.null(shasum)) {
  source_lines <- c(
    source_lines,
    "",
    "npm tarball checksums:",
    "",
    sprintf("  shasum: %s", shasum),
    sprintf("  integrity: %s", integrity)
  )
}
source_lines <- c(
  source_lines,
  "",
  "Copied files:",
  "",
  "  bio-tooltips.css",
  "  bio-tooltips.global.js",
  "  LICENSE"
)
writeLines(source_lines, file.path(dest, "SOURCE"))

old_source <- readLines(file.path(dest, "README.md"), warn = FALSE)
old_version <- regmatches(
  old_source,
  regexpr("[0-9]+\\.[0-9]+\\.[0-9]+(?:-[0-9A-Za-z.-]+)?", old_source)
)
old_version <- old_version[nzchar(old_version)][[1L]]

pin_files <- c(
  "R/dependencies.R",
  "README.md",
  "cran-comments.md",
  "inst/htmltools/bio-tooltips/README.md",
  "tests/testthat/test-dependencies.R",
  "vignettes/BioTooltipR.Rmd"
)
for (path in pin_files) {
  lines <- readLines(path, warn = FALSE)
  lines <- gsub(old_version, version, lines, fixed = TRUE)
  writeLines(lines, path)
}

message("Vendored bio-tooltips ", version, " into ", dest)
