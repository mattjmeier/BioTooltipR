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

find_npm <- function() {
  npm <- Sys.which("npm")
  if (!nzchar(npm) && .Platform$OS.type == "windows") {
    npm <- Sys.which("npm.cmd")
  }
  if (!nzchar(npm)) {
    stop("npm was not found on PATH.", call. = FALSE)
  }
  npm
}

# Attempt a single `npm pack`. Returns list(ok = TRUE, path, shasum, integrity)
# on success, or list(ok = FALSE, details = <stderr lines>) on failure so the
# caller can decide whether to retry.
pack_npm_version_once <- function(npm, version) {
  work <- tempfile("bio-tooltips-npm-")
  dir.create(work)
  stderr_file <- tempfile("npm-pack-stderr-")
  output <- suppressWarnings(system2(
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
  ))
  status <- attr(output, "status")

  # `system2` leaves the status attribute NULL on success and only sets it to a
  # non-zero value (with a warning) when the command fails.
  if (is.null(status) || status == 0L) {
    metadata <- tryCatch(
      jsonlite::fromJSON(paste(output, collapse = "\n")),
      error = function(e) NULL
    )
    if (is.data.frame(metadata) && nrow(metadata) == 1L) {
      tarball <- file.path(work, metadata$filename[[1L]])
      if (file.exists(tarball)) {
        extract_dir <- file.path(work, "unpacked")
        dir.create(extract_dir)
        utils::untar(tarball, exdir = extract_dir)
        return(list(
          ok = TRUE,
          path = file.path(extract_dir, "package"),
          shasum = metadata$shasum[[1L]],
          integrity = metadata$integrity[[1L]]
        ))
      }
    }
  }

  details <- if (file.exists(stderr_file)) readLines(stderr_file, warn = FALSE) else character()
  list(ok = FALSE, details = details)
}

pack_npm_version <- function(version) {
  npm <- find_npm()

  # `npm publish` can lag by a few seconds to a couple of minutes before the
  # new version becomes queryable on the public registry. A vendoring run
  # triggered immediately after a release (via `repository_dispatch`) can hit an
  # "ETARGET: No matching version found" error even though the tarball appears
  # moments later. Retry the pack a bounded number of times with exponential
  # backoff instead of failing on the first miss. The schedule is tunable via
  # environment variables (used by the CI vendoring workflow).
  max_attempts <- as.integer(Sys.getenv("BIOTOOLTIPS_MAX_ATTEMPTS", "6"))
  if (is.na(max_attempts) || max_attempts < 1L) max_attempts <- 6L
  initial_delay <- as.numeric(Sys.getenv("BIOTOOLTIPS_INITIAL_DELAY_SECONDS", "15"))
  if (is.na(initial_delay) || initial_delay < 0) initial_delay <- 15

  delay <- initial_delay
  for (attempt in seq_len(max_attempts)) {
    result <- pack_npm_version_once(npm, version)
    if (isTRUE(result$ok)) {
      return(result)
    }

    if (attempt == max_attempts) {
      stop(
        "npm pack for bio-tooltips@", version,
        " failed after ", max_attempts, " attempts. The version may not be",
        "\npublished on npm yet.\n",
        paste(result$details, collapse = "\n"),
        call. = FALSE
      )
    }

    message(
      sprintf(
        "bio-tooltips@%s not available yet (attempt %d/%d); retrying in %s seconds...",
        version, attempt, max_attempts, delay
      )
    )
    Sys.sleep(delay)
    delay <- min(delay * 2, 120)
  }

  stop("Unreachable: npm pack retry loop ended without a result.", call. = FALSE)
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
