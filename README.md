
<!-- README.md is generated from README.Rmd. Please edit README.Rmd. -->

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![r-universe](https://gklorfine.r-universe.dev/ggfourfold/badges/version)](https://gklorfine.r-universe.dev/ggfourfold)
[![Last
Commit](https://img.shields.io/github/last-commit/gklorfine/ggfourfold)](https://github.com/gklorfine/ggfourfold)
[![Docs](https://img.shields.io/badge/pkgdown%20site-blue)](https://gavinklorfine.com/ggfourfold/)
<!-- badges: end -->

<!--
[![CRAN_Status_Badge](http://www.r-pkg.org/badges/version/ggfourfold)](https://CRAN.R-project.org/package=ggfourfold)
[![Downloads](http://cranlogs.r-pkg.org/badges/grand-total/ggfourfold)](https://cran.r-project.org/package=ggfourfold)
-->

# ggfourfold <img src="man/figures/logo.png" align="right" height="200px" /><br><sub>Fourfold Displays for ‘ggplot2’</sub>

A **ggplot2** extension that provides a geom and theme for creating
fourfold displays. Inspired by the `fourfold` SAS macro (Friendly, 2000)
and **vcd** R package (Meyer et al., 2026).

## Installation

The current development version (0.1.0) of **ggfourfold** can be
installed from [R-universe](https://gklorfine.r-universe.dev/ggfourfold)
or directly from the [GitHub
repository](https://github.com/gklorfine/ggfourfold) with:

``` r
# == R-universe ==
install.packages("ggfourfold", repos = "https://gklorfine.r-universe.dev")

# == GitHub ==
#install.packages("pak")
pak::pak("gklorfine/ggfourfold")
```

## Overview

A fourfold display (Friendly, 1994; Friendly & Meyer, 2016, Section 4.4)
is a visualization of a $2 \times 2$ table, or $2 \times 2 \times k$
tables via faceting. It consists of a circle that is split into
quadrants, giving a segment for each cell in the table. Unlike a pie
chart, the angles of the segments are fixed, and it is the radii that
vary.

In an unstandardized display, these quadrants have area proportional to
the sample size of their corresponding cell. Standardized displays
rescale the table so that the row and/or column totals are equal, while
preserving the sample odds ratio. This helps with comparing the
quadrants when one group is much larger than another. A fully
standardized display (the default) equates both the row *and* column
totals, and gives a visual interpretation of the sample odds ratio:

$$\hat{\theta} = \frac{n_{11} / n_{12}}{n_{21} / n_{22}}
             = \frac{n_{11} \, n_{22}}{n_{12} \, n_{21}} .$$

In a fully standardized display, the quadrants form a circle if
$\hat{\theta} = 1$. Otherwise, one diagonal pair of quadrants is larger
than the other, with this discrepancy reflecting the strength of
association between variables. The diagonal with more cases than
expected under independence is drawn in blue, with the other pair being
drawn in red. Intense shading is applied when $\hat{\theta}$ differs
significantly from 1, after adjusting for multiple testing across
panels. Confidence rings are also drawn, with the rings of adjacent
quadrants overlapping *iff* the 95% confidence interval for $\theta$
includes 1.

For more detail on fourfold displays and their use in this package, see
the [introductory
vignette](https://gavinklorfine.com/ggfourfold/articles/ggfourfold.html).

## Examples

The below examples use the `UCBAdmissions` data (Bickel et al., 1975),
which contains applicants to the six largest graduate departments at UC
Berkeley in 1973, classified by admission and gender. They examine the
association between gender (`Gender`) and admission (`Admit`), both
overall and within each department (`Dept`).

``` r
library(ggfourfold)
library(ggplot2)
```

To construct a fourfold display with **ggfourfold**, you add
`geom_fourfold()` and `theme_fourfold()` to a `ggplot2::ggplot()` call.
Then use `ggplot2::aes()` to map the two binary variables to `x` and
`y`. If the data are in frequency form, also supply a mapping for
`weight`. For a review of the different forms of categorical data in R,
and how to convert among them, see the **vcdExtra** (Friendly &
Klorfine, 2026) vignettes [*1. Creating and manipulating frequency
tables*](https://friendly.github.io/vcdExtra/articles/a1-creating.html)
and [*1a. Steps Toward Tidy Categorical Data
Analysis*](https://friendly.github.io/vcdExtra/articles/a1a-convert-collapse.html).

The below code constructs an unstandardized fourfold display from the
`UCBAdmissions` data. These data are in table form, so the first step is
to convert them into frequency form using `as.data.frame()`. Without
faceting, `geom_fourfold()` sums the counts over the excluded variables,
in this case, only `Dept`.

``` r
ucb <- as.data.frame(UCBAdmissions) # Table form -> frequency form

ggplot(ucb, aes(x = Gender, y = Admit, weight = Freq)) +
  geom_fourfold(std = "ind.max") +  # For unstandardized display
  theme_fourfold()
```

![](man/figures/README-ucb_unstd_noFacet-1.png)<!-- -->

Depicting raw counts, unstandardized displays are constructed by
specifying `std = "ind.max"` in `geom_fourfold()`. Quadrant sizes mostly
reflect that more men applied than women, and that most applicants were
rejected, so the association is difficult to discern. The default, fully
standardized display adjusts for these differences, making the
association easier to see.

``` r
ggplot(ucb, aes(x = Gender, y = Admit, weight = Freq)) +
  geom_fourfold() +
  theme_fourfold()
```

![](man/figures/README-ucb_std_noFacet-1.png)<!-- -->

This display depicts an association between `Admit` and `Gender` and
appears to show a gender bias; that is, men are significantly more
likely to be admitted than women, pooling over department. This is
illustrated through the much larger area and intense blue shading of the
male-admitted and female-rejected quadrants, along with the
non-overlapping confidence rings of adjacent quadrants. The white
diagonal line through the male-admitted and female-rejected quadrants
marks the direction of association.

To see the relationship between `Admit` and `Gender` across `Dept`, add
`ggplot2::facet_wrap()` or `ggplot2::facet_grid()` to draw one display
per `Dept`. Panels are fully standardized individually, facilitating
direct comparison.

``` r
ggplot(ucb, aes(x = Gender, y = Admit, weight = Freq)) +
  geom_fourfold() +
  facet_wrap(vars(Dept), labeller = label_both) +
  theme_fourfold()
```

![](man/figures/README-ucb_facet-1.png)<!-- -->

A different picture emerges after faceting by `Dept`; namely, there is
no significant association between `Admit` and `Gender` in departments
`B` through `F`, shown through pale shading. Further, there exists a
significant association in department `A`, though it is in the reverse
direction of the effect observed when `Dept` was pooled. This is a
well-known example of [Simpson’s
paradox](https://en.wikipedia.org/wiki/Simpson%27s_paradox), arising
because most women applied to departments with lower admission rates,
lowering the overall female rate of admission.

### Square displays

Four squares can be drawn instead of quarter-circles with
`shape = "square"`. Each square has the same area as the quarter-circle
it replaces, so both shapes display a table with identical areas. The
line through the center ends just past the outer corners of the two
squares it marks. A square, confidence ring, or line that reaches the
corners of the frame where the cell counts are drawn moves the counts of
every panel just outside those corners; here they all stay inside.

``` r
ggplot(ucb, aes(x = Gender, y = Admit, weight = Freq)) +
  geom_fourfold(shape = "square") +
  facet_wrap(vars(Dept), labeller = label_both) +
  theme_fourfold()
```

![](man/figures/README-ucb_square-1.png)<!-- -->

## References

<div id="refs" class="references csl-bib-body hanging-indent"
data-entry-spacing="0" data-line-spacing="2">

<div id="ref-Bickel-etal:75" class="csl-entry">

Bickel, P. J., Hammel, J. W., & O’Connell, J. W. (1975). Sex bias in
graduate admissions: Data from Berkeley. *Science*, *187*, 398–403.

</div>

<div id="ref-Friendly:94:TR217" class="csl-entry">

Friendly, M. (1994). *A fourfold display for 2 by 2 by $k$ tables* (No.
217). York University, Psychology Dept.
<https://datavis.ca/papers/4fold/4fold.pdf>

</div>

<div id="ref-vcd:Friendly:2000" class="csl-entry">

Friendly, M. (2000). *Visualizing categorical data*.
<span class="sans-serif">SAS</span> Institute.
<http://www.math.yorku.ca/SCS/vcd/>

</div>

<div id="ref-vcdExtra:package" class="csl-entry">

Friendly, M., & Klorfine, G. (2026).
*<span class="nocase">vcdExtra</span>: ’<span class="nocase">vcd</span>’
extensions and additions*.
<https://doi.org/10.32614/CRAN.package.vcdExtra>

</div>

<div id="ref-FriendlyMeyer:2016:DDAR" class="csl-entry">

Friendly, M., & Meyer, D. (2016). *Discrete data analysis with R:
Visualization and modeling techniques for categorical and count data*.
Chapman & Hall/CRC. <http://ddar.datavis.ca>

</div>

<div id="ref-vcd:package" class="csl-entry">

Meyer, D., Zeileis, A., Hornik, K., & Friendly, M. (2026). *Vcd:
Visualizing categorical data*.
<https://doi.org/10.32614/CRAN.package.vcd>

</div>

</div>
