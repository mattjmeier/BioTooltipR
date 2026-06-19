#!/usr/bin/env Rscript

# Vendor exact D3 and Ideogram npm releases used by Bio Tooltips gene visuals.
# This is a development-time script; package installation never downloads files.
#
# Usage:
#   Rscript scripts/vendor-visual-dependencies.R \
#     --d3-version 7.9.0 --ideogram-version 1.53.0

args <- commandArgs(trailingOnly = TRUE)

write_lines_lf <- function(lines, path) {
  con <- file(path, open = "wb")
  on.exit(close(con))
  text <- paste0(paste(enc2utf8(lines), collapse = "\n"), "\n")
  writeBin(charToRaw(text), con)
}

if (!file.exists("DESCRIPTION") ||
    !identical(read.dcf("DESCRIPTION")[[1L, "Package"]], "BioTooltipR")) {
  stop("Run this script from the BioTooltipR package root.", call. = FALSE)
}

validate_version <- function(version) {
  pattern <- "^[0-9]+\\.[0-9]+\\.[0-9]+(?:-[0-9A-Za-z.-]+)?$"
  if (length(version) != 1L || is.na(version) || !grepl(pattern, version)) {
    stop("Versions must be exact semantic versions such as 7.9.0.", call. = FALSE)
  }
  version
}

read_default <- function(argument) {
  lines <- readLines(file.path("R", "dependencies.R"), warn = FALSE)
  hit <- grep(sprintf('^[[:space:]]+%s = "', argument), lines, value = TRUE)
  if (length(hit) != 1L) stop("Could not find the ", argument, " default.", call. = FALSE)
  sub('.*= "([^"]+)".*', "\\1", hit)
}

values <- list(
  d3_version = read_default("d3_version"),
  ideogram_version = read_default("ideogram_version")
)
if (length(args) %% 2L != 0L) {
  stop("Arguments must be --d3-version VERSION and/or --ideogram-version VERSION.", call. = FALSE)
}
if (length(args)) {
  for (i in seq.int(1L, length(args), by = 2L)) {
    key <- switch(
      args[[i]],
      "--d3-version" = "d3_version",
      "--ideogram-version" = "ideogram_version",
      stop("Unknown argument: ", args[[i]], call. = FALSE)
    )
    values[[key]] <- validate_version(args[[i + 1L]])
  }
}

npm <- Sys.which("npm")
if (!nzchar(npm) && .Platform$OS.type == "windows") npm <- Sys.which("npm.cmd")
if (!nzchar(npm)) stop("npm was not found on PATH.", call. = FALSE)

pack_npm <- function(package, version) {
  work <- tempfile(paste0(package, "-npm-"))
  dir.create(work)
  stderr_file <- tempfile("npm-pack-stderr-")
  output <- system2(
    npm,
    c("pack", sprintf("%s@%s", package, version), "--json", "--pack-destination", shQuote(work)),
    stdout = TRUE,
    stderr = stderr_file
  )
  status <- attr(output, "status")
  if (!is.null(status) && status != 0L) {
    details <- if (file.exists(stderr_file)) readLines(stderr_file, warn = FALSE) else character()
    stop("npm pack failed for ", package, ".\n", paste(details, collapse = "\n"), call. = FALSE)
  }

  packed <- jsonlite::fromJSON(paste(output, collapse = "\n"))
  tarball <- file.path(work, packed$filename[[1L]])
  extract_dir <- file.path(work, "unpacked")
  dir.create(extract_dir)
  utils::untar(tarball, exdir = extract_dir)

  list(
    root = file.path(extract_dir, "package"),
    shasum = packed$shasum[[1L]],
    integrity = packed$integrity[[1L]]
  )
}

vendor_one <- function(package, version, asset) {
  packed <- pack_npm(package, validate_version(version))
  metadata <- jsonlite::fromJSON(file.path(packed$root, "package.json"))
  if (!identical(metadata$name, package) || !identical(metadata$version, version)) {
    stop("Downloaded npm metadata did not match ", package, "@", version, ".", call. = FALSE)
  }

  source_asset <- file.path(packed$root, asset)
  license_candidates <- file.path(packed$root, c("LICENSE", "LICENSE.md", "LICENSE.txt"))
  license <- license_candidates[file.exists(license_candidates)][1L]
  if (!file.exists(source_asset)) stop("Missing npm asset: ", asset, call. = FALSE)
  if (is.na(license)) stop("The npm package does not contain a license file.", call. = FALSE)

  dest <- file.path("inst", "htmltools", package)
  dir.create(dest, recursive = TRUE, showWarnings = FALSE)
  output_asset <- basename(asset)
  if (!file.copy(source_asset, file.path(dest, output_asset), overwrite = TRUE) ||
      !file.copy(license, file.path(dest, "LICENSE"), overwrite = TRUE)) {
    stop("Failed to copy vendored files for ", package, ".", call. = FALSE)
  }

  source_lines <- c(
    "These files were copied from the published npm package:", "",
    sprintf("  %s@%s", package, version), "",
    "Source package:", "",
    sprintf("  https://www.npmjs.com/package/%s/v/%s", package, version), "",
    "npm tarball checksums:", "",
    sprintf("  shasum: %s", packed$shasum),
    sprintf("  integrity: %s", packed$integrity), "",
    "Copied files:", "",
    sprintf("  %s", output_asset),
    "  LICENSE"
  )
  write_lines_lf(source_lines, file.path(dest, "SOURCE"))
  write_lines_lf(c(
    paste("# Local", package, "assets"), "",
    sprintf("Pinned `%s` %s runtime files used by BioTooltipR gene visuals.", package, version),
    "They are refreshed with `scripts/vendor-visual-dependencies.R`, never at package install time."
  ), file.path(dest, "README.md"))
}

old_versions <- list(
  d3 = read_default("d3_version"),
  ideogram = read_default("ideogram_version")
)
vendor_one("d3", values$d3_version, file.path("dist", "d3.min.js"))
vendor_one("ideogram", values$ideogram_version, file.path("dist", "js", "ideogram.min.js"))

pin_files <- c(
  "R/dependencies.R", "README.md", "cran-comments.md",
  "tests/testthat/test-dependencies.R", "vignettes/BioTooltipR.Rmd"
)
for (path in pin_files) {
  lines <- readLines(path, warn = FALSE)
  lines <- gsub(old_versions$d3, values$d3_version, lines, fixed = TRUE)
  lines <- gsub(old_versions$ideogram, values$ideogram_version, lines, fixed = TRUE)
  write_lines_lf(lines, path)
}

message(
  "Vendored d3@", values$d3_version,
  " and ideogram@", values$ideogram_version,
  " under inst/htmltools/."
)
