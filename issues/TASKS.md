# ggfourfold — development tasks

**Reviewed 2026-09-25** against the current `R/` source, documentation, and development
scripts before publishing on GitHub. The issues below were reproduced locally with
ggplot2 4.0.3; unfinished README/vignette content is outside this review.

As these items are resolved, check them off as [X] and record the fix and verification here.

## Accuracy / API fixes

- [X] **Keep category labels attached to the correct counts when scale breaks change**
  (2026-09-29) — `.fourfold_panel_table()` took labels from `get_labels()` in break order,
  but assigned counts using the mapped scale positions (limits order). With factor levels
  `c("a", "b")`, adding `scale_x_discrete(breaks = c("b", "a"))` swapped the displayed
  labels without swapping their counts, silently reversing the apparent category
  interpretation. Omitting a break (`breaks = "a"`) gave a misleading "exactly two x
  levels" error.
  - *Decision*: reject such breaks rather than resolve labels by position. `breaks` has no
    role in a fourfold display: `limits` reorders categories (which already worked) and
    `labels` renames them (named and unnamed both already worked). Reordered breaks
    reorder nothing even in an ordinary ggplot, so a user writing them probably meant
    `limits`, and omitted breaks would leave a category unlabelled.
  - *Fix*: new `.fourfold_check_breaks()`, called for the x and y panel scales before the
    labels are read. For discrete scales, breaks must equal the limits in order (compared
    as character, so logical variables work; the `NA` category is ignored on both sides so
    that the separate `na.rm` item below is unaffected). Otherwise it stops with e.g.
    ``fourfold x breaks in panel 1 are ("b", "a") but must be the x categories in order,
    ("a", "b"); use `limits` to reorder categories and `labels` to rename them``. Values
    are quoted with `encodeString()`, so levels containing commas stay unambiguous.
    Continuous scales are skipped here; they are now rejected earlier by
    `.fourfold_check_positions()` (see the continuous-scale item below). Breaks
    outside the categories are already dropped by the scale, so
    `breaks = c("a", "b", "z")` passes.
  - *Docs*: one sentence in `geom_fourfold()` `@details` on reordering with `limits`,
    renaming with `labels`, and the breaks error; `man/geom_fourfold.Rd` regenerated.
  - *Tests*: added the testthat setup (`tests/testthat.R`; there were no tests before) and
    `tests/testthat/test-geom-fourfold.R` (26 expectations): the error for reordered,
    function (`rev`), omitted, and `NULL` breaks on both axes, inconsistent
    `limits`/`breaks`, quoting of a level containing a comma, `facet_wrap` (x) and
    `facet_grid` (y), and a free-scale mismatch in panel 3 only; no change for matching or
    extra breaks; `limits` moving labels with their counts; `labels` renaming without
    moving counts; logical and character variables.
  - *Verification*: a battery of 48 plots (UCB and Titanic facets, all `std`/`margin`
    options, `conf_level = 0`, `extended = FALSE`, square shape, Bonferroni, custom palette,
    fixed aesthetics, free scales, `margins = TRUE`, labels/limits/breaks variants, and
    existing error cases) run against HEAD and the change. 38 cases were identical in layer
    data, errors, warnings, and rendered pixels (31 PNGs); the 10 that differ are all
    breaks settings that are now rejected: 6 that previously drew silently mislabelled
    displays, 3 that gave the misleading level-count error, plus
    `scale_x_discrete(drop = FALSE, breaks = c("a", "b"))` with an unused third level `c`.
    That last one previously drew correctly only by accident: with
    `limits = c("b", "a", "c")` and the same breaks, HEAD silently draws `a` over `b`'s
    counts. It now errors, consistent with the rule. `R CMD check --as-cran` (remote
    incoming checks off): Status OK, including tests, Rd cross-references, vignettes, and
    the PDF manual. On macOS with XQuartz, run the check with `env -u DISPLAY`, otherwise
    it hangs at "checking use of S3 registration" (tcltk).
  - *Independent verification* (subagent, own 143-plot set, HEAD vs change): 95 successful
    cases identical in layer data, warnings, and pixels; 12 identical errors (including
    the `NA` bug); 42 differ, all rejected breaks settings: 27 reversed/function breaks
    that previously drew wrong labels, 8 omitted/`NULL`/empty breaks that gave the
    misleading error, 5 that errored before for other reasons and now hit the breaks error
    first, and 2 with a third, unused category (the `drop = FALSE` case above and
    `limits = c("a", "b", "c")`). The new tests fail against HEAD's code. Full
    `R CMD check --as-cran` with remote checks: 1 NOTE, identical for HEAD (new submission;
    the SAS URL in `vignettes/refs.bib` redirects to a broken host). The Rd anchors
    `\link[ggplot2:scale_x_discrete]` are not flagged. Conforms to extrachecks.
  - *Known limitation*: when a scale has more than two categories *and* custom breaks, the
    breaks error comes first and lists all categories; following it leads to the
    level-count error. Both messages are accurate, and nothing is drawn wrongly.
  File: `R/geom-fourfold.R` (`.fourfold_check_breaks()`, `.fourfold_panel_table()`).

