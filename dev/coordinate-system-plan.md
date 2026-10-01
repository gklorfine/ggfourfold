# Plan: draw fourfold displays in ggplot2's coordinates

Status: design agreed by GK on 2026-10-01; implemented (uncommitted) on 2026-10-01 and
reviewed by two independent reviewers; decision B (below, "Panel shape") taken after
review. This replaces the earlier
version of this plan (written with GPT on 2026-10-01). The decisions below follow a
ggplot2-conventions review by a Claude subagent, checked by Claude; see "History" at
the end for what changed and why. Tracked in `issues/TASKS.md`, item "The geom draws
outside ggplot2's coordinate system".

## The problem

`GeomFourfold$draw_panel()` ignores `coord` and `panel_params` and draws each display in
its own viewport with native scales −1.3 to 1.3, stretched over the panel. ggplot2 still
builds ordinary discrete x and y scales (categories at positions 1 and 2) and uses them
for axes, gridlines, and other layers. So under any theme other than `theme_fourfold()`:

- the y axis runs opposite to the drawing (the geom puts the first `y` level at the top,
  as vcd does; ggplot2 puts position 1 at the bottom);
- circles become ellipses in non-square panels;
- `coord_flip()` flips the axes but not the drawing;
- other layers land in the wrong cell: `geom_point(aes(Gender, Admit))` at (Male,
  Admitted) is drawn in the Male–Rejected cell.

Statistics are unaffected.

## Requirements (GK)

1. Keep the first row at the top by default, matching vcd and the current display.
2. Square panels come from the theme (`theme_fourfold()`, `aspect.ratio = 1`), as in
   ggmosaic and ggmosaic2. *Revised by GK after review (decision B): the coordinate
   system's `ratio = 1` now keeps panels square and circles round; `theme_fourfold()` no
   longer sets `aspect.ratio`.*
3. Ordinary added layers (`geom_point()`, `geom_text()`, `annotate()`) land in the right
   cell, with no `coord_fourfold()` and no extra settings for normal plots.
4. Statistics do not change.

## Design

### Precedent

ggplot2's own `geom_sf()` returns its layer together with a default coordinate system,
`c(layer_sf(...), coord_sf(default = TRUE))` (checked in ggplot2 4.0.3), and its help
says it adds `coord_sf()` for you. Adding a coordinate system to a plot always replaces
the existing one ("last added wins"); ggplot2 prints "Coordinate system already present"
unless the replaced one has `default = TRUE`. This design follows that precedent.

According to the reviewer's check of the installed packages, neither ggmosaic nor
ggmosaic2 aligns ordinary layers with their cells (they draw on continuous product scales
and provide `geom_mosaic_text()`), and both draw the first category at the bottom, so
requirement 3 goes beyond them.

### 1. Return value: the layer plus a default coordinate system

`geom_fourfold()` returns

```r
list(layer, coord_cartesian(reverse = "y", ratio = 1, default = TRUE))
```

like `geom_sf()`. The user-facing syntax is unchanged:

```r
ggplot(ucb, aes(Gender, Admit, weight = Freq)) +
  geom_fourfold() +
  facet_wrap(vars(Dept)) +
  theme_fourfold()
```

- `class(geom_fourfold())` becomes `"list"` instead of a ggplot2 `Layer`. Pre-CRAN, so no
  users depend on it. No S7 dependency and no `update_ggplot()` method are needed.
- Direct use of the exported `GeomFourfold` with `layer()` gets no default coordinate
  system and follows whatever the plot has (bottom-first under plain Cartesian). Document.
- `reverse = "y"` keeps the first `y` level at the top for the drawing and every other
  layer alike. A reversed y *scale* (`limits = rev`) is not an alternative: it reorders
  the table (UCB Dept A odds ratio 0.349 → 2.864).
- `ratio = 1` (GK, 2026-10-01): one data unit across equals one unit up, so circles stay
  round under any theme. A theme `aspect.ratio` overrides it, so (decision B, below)
  `theme_fourfold()` no longer sets one. Cost: ggplot2 rejects a fixed ratio with
  free facet scales (`facet_wrap(scales = "free")`, `facet_grid(scales = "free")`). Every
  fourfold panel shares the same two categories, so free scales have little use.
  Checked with the prototype: `facet_grid(margins = TRUE)`, partial and single-variable
  margins, and MF's `margin_background()` all draw, and the Titanic margins grid is
  pixel-identical to today's; the marginal-table plans (`issues/marginal-plots.md`) need
  no free scales.

### 2. A user's own coordinate system replaces the default

(GK, 2026-10-01: accept and document, as for `geom_sf()`.) For example,
`+ coord_cartesian(clip = "off")` replaces the default, so the display becomes
bottom-first; it is still correct, aligned, and labelled. To keep the first row on top,
add `reverse = "y"` (and `ratio = 1` if wanted) to your own coordinate system. A
coordinate system added *before* `geom_fourfold()` is replaced by the default, with
ggplot2's usual message; add it after. No provenance check: in ggplot2,
`default = TRUE` means exactly "replace freely".

