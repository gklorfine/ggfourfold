# Plan: count placement fixes and a `counts` argument

Status: implemented and committed 2026-10-01; verification and independent review
recorded in `issues/TASKS.md` and `HANDOFF.md`. Original plan written by Claude. TASKS items: "Add a `counts = c(...)` argument" (Display /
layout), the count-reach bug (`conf_low_radius`) under "The geom draws outside ggplot2's
coordinate system", and the `ind.max` circle overlap under "Diagnostic follow-ups".
Later (GK, 2026-10-01): the layer-wide values described below as `setup_data()`
columns are now parameters computed in `GeomFourfold$setup_params()`; see the
follow-up in the TASKS record.

## Background

Counts sit inside the frame corners at local (±0.88, ±0.88) (`.fourfold_count_offset`),
or just outside them at ±1.02 when something in the display would overlap them. The
decision is made per layer: `GeomFourfold$setup_data()` computes `counts_reach` with
`.fourfold_counts_reach()` (the largest extent towards the corners over all panels), and
`makeContent.fourfold_counts()` compares it at draw time with the count limit
`.fourfold_count_limit(text_height) = min(0.80, 0.88 - text_height)`, measured from the
responsive text size. Local units: frame −1..1 (see `draw_panel()`).

Two bugs (both exist at 2c098be and at b8b9149):

1. **Squares ignore the lower confidence outline.** `.fourfold_counts_reach()` uses
   `radius` and `conf_high_radius`, not `conf_low_radius`. Off-diagonal cells grow when
   the odds ratio decreases, so their outer outline is the lower-limit one. Example:
   `table_plot`-style data x = a,a,b,b; y = u,v,u,v (levels in that order); w =
   c(2, 5, 5, 2); `shape = "square"`, `ticks = 0`: computed reach 0.749 < 0.80, so counts
   stay inside, but the true reach is 0.835 and the "5" counts sit on the outlines.
2. **Circles are never checked.** For `shape = "circle"` the reach is `-Inf`, so counts
   always stay inside. With `std = "ind.max"` the largest quarter-circle has radius 1 and
   its arc passes under the corner count (UCB Dept A: "512" on the red arc).

## Decisions (GK, 2026-10-01)

1. `"auto"` checks circles too (fixes bug 2), as well as squares with both outlines (bug 1).
2. Outside counts at small sizes can collide with category labels or a neighbouring
   panel. **Now:** keep the drawing extent (±1.3, `xmin`… = 0.2/2.8) and document it.
   **Later:** a separate TASKS item to reserve extra room when counts are outside.
3. New argument `counts = c("auto", "inside", "outside", "none")` in `geom_fourfold()`.

## Design

### Reach (both shapes)

Express every element's extent as how far it reaches into a corner, and compare it with
the count text's inner corner.

- **Squares** (unchanged method, fixed inputs): a quarter-square of radius `r` has outer
  corner (s, s) with `s = r * .fourfold_square_side`. Use `max` over `radius`,
  `conf_low_radius` and `conf_high_radius` (all finite values). Direction ticks: as now.
- **Circles** (new): a quarter-circle (or ring) of radius `r` overlaps the count text box
  when `r` exceeds the distance from the centre to the box's inner corner. The box spans
  from the offset 0.88 inwards by the text's width (x) and height (y), so its inner
  corner is at (0.88 − w, 0.88 − h) and the circle overlaps when
  `r > sqrt((0.88 - w)^2 + (0.88 - h)^2)` (and the box is in the circle's quadrant,
  which it always is). Direction ticks run along the diagonal from `r` to `r + ticks`;
  their end is at distance `r + ticks` from the centre along the diagonal, i.e. the point
  ((r + t)/√2, (r + t)/√2); it overlaps when both coordinates exceed the box's inner
  corner coordinates. Keep a safety margin comparable to the squares' 0.80 cap (decide
  and document it; e.g. require the arc to stay outside the box enlarged by 0.04).
