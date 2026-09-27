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

- [X] **Square fourfold displays: `shape = c("circle", "square")`** (2026-09-27) — prompted by
  the Fienberg-style square display noted in `dev/fourfold-ideas.md`.
  - Each cell is a quarter-square with the *same area* as the quarter-circle it replaces:
    side = `sqrt(pi) / 2` × radius (`.fourfold_square_side`). The side-equals-radius
    version tried first was about 27% heavier than the circles and filled the frame corners.
  - Confidence rings become nested square outlines; direction ticks start at the squares'
    outer corners along the diagonal.
  - **Count placement is decided per layer**: counts stay inside the frame corners unless
    some square, upper confidence outline, or direction tick in *any* panel reaches past
    the count limit; then counts in all panels move just outside the frame corners.
    Circles are unchanged.
    - The layer-wide *reach* is computed in `GeomFourfold$setup_data()`
      (`.fourfold_counts_reach()`, stored as the `counts_reach` column).
    - The *limit* is 0.80 by default (`.fourfold_square_count_limit`), lowered to
      `0.88 - measured count text height` when the text reaches further
      (`.fourfold_count_limit()`). Because count text is responsive to panel size, this
      is measured at draw time in `makeContent.fourfold_counts()`, which records
      `count_limit` and `outside` on the drawn grob. Facet panels share one size, so all
      panels still decide alike.
    - Measured: at 7 × 5 in with 6 panels the counts are at their 10 pt minimum and are
      0.132 normalized units tall, so the limit is 0.748 (the text, not the 0.80 default,
      governs at this size); at 3.5 × 2.5 in it drops to 0.514.
  - Finding: with the default `ticks = 0.15`, the square diagonal ticks point straight at
    the corner counts, so UCB with `std = "margins"` moves its counts outside because of the
    ticks alone. Forcing the counts inside confirmed the ticks collide with them in all six panels.
    With `ticks = 0` (or `extended = FALSE`) the counts stay inside; `std = "ind.max"` always
    moves them outside.
  - Statistics are identical for both shapes (checked radii and adjusted p-values via
    `layer_data()`).
  - Docs: `@details`, `@param shape`, a square `@examples` plot, and `@references` to
    Friendly (1994, TR 217) in `geom_fourfold()`; README gained a square example and the
    citation (entry added to `vignettes/refs.bib`). Also added the missing
    `Roxygen: list(markdown = TRUE)` to `DESCRIPTION`, which fixed raw markdown in all `.Rd`.
  - Visual check: `dev/square-counts.R` (source in RStudio, or
    `Rscript dev/square-counts.R [output-dir]` to write PNGs). It draws each case and
    prints the reach, count font size, measured limit, and resulting placement, including
    a small-device (3.5 × 2.5 in) case where the measured text height alone moves the
    counts outside.
  Files: `R/geom-fourfold.R`, `README.Rmd`, `DESCRIPTION`, `vignettes/refs.bib`,
  `dev/square-counts.R`.

- [ ] **Add a `counts = c("auto", "inside", "outside")` argument** — expose the count
  placement for both shapes. `"auto"` (the default) keeps the current per-layer rule
  (`.fourfold_counts_reach()` compared with the measured limit in
  `makeContent.fourfold_counts()`; pass the choice through to that grob): inside unless a square/outline/tick in any panel reaches the
  corner counts, then outside in every panel (always inside for circles). `"inside"` and
  `"outside"` force the placement, e.g. to keep squares visually close to vcd or to match
  layouts across separate plots. Consider whether `"outside"` needs more panel padding than
  the current ±1.3 viewport at small sizes: in the 3.5 × 2.5 in case of
  `dev/square-counts.R`, outside counts collide with the outer category labels and the
  neighbouring panel's counts (inside they would overlap the squares), so small displays
  may need more panel spacing or smaller count text. (The limit is now 0.80 by default,
  lowered to reflect the measured count text height at draw time.)
  Files: `R/geom-fourfold.R`, `dev/square-counts.R`.