### 3. Supported coordinate systems

`draw_panel()` accepts `CoordCartesian` and its subclasses (`coord_cartesian()`,
`coord_fixed()`/`coord_equal()`), with any `reverse`, limits, expansion, or clipping.
It stops with a clear error for:

- `coord_flip()` (GK, 2026-10-01): superseded in ggplot2's own help. Message: swap `x`
  and `y` in `aes()` instead, which transposes the table with the same odds ratio.
- `coord_sf()` (a `CoordCartesian` subclass, so test for it explicitly),
  `coord_transform()`, `coord_polar()`, `coord_radial()`: they would distort the areas
  that carry the display's meaning.

### 4. Drawing: keep the local drawing code, rescale its viewport

For Cartesian coordinates, `coord$transform()` only rescales each axis independently, so
the existing drawing code stays in its local units (frame −1 to 1, labels at ±1.16).
Only the viewport changes:

- Local `(u, v)` corresponds to data `x = 1.5 + u`, `y = 1.5 − v`. The frame is
  `[0.5, 2.5]` on both axes, i.e. the union of the four unit cells; the four quadrant
  centres are the category positions (1, 1), (1, 2), (2, 1), (2, 2).
- `draw_panel()` transforms the frame corners (0.5, 2.5) and (2.5, 0.5) with
  `coord$transform(..., panel_params)` and sets the viewport's `xscale`/`yscale` so that
  local −1 and 1 land there. A reversed axis gives a reversed native scale.
- Clipping stays off on the fourfold viewport (GK, 2026-10-01), as now. With the
  coordinate system's default `clip = "on"`, counts placed outside the frame corners
  lose digits ("512" → "12"; `std = "ind.max"`, `shape = "square"`, small devices), and
  only 16 of 48 test renders were pixel-identical. Turning clipping off made them
  identical. Consequence to document: zooming with `coord_cartesian(xlim =, ylim =)`
  does not crop the fourfold drawing.
- `GeomFourfold$setup_data()` reports the drawing's extent as numeric `xmin`/`xmax`/
  `ymin`/`ymax` of 0.2/2.8 (local ±1.3), the conventional mechanism (`geom_tile()`,
  `geom_boxplot()`). Without it the default discrete expansion (0.4–2.6) would cut into
  the labels at ±1.16. This reproduces today's drawing size exactly. Empty panels have no
  rows and report nothing.

### 5. Text and count placement under any orientation

The count code (`makeContent.fourfold_counts()`) uses fixed justifications and measures
text height in native units, both assuming the local y axis points up. With an
unreversed coordinate system the native scale is reversed, so counts hang outward
against the frame and the measured height is negative (seen in the prototype). Fix:

- take the text height in absolute value;
- derive `hjust`/`vjust` from the direction of the native scales, so counts are always
  placed inward (or outward when outside), for x and y reversal separately;
- check the outer category labels, the side labels' rotation, and the responsive size
  (it uses the panel's physical size, which does not change).

The default orientation (y reversed) keeps today's placement exactly.

### Panel shape (decision B, GK, 2026-10-01, after review)

Both reviewers found that `theme_fourfold()`'s `aspect.ratio = 1` overrode the
coordinate system's `ratio = 1` whenever the x and y ranges differed (a missing value's
slot, a one-axis zoom, an annotation outside the frame), squashing the circles, and that
the docs' "round under any theme" was false. Options: (A) keep both, the theme owning
squareness; (B) drop `aspect.ratio` from `theme_fourfold()` and let the coordinate ratio
keep circles round. GK chose B. Default plots are unchanged (both axes span 0.2–2.8, so
`ratio = 1` gives square panels); with a missing value the panel is wider and the display
stays round, so the missing-value hint below was dropped. Cost: a user's own coordinate
system without `ratio = 1` lets the display stretch to fill the panel (documented); in
exchange, such a coordinate system now allows `facet_grid(space = "free")`.

### 6. Missing-value category on the axes

(GK, 2026-10-01: accept, and add a hint. *Hint later dropped with decision B: the slot no
longer squashes the display.*) ggplot2 trains position scales before the stat
runs, so a missing `x` or `y` keeps an `NA` slot on that axis, as for every geom
(`geom_bar()` and `geom_point()` show it at position 3). The fourfold removes those rows
from the table, but its axis is wider (x 0.2–3.6 versus y 0.2–2.8), so under
`theme_fourfold()` the circles are squashed (unit ratio 0.765). Counts and statistics are
unaffected. The existing warning "Removed N rows containing missing fourfold values in
panel P." gains a hint: remove the missing values first, or use
`scale_x_discrete(na.translate = FALSE)` (or `scale_y_discrete()`). Do not set
`na.translate` from the geom or widen both axes: another layer may show the `NA`
category on purpose. With `na.rm = TRUE` the hint is silent like the warning; document
it in the Missing values section.

### 7. Annotations

