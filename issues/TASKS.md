# ggfourfold — development tasks

**Reviewed 2026-09-25** against the current `R/` source, documentation, and development
scripts before publishing on GitHub. The issues below were reproduced locally with
ggplot2 4.0.3; unfinished README/vignette content is outside this review.

As these items are resolved, check them off as [X] and record the fix and verification here.

## Accuracy / API fixes

- [ ] **Keep category labels attached to the correct counts when scale breaks change** —
  `.fourfold_panel_table()` takes labels from `get_labels()` in break order, but assigns
  counts using the mapped scale positions. With factor levels `c("a", "b")`, adding
  `scale_x_discrete(breaks = c("b", "a"))` swaps the displayed labels without swapping
  their counts. This silently reverses the apparent category interpretation. Resolve labels
  by their corresponding scale positions rather than assuming break order matches data
  order. Verify both axes with reordered breaks and custom labels, and cover omitted
  breaks so display settings do not change the underlying table.
  File: `R/geom-fourfold.R` (`.fourfold_panel_table()`).

- [ ] **Handle tables with an entirely empty row or column explicitly** — for
  `matrix(c(0, 0, 10, 20), nrow = 2)`, the default display gives identical lower and upper
  confidence-ring radii despite a wide calculated odds-ratio interval. Inference applies
  the 0.5 correction, but confidence tables are reconstructed using the original zero
  margins; standardizing those reconstructed tables loses the requested interval bounds.
  With `margin = 2`, the same table also produces two `NaN` sector radii through division
  by a zero column total. Choose and document a consistent treatment, or reject zero-margin
  tables with an informative error. Verify empty rows and columns separately from isolated
  zero cells, including default, single-margin, and maximum-based standardization.
  File: `R/geom-fourfold.R` (`.fourfold_compute_layer()`,
  `.fourfold_table_with_or_and_margins()`, `.fourfold_standardize()`).

- [ ] **Align mapped drawing aesthetics with the documented API** — the help advertises
  `colour`, `linewidth`, `alpha`, `size`, and `family` as fixed or mapped properties, but
  `.fourfold_compute_layer()` constructs fresh output without preserving those mappings.
  Reproduced with `aes(colour = x)`: all outlines use the default black. `draw_panel()` also
  reads drawing properties from only the first output row. Either implement and define the
  supported mapping behavior, including aggregation within a panel, or document these as
  fixed arguments and explicitly reject unsupported mappings rather than silently ignoring
  them. Regenerate the help after updating the roxygen text.
  Files: `R/geom-fourfold.R`, `man/geom_fourfold.Rd`.

- [ ] **Remove missing categories consistently with `na.rm`** — adding a row with an `NA`
  factor value mapped to `x` causes an "exactly two x levels" error even when
  `na.rm = TRUE`. The discrete scale retains a missing-value category after incomplete
  observations are removed, so validation sees three labels. Separate the valid category
  positions from the missing-value category when building the table. Verify missing `x`,
  `y`, and `weight` values: `na.rm = TRUE` should remove incomplete observations silently;
  `FALSE` should remove them with the documented warning. Retain useful errors for panels
  with no complete observations or no positive total.
  File: `R/geom-fourfold.R` (`.fourfold_panel_table()`).

## Development scripts

- [ ] **Repair stale source paths and the missing verification reference** —
  `Rscript dev/verify-geom-fourfold.R` currently stops immediately trying to source
  `dev/geom-fourfold.R`; the implementation now lives in `R/`. The script also sources a
  nonexistent `dev/ggfourfold.R` and calls its unavailable `ggfourfold_data()` reference
  helper. `dev/examples.R` similarly searches obsolete development locations, and both
  script headers give commands under the nonexistent `dev/fourfold/` directory. Update
  loading and run instructions, replace or restore the reference calculation, and check
  both scripts from a fresh R session at the package root. Keep the numerical reference
  independent of the implementation being tested.
  Files: `dev/verify-geom-fourfold.R`, `dev/examples.R`.

## Display / layout

- [ ] **Reduce overlap in the unstandardized README display** — review the space occupied
  by the sectors and labels; scale down the display area if text overlaps excessively.
  Existing task retained from the original list.
  Files: `README.Rmd`, `R/geom-fourfold.R`.

## Verification recorded (2026-09-25)

The package built successfully, including its vignette. `R CMD check --no-manual
--no-vignettes` on that tarball finished with status OK; vignette rebuilding during check
and the PDF manual were not checked. Repository-index access was unavailable during the
dependency check, so this used the locally installed dependencies.

Independent calculations matched the Berkeley examples' odds ratios, standard errors,
Wald confidence intervals, raw p-values, Holm adjustment, and individual/global maximum
standardizations. These checks do not resolve the edge cases above, and the existing
development verification script remains broken as noted above.
