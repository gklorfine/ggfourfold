# ggfourfold 0.1.1.9000

* `geom_fourfold()` has a new argument `labels`. With `labels = "both"`, each
  side of the display is labeled with the name of the variable and the level,
  as in `vcd::fourfold()`, for example "Gender: Male". Suggested by Michael
  Friendly.
* The documentation of `geom_fourfold()` now explains that, if drawn, the
  axis titles (which `theme_fourfold()` hides by default) appear next to the
  levels of the other variable (e.g., an *x*-axis label would appear next to the
  levels of *y*, being that its variable levels appear at the top and bottom of
  the fourfold display). Suggested by Michael Friendly.

# ggfourfold 0.1.1

* Corrected the DOI for Friendly and Meyer (2016) in the package description.

# ggfourfold 0.1.0

* Initial CRAN release.