`aes(x = Male, y = Admitted)` means the Male–Admitted cell, as in `geom_tile()` and
`geom_count()`: a fixed quadrant position, not the centre of the sector, whose size
varies with the data. Document with an example (a point or label in each cell). A third
category in another layer is still an error from the stat ("exactly two levels").

## Documentation

`geom_fourfold()` help: return value (list with a default coordinate system); first row
on top via `reverse = "y"`; replacing the coordinate system (add `reverse = "y"`, add it
after the geom); supported coordinate systems and the `coord_flip()` alternative; free
scales not supported (because of `ratio = 1`), and `facet_grid(space = "free")` not
supported with `theme_fourfold()` (ggplot2 rejects a theme aspect ratio with free space);
annotation positions; clipping and zoom; the `NA` axis slot in Missing values. README and
vignette examples unchanged; NEWS entry.

## Verification

Per `CLAUDE.md`, old (HEAD) against new:

1. **Statistics:** every statistical column `identical()` (counts, standardized values,
   radii, rings, odds ratios, SEs, intervals, p-values, adjusted p-values, flags,
   palette indices) across the existing case grids; `dev/verify-geom-fourfold.R`
   (vcd reference) passes.
2. **Pixels:** default plots pixel-identical to HEAD under `theme_fourfold()`: UCB,
   Titanic grid and margins, both shapes, all `std`/`margin` settings, counts outside the
   frame, blank and empty panels, several device sizes and base sizes, PNG and PDF.
3. **Alignment:** actual `geom_point()`/`geom_text()` grobs at each cell's quadrant
   centre, under no reversal, x, y and both, with zoom, fixed and free-space facets,
   margins; both addition orders of a user coordinate system.
4. **Text:** counts inside and outside the frame placed inward/outward correctly under
   each reversal; no negative heights.
5. **Errors:** `coord_flip()`, `coord_sf()`, `coord_transform()`, `coord_polar()`,
   `coord_radial()`; free scales (ggplot2's message).
6. **Missing values:** the hint, and identical statistics with and without the `NA` slot.
7. **ggplot2 4.0.0** (the minimum in `DESCRIPTION`) in a clean library: `reverse`,
   `ratio`, list addition, and the checks above.
8. `R CMD check --as-cran`, extrachecks, spelling, tests for each item above.

## Not part of this change (separate TASKS items)

- **Count reach ignores the lower confidence outline:** `.fourfold_counts_reach()` uses
  `radius` and `conf_high_radius` but not `conf_low_radius`, which can be the largest.
  For `c(2, 5, 5, 2)`, `shape = "square"`, `ticks = 0`, the computed reach is 0.749
  against a true 0.835 and a count limit of 0.80, so counts can overlap an outline.
  Exists today; fix separately with before/after checks.
- **Per-panel count placement:** whether counts go outside can differ between panels of
  different physical sizes (minimum font size). Exists today; correct the docs' claim of
  uniform placement or coordinate it separately.
- **Marginal fourfold displays:** unaffected (see section 1).

## History: what changed from the earlier plan

The earlier plan (GPT, 2026-10-01) and its GPT review (not kept in the repository; its
findings appear in the table below) reached the same core design (draw in data
coordinates, geom-supplied reversed y), but over-built the mechanism. A Claude subagent
reviewed it against ggplot2 conventions; Claude reproduced its prototype and checks.

| Earlier plan / review | Now | Why |
|---|---|---|
| Custom component class with an S7 `update_ggplot()` method | Plain `list(layer, coord)` | `geom_sf()` precedent; neither is a `Layer`, so the wrapper preserved nothing |
| Provenance predicate to tell explicit from implicit default coordinates | None; last added wins | That is ggplot2's meaning of `default = TRUE` |
| Transform every vertex through `coord$transform()` and re-derive all text placement | Rescale the existing viewport; fix only count justification | Cartesian transforms are per-axis rescalings; drawing code unchanged |
| No coordinate ratio (theme only) | `ratio = 1` plus theme | Round circles under any theme; theme still wins; free scales given up |
| Support `coord_flip()` | Error, suggest swapping `x` and `y` | Superseded in ggplot2; transposing gives the same odds ratio |
| Widen both axes for the `NA` category (layout-aware bounds) | Accept the slot, add a hint | ggplot2 keeps the slot for every geom |
| Physical-unit diagnostics and warnings | None | No ggplot2 geom does this |
| Clipping governed by the coordinate system (review); `clip = "inherit"` (prototype) | Clipping off, as now | Clipping cut off counts outside the frame |
| Count reach and per-panel placement as release gates | Separate items | Both exist today, independent of this change |

The reviewer's prototype (about 15 lines: `setup_data()` bounds, viewport rescaling,
list return) gave identical statistics, a pixel-identical UCB default, and correct
alignment under `theme_grey()`. Claude's wider check found the clipping difference and
the count-justification problem above. Scripts: Claude scratchpad, `conventions-review/`
(reviewer) and `myverify/` (Claude), not kept in the repository.