- [X] **Check that the scale maps the two categories to positions 1 and 2** (found
  2026-09-29 by the independent verification of the breaks item; fixed 2026-09-29) —
  counts are placed with `as.integer(data$x)`, which assumes category *i* sits at position
  *i*. ggplot2 4.0's discrete-scale `palette` broke this silently: with levels
  `c("a", "b")`, `scale_x_discrete(palette = function(n) rev(seq_len(n)))` drew `a` over
  `b`'s counts (UCB by Dept drew the female counts under "Male"), and
  `palette = function(n) c(1, 1.5)` truncated 1.5 to 1 and piled every count into column
  `a`. A contrived variant: `limits = c("a", NA, "b")` with `breaks = c("a", "b")` and
  data in `a` and `NA` labelled the `NA` column "b".
  - *Fix*: new `.fourfold_check_positions()`, called for the x and y panel scales before
    the breaks and level-count checks. It also handles the continuous-scale item below.
    For a discrete scale, the non-`NA` limits must map (`scale$map()`, the same mapping
    that produced `data$x`) to exactly 1, 2, … in order. They are mapped as character,
    because ggplot2 matches data to limits as text: numeric `limits = c(8, 4)` (which
    ggplot2 warns about but draws correctly) would otherwise be mapped to positions 8 and
    4 and wrongly rejected. Otherwise it stops with e.g.
    ``fourfold x categories in panel 1, ("a", "b"), are at positions (2, 1) but must be
    at (1, 2); use `limits`, not a scale `palette`, to reorder categories``. The contrived
    `NA` variant now fails the same way ("positions (1, 3)"). A trailing `NA` category
    (the `na.rm` item below) and scales with more than two categories at positions 1..n
    pass, so they reach the same errors as before. A palette that keeps the positions
    (e.g. `seq_len`) is accepted.
  - *Docs*: the `geom_fourfold()` `@details` sentence on `breaks` now also covers a
    `palette` that moves categories; `man/geom_fourfold.Rd` regenerated.
  - *Tests* (appended to `tests/testthat/test-geom-fourfold.R`, 44 expectations in all):
    reversed palettes on x and y, an uneven palette, a faceted UCB display, `NA` inside
    the limits, an unchanged display with `palette = seq_len`, and numeric `limits`
    giving the same display as character `limits`.
  - *Verification* (covers both items): the 48-plot battery from the breaks item plus 19
    new cases (palettes, continuous `y`, integer, Date, binned, 0/1 codes with `factor()`,
    numeric data with `scale_x_discrete()` with and without `limits`, numeric `limits` on
    x and y, an `annotate()` layer, `coord_flip`), run against HEAD (76152e7) and the
    change. 52 cases were identical in layer data, errors, warnings, and rendered pixels
    (36 PNGs); the 15 that differ are all intended: 7 that previously drew silently wrong
    displays (reversed and uneven palettes on x, y, and UCB; continuous with reversed
    breaks or 1.5 values; numeric data with `scale_x_discrete(limits = c("2", "1"))`) and
    7 that gave a misleading error (continuous x, continuous y, integer, Date, binned,
    numeric data with `scale_x_discrete()`: "has 5 and 2" levels and similar; `NA` inside
    the limits) now give the new errors. One previously correct display now errors:
    numeric 1/2 with `scale_x_continuous(breaks = c(1, 2))`, as the continuous item
    intended; `factor(x)` is the fix the message gives. No new spelling flags.
    `R CMD check --as-cran` (remote incoming checks off, `env -u DISPLAY`): Status OK,
    including tests, examples, vignettes, and the PDF manual.
  - *Independent verification* (subagent, own plot sets, HEAD vs change, two rounds). The
    first round found that numeric `limits` were wrongly rejected (fixed by the character
    mapping above) and that numeric data on an explicit discrete scale were still drawn
    wrongly (now rejected; see the continuous item). The second round, on the revised code,
    covered 180 plots. 116 were identical in layer data, warnings, pixels, or error. The 64
    that differ are 0 regressions; 29 silently wrong at HEAD, now errors; 6 correct at HEAD
    by coincidence (numeric 1/2 with `breaks = 1:2`), now the deliberate categorical
    error; and 29 errors before with clearer errors now. A recount from the raw data found
    every plot that builds correct. A further 41 plots hunted for false positives:
    `annotate()`, `geom_vline()`/`geom_hline()`, numeric `geom_text()`/`geom_rect()` with
    ±Inf, jitter/nudge/count layers, 2–3 fourfold layers, free scales, `facet_grid`,
    `margins = TRUE`, and `coord_flip`. All that build match HEAD, with no false positives.
    The `length()` refinement, suggested and tested on all 221 plots by the subagent,
    also rejects the free-scale variant. The new tests fail against HEAD and against the
    first revision. `R CMD check --as-cran` with remote checks gave 1 NOTE, identical to
    HEAD's (new submission; the SAS URL in `vignettes/refs.bib`).
  - *Limitation*: the positions error always suggests `limits` rather than a `palette`,
    which doesn't fit the contrived cases where the cause is an `NA` first or in the
    middle of the limits or factor levels.
  File: `R/geom-fourfold.R` (`.fourfold_check_positions()`, `.fourfold_panel_table()`).

