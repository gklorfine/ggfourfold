# Fourfold displays for 2-by-2 tables

`geom_fourfold()` draws a fourfold display in each ggplot2 panel. Sector
radii represent cell frequencies after the selected standardization,
while sector colours, confidence rings, and direction ticks show the
direction and strength of association.

## Usage

``` r
GeomFourfold

geom_fourfold(
  mapping = NULL,
  data = NULL,
  ...,
  std = c("margins", "ind.max", "all.max"),
  margin = c(1, 2),
  conf_level = 0.95,
  extended = TRUE,
  ticks = 0.15,
  p_adjust_method = stats::p.adjust.methods,
  shape = c("circle", "square"),
  palette = fourfold_palette(),
  na.rm = FALSE,
  show.legend = FALSE,
  inherit.aes = TRUE
)
```

## Format

A `GeomFourfold` ggproto object.

## Arguments

- mapping:

  Set of aesthetic mappings created by
  [`ggplot2::aes()`](https://ggplot2.tidyverse.org/reference/aes.html).
  If supplied and `inherit.aes = TRUE`, these are combined with the
  plot's default mappings.

- data:

  The data to display in this layer. If `NULL`, the default, the data
  are inherited from the plot.

- ...:

  Other arguments passed to
  [`ggplot2::layer()`](https://ggplot2.tidyverse.org/reference/layer.html),
  typically fixed aesthetics such as `colour` or `linewidth`.

- std:

  Standardization method. `"margins"` fixes the selected margins,
  `"ind.max"` divides each panel by its largest cell, and `"all.max"`
  divides every panel by the largest cell in the complete layer.

- margin:

  Integer vector selecting the table margins when `std = "margins"`. Use
  `c(1, 2)` for both margins, `1` for the `y` margin, or `2` for the `x`
  margin.

- conf_level:

  Confidence level in `[0, 1)`. Set to `0` to suppress confidence rings.

- extended:

  If `TRUE`, use adjusted p-values to emphasize association and draw
  direction ticks.

- ticks:

  Non-negative length of the association direction ticks in the geom's
  normalized panel coordinates.

- p_adjust_method:

  Method passed to
  [`stats::p.adjust()`](https://rdrr.io/r/stats/p.adjust.html) for
  adjustment across panels. Defaults to `"holm"`, the first value in
  [stats::p.adjust.methods](https://rdrr.io/r/stats/p.adjust.html).

- shape:

  Shape of the cell sectors: `"circle"` (the default, as in
  [`vcd::fourfold()`](https://rdrr.io/pkg/vcd/man/fourfold.html)) draws
  quarter-circles; `"square"` draws quarter-squares of equal area.

- palette:

  Character vector of at least six valid colours in the semantic order
  used by
  [`fourfold_palette()`](https://gavinklorfine.com/ggfourfold/reference/fourfold_palette.md).

- na.rm:

  If `FALSE`, the default, missing observations are removed with a
  warning. If `TRUE`, they are removed silently.

- show.legend:

  Logical indicating whether this layer should be included in legends.
  The default is `FALSE` because the semantic fills are not a mapped
  aesthetic.

- inherit.aes:

  If `FALSE`, override rather than combine with the plot's default
  aesthetic mappings.

## Value

A ggplot2 layer that can be added to a
[`ggplot2::ggplot()`](https://ggplot2.tidyverse.org/reference/ggplot.html)
object.

## Details

Map the two-level horizontal variable to `x`, the two-level vertical
variable to `y`, and cell frequencies to `weight`. When `weight` is
omitted, each row counts as one observation. The first `x` level is
drawn on the left and the second on the right; the first `y` level is
drawn at the top and the second at the bottom. Set factor levels
explicitly when their order matters. Alternatively, reorder categories
with the `limits` argument of
[`ggplot2::scale_x_discrete()`](https://ggplot2.tidyverse.org/reference/scale_discrete.html)
or
[`ggplot2::scale_y_discrete()`](https://ggplot2.tidyverse.org/reference/scale_discrete.html),
and rename them with `labels`. Scale `breaks` that reorder or omit
categories, and a scale `palette` that moves them, are errors.

One panel must contain exactly one 2-by-2 table. Use
[`ggplot2::facet_grid()`](https://ggplot2.tidyverse.org/reference/facet_grid.html)
or
[`ggplot2::facet_wrap()`](https://ggplot2.tidyverse.org/reference/facet_wrap.html)
to display stratified tables. Duplicate `x`/`y` combinations within a
panel are summed and missing cells are completed with zero counts.

Odds ratios, Wald confidence intervals, and extended-display p-values
match the calculations in
[`vcd::fourfold()`](https://rdrr.io/pkg/vcd/man/fourfold.html). If any
observed cell is zero, 0.5 is added to all four cells for inference; see
the Zero counts section for how such tables are drawn. P-values are
adjusted across all panels in the layer that have one. A panel whose
counts are all zero has none, whereas
[`vcd::fourfold()`](https://rdrr.io/pkg/vcd/man/fourfold.html) counts it
with a p-value of 1, so in a layer with such a panel the adjusted
p-values differ from those it gives. Confidence intervals themselves are
not adjusted.

With `shape = "square"`, each cell is drawn as a quarter-square with the
same area as the corresponding quarter-circle (side \\r\sqrt{\pi}/2\\
for radius \\r\\), so the two shapes display a table with identical
areas. Confidence rings become nested square outlines. Cell counts stay
inside the frame corners unless a square, confidence outline, or
direction tick in any panel of the layer would reach them, as is always
the case with `std = "ind.max"`; the counts in every panel are then
placed just outside the frame corners.

The six semantic fill colours are supplied by `palette`; they are not
mapped through a ggplot2 fill scale. Typography and layout defaults are
controlled by
[`theme_fourfold()`](https://gavinklorfine.com/ggfourfold/reference/theme_fourfold.md).

## Aesthetics

`geom_fourfold()` understands the following aesthetics:

- `x` (required): a categorical variable (factor, character, or logical)
  with exactly two levels. Convert numeric codes, such as 0/1, with
  [`factor()`](https://rdrr.io/r/base/factor.html).

- `y` (required): a categorical variable with exactly two levels.

- `weight`: non-negative cell frequencies; defaults to `1`.

- `colour`, `linewidth`, `alpha`, `size`, and `family`: fixed or mapped
  drawing properties. `size` and `family` default to values inherited
  from the plot theme.

## Zero counts

If any cell of a panel's table is zero, 0.5 is added to all four cells
before the odds ratio, its standard error, and the confidence interval
are computed, as in
[`vcd::fourfold()`](https://rdrr.io/pkg/vcd/man/fourfold.html). The
count labels always show the observed counts.

A panel whose four counts are all zero, such as an empty stratum in a
faceted display, is drawn blank: only its frame, axes, labels, and zero
counts are shown, with no sectors, rings, or direction tick. It has no
odds ratio, confidence interval, or p-value (they are `NA`) and is left
out of the p-value adjustment, so it does not change the other panels.
(With the default `margin = c(1, 2)`,
[`vcd::fourfold()`](https://rdrr.io/pkg/vcd/man/fourfold.html) instead
draws such a stratum from the corrected table, as four equal
quarter-circles.) A facet level with no rows at all, for example with
`drop = FALSE`, is left empty by ggplot2 as usual, without a frame or
counts.

Each confidence ring shows the table that has the observed row and
column totals and an odds ratio equal to one confidence limit,
standardized like the data. With the default `margin = c(1, 2)`, which
depends only on the odds ratio, this is the fully standardized table at
that limit. With the other `std` and `margin` settings, if a whole row
or column is zero, the observed totals admit no other table, so the
rings of that panel are built from the row and column totals of the
table with 0.5 added to every cell, rescaled to the observed total
(which matters only for `std = "all.max"`). Panels with isolated zero
cells, but no empty row or column, keep the observed totals for their
rings.

A table with an empty row or column contains no information about the
odds ratio: with an empty row, for example, nothing is known about how
that row would split between the columns. Its odds ratio and p-value
exist only because of the correction. With an empty row, the odds ratio
is the ratio of the two counts in the other row, each plus 0.5, so it
reflects how that row splits rather than an association. The rings are
correspondingly wide, but the p-value can still fall below the
significance level, so the colour, significance shading, and direction
tick of such a panel say nothing about an association.

The sectors show the observed table wherever the standardization can use
it:

- With `std = "margins"` and the default `margin = c(1, 2)`, the sectors
  depend only on the odds ratio, which already includes the correction.

- With `margin = 1`, a row that is entirely zero has no proportions, so
  it is drawn from the corrected table, as two equal quarter-circles.
  The other row keeps its observed proportions. The same applies to an
  empty column with `margin = 2`. An empty column with `margin = 1`, or
  an empty row with `margin = 2`, keeps its observed proportions and so
  has no sectors, except in a cell it shares with an empty row (or
  column) that is drawn from the corrected table.

- With `std = "ind.max"` or `"all.max"`, the sectors show the observed
  counts, so an empty row or column has no sectors. Its rings still come
  from the corrected totals, so they need not match the sectors.

Weights that are very small but not zero, such as the remainder of
floating-point arithmetic (`0.1 + 0.2 - 0.3`), count as observations, so
a row or column of them is not empty and its rings keep the observed
totals. Where the standardization keeps such a row or column near zero
(`std = "ind.max"` or `"all.max"`, `margin = 2` for a row, or
`margin = 1` for a column), its near-zero totals leave almost no room
for other odds ratios, so the rings lie on the sectors, as if the
estimate were precise. An exactly empty row or column gets the wide
rings described above instead. Round such weights, for example with
`round(w, 8)`, if they are meant to be zero.

## References

Friendly, M. (1994). *A fourfold display for 2 by 2 by k tables*
(Technical Report No. 217). York University, Psychology Department.
<http://datavis.ca/papers/4fold/4fold.pdf>

Friendly, M., & Meyer, D. (2016). *Discrete Data Analysis with R:
Visualization and Modeling Techniques for Categorical and Count Data*
(Section 4.4). Chapman & Hall/CRC. <http://ddar.datavis.ca>

## See also

[`theme_fourfold()`](https://gavinklorfine.com/ggfourfold/reference/theme_fourfold.md),
[`fourfold_palette()`](https://gavinklorfine.com/ggfourfold/reference/fourfold_palette.md),
[`ggplot2::facet_grid()`](https://ggplot2.tidyverse.org/reference/facet_grid.html),
and
[`ggplot2::facet_wrap()`](https://ggplot2.tidyverse.org/reference/facet_wrap.html)

## Examples

``` r
ucb <- as.data.frame(UCBAdmissions)

ggplot2::ggplot(
  ucb,
  ggplot2::aes(x = Gender, y = Admit, weight = Freq)
) +
  geom_fourfold() +
  ggplot2::facet_wrap(ggplot2::vars(Dept), ncol = 3) +
  ggplot2::labs(title = "Berkeley admissions") +
  theme_fourfold()


# Quarter-squares of equal area instead of quarter-circles
ggplot2::ggplot(
  ucb,
  ggplot2::aes(x = Gender, y = Admit, weight = Freq)
) +
  geom_fourfold(shape = "square") +
  ggplot2::facet_wrap(ggplot2::vars(Dept), ncol = 3) +
  theme_fourfold()

```
