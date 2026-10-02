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

- [X] **Handle tables with an entirely empty row or column explicitly** (fixed
  2026-09-30; record below the original description) — for
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
  total), mirroring the `margin = 2` case for an empty column. (Found while fixing: ggplot2
  then drops the rows with `NaN` radii, so those displays also drew "NA" labels and put
  counts in the wrong corners, e.g. 5 under Male/No for 1st-class children.)
  - *Decision* (GK, 2026-09-30, following MF's suggestion in `issues/marginal-plots.md`,
    section 14, point 2): draw such tables rather than reject them.
    - Rings use the row and column totals of the 0.5-corrected table **only** when a row
      or column total is exactly zero. Tables with isolated zero cells keep the observed
      totals, as before and as in `vcd::fourfold()`. The alternative, switching whenever
      any cell is zero, would have changed displays that already worked (rings move by up
      to 0.08 with `ind.max`, 0.4 with `all.max` on small tables) and built their rings
      around n + 2 while the sectors show n. An independent statistician subagent reached
      the same recommendation.
    - Sectors show the observed table wherever the standardization can use it. With
      `margin = 1`, only an empty row is drawn from the corrected table (0.5/0.5); the
      other row keeps its observed proportions. Likewise an empty column with
      `margin = 2`. `ind.max`/`all.max` keep the observed counts, so an empty row has no
      sectors while its rings come from the corrected totals.
    - No console message; the behaviour is documented instead.
  - *Fix*:
    - `.fourfold_compute_layer()` builds the rings of a panel with a zero row or column
      total from the corrected table, rescaled to the observed total. Rescaling keeps the
      odds ratio and every proportion, so it matters only for `all.max`, where the
      unscaled n + 2 table drew rings up to 686 times the frame for small weights.
    - With the default `margin = c(1, 2)`, which depends only on the odds ratio, each
      ring is now drawn directly at its confidence limit, `u = sqrt(L) / (1 + sqrt(L))`,
      instead of via a ring table. For finite positive limits this is the same value.
      At a limit of exactly 0 or `Inf` (a cell below about 1e-5 without an exact zero, or
      `conf_level` within 1e-16 of 1) the ring table has exact zero cells, which the 0.5
      correction then moved well inside the interval. HEAD and vcd already did this at a
      limit of `Inf`, through their explicit `or == Inf` branch: for `c(1e-7, 5, 3, 1)`
      they draw the upper ring at 0.883/0.469 rather than (1, 0, 0, 1). At a limit of 0
      only rounding residue spared them, and the precise solver below no longer leaves
      any.
    - `.fourfold_standardize()` fills a zero-total row (`margin = 1`) or column
      (`margin = 2`) from the corrected table's proportions.
    - An odds ratio that over- or underflows (weights such as 1e200 and 1e-200) is now
      the error "the odds ratio in fourfold panel 1 cannot be computed: the weights are
      too large or too small". HEAD gave "missing value where TRUE/FALSE needed" or
      `NaN` radii; with `conf_level = 0` it drew an underflowed odds ratio as exactly 0.
  - *Precision*: near-zero but positive weights (1e-10, or `0.1 + 0.2 - 0.3`) still gave
    `NaN` rings, or radii of 2 with `margin = 1`, from cancellation in the quadratic root;
    the exact-zero test above does not catch them. `.fourfold_table_with_or_and_margins()`
    now solves for each of the four cells directly (new `.fourfold_cell_with_or()`),
    moving it to the solved position by swapping rows and/or columns, so small cells are
    never differences of large totals. Each branch writes the discriminant as a sum of
    non-negative terms, the root is taken in its cancellation-free form, and odds ratios
    above 1 are divided out so nothing overflows; odds ratios of 0, `Inf`, and ±1e300
    give the boundary tables. It solves for the table divided by its total and scales
    back, so totals of 1e200 or 1e-200 no longer over- or underflow the products of
    totals (HEAD gave `NaN` radii there; the first revision an R error). Against a 400-bit Rmpfr solution on 3,000 random tables
    (cells 1e-10 to 1e13, log odds ratios with SD 8): largest relative cell error
    1.5e-11 (the limit set by double-precision totals), against 3.5e6 for HEAD and 1.0
    for a first revision that only swapped columns. HEAD was visibly wrong in some
    cases: `c(.001, .003, .002, .0005)` with `conf_level = 0.5` drew its lower ring
    45,000 times too large (relative); the change matches the analytic value exactly.
  - *Docs*: new "Zero counts" section in `geom_fourfold()`: the correction; what rings
    show, drawn at the limit for the default display, and the corrected-totals fallback
    (rescaled; only for `all.max` does that matter); that such a panel contains no
    information about the odds ratio, that its odds ratio and p-value exist only
    because of the correction (yet the p-value can be significant), and so its colour,
    shading, and tick say nothing about an association; sectors per
    `std`/`margin`, including an empty column with `margin = 1` crossing an empty row;
    near-zero weights; an all-zero panel was an error (see the next item). `@details`
    points to it.
    `man/geom_fourfold.Rd` regenerated.
  - *Tests* (appended to `tests/testthat/test-geom-fourfold.R`, 269 expectations in all):
    finite radii and no warnings for an empty row, an empty column, and both, including
    totals of 1e200 and 1e-200, under every `std`/`margin`; rings of an empty row/column checked against tables found by
    `uniroot()` on the rescaled corrected totals; the `margin = 1`/`2` sector fallback;
    observed sectors elsewhere; rings of an isolated-zero and a zero-free table checked
    against the observed totals; near-zero weights; the faceted Titanic display without
    warnings or `NA` labels; ring-table precision at extreme odds ratios and table sizes;
    `all.max` rings within the frame; default rings at limits of 0 and `Inf`; the
    overflow error. Against HEAD, 101 expectations in 9 of these tests fail (two tests
    error); the two regression guards (isolated-zero/zero-free rings, observed
    sectors) pass.
  - *Verification*: a battery of 210 plots (18 synthetic tables — none, isolated zeros,
    diagonal zeros, empty rows and columns, both, large and skewed counts, fractional
    and near-zero weights — plus faceted Titanic, UCB, and a mixed layer, each under 10
    settings: all `std`/`margin`, `conf_level` 0.99 and 0, `extended = FALSE`, square
    shape) run against HEAD (3ae2101) and the final change. 84 plots are identical in
    layer data and pixels. In this battery, the 126 that differ all differ only in panels
    with an empty or near-zero row or column (rings, and sectors with `margin = 1`/`2`).
    More generally, rings also change wherever HEAD's ring tables had zero cells or lost
    precision, e.g. tiny weights whose interval reaches 0 or `Inf` (see *Fix* and
    *Precision*). Also differing: the layer-wide `counts_reach` in 15 square-shape
    plots, where HEAD's `NaN` or `Inf` reach had kept counts inside the frame under the
    squares, or the new full-range rings of a [0, `Inf`] interval reach the corners. Counts, odds ratios, standard errors,
    intervals, p-values, and colours are identical in all 210. HEAD had `NaN` radii in 92
    plots and warnings in 92; the change has none. Side-by-side images checked by eye.
    `R CMD check --as-cran` (remote incoming checks off, `env -u DISPLAY`): Status OK;
    PDF manual builds; no new spelling flags. `dev/verify-geom-fourfold.R`, once
    repaired (see "Development scripts" below), passes against the change.
  - *Independent verification* (two statistician subagents, own plot sets and
    references, on the first revision; one of them also reviewed the revised solver and
    `all.max` rescaling). Both confirmed the design works and that inference, palette,
    labels, and ordinary panels are unchanged (662 and 2,640 cases; pixel-identical for
    ordinary data). On the revised solver, radii matched `vcd::fourfold()`'s drawn
    polygons to 3e-14; on the first revision one reviewer had found a 6.3e-5 deviation
    for `c(1e9, 1, 1, 1e9)`. Their findings, all addressed above: the first revision's solver lost precision for large
    odds ratios (its discriminant cancelled) and near double roots; `all.max` rings of
    empty-row panels overshot the frame; rings at limits of exactly 0 or `Inf` were
    re-corrected; an empty column with `margin = 1` does get a sector where it crosses
    an empty row; the near-zero paragraph and the colour sentence (which omitted the
    significance shading) were inaccurate. Not adopted: setting the p-value and shading
    of empty-row panels to `NA` (documented instead). Second round (one reviewer, on
    the revised code): the default rings at the limit, the overflow error, the docs, and
    the tests confirmed (2,640-case grid unchanged from the reviewed version except the
    [0, `Inf`] rings; every default ring equals `sqrt(u(limit))` exactly; 101 HEAD
    failures confirmed). Its findings, addressed above: the ring-base rescale and the
    solver overflowed for totals above about 1e154; this record misstated what HEAD and
    vcd do at a limit of `Inf`; the near-zero paragraph should say that the rings lie on
    the sectors, as if the estimate were precise. Third round (the other reviewer, on
    the final code, against a 2,500-bit Rmpfr reference on 4,000 random tables): no
    `NaN`, negative, or false-zero cells and a largest relative cell error of 1.1e-12,
    against 579 `NaN`/negative results, 322 false zeros, and errors up to 1.9e-2 for
    HEAD; all 340 non-default rings in its 34-table set match the reference built from
    the documented totals to 3.6e-12; every default ring within 1e-12 of its limit;
    radii match `vcd::fourfold()` to 6e-12 on 120 non-degenerate combinations (the
    largest gap, `c(1, 1000, 1000, 1)`, is vcd's own imprecision); all docs claims true.
    On its 662 plots, 345 are identical up to floating-point noise, 294 changed are
    tables with an empty or near-zero row or column, and 23 are tiny-weight tables in
    the default display, whose rings HEAD collapsed to about 0.707 and which are now
    drawn at their confidence limits.
  - *Limitations*: near-zero weights count as observations, so where the
    standardization keeps such a row near zero its ring quadrants stay near zero too,
    unlike an exact zero (documented, with `round()` suggested). An empty-row panel's
    p-value comes from the correction alone and can be "significant" (e.g.
    `c(0, 1000, 0, 1)`, adjusted p = 0.0026), as in vcd; documented (GK decided on
    2026-09-30 to keep this behaviour rather than drop such a p-value). A panel whose
    four counts are all zero was still an error ("must have a positive total"); it is
    now drawn blank (next item).
  File: `R/geom-fourfold.R` (`.fourfold_compute_layer()`,
  `.fourfold_table_with_or_and_margins()`, `.fourfold_standardize()`).

- [X] **Draw a panel whose counts are all zero as a blank panel** (found 2026-09-30
  while fixing the item above; fixed 2026-09-30) — a panel whose four counts are all
  zero stopped the whole plot with "fourfold panel N must have a positive total".
  `as.data.frame()` of a table keeps zero-count rows, so this was easy to hit: the
  full `Titanic` faceted by `Age ~ Class` failed because the crew had no children.
  `vcd::fourfold()` draws such a stratum from the 0.5-corrected table, as four equal
  quarter-circles with an odds ratio of 1, which looks like a real table with no
  association although there is no data.
  - *Decision* (GK, 2026-09-30, after Claude agreed): draw it blank, with the frame,
    axes, category labels, and the four zero counts, but no sectors, rings, or
    direction tick. Its odds ratio, standard error, interval, and p-values are `NA`,
    and it is left out of the p-value adjustment, so it changes nothing in the other
    panels. No console message (the zeros are visible); documented. The same applies
    when every panel in the layer is empty. With `margin = 1`, an empty row in an
    otherwise non-empty panel is still drawn as equal halves (item above): there the
    rest of the panel has data.
  - *Fix*: `.fourfold_panel_table()` no longer rejects a zero total.
    `.fourfold_compute_layer()` marks empty panels: radii 0, statistics `NA`, and a
    valid but unused palette index, so that ggplot2 does not drop their rows as missing
    (the cause of the "NA" labels in the item above). `p.adjust()` ignores missing
    p-values for every method in `stats::p.adjust.methods` (checked), so the other
    panels' adjusted p-values are unchanged. `draw_panel()` skips the sectors and the
    direction tick of a panel with all-zero counts, and `.fourfold_counts_reach()`
    ignores ticks of a panel without an odds ratio.
  - *Docs*: a paragraph in the "Zero counts" section of `geom_fourfold()` (and the
    difference from vcd, which holds for the default `margin = c(1, 2)`; with the
    other settings vcd gets `NaN` and draws nothing), and that a facet level with no
    rows at all is an ordinary empty ggplot2 panel. `@details` now says p-values are
    adjusted across the panels that have one, and that vcd counts an empty stratum
    with p = 1, so adjusted p-values in such a layer differ from vcd's (full `Titanic`
    by class and age: one panel's Holm value 0.303 here, 0.404 in vcd).
    `man/geom_fourfold.Rd` regenerated.
  - *Tests* (appended; 351 expectations in all): an all-zero panel under every
    `std`/`margin` and the square shape has zero radii, `NA` statistics, a non-missing
    palette index, no warnings, and draws only the frame, axes, labels, and counts
    (checked by grob name); adding an empty department to UCB leaves every column of
    the other six panels identical, including the Holm-adjusted p-values and the
    layer-wide count placement; faceted `Titanic` with the crew draws every panel. All
    three fail (error) against HEAD (186726b).
  - *Dev script*: `dev/verify-geom-fourfold.R` checked for the old error; it now
    checks the blank panel and that the other panels' adjusted p-values are unchanged.
  - *Verification*: the 210-plot battery from the item above plus 40 plots with an
    empty panel (full `Titanic` with the crew, UCB plus an empty department, a single
    empty table, and a mixed layer, each under the 10 settings), run against HEAD
    (186726b) and the change. The 210 without an empty panel are identical in layer
    data, pixels, and errors. The 40 with one all errored at HEAD and now draw without
    warnings; in the UCB case the other six panels are bit-identical to UCB alone in all
    10 settings. Images checked by eye. `R CMD check --as-cran` on the built package:
    Status OK, including the PDF and HTML manuals.
  - *Independent verification* (the same two statistician subagents). Both found the
    change correct with no regressions. One ran 784 plots (683 layers without an empty
    panel identical to 186726b, 0 differing pixels; 101 with one, all drawing without
    warnings), the other 3,684 cases and 1,104 PNGs without an empty panel (identical)
    and 1,728 comparisons adding an empty panel under every `std`/`margin`, both
    shapes, all 8 `p.adjust` methods, and the panel placed first or last (other panels
    identical in every value; pixel differences only inside the empty panel). Blank
    panels checked under 216 settings; edge cases drawn blank include `facet_grid(margins
    = TRUE)`, free scales, zero rows mixed with `NA` weights, `-0` weights, `ticks = 0`,
    and every panel empty. Planted bugs (counting the empty panel's p as 1, drawing its
    sectors, dropping the tick guards) each failed a test. Their findings, addressed:
    the `@details` claim that p-values match vcd, the default-`margin` qualifier on the
    vcd comparison, the stale test count, a stricter (identical) comparison of the
    other panels in the test, and a sentence on facet levels with no rows. Both also
    noted that a panel with no complete observations is still an error; this is left
    for the `na.rm` item below.
  File: `R/geom-fourfold.R` (`.fourfold_panel_table()`, `.fourfold_compute_layer()`,
  `.fourfold_counts_reach()`, `GeomFourfold$draw_panel()`).

- [X] **Align mapped drawing aesthetics with the documented API** (fixed 2026-10-01) —
  the help advertises
  `colour`, `linewidth`, `alpha`, `size`, and `family` as fixed or mapped properties, but
  `.fourfold_compute_layer()` constructs fresh output without preserving those mappings.
  Reproduced with `aes(colour = x)`: all outlines use the default black. `draw_panel()` also
  reads drawing properties from only the first output row. Either implement and define the
  supported mapping behavior, including aggregation within a panel, or document these as
  fixed arguments and explicitly reject unsupported mappings rather than silently ignoring
  them. Regenerate the help after updating the roxygen text.
  - *What HEAD actually did* (corrected after review): ordinary mappings, evaluated
    before the stat, were silently ignored because the stat builds fresh output without
    those columns. Mappings to computed variables, applied after the stat, did work:
    `aes(colour = after_stat(significant))` drew each panel's outlines by significance,
    `after_stat(PANEL)` gave each stratum its own outline colour, `linewidth =
    after_stat(odds_ratio)` and `after_scale()`/`stage()` modifications applied too, both
    in the layer and inherited from `ggplot()`. A mapped value that varies within a
    panel, such as `after_stat(count)`, was silently drawn with the first cell's value,
    because `draw_panel()` reads the drawing properties from the first row.
  - *Decision* (GK, 2026-10-01): fixed arguments only, including blocking the
    computed-variable mappings that worked at HEAD (option A; deliberate, and tentative
    — see the next item).
    - Ordinary mappings: a panel draws one table, so a mapping that varies within a
      panel (e.g. `aes(colour = Gender)`) has no single value to draw; fills are the
      semantic `palette`; text size and font come from the plot theme.
    - Computed-variable mappings (`after_stat()`, `after_scale()`, `stage()`): supporting
      them would make the computed column names (`significant`, `odds_ratio`, `PANEL`,
      ...) public API on CRAN. MF asked on 2026-09-29 (`issues/marginal-plots.md`,
      section 14, reply 6) to hold off documenting the computed columns as public until
      the margin feature settles. Blocking now costs nobody (the package is not on CRAN
      yet), and unblocking later is non-breaking; the reverse would break user code. The
      first version of this record wrongly said a per-panel mapping would need the
      column carried through the stat; the computed columns already are.
    - A mapping in the layer itself (`geom_fourfold(aes(colour = ...))`, or of
      `linewidth`, `alpha`, `size`, or `family`, including `color`, `lwd`, and the other
      names `aes()` standardizes, and computed-variable mappings) is an error when the
      layer is created. `aes(colour = NULL)`, which removes an inherited mapping, is
      allowed.
    - A mapping inherited from `ggplot()` is ignored, since a plot-level mapping is
      often meant for another layer such as `geom_text()`; an error there would break
      legitimate plots. This matches how ggplot2 treats an inherited aesthetic a layer
      cannot use. (A warning was considered and rejected: it would fire on every
      multi-layer plot that maps colour globally.) Inherited computed-variable mappings,
      which HEAD applied, are now ignored too, so the rule is the same for both kinds.
  - *Fix*: new `.fourfold_check_mapping()`, called first in `geom_fourfold()`, stops
    with e.g. "`colour` and `size` cannot be mapped in geom_fourfold(), which draws one
    table per panel; set colour, linewidth, and alpha as fixed arguments, e.g.
    `geom_fourfold(colour = "grey30")`, and text size and font with
    `theme_fourfold()`". It skips anything that is not an `aes()` mapping
    (`ggplot2::is_mapping()`), so a data frame passed in the mapping position still gets
    ggplot2's own error, and skips `NULL` entries. The five properties are listed once,
    in `.fourfold_fixed_aes`. The stat already drops ordinary mappings; for inherited
    computed ones, `GeomFourfold$setup_data()` drops the `after_stat()` columns and a
    new `GeomFourfold$use_defaults()` drops the `after_scale()`/`stage()` modifiers
    before calling ggplot2's method. Reading the drawing properties from the first row
    in `draw_panel()` is correct now that they are constant.
  - *Docs*: the Aesthetics section lists only `x`, `y`, and `weight` as aesthetics and
    explains the fixed drawing properties, that text size and font are inherited from
    the plot theme, `palette` for fills, the error for a layer mapping (including
    computed variables), and that an inherited one is ignored. `man/geom_fourfold.Rd`
    regenerated.
  - *Tests* (appended; 388 expectations in all): a layer mapping of each property
    (with `color` and `lwd`) is an error, as are `after_stat()`, `after_scale()`, and
    `stage()` mappings; two or three are listed with "and"; `x`/`y`/`weight` mappings
    and `aes(colour = NULL)` are accepted; a data frame gets ggplot2's error;
    plot-level ordinary and computed mappings give layer data identical to no mapping,
    without warnings, while ordinary ones still reach a `geom_text()` layer; fixed
    values reach the layer data and the drawn grobs (colour with alpha, line width in
    points).
  - *Verification*: the 250-plot battery (no mappings) is identical to HEAD (944d040)
    in layer data, warnings, errors, and pixels. Mapping cases: plot-level ordinary
    mappings (one, several, with fixed overrides) and fixed values are identical to HEAD
    in data and pixels, and a plot-level mapping gives the same result as
    `inherit.aes = FALSE`; layer mappings of colour and size, which HEAD silently
    ignored, now error; plot-level `after_stat(significant)`, `after_stat(PANEL)`,
    `after_scale(alpha)`, and `stage(..., after_scale = "red")`, which HEAD applied, now
    give the default black outlines; fixed values and theme-derived text sizes
    (`theme_bw(base_size = 20)`: 7.03) are unchanged. No README, vignette, or example
    maps these properties. Both dev scripts pass; `R CMD check --as-cran` on the built
    package: Status OK, including Rd cross-references and the PDF and HTML manuals.
  - *Independent verification* (the two statistician subagents, on the first version
    of this change): both confirmed ordinary layer mappings error, inherited ones change
    nothing, fixed values work, and nothing else changes (3,780 grid entries and 1,140
    PNGs; 801 plots). Both found that the check also blocked computed-variable mappings
    that worked at HEAD and that the record misdescribed HEAD; this led to the decision
    above. Their other findings, addressed: `aes(colour = NULL)` was rejected; a data
    frame in the mapping position got a misleading message; inherited computed mappings
    were still applied, contrary to the docs; "text size and family come from
    `theme_fourfold()`" was too narrow; the message's list grammar; a long roxygen line.
    Second round (both, on the revised change): correct, with no regressions. One
    reviewer's 3,780 grid entries and 1,140 PNGs, and the other's 822 plots (five
    themes, fixed values, empty panels), are identical to 944d040 except the intended
    plot-level `after_stat()`/`after_scale()`/`stage()` cases (11 plots), whose layer
    data are now `identical()` to the unmapped plot while `geom_text()` still gets the
    mappings. The `use_defaults()` override matches ggplot2 4.0.3's signature; fixed
    values (including `I("red")`), theme defaults, `from_theme`, `get_geom_defaults()`,
    and `update_geom_defaults()` behave as at HEAD; `setup_data()` drops nothing the
    drawing needs. Finding addressed: the docs' "inherited mappings are ignored" needed
    the `after_stat()` exception below. Not adopted (optional): dropping an inherited
    `fill = after_stat(...)` column too (unused and harmless, as at HEAD).
  - *Limitations*: an inherited `after_stat()` mapping to a variable the fourfold stat
    does not compute, e.g. `ggplot(..., aes(size = after_stat(n))) + geom_fourfold() +
    geom_count()`, still stops the plot ("object 'n' not found"), as at HEAD: ggplot2
    evaluates it before the geom can drop it. Documented, with `inherit.aes = FALSE` or
    moving the mapping as the remedy. Calling `ggplot2::layer()` directly with
    `GeomFourfold` skips the layer-mapping check (advanced use; such mappings are then
    ignored).
  Files: `R/geom-fourfold.R` (`geom_fourfold()`, `.fourfold_check_mapping()`,
  `GeomFourfold$setup_data()`, `GeomFourfold$use_defaults()`), `man/geom_fourfold.Rd`.

- [ ] **Tentative: allow drawing properties mapped to per-panel computed variables**
  (potential feature, deferred 2026-10-01; decide with MF once the computed columns are
  documented) — the item above blocks mappings such as
  `geom_fourfold(aes(colour = after_stat(significant)))`, which worked before it. They
  would let users outline significant panels in another colour, give each stratum its
  own outline colour (`after_stat(PANEL)`), or scale line width by the odds ratio.
  - *Why deferred*: the mapped names (`significant`, `odds_ratio`, `PANEL`, ...) would
    become public API on CRAN. MF asked to hold off documenting the computed columns
    until the margin feature settles (`issues/marginal-plots.md`, section 14, reply 6),
    and the margin feature may add or rename some (e.g. `is_margin`).
  - *What it would take*: let `after_stat()`, `after_scale()`, and `stage()` mappings
    through `.fourfold_check_mapping()` (ordinary mappings stay an error), stop dropping
    them in `GeomFourfold$setup_data()` and `use_defaults()`, and add an error when a
    mapped value differs between the cells of a panel (e.g. `after_stat(count)`), since
    a panel is drawn with one value. Document the computed variables as public, with
    examples, and decide whether legends should show (`show.legend` is `FALSE`). Small
    code change, plus tests; non-breaking, since it only turns errors into working
    plots.
  Files: `R/geom-fourfold.R`, `man/geom_fourfold.Rd`.

- [X] **Remove missing categories consistently with `na.rm`** (fixed 2026-10-01) —
  adding a row with an `NA` factor value mapped to `x` caused an "exactly two x levels"
  error even when `na.rm = TRUE`. The discrete scale keeps a missing-value category, so
  missing `x`/`y` rows reached the table as position 3 rather than `NA`, the `is.na()`
  filter did not remove them, and validation counted three labels.
  `.fourfold_check_positions()` and `.fourfold_check_breaks()` already ignored the `NA`
  category.
  - *Found while fixing*:
    - *A missing value could be drawn as a category* (found by reviewer A). With
      `scales = "free_x"` and all of one panel's Female rows `NA`, that panel's scale
      was ("Male", `NA`), so the missing value landed at position 2. It passed every
      check and was drawn as a second category labelled "NA", with an odds ratio
      (1.13) and no error, even with `na.rm = TRUE`.
    - *A missing weight counted as zero* (found by both reviewers). Removing a row with
      an `NA` weight left its cell at 0, which in aggregated data (one row per cell) is
      an invented zero count, not complete-case deletion. With UCB Dept A's
      Male–Admitted weight `NA`, the odds ratio went from 0.349 to 0.00035 and the Holm
      p-value from 3.7e-4 to 1.8e-7, silently with `na.rm = TRUE`.
  - *Decisions* (GK, 2026-10-01, after the two reviewers below were asked for
    independent recommendations):
    - `na.rm` follows ggplot2: incomplete rows are always removed; `na.rm = FALSE` warns
      and `na.rm = TRUE` suppresses those warnings (ggplot2 may still warn about
      empty free-scale panel guides; see the limitation below).
    - A row with a missing `x` or `y` is removed. A row with a missing `weight` and
      known `x` and `y` makes its cell's count, and so the panel's table, unknown: the
      panel is left empty rather than drawn with a zero. (Options considered: count it
      as zero and document that; an error, as in vcd, which stops on any `NA` count.)
    - A panel with no known table, whether all its rows were removed or it has a
      missing weight, is left as an ordinary empty ggplot2 panel, with no frame,
      counts, or label. It no longer stops the plot. Options considered: keep the error
      ("fourfold panel 7 contains no complete observations"); a centred "NA" or "no
      complete data" label (GK's first leaning); "NA" in the four count positions. Both
      reviewers recommended the empty panel: it cannot be read as zero counts or as no
      association; it matches ggplot2 when `na.rm` empties a facet and the existing
      look of a facet level with no rows; a label would mark only fully missing panels,
      making partly missing ones look complete by contrast; and users can add a label
      with `annotate()` but could not remove a built-in one. Four "NA" counts looked
      almost like the all-zero panel.
  - *Fix* (`.fourfold_panel_table()`, `.fourfold_compute_layer()`):
    - The scale checks now run first. Missing `x`/`y` are found by the new
      `.fourfold_missing_category()`: `NA`, or the position the panel's scale maps `NA`
      to (`scale$map(NA)`), so it works with fixed and free scales and with
      `na.translate = FALSE`.
    - All non-missing weights are validated (finite, non-negative), including rows
      with missing x/y, before a missing weight empties the panel.
    - `.fourfold_missing_category()` rejects palettes that map NA onto a real
      category position, which would otherwise silently corrupt the table; an
      NA-only free scale remains allowed. The combined x/y check in
      `.fourfold_panel_table()` uses this helper for each axis.
    - Labels drop the missing-value break: `get_labels()[!is.na(get_breaks())]`.
      `get_labels(breaks)` was not used because an unnamed `labels` vector is not
      subset by it.
    - A panel without a known table returns `NULL`; `.fourfold_compute_layer()` drops
      those before `all.max`, inference, and `p.adjust()`, and returns an empty data
      frame when no panel is left. The panel has no rows in the layer data, so
      `draw_panel()` is never called for it and needs no change.
    - Warnings (with `na.rm = FALSE`): "Removed N rows containing missing fourfold
      values in panel P." (with ", leaving it empty" when none remain) and "Left
      fourfold panel P empty: N rows have a missing weight, so the panel's table is
      unknown."
    - Free scales: a panel that loses all of one category now has one category, as it
      would without those rows, and stops with "panel 3 has 1 and 2" instead of drawing
      "NA" as a category. With fixed scales that column is empty, as without the rows.
  - *Docs*: new "Missing values" section; `na.rm` and the `@details` sentence on cells
    completed with zeros ("cells with no rows") updated; `man/geom_fourfold.Rd`
    regenerated. Margin panels from `facet_grid(margins = TRUE)` that pool an
    unknown stratum are unknown too and left empty.
  - *Tests* (9 new `test_that()` blocks): missing `x`/`y` equal to dropping the rows,
    for a trailing `NA` level, `addNA()`, a logical variable, and individual-level
    data; labels with the `NA` category under custom, named, function, reordered, and
    `na.translate = FALSE` labels; the free-scale bug; a missing weight equal to
    dropping its stratum (`identical()` values, 6 settings including `all.max`, square,
    and `p_adjust_method`), `NaN`, and a row with both `x` and weight missing; invalid
    weights next to a missing one; empty panels and an all-empty layer built and drawn
    for both shapes, with no grobs in the empty panel. Five of the original six fail at HEAD
    (f8e09d0); the invalid-weights one guards a check that already worked. Follow-up
    regressions cover invalid weights on missing-category rows on either axis,
    colliding NA palettes on either axis, and a panel with separate missing x and
    missing weight rows. The equivalence cases now include `Freq[2] <- NA`, leaving
    the largest known cell in the emptied panel to exercise `all.max`. Warning
    assertions require exactly "1 row has" or "N rows have".
  - *Initial verification* (preceding Claude session; `dev/` scripts not changed;
    scratch scripts compared HEAD f8e09d0 and the change): the 8 complete-data plots (UCB, square, `all.max`, `ind.max`,
    free scales, Titanic grid, individual-level data) have identical layer data and
    warnings, and 4 rendered PNGs are pixel-identical. 20 equivalence checks are exact
    (`all.equal(tolerance = 0)`): every missing-value plot equals the plot with those
    rows or that stratum removed, under 7 `std`/`margin`/inference settings. Edge
    cases: `NA` in the middle or first in `limits` (still the position error), a third
    real category (still the two-level error), `coord_flip()`, another layer, a
    `facet_grid()` cell, one panel, and every panel empty all build and draw. Images
    checked by eye. `dev/verify-geom-fourfold.R` passes; `R CMD check --as-cran`: 0
    errors, warnings, or notes; no new spelling flags.
  - *Known limitation (ggplot2's)*: if an entire `x` or `y` column is `NA` and
    `scale_x_discrete(na.translate = FALSE)` is used, the scale has no categories and
    ggplot2's limit expansion fails with "replacement has length zero". ggplot2's own
    `geom_bar()`, `geom_boxplot()` and `stat_summary()` fail the same way; not handled.
  - *Additional ggplot2 limitation*: drawing an empty panel with free scales can
    emit "Position guide is perpendicular...", even with `na.rm = TRUE`. This
    option suppresses the fourfold missing-value warnings, not ggplot2 guide warnings.
  - *Independent verification* (two reviewers, completed in the preceding Claude
    session; counts reported in its handoff): over 600 complete-data comparisons
    against HEAD and 1,275 missing-value equivalence checks were identical. Both
    reviewers found the fix correct without regressions. Their substantive findings
    were the invalid-weight validation and NA-palette collision checks above; both
    are fixed and now covered by regression tests. Documentation now records the
    free-scale guide warning and unknown margin panels.
  - *Codex completion verification* (2026-10-01): 1,376 test assertions pass without
    failures, warnings, or skips; `dev/verify-geom-fourfold.R` passes. Re-ran the
    complete-data comparisons: 8 results identical to HEAD and 4 PNGs pixel-identical
    to saved HEAD renderings. All 18 scratch missing-value equivalence checks pass.
    Reviewed the relevant extrachecks guidance (documentation, examples, suggested
    dependencies, and DESCRIPTION). `DISPLAY= R CMD check --as-cran` completed with
    0 errors, 0 warnings, and 1 NOTE: new submission and the existing SAS reference
    URL lookup failure in the vignette (temporary log, not kept).
  - *Final independent Codex review* (requested by GK): no actionable findings.
    The reviewer independently passed 24 exact equivalence cases across both axes,
    fixed/free scales, and three standardizations; checked a duplicated missing-count
    row; independently aggregated Titanic grid margins and confirmed exactly the
    panels pooling the unknown count were excluded; successfully drew the margin plot.
  File: `R/geom-fourfold.R` (`.fourfold_missing_category()`, `.fourfold_panel_table()`,
  `.fourfold_compute_layer()`), `man/geom_fourfold.Rd`,
  `tests/testthat/test-geom-fourfold.R`.

## Development scripts

- [X] **Repair stale source paths and the missing verification reference** (fixed
  2026-09-30) —
  `Rscript dev/verify-geom-fourfold.R` currently stops immediately trying to source
  `dev/geom-fourfold.R`; the implementation now lives in `R/`. The script also sources a
  nonexistent `dev/ggfourfold.R` and calls its unavailable `ggfourfold_data()` reference
  helper. `dev/examples.R` similarly searches obsolete development locations, and both
  script headers give commands under the nonexistent `dev/fourfold/` directory. Update
  loading and run instructions, replace or restore the reference calculation, and check
  both scripts from a fresh R session at the package root. Keep the numerical reference
  independent of the implementation being tested.
  - *Fix*: both scripts now load the package with `pkgload::load_all()` from the
    script's own directory (which also exposes the internal helpers the verification
    uses), and their headers give `Rscript dev/verify-geom-fourfold.R` and
    `Rscript dev/examples.R`. Both look for the file being `source()`d before Rscript's
    `--file`, so they also work when sourced from another script, and fall back to the
    file name when `source(chdir = TRUE)` has made a relative path stale. In
    `dev/examples.R`, `.show_fourfold_example()` now draws each plot on a null device
    when not interactive, so `Rscript dev/examples.R` checks all six, including the
    count placement done at drawing time; export paths moved
    from `dev/fourfold/output/` to `dev/output/` (now in `.gitignore`); and the Titanic
    example's comment no longer cites "structural zeroes" (it now points to the Zero
    counts section). The verification script writes its one bare `ggplotGrob()` to a
    null device instead of `Rplots.pdf` in the working directory, and its closing
    message no longer says "dev geom".
  - *Reference*: the removed files were never in this repository's history, so
    `ggfourfold_data()` could not be restored. `fourfold_reference()` replaces it,
    independently of the package's closed forms: standardized cells by iterative
    proportional fitting to unit row and column totals (0.5 added when a cell is zero,
    as in vcd), ring tables by `uniroot()` on the log odds ratio with the observed
    totals, then the same standardization. The fitting stops once the row totals are 1
    after a column step (stopping on a small change per step stopped early, wrongly by
    up to 9e-10, on 813 of 1,659 strongly associated random tables; the new rule was
    within 1.1e-13 whenever it stopped, and otherwise errors at the iteration cap). It
    matches the package on UCB at the script's original tolerance of 1e-13. A new block
    checks the rings with `margin = 1`, `margin = 2`, `ind.max`, and `all.max` against
    the same reference with the matching standardization; previously only the default
    display's rings were checked, and that display cannot show which totals the rings
    were built from.
  - *Verification*: from fresh R sessions, the verification script passes run with
    Rscript from the package root and from another directory, and via `source()`
    (with `chdir = TRUE`, and by absolute path from elsewhere); `dev/examples.R` runs
    with Rscript from both, and via `source()` with relative, absolute, and
    `chdir = TRUE` paths, with all 6 example plots building without warnings. No files
    are written to the package root. Mutation checks on a scratch copy: scaling the
    default sectors by 1 + 1e-9, or the ring solver's cell by 1 + 1e-7, or building every
    panel's rings from `tab + 0.5`, makes the verification script fail.
  - *Independent verification* (two statistician subagents). The first, on the first
    repair: both scripts ran in every mode above, the reference was accurate to 2.3e-16
    (fitting) and 2e-15 (ring cells) against Rmpfr, and planted errors of 1 + 1e-13 were
    caught. Its findings — the `chdir = TRUE` path, the missing ring checks for
    non-default standardizations, the stopping rule, sourcing the verification from
    elsewhere, plus building every example, ignoring `dev/output/`, and the "dev geom"
    message — are all addressed above. The second, on the revised scripts: exit 0 and
    no files written in 16 invocation modes; fitting accurate to 2.2e-16 on UCB and on
    2,999 random tables (|log OR| up to 9.1, none failing to converge); planted errors
    caught down to 1 + 3e-13 in rings and 1 + 1e-12 in sectors and solver cells, plus
    rings from `tab + 1e-6`, swapped margins, a panel maximum for `all.max`, and swapped
    bounds. Its suggestions, adopted: draw (not only build) the examples, and note that
    `fourfold_reference()` needs strata without an empty row or column.
  Files: `dev/verify-geom-fourfold.R`, `dev/examples.R`.