- Since the circle test needs text width as well as height, move the comparison into
  `makeContent.fourfold_counts()` (measure width and height of every count label there,
  absolute values as now), and pass it the radii it needs (per layer: the maximum radius
  over `radius`/`conf_low_radius`/`conf_high_radius` over all panels, plus the tick
  reach), instead of a single precomputed `counts_reach`. Keep the decision layer-wide:
  counts are outside in every panel if any panel's drawing reaches them. (The existing
  caveat stays: the limit uses each panel's measured text size, so with very different
  panel sizes the decision can differ between panels. Do not change that here.)
- Blank panels (all counts zero) have no sectors, rings or ticks; empty panels have no
  rows. Neither should force counts outside.

### `counts` argument

- `geom_fourfold(..., counts = "auto")`, validated like the existing arguments (see the
  `.fourfold_check_*` helpers and how `shape` is validated; same error style). Add to
  `GeomFourfold`'s `extra_params` and `draw_panel()` signature; pass to the counts grob.
- `"auto"`: the rule above. `"inside"`: always at ±0.88 (as vcd), even if overlapped.
  `"outside"`: always at ±1.02. `"none"`: no count text drawn (do not add the
  `fourfold-counts` grob, or add it empty). Layer data are identical for every value
  (the `count` column stays).
- Count justification must keep working under every coordinate reversal (see
  `makeContent.fourfold_counts()`, which flips `hjust`/`vjust` from the native scales'
  direction).

### Docs

`@param counts`; update `@details` ("Cell counts stay inside the frame corners unless…",
currently squares only) to describe the rule for both shapes and the four values; note
that outside counts can collide with category labels or neighbouring panels at small
sizes (increase panel spacing, use `counts = "inside"`, or smaller text). NEWS.md stays
"Initial CRAN submission." (unreleased).

### TASKS

Mark the `counts` item, the `conf_low_radius` bug and the circle-overlap follow-up done
with a record (fix, verification, reviews). Add a new item: "Reserve room for counts
outside the frame" (decision 2b): enlarge the drawing extent / panel padding when counts
are outside, so they do not collide at small sizes; note it changes display size.

## Verification (per `CLAUDE.md`)

Compare against the last commit before the change (b8b9149 or later HEAD), each version
loaded with `pkgload::load_all()` in a separate R process, ONE rendered image per R
process (several sizes in one session shift pixels):

1. Statistics: every layer-data column identical (the `counts_reach` column may change or
   be removed — report it; all statistical columns must be `identical()`), across all
   `std`/`margin`, both shapes, inference settings, UCB, Titanic with and without
   margins, zero/blank/empty panels, missing values.
2. Pixels: for `counts = "auto"` (default), list every image that changes versus the old
   version and check each by eye: it must be a plot where something overlapped the counts
   (squares with off-diagonal outlines reaching the corners; circles with `ind.max` or
   other large radii) and now has counts outside. Everything else identical.
3. `"inside"`, `"outside"`, `"none"` render as described in every orientation (none, x,
   y, xy reversal) and both shapes; `"inside"` with squares reproduces the old inside
   placement.
4. Tests (testthat): the two bug examples above go outside under `"auto"`; default
   circles (UCB) stay inside; each value of `counts`; `"none"` has no count text grobs;
   invalid value is an error; layer data identical across values; decision identical
   across orientations. Plant bugs (drop `conf_low_radius`; circles back to `-Inf`;
   ignore `counts`) and confirm tests catch them.
5. `devtools::test()`, `Rscript dev/verify-geom-fourfold.R`, `dev/square-counts.R`
   (update its comments if the rule description changes), `R CMD check --as-cran`
   (use `env -u DISPLAY` on this Mac), spelling, extrachecks.
6. Independent review by two reviewers (statistics/visual correctness; ggplot2 API and
   docs), feeding findings back before committing.
