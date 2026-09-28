# Theme for fourfold displays

`theme_fourfold()` supplies a square, uncluttered panel and responsive
typography for
[`geom_fourfold()`](https://gavinklorfine.com/ggfourfold/reference/geom_fourfold.md).
It also styles facet strips like fourfold stratum headings and provides
compact spacing that remains readable in both the RStudio plot pane and
exported graphics.

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
and count labels drawn inside
[`geom_fourfold()`](https://gavinklorfine.com/ggfourfold/reference/geom_fourfold.md).
Those labels respond to the physical panel size while retaining a
readable lower bound. Additional theme elements passed through `...` are
applied last and therefore override the defaults.

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
