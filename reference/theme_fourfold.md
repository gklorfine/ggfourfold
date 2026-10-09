# Theme for fourfold displays

`theme_fourfold()` is a minimal theme for
[`geom_fourfold()`](https://gavinklorfine.com/ggfourfold/reference/geom_fourfold.md)
that gives plots the plain look of
[`vcd::fourfold()`](https://rdrr.io/pkg/vcd/man/fourfold.html): a white
panel without axes or gridlines, facet labels without boxes, centered
titles, and compact spacing between panels. It also sets the text size,
font, and line width.

## Usage

``` r
theme_fourfold(base_size = 12, base_family = "", ...)
```

## Arguments

- base_size:

  Base font size in points.

- base_family:

  Base font family. The default, `""`, uses the graphics device's
  default family.

- ...:

  Additional arguments passed to
  [`ggplot2::theme()`](https://ggplot2.tidyverse.org/reference/theme.html).
  They are applied after the fourfold defaults.

## Value

A complete ggplot2 theme.

## Details

`base_size` and `base_family` control all text, including the category
labels and cell counts drawn by
[`geom_fourfold()`](https://gavinklorfine.com/ggfourfold/reference/geom_fourfold.md).
These grow with the size of each panel, so larger plots get larger
labels, but never shrink below five-sixths of `base_size` (10 points by
default). Additional theme elements passed through `...` are applied
last and therefore override the defaults.

The theme sets no `aspect.ratio`. The display stays round, and the
panels square by default, because
[`geom_fourfold()`](https://gavinklorfine.com/ggfourfold/reference/geom_fourfold.md)
adds a coordinate system with `ratio = 1` (see the Coordinate systems
section of
[`geom_fourfold()`](https://gavinklorfine.com/ggfourfold/reference/geom_fourfold.md)).
Passing `aspect.ratio` through `...` fixes the panel's shape and
overrides that ratio, so circles become ellipses when the ranges of the
`x` and `y` axes differ, for example when a missing value keeps a place
on one axis. Therefore, it is recommended to leave `aspect.ratio` unset.

This theme uses ggplot2's theme-derived geom defaults and requires
ggplot2 4.0.0 or later.

## See also

[`geom_fourfold()`](https://gavinklorfine.com/ggfourfold/reference/geom_fourfold.md)
and
[`ggplot2::theme()`](https://ggplot2.tidyverse.org/reference/theme.html)

## Examples

``` r
ucb <- as.data.frame(UCBAdmissions)

ggplot2::ggplot(
  ucb,
  ggplot2::aes(x = Gender, y = Admit, weight = Freq)
) +
  geom_fourfold() +
  ggplot2::facet_wrap(ggplot2::vars(Dept), ncol = 3) +
  theme_fourfold(base_size = 12)

```