- [X] **Continuous `x`/`y` scales mislabel or mis-tabulate silently** (found 2026-09-29
  while fixing the breaks item above; fixed 2026-09-29 together with the item above) — a
  numeric `x` coded 1/2 on a continuous scale errored with the default breaks ("panel 1
  has 5 and 2" levels), but with `scale_x_continuous(breaks = c(2, 1))` it drew the
  counts for `x = 1` under the label "2". Values were placed with `as.integer()`, so
  `x = c(1, 1.5)` with `breaks = c(1, 2)` silently put every count in the first column.
  - *Fix*: `.fourfold_check_positions()` rejects any non-discrete `x`/`y` scale
    (continuous, integer, Date, binned) with "fourfold x in panel 1 must be categorical
    (a factor, character, or logical variable), not continuous; convert numeric codes
    with `factor()`". The same error covers numeric data on an explicit
    `scale_x_discrete()`: ggplot2 leaves such values unmapped, so the raw values became
    positions, and `scale_x_discrete(limits = c("2", "1"))` silently drew `x = 1`'s
    counts under "2" (found by the independent verification; also at HEAD). This is
    detected as a discrete scale with a continuous range (`scale$range_c$range`) but an
    empty discrete range (`scale$range$range`, tested with `length()` because with free
    scales an empty range can be `character(0)` rather than `NULL`). Both are required,
    because `annotate()` with a numeric `x` on a categorical axis also sets the continuous
    range. These are internal ggplot2 fields. If `range_c` were renamed the check would
    simply stop firing; if only `range` were renamed, plots with numeric annotations would
    start to error, which the `annotate()` test would catch.
  - *Limitation*: if another layer trains categorical values on the same axis (e.g. a
    `geom_blank()`, `geom_text()`, or second `geom_fourfold()` with factor `x`), the
    discrete range is not empty, so numeric fourfold data slip past the check and can be
    drawn under the wrong labels, as at HEAD. This is contrived; converting with
    `factor()` avoids it.
  - *Docs*: the Aesthetics section now says `x` and `y` must be categorical and suggests
    `factor()` for numeric codes such as 0/1.
  - *Tests*: numeric x with default, reversed, and binned breaks; values 1 and 1.5;
    continuous `y`; a Date; numeric data with `scale_x_discrete()` with and without
    `limits`; an `annotate()` layer with a numeric `x` leaving the display unchanged; and
    0/1 codes converted with `factor()` giving the right table.
  - *Verification*: see the item above.
  File: `R/geom-fourfold.R` (`.fourfold_check_positions()`).

- [ ] **Handle tables with an entirely empty row or column explicitly** — for
  `matrix(c(0, 0, 10, 20), nrow = 2)`, the default display gives identical lower and upper
  confidence-ring radii despite a wide calculated odds-ratio interval. Inference applies
  the 0.5 correction, but confidence tables are reconstructed using the original zero
  margins; standardizing those reconstructed tables loses the requested interval bounds.
  With `margin = 2`, the same table also produces two `NaN` sector radii through division
  by a zero column total. Choose and document a consistent treatment, or reject zero-margin
  tables with an informative error. Verify empty rows and columns separately from isolated
  zero cells, including default, single-margin, and maximum-based standardization.

  *Real-data example* (found 2026-09-28): `Titanic` without the crew, faceted by age and
  class, warns "NaNs produced" twice (from `sqrt(.fourfold_odds(tab)$or)` in
  `.fourfold_standardize()`). Every child in 1st and 2nd class survived, so the `No` row of
  those two panels is empty (1st: Male 0/5, Female 0/1; 2nd: 0/11, 0/13):
  ```r
  titanic_dat <- as.data.frame(Titanic[c("1st", "2nd", "3rd"), , , ])
  ggplot(titanic_dat, aes(x = Sex, y = Survived, weight = Freq)) +
    geom_fourfold() +
    facet_grid(Age ~ Class) +
    theme_fourfold()
  ```
  Counts and odds ratios are correct (they match `vcd::loddsratio()` run on each panel's
  2 × 2 table), but in both panels the lower ring is `NaN` in all four cells and is not
  drawn. (Run on the whole 2 × 2 × 2 × 3 table, `loddsratio()` adds 0.5 to every cell
  because some cells are zero, so it matches only the two panels that contain zeros. For
  the strata without zeros it differs, e.g. Adult × 1st 64.35 vs the geom's 72.46. The geom
  follows `vcd::fourfold()`, which adds 0.5 per stratum; see `issues/marginal-plots.md`,
  section 5.) In the table rebuilt for the
  lower bound (OR 0.0036), the cells that should be 0 come out as ±2.7e-15 from rounding
  in the quadratic solution; the negative one gives an odds ratio of −0.2, whose square
  root is `NaN`. The upper bound (OR 20.4) reproduces the observed table exactly, so the
  upper ring traces the sectors, which is the "identical radii" symptom above. With
  `margin = 1` the sector radii of the empty row are also `NaN` (division by a zero row
  total), mirroring the `margin = 2` case for an empty column.
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
  with no complete observations or no positive total. (`.fourfold_check_positions()` and
  `.fourfold_check_breaks()` already ignore the `NA` category; a trailing `NA` category
  passes both. Note that missing `x` rows currently reach the table as
  position 3 rather than `NA`, so the `is.na()` filter does not remove them.)
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

- [ ] **Proposal: coloured direction ticks, and a way to style them** (MF, 2026-09-27) —
  the diagonal ticks are currently thin black lines drawn with the frame's line width, and
  they are easy to miss, especially against the navy fill of a significant panel. MF
  suggested colouring them. A mock-up (recolouring the tick grobs of the UCB Dept A–C
  display) compared four versions:
  1. black (current);
  2. blue matching the fill of the ticked cells: fails in non-significant panels, where a
     pale `#A0A0FF` tick on white nearly disappears;
  3. **dark blue (`#000080`) in every panel — recommended**: visible on both pale and
     intense panels, and it reinforces the existing colour meaning, since blue already
     marks the diagonal the association favours;
  4. green (`#009E73`): the most distinct, but it adds a third hue to the two-colour scheme
     without adding information. The tick's position already gives the direction, and it
     is always on the blue diagonal, so "red vs blue" ticks would in practice always be
     blue.

  Also: coloured ticks need to be thicker than the outline (about 2.5 lwd in the mock-up) to
  be seen, and at the default length (`ticks = 0.15`) every version is small. Consider a
  thicker and possibly longer default.

  *Recommendation:* default tick colour = `palette[6]` (the strong blue) rather than a new
  seventh palette entry, so custom palettes carry it along. Keep black (the vcd look)
  available through an argument.

  *API for styling the ticks.* Options considered:
  - **Flat dotted arguments, as ggplot2 4.0 does for sub-parts of a geom** (recommended).
    `geom_boxplot()` has `whisker.colour`/`whisker.color`, `whisker.linetype`,
    `whisker.linewidth`, and likewise `staple.*`, `median.*`, `box.*`; `geom_violin()`
    has `quantile.*`; `geom_crossbar()` has `middle.*`/`box.*`. Here:
    `ticks = 0.15` (length; `0` = none, unchanged for backward compatibility) plus
    `tick.colour` (with `tick.color` alias; `NULL` = `palette[6]`), `tick.linewidth` and
    `tick.linetype`. This is familiar to ggplot2 users, each argument can be documented and
    validated separately, and the same pattern extends naturally to other parts later,
    e.g. `ring.colour`/`ring.linewidth`/`ring.linetype` for the confidence rings, or
    `frame.*`.
  - A list argument, `ticks = list(length = 0.15, colour = , linewidth = , ...)` or
    `tick.args = list(...)`: compact and vcd/base-graphics-like (cf. `gp = gpar()`), but
    not how ggplot2 geoms are styled. It needs merging with defaults when only some
    elements are given, and makes it harder to document and validate each setting. It
    would also change the meaning of the existing numeric `ticks`.
  - A helper constructor, e.g. `ticks = fourfold_ticks(length = 0.15, colour = ...)`, like
    `arrow()` in `geom_segment()`: tidy and self-documenting, but one more exported
    function, and less conventional than the dotted form for simple styling.

  Related: the "Square tick direction" item above. Decision for GK.
  Files: `R/geom-fourfold.R` (`draw_panel()` tick segments, `geom_fourfold()` arguments and
  validation, docs), README/vignette figures.

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

## Multi-way tables: pooling and homogeneity

**Deferred to a later release (MF, 2026-09-29).** Marginal plots need more thought and are
not planned for the first CRAN release. This covers the items in this section: marginal
displays, `margin_background()` and the reference ring. The design discussion is in
`issues/marginal-plots.md` (GK), which supersedes the collapsed-table premise of the
entries below. Exploration data: `dev/marginal-fourfold.R` (Detergent) and
`dev/synthetic-2x2x2x4.{R,md}`.

Both ideas come from "Marginal plots" and "departures from homogeneity" in
`dev/fourfold-ideas.md`. A prototype is in `dev/marginal-fourfold.R`, using
`vcdExtra::Detergent` permuted to Preference × M_User × Temperature (R = 2) ×
Water_softness (C = 3). vcdExtra's `woolf_test(decompose = TRUE)` splits the homogeneity
test into Rows, Cols and Residual components for this table. Source the script in RStudio,
or run `Rscript dev/marginal-fourfold.R [output-dir]` to write PNGs.

- [ ] **Marginal fourfold displays for 2 × 2 × R × C tables** — show the marginal 2 × 2
  tables pooled over R, over C, and over both, next to the strata, to show the effect of
  pooling.
  - *Works already*: `facet_grid(R ~ C, margins = TRUE)` adds an "(all)" column (pooled
    over C, one table per level of R), an "(all)" row (pooled over R), and the corner
    (pooled over both). No package changes are needed to draw it.
  - *Detergent*: the pooled log odds ratios match the Woolf decomposition. Pooled over
    water softness: High −0.85 vs Low −0.41 (Rows component, p = .096). Pooled over
    temperature: Soft −0.17, Medium −0.68, Hard −0.87 (Cols component, p = .069).
    Collapsing barely changes the odds ratios: each marginal log odds ratio is within 0.02
    of the Mantel–Haenszel estimate for the strata it pools. So here pooling hides
    heterogeneity rather than introducing collapsibility bias.
  - *Problems to fix if supported*:
    - With `margins = TRUE`, the "(all)" panels are part of the layer, so the Holm
      adjustment runs over all 12 panels: 6 strata plus 6 pooled tables that are not
      independent of them.
    - `std = "all.max"` would scale every panel by the pooled corner table.
    - Consider identifying the margin panels (ggplot2 labels them `"(all)"`) and excluding
      them from the p-value adjustment and the `all.max` maximum, or documenting the
      behaviour.
  - Also possible: a vignette section, or an example using `woolf_test(decompose = TRUE)`
    alongside the plot.
  Files: `R/geom-fourfold.R` (`.fourfold_compute_layer()`), vignette.

- [ ] **Shade the margin panels: `margin_background()`** (MF, 2026-09-28) — give the "(all)"
  row and column of `facet_grid(margins = TRUE)` a light background (default very light
  tan, `#F5EEDC`) so the pooled tables stand apart from the strata. See
  `dev/marginal-fourfold.png`.
  - **Q: include in the initial CRAN release?** MF: "quite nice to include, but don't want
    to hold this up." It is small, self-contained, and does not touch `geom_fourfold()`,
    so it could go in now or wait. Decision for GK.
    **Answered (MF, 2026-09-29): defer**, together with the marginal plots it serves. This
    agrees with GK's recommendation in `issues/marginal-plots.md` (section 8) to ship the
    shading with the margin changes, not before.
  - *Why a stat*:
    - A theme can't do it, because `panel.background` applies to every panel.
    - An ordinary `geom_rect()` layer can't either. `margins = TRUE` copies every layer's
      rows into the "(all)" panels, and layer data that already contain "(all)" make
      ggplot2's `reshape_add_margins()` fail with a duplicated factor level.
  - *Prototype* (in `dev/marginal-fourfold.R`): `StatMarginPanels$compute_layer()` looks
    up each panel's facet values in `layout$layout` and returns one full-panel rectangle
    (`-Inf`/`Inf`) for each panel where any facet variable is `"(all)"`.
    `margin_background(fill = "#F5EEDC")` wraps it as a `layer(stat = StatMarginPanels,
    geom = "rect", inherit.aes = FALSE, ...)` to add *before* `geom_fourfold()`. Checked:
    exactly the 6 margin panels are shaded, including inside the frame, and the fourfold
    statistics are unchanged.
  - *If exported*:
    - Name: e.g. `margin_background()` or `fourfold_margins()`.
    - Arguments: `fill`, and maybe `alpha`.
    - Documentation: say it must come before `geom_fourfold()`, and has no effect without
      `margins = TRUE`. It relies on ggplot2's `"(all)"` label for margin panels, which
      is not formally documented, so a test should catch any change.
    - Tests: which panels are shaded for `margins = TRUE` and for `margins = "<var>"`.
    - Docs example: `vcdExtra::Detergent`, which would need vcdExtra in `Suggests`.
  Files: new `R/margin-background.R` (or in `R/geom-fourfold.R`), tests, vignette/README
  example.

- [ ] **Reference ring for a common odds ratio (departures from homogeneity)** — *deferred to
  a later release (MF, 2026-09-28).* Draw a
  reference ring in each panel at a common odds ratio θ₀. The default would be the
  Mantel–Haenszel estimate over the strata; a user-supplied number should also be
  accepted.
  - In stratum panels, sectors inside or outside the ring show departures from
    homogeneity.
  - In "(all)" panels, a departure shows that collapsing changes the odds ratio.
  - *Prototype*: `add_reference_ring()` in `dev/marginal-fourfold.R` adds dashed arcs to
    the drawn plot by editing its grobs, without changing the geom. A dashed grey ring was
    lost among the black confidence rings; dashed green (`#009E73`, lwd 2) is clearly
    visible.
  - *Detergent, θ_MH = 0.57*: Soft/Low (θ = 0.98) and Soft/High are clearly weaker than the
    ring, and Medium/High and Hard/Low stronger. This is the pattern behind the Cols
    component.
  - *Geometry*: with both margins equated (the default), the reference table depends only
    on θ₀, with radii √p (diagonal) and √(1 − p) (off-diagonal), p = √θ₀ / (1 + √θ₀). For
    `margin = 1` or `2`, or unstandardized displays, the ring must be built from each
    panel's own margins with `.fourfold_table_with_or_and_margins(θ₀, tab)`, as the
    confidence rings are.
  - *Open questions*:
    - One common θ₀ for every panel (the homogeneity view, as prototyped), or, in each
      "(all)" panel, the Mantel–Haenszel estimate over the strata it pools (the pooling
      view)?
    - The Mantel–Haenszel estimate must be computed from the strata only, excluding any
      "(all)" panels.
    - Styling should follow the tick-styling proposal, e.g. `reference.colour`,
      `reference.linetype`, `reference.linewidth`.
  - *Possible API*: `geom_fourfold(reference = NULL)`, where `NULL` means no ring,
    `"mh"` means the Mantel–Haenszel common odds ratio across the layer's strata, and a
    positive number means that odds ratio.
  Decision for GK/MF.
  Files: `R/geom-fourfold.R` (stat: compute θ₀ and ring radii per panel; geom: draw),
  `dev/marginal-fourfold.R`.

## Verification recorded (2026-09-25)

The package built successfully, including its vignette. `R CMD check --no-manual
--no-vignettes` on that tarball finished with status OK; vignette rebuilding during check
and the PDF manual were not checked. Repository-index access was unavailable during the
dependency check, so this used the locally installed dependencies.

Independent calculations matched the Berkeley examples' odds ratios, standard errors,
Wald confidence intervals, raw p-values, Holm adjustment, and individual/global maximum
standardizations. These checks do not resolve the edge cases above, and the existing
development verification script remains broken as noted above.
