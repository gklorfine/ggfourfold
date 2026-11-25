## Submission

This is a minor release, updating 0.1.0 to 0.2.0. It adds a `labels` argument
to `geom_fourfold()`, replaces links to datavis.ca, which is now offline, and
corrects a DOI in the package description.

## Test environments

* Local: macOS Tahoe 26.7.3 (aarch64-apple-darwin23), R 4.6.1
* GitHub Actions (R-CMD-check):
  * macOS Tahoe 26.7.2, R 4.6.2
  * Windows Server 2022, R 4.6.2 (ucrt)
  * Ubuntu 26.04.1 LTS, R-devel (2026-11-24 r90980)
  * Ubuntu 26.04.1 LTS, R 4.6.2
  * Ubuntu 26.04.1 LTS, R 4.5.3
* win-builder: Windows Server 2022, R-devel (2026-11-17 r90926 ucrt)

## R CMD check results

0 errors | 0 warnings | 0 notes

## URL checks

* The R-universe URLs in README.md return 403 to automated clients because of
  Cloudflare bot protection; they work in a browser.
* https://doi.org/10.1201/b19022 in README.md is a valid DOI. It resolves to
  Taylor & Francis, which returns 503 to the HEAD requests that URL checks
  send, but it opens in a browser.

## Reverse dependencies

There are currently no reverse dependencies.
