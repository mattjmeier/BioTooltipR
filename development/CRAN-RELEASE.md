# CRAN Release Checklist

A guide for releasing this package to CRAN. Follow the checklist instead of relying on memory.

## 1. Decide what kind of release this is

The development version will normally look like `x.y.z.9000`.

Choose the next release version:

* [ ] **Patch** — `1.2.3.9000` → `1.2.4`

  * Bug fixes, documentation changes, small internal improvements.
  * No intentional breaking API changes.

* [ ] **Minor** — `1.2.3.9000` → `1.3.0`

  * New functionality or other meaningful backwards-compatible changes.
  * May also include bug fixes.

* [ ] **Major** — `1.2.3.9000` → `2.0.0`

  * Breaking API changes or a substantial redesign.
  * Pay particular attention to reverse dependencies.

Do **not** remove the `.9000` development suffix until the release is actually ready to submit.

---

## 2. Get the development environment into a clean state

Make sure the Pixi environment is current and reproducible:

```bash
pixi install
# Enter the environment or use R directly with `pixi run R`
pixi shell
```

Then make sure the repository itself is clean and intentional:

* [ ] All intended changes are committed.
* [ ] No accidental generated/temp files are present.
* [ ] `DESCRIPTION` is current.
* [ ] Dependencies in `DESCRIPTION` are correct.
* [ ] Documentation is current.
* [ ] Tests pass.
* [ ] Vignette builds.
* [ ] `README` is current, if applicable.
* [ ] `NEWS.md` describes the changes in this release.

If using roxygen:

```r
devtools::document()
```

Run the tests:

```r
devtools::test()
```

---

## 3. Check the package carefully

First check the current CRAN results page for the package. Do not blindly submit an update without seeing whether CRAN is already reporting problems with the existing version.

Run a proper local CRAN-style check:

```r
devtools::check(
  remote = TRUE,
  manual = TRUE
)
```

Target:

```text
0 errors | 0 warnings | 0 notes
```

A NOTE is not automatically fatal, but understand every NOTE and explain anything unavoidable in `cran-comments.md`.

Also check R-devel on Windows:

```r
devtools::check_win_devel()
```

Consider URL checking separately if the package contains many external links:

```r
urlchecker::url_check()
```

* [ ] Local CRAN-style check is clean.
* [ ] R-devel / win-builder check is clean.
* [ ] Any NOTE is understood and defensible.
* [ ] URLs are valid.
* [ ] Examples/tests do not depend incorrectly on network access, local files, etc.

---

## 4. Check reverse dependencies

CRAN expects reverse dependencies to be checked for package updates.

If there are no reverse dependencies, record that in `cran-comments.md`.

If there are reverse dependencies:

```r
revdepcheck::revdep_check()
```

Focus on **new failures caused by this version**, rather than failures that already occur with the CRAN release.

* [ ] Reverse dependencies checked.
* [ ] No new downstream failures attributable to this release.
* [ ] Results summarized in `cran-comments.md`.

### Extra care for breaking/API changes

If this release breaks downstream packages:

* [ ] Identify affected packages.
* [ ] Contact their maintainers with the required changes.
* [ ] Give them **at least two weeks, preferably longer**, before submitting.
* [ ] Mention affected packages and maintainer notification in `cran-comments.md`.

Do not surprise downstream maintainers with a breaking CRAN release.

---

## 5. Update `cran-comments.md`

`cran-comments.md` is the note to the CRAN reviewers. It should contain:

```markdown
## R CMD check results

0 errors | 0 warnings | 0 notes

## Reverse dependencies

There are currently no downstream dependencies for this package.
```

Or summarize the actual revdep results if there are any.

Also explain:

* unavoidable NOTEs;
* unusual check behaviour;
* special build requirements;
* relevant CRAN-requested changes;
* reverse-dependency issues.

For a resubmission, add something like:

```markdown
## Resubmission

This is a resubmission. In this version I have:

* Fixed ...
* Updated ...
* Rechecked ...
```

Keep `cran-comments.md` tracked in Git, but excluded from the package tarball via `.Rbuildignore`.

---

## 6. Make the actual release version

Only once everything above looks good:

```r
usethis::use_version("patch")
```

or:

```r
usethis::use_version("minor")
```

or:

```r
usethis::use_version("major")
```

Check the resulting changes to `DESCRIPTION` and `NEWS.md`.

* [ ] Version number is correct.
* [ ] `.9000` is gone.
* [ ] `NEWS.md` has the correct released version heading.
* [ ] Release-version changes are committed.

It is worth doing one final check of the release state before uploading.

---

## 7. Submit to CRAN

Submit:

```r
devtools::submit_cran()
```

This builds the CRAN source tarball and submits it through CRAN's web submission process.

### IMPORTANT: approve the email

CRAN will send a confirmation email to the package maintainer.

* [ ] **CLICK THE CONFIRMATION LINK.**

The submission is not complete until the email is confirmed.

After submission:

* [ ] Do not submit another version while this one is still pending.
* [ ] Keep the generated `CRAN-SUBMISSION` file until the release process is finished.

---

## 8. If CRAN asks for changes

Read the CRAN message carefully and fix exactly what they are asking about.

Then:

* [ ] Make the requested changes.
* [ ] Update the `Resubmission` section of `cran-comments.md`.
* [ ] Re-run the relevant checks.
* [ ] Prefer increasing the package version again before resubmitting.
* [ ] Submit again with `devtools::submit_cran()`.
* [ ] Approve the new confirmation email.

Do not send the package itself to CRAN by email.

---

## 9. After CRAN accepts the release

Wait until the package is actually visible on CRAN.

Then:

* [ ] Confirm the CRAN package page shows the new version.
* [ ] Check the CRAN check-results page once builds have populated across platforms.
* [ ] Create the GitHub release/tag:

```r
usethis::use_github_release()
```

* [ ] Return the package to a development version:

```r
usethis::use_dev_version(push = TRUE)
```

For example:

```text
1.2.4        # released on CRAN
1.2.4.9000   # development begins again
```

If reverse-dependency checking created a local `revdep/` workspace and it is no longer needed:

```r
revdepcheck::revdep_reset()
```

---

## Reminders

* **`.9000` means development; don't submit it to CRAN.**
* **Check the existing CRAN results before submitting an update.**
* **Reverse-dependency checking applies to updates, not only major releases.**
* **Breaking downstream packages requires advance notice.**
* **Run the CRAN-style check, preferably including R-devel.**
* **After acceptance, create the GitHub release and go back to `.9000`.**