- [ ] **Square tick direction** — the diagonal direction ticks are what usually force square
  counts outside. Consider an alternative for squares (e.g. shorter ticks, or ticks drawn
  along the outer edges) so that typical `std = "margins"` displays can keep counts inside.

## Inference

- [ ] **Should the confidence rings be adjusted for multiple comparisons?** (raised
  2026-09-27 while writing the vignette's "Confidence rings" section)

  *What the adjustment would apply to.* In a 2 × 2 × k table there is one test per
  stratum, H0: θ_c = 1 for c = 1, …, k. Within a single stratum there is only that one
  test, so nothing needs adjusting *within* a stratum. Multiplicity arises only
  *overall*, from the family of k tests across strata, i.e. across the facet panels of one
  layer. (A single overall test, such as Cochran–Mantel–Haenszel for a common θ = 1 or the
  Woolf/Breslow–Day test of homogeneity, answers a different question and needs no
  adjustment.)

  *Current behaviour* (same in `ggfourfold` and `vcd::fourfold()`): the k p-values are
  adjusted across the panels of the layer with `p_adjust_method` (default Holm), and the
  adjusted p-values decide only which panels get the intense colours. Each panel's rings are
  that stratum's own unadjusted interval at `conf_level`. So colour and rings can disagree:
  a stratum whose rings only just separate (unadjusted p < 0.05) can still be drawn in the
  pale colours (adjusted p ≥ 0.05). The vignette now describes this.

  *If adjusting rings* (e.g. an `adjust_rings = FALSE` argument): the aim would be
  *simultaneous* intervals whose joint coverage over all k strata is at least `conf_level`.
  Holm is a step-down *testing* procedure and has no simple matching confidence intervals,
  so it can't be used directly for rings. Bonferroni is the natural choice: each stratum's
  interval at level 1 − α/k. Šidák (1 − (1 − α)^(1/k)) is slightly narrower and assumes
  independent strata, which holds for disjoint strata. Rings separating would then agree
  with a Bonferroni test, but not always with the Holm-adjusted colour emphasis. Holm
  rejects at least as often as Bonferroni, so a panel could be drawn intense while its
  adjusted rings still overlap. Options: adjust rings with Bonferroni and document the
  difference; tie the colour emphasis to the same method when rings are adjusted; or leave
  rings unadjusted (current, vcd-compatible) and just document it. For k = 1 (no facets),
  all choices coincide. Decision for GK/MF.
  Files: `R/geom-fourfold.R` (`.fourfold_compute_layer()`), vignette "Confidence rings".

- [ ] **Check the diagnosis of a discrepancy with DDAR, §4.4.2** — in writing the vignette,
  Claude noted that DDAR (`C:\Dropbox\Documents\VCDR\ch04.Rnw`, about lines 1186–1195,
  including the footnote on Holm's method) describes the rings in the stratified Berkeley
  figure as *joint* 95% intervals for θ_c, c = 1, …, k. Reading the `vcd::fourfold()` source
  (vcd 1.4-14) suggests that `p.adjust(..., method = p_adjust_method)` is applied only to the
  log odds ratio tests that set the colour emphasis (`p.lor.test`, used in `emphasize`).
  The rings appear to use `qnorm((1 ± conf_level) / 2)` without adjustment, so they would be
  individual, not joint, intervals. `ggfourfold` matches that behaviour. To verify (MF):
  confirm against the vcd source (`vcd:::fourfold`, the `p.lor.test` and `theta <- or *
  exp(qnorm(...) * se)` lines), check whether earlier vcd versions or the original SAS
  `fourfold` macro adjusted the rings, and if the book text is wrong, note it for a
  DDAR errata/2nd edition.

## Data input

- [ ] **Accept data in table form** (`table`, `xtabs`, `ftable`, `structable`) — at present
  `geom_fourfold()` needs long (frequency) form, e.g. `as.data.frame(UCBAdmissions)`, and the
  vignette says it "currently works on data in *long form*". `vcd::fourfold()` takes a
  2 × 2 × k array directly. (MF thought ggmosaic2 might accept tables, but it doesn't: its
  README and the "Three Forms of Frequency Tables" vignette pipe tables through
  `as.data.frame()`, so it offers no mechanism to copy.)

  *What happens now* (ggplot2 4.0.3, checked 2026-09-27): no table form is accepted.
  `ggplot(UCBAdmissions)` fails inside `ggplot()` itself with "`data` must be a
  <data.frame>, or an object coercible by `fortify()` …" because `dim(data)` is not of
  length 2. A 2-D table also fails, because `as.data.frame()` changes its dimensions
  (2 × 2 → 4 × 3). `geom_fourfold(data = UCBAdmissions)` fails the same way when the layer
  is constructed. `ftable` and `structable` objects fail the same checks.

  *Options*, which can be combined:
  1. **Convert layer data inside `geom_fourfold()`** before calling `layer()`: if `data` is a
     `table` (including `xtabs`), `ftable` or `structable`, convert with
     `as.data.frame(as.table(data), stringsAsFactors = TRUE)`. Factor levels keep the
     table's dimname order, so orientation is preserved. Small, self-contained, and uses
     only ggplot2's public API. Limitation: only `geom_fourfold(data = tab)` works, not
     `ggplot(tab)`, because `ggplot()` rejects the table before the geom sees it.
  2. **A convenience constructor**, e.g. `ggfourfold(tab, ...)`, returning a `ggplot` with
     the vcd array convention built in: dimension 1 → `y` (rows), dimension 2 → `x`
     (columns), `weight = Freq`, with strata from the remaining dimensions added as
     `facet_wrap()` (one) or `facet_grid()` (two), plus `theme_fourfold()`. This is closest
     to `vcd::fourfold(UCB)` and is the `ggfourfold()` array wrapper that
     `dev/fourfold-plan.md` deferred ("may later become a convenience wrapper if real
     usage warrants it"). The result is an ordinary ggplot, so it can still be extended with
     `+`.
  3. **Register a `fortify.table()` S3 method** so that `ggplot(UCBAdmissions, ...)` works.
     A quick trial confirmed this works with faceting. However, ggfourfold owns neither the
     generic nor the class, so the method would change `ggplot()` for *every* table
     whenever ggfourfold is loaded. This could clash with other packages or with a future
     ggplot2 method, and is questionable for CRAN. Not recommended without discussion.

  *Pitfall for 1 and 2*: `weight` must default to the frequency column. If a user supplies a
  table but doesn't map `weight`, each cell would silently count as 1, giving a plausible
  but wrong display. When the input was a table, add `weight = Freq` to the mapping unless
  `weight` is already mapped. (Beware name clashes: `as.data.frame.table()` uses `Freq`,
  which fails if a dimension is itself called `Freq`.)

  *Also*: validate that dimensions 1 and 2 have two levels each (the existing per-panel
  checks already give an error); decide how to treat `NA` dimnames and 1-D tables; add tests
  comparing table input with the equivalent long-form data; update the vignette's "currently
  works on data in long form" sentence and the README. `vcd` and `vcdExtra` are in the
  same family of packages, and vcdExtra's helpers for converting between case, frequency and
  table forms may be worth reusing or pointing to in the docs.

  Suggested order: 1 (cheap, no API risk), then 2 if a vcd-like one-liner is wanted.
  Decision for GK.
  Files: `R/geom-fourfold.R`, new `R/ggfourfold.R` (for 2), tests, vignette, README.

## Verification recorded (2026-09-25)

The package built successfully, including its vignette. `R CMD check --no-manual
--no-vignettes` on that tarball finished with status OK; vignette rebuilding during check
and the PDF manual were not checked. Repository-index access was unavailable during the
dependency check, so this used the locally installed dependencies.

Independent calculations matched the Berkeley examples' odds ratios, standard errors,
Wald confidence intervals, raw p-values, Holm adjustment, and individual/global maximum
standardizations. These checks do not resolve the edge cases above, and the existing
development verification script remains broken as noted above.
