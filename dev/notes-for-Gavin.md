# ggfourfold vs. vcd::fourfold: notes from a real use

Michael Friendly, 2026-11-10 (drafted with Claude)

Package: **ggfourfold 0.1.0** (CRAN), compared with `vcd::fourfold()`.

## The task

Seven fourfold displays, one for each binary predictor (Female, Employed, Related,
Financial, and three AI guesses) against `Killer`, for 166 characters in the 12 Miss
Marple novels (Lutz, 2026, *Significance*). The data are individual-level: one row per
character, with 0/1 columns. Code: `AgathaChristie.R`, chunk `fig-fourfold`.

## Bottom line

ggfourfold was **easier** than `vcd::fourfold()`, and the result looks better. The one
real gap is that there's no way to show which variable is which.

## The two versions

**vcd**: build a 2 × 2 × 7 array by hand, then plot:

```r
ff <- array(sapply(ff_vars, function(v) xtabs(reformulate(c(v, "Killer")), fac)),
            dim = c(2, 2, length(ff_vars)),
            dimnames = list(Predictor = c("No", "Yes"), Killer = c("No", "Yes"),
                            Variable = sprintf("%s (OR = %.1f)", labels[ff_vars],
                                               uni[labels[ff_vars], "OR"])))
fourfold(ff, mfcol = c(2, 4), std = "margins", conf_level = 0.95, fontsize = 10)
```

**ggfourfold**: stack into long form, then facet:

```r
ff_long <- do.call(rbind, lapply(seq_along(ff_vars), function(i)
  data.frame(Variable = ff_lab[i], Predictor = fac[[ff_vars[i]]],
             Killer = factor(fac$Killer, labels = c("Innocent", "Killer")))))
ff_long$Variable <- factor(ff_long$Variable, levels = ff_lab)

ggplot(ff_long, aes(x = Predictor, y = Killer)) +
  geom_fourfold() +
  facet_wrap(vars(Variable), nrow = 2) +
  theme_fourfold()
```

## What was easier with ggfourfold

- **Data step.** The amount of code is about the same, but long form is the natural shape
  for individual-level data. With vcd, I had to assemble the array and its `dimnames` by hand.
  
- **Layout just worked.** With vcd, my first try (`par(mfrow = c(2, 4))` and a loop)
  drew all seven panels on top of each other, because `fourfold()` uses grid graphics and
  ignores `par()`. Its own `mfrow` argument then filled the panels column by column, so I
  needed `mfcol` to get row order. Even then the panels were small, with a lot of white
  space. `facet_wrap()` filled the page with no extra work.
  
- **Titles.** Facet labels can hold two lines ("Financial gain" / "OR = 51.8"). vcd adds a
  "Variable:" prefix to each panel title.
  
- **Details handled for me.** Counts move out to the corners when the rings reach them,
  Holm adjustment for the shading is the default (as in vcd), and `ggsave()` and Quarto
  needed no special handling.

## Where it was harder

1. **There's no way to show variable names.** `theme_fourfold()` builds on
   `theme_void()`, so there are no axis titles. With No/Yes levels on both variables, a
   reader can't tell which is the predictor and which is `Killer`. vcd labels each side as
   "Killer: No", and so on. My workaround was to rename the `Killer` levels to
   Innocent/Killer and put the predictor's name in the facet title. That works here, but it
   won't always be possible.

2. **Turning axis titles back on misleads.** I tried

   ```r
   labs(x = "Financial gain") + theme(axis.title.x = element_text())
   ```

   The title appears at the bottom, right next to the **y** levels, because the `x` levels
   are drawn on the left/right sides and the `y` levels on top/bottom. A reader would pair
   "Financial gain" with "Killer".

   *Suggestion:* an argument such as `labels = c("levels", "both")`, where `"both"` draws
   "Var: level" on each side, as `label_both` does for facets and as vcd does. At the
   least, the docs should say how `x` and `y` map to the sides of the display.

3. **Minor, versions:** the package was already at 0.1.0 before the CRAN submission. A
   local build from 2026-10-05, before the switch from ticks to the diagonal band, was
   therefore indistinguishable by version from the CRAN release. Using a `0.1.0.9000`-style
   dev version between releases would avoid that.