## Display / layout

- [X] **The geom draws outside ggplot2's coordinate system** (found 2026-10-01 by
  reviewer B of the `na.rm` item; diagnosed by GK and Claude) — `draw_panel()` ignores
  `panel_params` and `coord` and draws each display in its own viewport with a fixed
  native scale of −1.3 to 1.3, stretched over the whole panel. The `x` and `y` scales
  only carry the category names, but ggplot2 still builds ordinary discrete axes from
  them (positions 1 and 2, range 0.4–2.6) and uses them for axes, gridlines, and other
  layers. With `theme_fourfold()` none of this shows: it is built on `theme_void()` and
  sets `aspect.ratio = 1`. With any other theme or coordinate system (checked with
  `theme_grey()` on UCB Dept A):
  - *The y-axis labels run the other way*: ggplot2 puts position 1 at the bottom, while
    the geom draws the first `y` level at the top, as in vcd. Gridlines line up with
    nothing.
  - *Circles become ellipses* in a non-square panel; area ratios survive, but it no
    longer looks like a fourfold display.
  - *`coord_flip()` flips the axes but not the drawing*, so the axis titles name the
    wrong variables.
  - *Other layers land in the wrong cells*: `geom_point(aes(Gender, Admit))` at (Male,
    Admitted) is drawn in the bottom-left (Male–Rejected) cell, and near but not on any
    cell centre. `geom_text()` labels or annotations on a fourfold have the same
    problem.

  Counts, odds ratios, and tests are unaffected; only what ggplot2 draws around and on
  top of the display is wrong.
  - *Options first considered* (2026-10-01): (a) document the limitation and reject
    `coord_flip()`; (b) hide the position axes and force square panels; (c) a dedicated
    `coord_fourfold()`. Claude recommended (a) and (b). GK preferred a real fix, since an
    annotation landing in the wrong cell is worse than an unsupported operation.
  - *Plan* (agreed by GK, 2026-10-01; not implemented): `dev/coordinate-system-plan.md`.
    Draw in ggplot2's coordinates, following `geom_sf()`:
    - `geom_fourfold()` returns `list(layer, coord_cartesian(reverse = "y", ratio = 1,
      default = TRUE))`; plot syntax is unchanged, but the return value is a list, not
      a `Layer`.
    - The geom keeps its drawing code and rescales its viewport from
      `coord$transform()`, with clipping still off; `setup_data()` reports the extent
      0.2–2.8. The quadrant centres are the category positions, so ordinary layers
      align.
    - GK's decisions: a user's own coordinate system replaces the default (document
      adding `reverse = "y"`); `coord_flip()` and non-Cartesian coordinate systems are
      errors (swap `x` and `y` instead); the `NA` axis slot is accepted, with a hint in
      the missing-values warning; `ratio = 1` is included (free facet scales then
      unsupported; checked not to affect the marginal-table plans).
    - Count placement must be fixed for unreversed orientations (justification and
      negative native heights in `makeContent.fourfold_counts()`).
    - History: an earlier plan written with GPT and its GPT review (not kept in the
      repository; summarised in the plan's History section) reached the same core design with a
      heavier mechanism (S7 component class, provenance check, per-vertex transforms,
      physical-unit diagnostics). A ggplot2-conventions review by a Claude subagent,
      reproduced by Claude, simplified it; the plan's History section lists each change.
  - *Found during planning; fixed by the counts item below (2026-10-01)*:
    `.fourfold_counts_reach()` previously ignored
    `conf_low_radius` (for `c(2, 5, 5, 2)`, squares, `ticks = 0`: reach 0.749 versus a
    true 0.835 and a count limit of 0.80); whether counts go outside can differ between
    panels of different physical sizes (now documented).
  - *Implemented* (2026-10-01, uncommitted; Claude as project manager, code by Sonnet
    subagents, per `dev/coordinate-system-plan.md`):
    - `geom_fourfold()` returns `list(layer, coord_cartesian(reverse = "y", ratio = 1,
      default = TRUE))`.
    - `GeomFourfold$setup_data()` adds `xmin`/`xmax`/`ymin`/`ymax` = 0.2/2.8;
      `draw_panel()` checks the coordinate system (new `.fourfold_check_coord()`: errors
      for `coord_flip()`, with the advice to swap `x` and `y`, and for non-Cartesian
      systems) and sets the display's viewport scales from `coord$transform()` of the
      frame corners, rounded to 10 digits so the default is exactly ±1.3; clipping stays
      off.
    - `makeContent.fourfold_counts()`: text height in absolute value and justification
      from the direction of the native scales, so counts sit inward (or outward) under
      any reversal.
    - Docs: `@return`, new "Coordinate systems" and "Annotations" sections, an
      `annotate()` example, Missing values. NEWS left as "Initial CRAN submission."
      (unreleased package).
  - *Decision B* (GK, after review): `theme_fourfold()` no longer sets
    `aspect.ratio = 1`. The theme's aspect ratio overrode the coordinate ratio whenever
    the x and y ranges differed (a missing value's axis place, a one-axis zoom, an
    annotation outside the frame), squashing the circles. Now the coordinate ratio keeps
    circles round and panels square by default; a user's own coordinate system without
    `ratio = 1` lets the display stretch (documented). The missing-value hint warning
    added during implementation was removed again, since the axis place no longer
    distorts the display. Free facet scales are an error with the default coordinate
    system (fixed ratio); with one's own coordinate system without `ratio` they work.
  - *Verification* (scratch harness, HEAD 2c098be vs the change, ggplot2 4.0.3 and the
    minimum 4.0.0 with identical results):
    - statistics: 245 cases (all `std`/`margin`, shapes, inference settings, 8
      `p.adjust` methods, UCB, Titanic with and without margins, individual rows,
      zero/empty/blank tables, missing values): all 5,852 statistical columns
      `identical()`; warnings identical in all 245; the only behaviour differences are
      free facet scales (now ggplot2's fixed-ratio error) and `facet_grid(space =
      "free")` under `theme_fourfold()` (now draws);
    - pixels: 260 default images (`theme_fourfold()` at base sizes 12 and 8, four
      device sizes, PDF) identical to HEAD; separately 30 one-image-per-process renders
      byte-identical after decision B;
    - alignment: 117 plots (13 coordinate setups × 3 themes × 3 datasets): 6,084 points
      and text labels at their cells' quadrant centres (error ≤ 1e-16);
    - text: 96 orientation renders, counts inside/outside the frame placed correctly;
    - tests: 2,248 expectations pass; `dev/verify-geom-fourfold.R` passes;
      `R CMD check --as-cran` 0 errors, warnings, notes.
  - *Independent review* (two Opus subagents as statisticians with ggplot2-extension
    experience): both approved with changes; no implementation bugs; statistics and
    default rendering confirmed unchanged (one rendered 204 files one per process; one
    checked 768 and the other 1,848 aligned panels). Their findings, all addressed:
    clipping and the absolute text height were untested (planted bugs survived; tests
    added); the claim that `ratio` keeps circles round "under any theme" was false under
    `theme_fourfold()` (led to decision B); docs on replacing the coordinate system
    (include `ratio = 1`, `coord_fixed()`/`coord_equal()`, after the last
    `geom_fourfold()`), free scales, and zoom spill-over. Re-review after decision B:
    approve; one false doc claim (free space keeps displays round) fixed; 14 of 15
    planted bugs caught (the survivor is a pre-existing constant, the outside offset).
  - *Pre-existing, not from this change* (see the new items under "Diagnostic
    follow-ups"): very small devices stop with "Viewport has zero dimension(s)"; with
    `std = "ind.max"` circles, the largest count can overlap its arc; `layer()` with
    `GeomFourfold`/`StatFourfold` and no parameters fails in the stat.
  Files: `R/geom-fourfold.R` (`geom_fourfold()`, `GeomFourfold$setup_data()`,
  `GeomFourfold$draw_panel()`, `makeContent.fourfold_counts()`), tests, docs, NEWS.

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

- [x] **Add `counts = c("auto", "inside", "outside", "none")` and fix count reach**
  (implemented 2026-10-01; GPT-6.1 Sol implementation/verification, independent
  GPT-6 Astra review; follow-up changes and commit by Claude):
  - `"auto"` includes both confidence bounds for squares and checks circles against
    measured count width and height. Circle boxes have 0.04 clearance towards the
    centre on each axis; diagonal ticks use their actual endpoint coordinates.
    Circle labels and drawing reach are shared across the layer, excluding blank
    panels. Different physical panel sizes can still give different decisions.
  - `"inside"` and `"outside"` force placement; `"none"` omits count text. All modes
    preserve statistical data and reversal-aware justification. Current drawing
    extent and typography are unchanged. Outside crowding at small sizes is documented.
    Reserving extra room for outside counts was considered and dropped (GK,
    2026-10-01): text only crowds, without overlapping, in small plots, and wider
    room shrinks every display without separating the counts from the labels.
  - 2,913 test assertions pass (no failures/warnings/skips). Planted omissions of
    the lower CI bound, circle checking, and the counts choice cause 2, 87, and
    180 failures respectively. Both development verification scripts pass.
  - Against HEAD b8b9149, 720 cases have identical statistical columns, warnings,
    and numerical areas; 20 additional dataset/shape cases have identical full
    layer data across all four choices. Only drawing metadata changes:
    `counts_reach` now stores outline reach; new `counts_tick_reach` and
    `counts_labels` carry diagonal reach and shared label measurements.
  - 52 default image comparisons: 32 pixel-identical, 20 move counts outside
    (18 circle cases, 2 lower-CI square cases). Every changed pair and all 24
    explicit-mode/orientation images inspected by the project manager. Clearance
    can move counts before literal overlap (the strong-circle case); layer-wide
    aggregation also deliberately moves non-overlapping cells together. Removing
    count grobs makes all 20 changed pairs pixel-identical; all 8 forced-inside
    shape/orientation images exactly reproduce the old inside placement.
  - Independent Sol ggplot2 API/docs audit: no actionable findings.
  - Independent Astra review: no correctness/API findings after 320 geometry
    checks and 16 randomized four-facet statistical comparisons. Its P3 wording
    suggestion was applied: documentation says drawings "come close" to counts.
  - `R CMD check --as-cran` with `env -u DISPLAY`: 0 errors, 0 warnings, 1 NOTE
    (new submission and the existing SAS vignette-reference URL lookup failure).
    No new spelling flags; relevant extrachecks guidance reviewed (documentation,
    examples, dependencies, DESCRIPTION, URLs). The final check after the wording
    refinement has the same result (temporary logs, not kept).
  - Reproduction: `dev/counts-verification.R`. The detailed logs, rendered
    comparisons, image manifest, mutation runner, and independent review were
    temporary logs, not kept. Plan: `dev/counts-plan.md`.
  - *Follow-up* (Claude, 2026-10-01, requested by GK):
    - The layer-wide count values are no longer layer-data columns.
      `GeomFourfold$setup_params()`, which sees the whole layer's data, computes
      `counts_reach`, `counts_tick_reach`, and `counts_labels` (blank panels
      excluded) and passes them to `draw_panel()` as parameters; without them, as
      when `draw_panel()` is called directly, a panel is placed on its own. The
      layer data now have the columns of b8b9149 less `counts_reach`.
    - An invalid choice names its argument, e.g. `` `counts` must be one of "auto",
      "inside", "outside", or "none" `` (likewise `std`, `shape`, and
      `p_adjust_method`), instead of R's "'arg' should be one of".
    - 2,826 test expectations pass (no failures/warnings/skips): 15 new; 102 fewer
      because `same_values()` compares layer data column by column and the three
      columns are gone. Both development scripts pass (720 cases identical to
      b8b9149 apart from those columns). Against the version above, 1,152 ragg PNGs
      (576 cases: UCB, Titanic with and without margins, both shapes, six `std`/
      inference settings, all four `counts`, four coordinate systems; 9 × 6 and
      4 × 3 in) are byte-identical and all 8,352 drawn count grobs place their
      counts identically; 8 edge cases (empty and blank layers, two layers, direct
      `layer()`, `drop = FALSE`, missing values) render byte-identically. Against
      b8b9149, all 17,856 shared layer-data columns of the 576 cases are
      `identical()`. Spelling unchanged; R CMD check not rerun (GK).
  Files: `R/geom-fourfold.R`, `man/geom_fourfold.Rd`,
  `tests/testthat/test-geom-fourfold.R`, `dev/square-counts.R`,
  `dev/counts-verification.R`.

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


## Diagnostic follow-ups (missing-value and coordinate-system reviews)

- [x] Very small devices (e.g. Titanic `facet_grid(margins = TRUE)` with
  `shape = "square"`, `std = "ind.max"` at 1.5 × 4 in) stop with "Viewport has zero
  dimension(s)" from `convertHeight()` in `makeContent.fourfold_counts()` (also at
  2c098be; found by the coordinate-system reviewers). A small RStudio plot pane could hit
  it.
  Fixed on 2026-10-01: `makeContent.fourfold_counts()` returns early with no children
  when the panel has zero width or height, where native units cannot be measured; the
  category labels still draw, collapsed with the panel, as `geom_text()` does. Covered
  by "a plot too small for its layout is drawn without counts".
- [x] With `std = "ind.max"` and circles, the largest count could overlap its own arc
  (UCB Dept A, "512"). Fixed with the counts argument on 2026-10-01; see its
  implementation and verification record above.
- [x] `layer(geom = GeomFourfold, stat = StatFourfold)` without parameters fails in the
  stat (`conf_level > 0 && extended` with NULLs). Give defaults or document that
  `geom_fourfold()` is the supported constructor.
  Fixed on 2026-10-01: `StatFourfold$setup_params()` fills in the defaults of
  `geom_fourfold()` for NULL parameters, and `GeomFourfold$draw_panel()` has matching
  defaults for `palette`, `ticks`, and `extended`. Covered by "a layer built from the
  geom and stat has the defaults of geom_fourfold()". The defaults now live in one
  internal list, `.fourfold_defaults`, checked against `geom_fourfold()` by a test, and
  `StatFourfold` is exported and documented with `GeomFourfold`, as ggmosaic exports its
  Stats (GK, 2026-10-01).
- [x] Two `geom_fourfold()` layers in one plot draw the first layer twice and never the
  second: every panel's display is a gTree named `"fourfold-panel"`, and grid draws a
  gTree's children by looking up their names, so both lookups find the first layer's
  display (also at b8b9149; found while verifying the counts follow-up). Give the
  display a unique name, e.g. `grid::grobName(prefix = "fourfold-panel")`, and check
  the tests that look it up.
  Fixed on 2026-10-01: `GeomFourfold$draw_panel()` names the display
  `grid::grobName(prefix = "fourfold-panel")`; the tests that look it up use
  `grep = TRUE` and still pass. Covered by "two fourfold layers in one panel are both
  drawn".

- [x] Distinguish values excluded by discrete scale limits from actual missing values
  in the "missing fourfold values" warning (pre-existing behavior).
  Not distinguished; the warning is reworded on 2026-10-01 to ggplot2's "missing values
  or values outside the scale range", since after scale mapping both are NA and cannot
  be told apart reliably. The Missing values section says limits-excluded values are
  removed the same way. Covered by "values outside a discrete scale's limits are removed
  like missing values".
- [x] Consider identifying facets by labels in warnings instead of internal panel
  numbers (pre-existing behavior).
  Closed without change (GK, 2026-10-01): ggplot2's own warnings do not name panels.
- [x] Recheck the existing SAS reference URL in `vignettes/refs.bib:62`; the
  network-enabled CRAN check on 2026-10-01 reported a lookup failure for it.
  Fixed on 2026-10-01: the `url` field of `Friendly:94c` is removed, as it redirects to
  a broken address.
- *Verification of the 2026-10-01 fixes above* (code by Sonnet subagents, Claude as
  project manager; two independent Opus reviews approved, their findings addressed):
  2,986 test expectations pass with no failures, warnings, or skips, and the new tests
  fail on 94f93e3. Against 94f93e3, the 576-case grid (UCB, Titanic with and without
  margins, both shapes, six `std`/inference settings, all `counts` values, four
  coordinate systems) has identical layer data, and its 1,152 ragg PNGs (9 × 6 and
  4 × 3 in) are byte-identical; 11 missing-value and limits cases differ only in the
  reworded warning, as do 72 of `dev/counts-verification.R`'s 720 cases (all 720
  identical after mapping the wording). Plots that used to stop now draw: widths of
  1.6-1.8 in for Titanic margins, single panels down to 0.05 in. `R CMD check
  --as-cran`: 1 NOTE (new submission only; the SAS URL failure is gone). No new
  spelling flags.
