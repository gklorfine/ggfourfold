# Marginal fourfold displays for 2 × 2 × R × C tables

**Discussed 2026-09-28** (GK, with Claude; two independent statistician reviews). This file
records the interpretation of MF's idea, the evidence gathered, the current plan, and the
decisions still outstanding. It supersedes the premise of the three items in
`issues/TASKS.md`, "Multi-way tables: pooling and homogeneity" (MF, 2026-09-28), which are
built on collapsed tables; see [Changes to MF's TASKS entries](#9-changes-to-mfs-tasks-entries).

Numbers below use Titanic without the crew as a 2 × 2 × 2 × 3 table (Sex × Survived ×
Age × Class), unless stated otherwise:

```r
d <- subset(as.data.frame(Titanic), Class != "Crew"); d$Class <- droplevels(d$Class)
x <- xtabs(Freq ~ Sex + Survived + Age + Class, d)
```

The full table cannot be plotted at present: the Child × Crew stratum is empty and
`geom_fourfold()` aborts with "fourfold panel 4 must have a positive total".

## Contents

1. [The idea and its interpretation](#1-the-idea-and-its-interpretation)
2. [What a margin panel shows](#2-what-a-margin-panel-shows)
3. [Rings and colour in margin panels](#3-rings-and-colour-in-margin-panels)
4. [Showing whether pooling is justified](#4-showing-whether-pooling-is-justified)
5. [Zero cells and uninformative strata](#5-zero-cells-and-uninformative-strata)
6. [Standardization and count labels](#6-standardization-and-count-labels)
7. [Identifying margin panels](#7-identifying-margin-panels)
8. [Margin shading](#8-margin-shading)
9. [Changes to MF's TASKS entries](#9-changes-to-mfs-tasks-entries)
10. [Implementation plan](#10-implementation-plan)
11. [Outstanding decisions](#11-outstanding-decisions)
12. [Evidence](#12-evidence)
13. [Notes for vcdExtra](#13-notes-for-vcdextra)
14. [Summary for MF](#14-summary-for-mf)

## 1. The idea and its interpretation

MF, `dev/fourfold-ideas.md`:

> For the 2 x 2 x R x C case (cf `woolf_test()`) showing the fourfold plot for the marginal
> 2 x 2 R & 2 x 2 C tables would show the effect of pooling over R or C or both, assuming
> the odds ratios are equal.

This is not the R × C grid itself: that already exists through
`facet_grid(rows = vars(R), cols = vars(C))`. It is an **(R + 1) × (C + 1)** grid:

| | C₁ … C_C | extra column |
|---|---|---|
| R₁ … R_R | the R·C strata | each row pooled over C |
| extra row | each column pooled over R | corner: pooled over both |

`vcdExtra::woolf_test()` tests homogeneity of the stratum odds ratios; the development
version (`~/Non-iCloud/Data-Vis_Lab/packages/vcdExtra/`) accepts 2 × 2 × R × C arrays and
has `decompose = TRUE` and `woolf_twoway()`. The display is meant to show what Woolf's test
is for: whether the stratum odds ratios can be pooled.

**GK's goal:** the margin panels should visualize the purpose of Woolf's test. Odds ratios
are non-collapsible.

**What exists today.** `facet_grid(R ~ C, margins = TRUE)` already draws the grid with the
current geom. ggplot2 copies the data into "(all)" panels, and the geom sums the counts per
panel, so the margin panels are **collapsed** tables. Their odds ratios match the pooled
tables computed by hand (Titanic: by Age 1.99, 12.60; by Class 67.09, 44.07, 4.07; corner
10.45). MF's prototype `dev/marginal-fourfold.R` uses this with `vcdExtra::Detergent`.

## 2. What a margin panel shows

Notation: for stratum (i, j), yᵢⱼ is the log odds ratio and
wᵢⱼ = (1/n₁₁ + 1/n₁₂ + 1/n₂₁ + 1/n₂₂)⁻¹ its Woolf (inverse-variance) weight. Woolf's
statistic is Q = Σ wᵢⱼ (yᵢⱼ − ȳ_w)², on k − 1 df, where ȳ_w = Σ w y / Σ w. `woolf_test()`
returns ȳ_w as `expected`.

Candidates for the odds ratio a margin panel draws:

| Option | What it is |
|---|---|
| Collapsed | odds ratio of the table with counts summed over the pooled strata |
| Woolf | exp(ȳ_w) over the pooled strata |
| Mantel–Haenszel | the MH common odds ratio over the pooled strata |
| Conditional MLE | common odds ratio from a stratified logistic model / exact CMH |

### Why not the collapsed table

- **Non-collapsibility.** With two strata that each have odds ratio 4, and Z independent of
  X (baseline risks 0.1 and 0.8), the collapsed odds ratio is 2.03. The Woolf pooled
  estimate is 4.00 and Woolf's test gives p = 1.00. A collapsed margin would show a
  discrepancy the test correctly says is not there. (Reviewer 2: 2.02 with risks .13/.87,
  2.58 with .20/.80.) Equal odds ratios are not enough for collapsibility; Z must also be
  conditionally independent of X given Y, or of Y given X.
- The collapsed table mixes heterogeneity, confounding and non-collapsibility.
- It would draw the "second fault" described in vcdExtra's `issues/woolf.md`: a log odds
  ratio of summed counts is not a weighted average of the stratum log odds ratios.
- It is the right display for **Simpson's paradox** (UCBAdmissions: collapsed 1.84,
  MH 0.905), which is a different question.

### Why Woolf

- ȳ_w is exactly the reference Woolf's statistic measures departures from.
- The grid matches nested weighted least-squares models fitted to the RC values yᵢⱼ with
  weights wᵢⱼ (Fix 2 in vcdExtra's `issues/woolf.md`):
  - corner = fit of `y ~ 1`, whose weighted SSE S₀ is the overall Woolf statistic;
  - extra column = fits of `y ~ row`, the within-row weighted means;
  - extra row = fits of `y ~ col`;
  - cells = the saturated model.
- Verified (reviewer 1) to about 1e-13 on Titanic, the counterexample in `issues/woolf.md`,
  a random 2 × 2 × 4 × 3 table and 2000 further random tables.
- A stratum's 95% ring excludes the Woolf reference exactly when its term in Q,
  wᵢⱼ(yᵢⱼ − ȳ_w)², exceeds 3.84 (with the same zero-cell rule; reviewer 2, checked on
  Titanic).

### Qualifications (reviewer 1)

- "Comparing the cells with their margin panel is the test" is exact only against the
  **corner**. Comparing cells with a row margin gives the within-row tests, which add up
  to S_R. The grid shows two exact splits: S₀ = Q_R + S_R and S₀ = Q_C + S_C, where
  Q_R = Σᵣ w_r+ (ȳ_r − ȳ)² is the weighted spread of the row margins around the corner.
- The test weights departures, so equal-looking departures are not equal contributions.
  Child × 1st sits 3.36 log units from the corner but adds 2.3 to Q; Adult × 3rd sits 0.58
  away and adds 8.4. Adult × 3rd carries 63% of the weight, so the corner is largely that
  one stratum. Its naive standardized departure (y − ȳ)√w is −2.89; with the correct
  variance 1/w − 1/W it is −4.73. The 3.84 link above uses the naive version.
- The fully standardized drawing compresses large odds ratios: with
  p = √θ / (1 + √θ), θ = 49 and θ = 55 give p = 0.875 and 0.881.
- The additive model `y ~ row + col` appears nowhere in the grid. Row margin + column
  margin − corner differs from the additive fit by up to 0.46 log units (Titanic), 0.80
  (counterexample) and 0.93 (random table), so the grid cannot show interaction.
- Q_R and Q_C are both unadjusted. Q_R + Q_C + S_A ≠ S₀ under unequal weights (Titanic
  68.82 vs 63.19; counterexample 76.50 vs 85.23; random 4 × 3 table 235.2 vs 176.5; over
  2000 random tables the sum exceeds S₀ 60% of the time, 5th–95th percentiles of the
  relative gap −0.39 and +0.22). The sum is exact when the weights are separable,
  wᵢⱼ = aᵢbⱼ. Unadjusted Q_R follows χ²(R − 1) only with no column effect or separable
  weights. The display must not imply an additive decomposition.
- Under heterogeneity, the pooled value estimates a weighted average whose weights depend
  on the sample sizes. Margins can be skewed by where the weight sits: 91% of the Child
  weight is 3rd class; the Adult/Child margin ratio is 4.91, but 3.03 adjusting for Class
  in the additive model.

### The case for Mantel–Haenszel (reviewer 2)

Reviewer 2 recommended MH as the default: in well-filled tables Woolf, MH and the
conditional MLE agree, and where they differ (sparse strata, zero cells) Woolf is the one
that fails. MH and the conditional MLE also have a nested structure (logit models with
`X + X:R`, etc.), with likelihood-ratio tests on the count scale and no 0.5 correction.
See the simulation in [Evidence](#12-evidence). An independent rerun with a different
design (20 strata of 16, 8 per group, OR 3, baseline risks 0.2–0.6, 2000 replications)
agreed: log-scale bias −0.054 (Woolf) vs 0.003 (MH); Woolf's test rejected 0.6% of the
time at nominal 5%.

Most of the Titanic gap between Woolf and MH comes from two uninformative strata (see
[section 5](#5-zero-cells-and-uninformative-strata)). With the per-stratum zero rule and
those strata dropped:

| Margin | Woolf | Mantel–Haenszel |
|---|---|---|
| 1st, 2nd, 3rd | 72.46, 67.69, 3.99 | 72.46, 67.69, 3.95 |
| Child | 2.22 | 2.22 |
| Adult | 9.46 | 12.10 |
| Corner | 8.06 | 10.24 |

The remaining gaps are where the strata are heterogeneous (within-Adult Q ≈ 52 on 2 df):
there is no common odds ratio to estimate, and each estimator weights the strata
differently. (Reviewer 2, Adult row: Woolf 9.5, MH 12.1, conditional MLE 12.8; corner
Woolf 7.8, MH 10.2, conditional MLE 11.1, collapsed 10.4.)

On Detergent (MF's example, see [Evidence](#12-evidence)) collapsed, Woolf and MH agree
within 0.02 on the log scale, so it cannot show the difference between them.

### Decision (GK, 2026-09-28)

- `pooled = c("woolf", "mh")`, default `"woolf"`, both in the first version. No
  `"collapsed"` option.
- Consequence: `facet_grid(margins = TRUE)` will no longer draw collapsed tables, so the
  display no longer shows non-collapsibility or Simpson's paradox. MF's entry and his ring
  prototype rely on that view, so **MF needs to agree** (see
  [section 11](#11-outstanding-decisions)).
- Breslow–Day and a "test follows estimator" pairing (reviewer 2's suggestion) are out of
  scope for now.

## 3. Rings and colour in margin panels

**Rings keep their usual meaning in every panel** (agreed in discussion).

- In a stratum panel, the rings are that stratum's 95% interval, as now and as in
  `vcd::fourfold()`: adjacent rings overlap iff the interval includes 1.
- In a margin panel, the rings are the 95% interval of the pooled odds ratio, built the
  same way, with SE = 1/√Σw over the pooled strata (for `"mh"`, the Robins–Breslow–
  Greenland variance, as in `mantelhaen.test()`). They answer the same question: is the
  pooled odds ratio different from 1?
- Assumptions: independent strata and weights treated as known. The SE does not require
  homogeneity (Var(Σwy/Σw) = 1/W for any stratum means), but under heterogeneity the
  interval is for a sample-size-weighted average. At Titanic's stratum sizes, simulated
  under a common odds ratio, the corner's interval covered 94.0% (reviewer 1). Woolf's SE
  was conservative in sparse data (0.28 vs actual 0.25; reviewer 2).
- **Caveat for the docs:** under heterogeneity the margin rings are narrow around an
  average that means little. Adult margin: 9.46, rings 6.77–13.22, while its strata range
  from 4.41 to 72.46. A random-effects (DerSimonian–Laird) interval is about 3.3–198
  (reviewer 1; reviewer 2's corner: Woolf 5.7–10.7 vs DL 1.9–38.9).
- **Rejected:** restyling margin rings (dashed, faded, omitted) when the homogeneity test
  rejects. It would make one element carry two different tests, and a dashed ring would
  read as "less sure the odds ratio differs from 1". Also rejected: random-effects rings,
  which would give margin rings a different meaning from every other ring.

**Colour emphasis.**

- Margin panels must be excluded from the Holm adjustment across panels. They are not
  independent tests. Evidence:
  - Titanic, Child × 3rd: adjusted p 0.303 with strata only, 0.334 with margins.
  - Detergent (MF's figure): High × Hard is 0.034 with strata only (drawn intense) and
    0.051 with margins (drawn pale). High × Medium 0.023 → 0.031, Low × Hard 0.024 → 0.033.
- The margin panels' own emphasis would come from a test of pooled odds ratio = 1 (a Woolf
  z-test for `"woolf"`, the CMH test for `"mh"`). Outstanding: whether those p-values are
  left unadjusted, so each margin panel answers its own question, or Holm-adjusted as a
  separate group of the R + C + 1 margin panels. (Holm stays valid although the margins
  overlap, since it doesn't assume independence.) On Detergent the choice changes no colour
  at 0.05: e.g. Low 0.011 unadjusted vs 0.022 adjusted, Soft 0.45 either way.

## 4. Showing whether pooling is justified

Each margin panel gets the Woolf homogeneity test of the strata it pools:

| Margin panel | Strata pooled | df |
|---|---|---|
| extra column (a row level) | C | C − 1 |
| extra row (a column level) | R | R − 1 |
| corner | R·C | RC − 1 (the overall `woolf_test()`) |

Titanic examples (per-stratum zero rule):

| Margin | Strata | Pooled | Rings | Woolf test |
|---|---|---|---|---|
| 3rd class | 2.22, 4.41 | 3.99 | 2.77–5.73 | Q = 1.7, df 1, p = 0.19 |
| Adult | 72.46, 67.69, 4.41 | 9.46 | 6.77–13.22 | Q = 52.3, df 2, p = 4.5e-12 |

The 3rd-class margin is a fair summary; the Adult margin is an average no class has,
pulled toward 3rd class because it has the most weight.

- **Current plan:** add Q, df and p for each margin panel as extra columns of the layer's
  computed data. Nothing is drawn by default. Today such columns can only be read with
  `ggplot2::layer_data()`: `StatFourfold` is not exported and the existing columns
  (`odds_ratio`, `p_value`, `p_adjusted`, …) are undocumented, so another layer cannot use
  them through `after_stat()`. How users should reach them is part of the computed-variables
  decision (section 11).
- Showing one test per margin panel is several tests at once (multiple comparisons).
- **Dropped:** a faint outline of the pooled odds ratio inside each stratum panel (GK: too
  busy). MF's reference ring is deferred to a later release; see
  [section 9](#9-changes-to-mfs-tasks-entries).
- **Not to be used:** `woolf_test(decompose = TRUE)` alongside the plot. Its Rows and Cols
  values are computed from collapsed counts, the construction vcdExtra's `issues/woolf.md`
  shows is invalid (see [section 9](#9-changes-to-mfs-tasks-entries)).

## 5. Zero cells and uninformative strata

### The 0.5 correction rule

An odds ratio ad/bc is 0, infinite or undefined when a cell is zero, so 0.5 is added
first. There are two rules for which cells get it:

| Rule | What gets +0.5 | Used by |
|---|---|---|
| Per stratum | the 4 cells of a stratum that itself has a zero | `vcd::fourfold()`, ggfourfold |
| Whole table | every cell of every stratum, if any cell anywhere is zero | `vcd::woolf_test()`, `vcd::loddsratio()` (default), `vcdExtra::woolf_test()` |

The inconsistency comes from vcd itself (vcd 1.4.13; `fourfold`: `f <- x[, , i]; if
(any(f == 0)) f <- f + 0.5`; `woolf_test`: `if (any(x == 0)) x <- x + 1/2`; `loddsratio`:
`correct = any(x == 0)` over the whole array, though `correct` also accepts a numeric array
of per-cell additions).

Effect on Titanic: Adult × 1st has no zeros, so its panel shows 72.46, but `woolf_test()`
uses 64.34 because Child strata contain zeros. The margins can match the stratum panels
drawn next to them (per stratum) or `woolf_test()$expected` (whole table), not both:
Adult margin 9.46 vs 9.49.

| Titanic, all strata | Per stratum | Whole table |
|---|---|---|
| Corner | 7.827 | 7.825 |
| Age margins | 1.957, 9.459 | 1.933, 9.486 |
| Class margins | 53.25, 57.87, 3.986 | 48.96, 54.71, 3.952 |
| Within-Age Q | 0.930, 52.26 | 0.914, 51.54 |

- Both reviewers prefer per stratum: a stratum's value doesn't depend on other strata, the
  stratum rings stay consistent with their Q terms, and it was less biased in sparse data
  (−0.08 vs −0.20 on the log scale; reviewer 2).
- The within-row identities only hold if the within-row statistics use the same y and w.
  Running `woolf_test()` on the Adult slice alone skips the correction (no zeros there) and
  gives 52.26, not 51.54.
- The rule matters for `"woolf"`; it does not arise for `"mh"`.

**Decision (GK, 2026-09-28): per stratum**, matching `vcd::fourfold()`, which the geom
reproduces, and the geom's current behaviour for the stratum panels. Margin estimates use
the same per-stratum y and w as the panels. Consequence to document: for tables with a zero
anywhere, the margins will not equal `woolf_test()$expected` or `loddsratio()` on the whole
table (Titanic Adult margin 9.46 vs 9.49; Adult × 1st 72.46 vs 64.34). Tests against
`vcdExtra::woolf_test()` must use tables without zeros, or apply the per-stratum rule
before calling it. Whether vcdExtra's `woolf_test()` should switch is a separate question
([section 13](#13-notes-for-vcdextra)).

### Uninformative strata

Every 1st- and 2nd-class child survived, so those strata have an empty row/column and an
odds ratio of 0/0: they carry no information about the odds ratio. The 0.5 correction
turns them into 0.27 and 1.17 with positive weight.

- The Child × 1st stratum has 5% of the 1st-class weight but pulls the 1st-class margin
  from 72.46 to 53.2 (per stratum) or 49.0 (whole table).
- It creates a spurious within-1st-class Q = 5.85 on 1 df.
- Such strata count toward the df: all six Titanic strata give Q = 63.4 on 5 df (per
  stratum); dropping the two gives 60.2 on 3 df. With the crew kept, an all-zero stratum
  enters `woolf_test()` with y = 0 and w = 1/8, giving 7 df.
- MH ignores them automatically (they add zero to both of its sums), as does the
  conditional MLE.

**Proposed rule:** leave strata with an empty row or column out of the margin estimates and
the test's df, and flag them. Edge cases: a margin with one informative stratum has 0 df
(no test); a margin with none has nothing to pool (drawn empty).

- *Leaving them out*: the 1st-class margin becomes Adult × 1st alone (72.46, 0 df, no
  homogeneity test); the corner's test becomes Q = 60.2 on 3 df instead of 63.4 on 5.
- *Flagging them*: e.g. a message naming the strata left out of the pooled estimates
  ("Child × 1st and Child × 2nd have an empty row …"), and/or a computed variable marking
  each stratum as informative or not. The stratum panels are still drawn as usual.

**Relation to the existing task.** This is the same kind of table as the `issues/TASKS.md`
item "Handle tables with an entirely empty row or column explicitly", which already lists
these Titanic panels as its real-data example (NaN lower rings, `margin = 1` NaN radii). The
two questions are separable:

- how to *draw* such a panel (existing task, general);
- how such a stratum *enters a margin* (this feature).

They only interact if the existing task decides to reject such tables with an error; the
panels would then never reach the margins.

**Question for MF** (GK, 2026-09-28): should uninformative strata be left out of the margin
estimates and the test's df, and flagged, as proposed? And should this be done as part of
the margin feature, before the existing empty row/column drawing task (suggested, since the
two are independent), or after it?

## 6. Standardization and count labels

| Setting | What it does |
|---|---|
| `std = "margins"`, `margin = c(1, 2)` (default) | "Fully standardized" (README): row and column totals equated, odds ratio kept. The drawing depends only on the odds ratio. |
| `std = "margins"`, `margin = 1` or `2` | Partly standardized: one set of totals equated; the drawing still depends on the other split. |
| `std = "ind.max"` | Unstandardized: each panel scaled by its own largest cell; areas show raw counts. |
| `std = "all.max"` | Unstandardized: every panel scaled by the largest cell in the layer, so panel sizes are comparable across panels. |

A margin panel has only a pooled odds ratio, not a table of counts. A fully standardized
display needs nothing else (radii √p on the diagonal and √(1 − p) off it,
p = √θ / (1 + √θ)); the other three settings need counts.

**Decision (GK, 2026-09-28): error.** When margin panels are present, `geom_fourfold()`
gives an informative error unless the display is fully standardized (`std = "margins"`,
`margin = c(1, 2)`). This covers `margin = 1` or `2`, `"ind.max"` and `"all.max"`. The
message should say that margin panels show a pooled odds ratio, which has no counts to
draw, and suggest the fully standardized default or dropping `margins = TRUE`. Both shapes
(`"circle"`, `"square"`) are allowed: fully standardized squares also depend only on the
odds ratio.

Option not taken (possible later): a **stand-in table**, the collapsed table's totals with
the odds ratio set to the pooled value, built with `.fourfold_table_with_or_and_margins()`
as for the confidence rings. Only then would `all.max` matter: the corner holds the largest
cell and would shrink every stratum panel, so margin panels would have to be left out of
the maximum (MF's suggestion).

### Margin-panel label (GK, 2026-09-28)

GK is fairly unsure about where the label should go (see below), but thinks printing counts
in margin panels would mislead, for two reasons:

- **No counts in margin panels.**
  - *Non-collapsibility.* Summed counts describe the collapsed table, and odds ratios are
    non-collapsible: the collapsed odds ratio can differ from every stratum's even when
    the strata agree and nothing is confounded
    ([section 2](#2-what-a-margin-panel-shows)). Printing summed counts presents the
    collapsed table as the summary of the strata.
  - *The drawn odds ratio is not the one the counts give.* The panel draws the pooled
    estimate, not the odds ratio of the summed counts. Titanic Adult margin: the summed
    counts 659, 106, 146 and 296 give 12.60, while the drawing shows the Woolf 9.46. In
    every other panel the printed counts and the shape agree, so a reader would expect
    the same here.
- **Label text:** `Pooled OR = 9.46`. The estimator is named in the documentation, not the
  panel. Wordings considered:

  | Label | Verdict |
  |---|---|
  | `Pooled OR = 9.46` | chosen: plain, the same for either estimator |
  | `Woolf OR` / `MH OR` | names the estimator, but "Woolf OR" is not a familiar term |
  | `Common OR` | rejected: says the strata share one odds ratio (false for Adult, p ≈ 5e-12) |
  | `OR pooled over Class` | says what was pooled, but long; the corner needs "Age and Class" |
  | `θ̂ pooled` | compact, but harder to read; needs plotmath |

  Optional second line, not decided: `n = 1207` (the size that full standardization
  hides), or the homogeneity result, e.g. `Woolf p < 0.001`.
- **Placement (GK fairly unsure):** tentatively along the top, inside the frame. Possibly
  split either side of the vertical axis line: `Pooled` to the left, `OR = 9.46` to the
  right.
- **Note for MF:** the placement can be changed if you prefer something else.
- **Caveat from a mock-up** (Titanic grid, today's collapsed shapes, labels at y = 0.86,
  8 pt): the frame spans −1 to 1, and a fully standardized quadrant has radius √p
  (diagonal) or √(1 − p) (off-diagonal), p = √θ / (1 + √θ). A label along the top centre is
  overlapped when an upper quadrant's radius exceeds about 0.82, i.e. roughly θ > 4 or
  θ < 0.25 at that font size, before counting its confidence ring. In the mock-up the text
  sat on the navy upper-left sector, and was unreadable, in the Adult, 1st-class, 2nd-class
  and corner margins (collapsed 12.6, 67.1, 44.1, 10.4; the Woolf values 9.46, 72.46 and
  67.69 are similar or larger), and partly in the 3rd-class margin (4.07). Splitting the
  label around the vertical line avoids the line but not the sector. Alternatives:
  - **Top corners:** `Pooled` at the top-left count position, `OR = …` at the top-right.
    Clear in most panels; tight with very strong associations (the text touched the arc
    or the vertical line in the 1st- and 2nd-class margins).
  - **Stacked in the free top corner:** `Pooled` over `OR = …` in the top corner that holds
    the smaller, off-diagonal quadrant (top-right when θ > 1, top-left when θ < 1). Always
    clear of the circles, but the label changes side between panels.
  - **Outside the frame:** needs extra panel padding; the top already holds the axis label.
  - With `shape = "square"`, whichever is chosen needs the same reach check as the counts.

## 7. Identifying margin panels

- `.fourfold_compute_layer()` receives `layout`. `layout$layout` lists every panel's facet
  values, with `"(all)"` for margin panels (checked by tracing the function on Titanic).
  Reviewer 2's claim that a stratum aesthetic or a wrapper is needed is wrong.
- `layout$facet$params$margins` is `TRUE` with `margins = TRUE`, `FALSE` without, and
  `NULL` for `facet_wrap()` (checked). Require that `margins` is set as well as the
  `"(all)"` label, so a real level called "(all)" is not mistaken for a margin when margins
  are off. (With margins on, data that already contain "(all)" make ggplot2's
  `reshape_add_margins()` fail, per MF.)
- The strata of a margin panel are the non-margin panels that match it on every facet
  variable that is not "(all)".
- Support partial margins (`margins = "Temperature"`) and the single-variable case
  (`facet_grid(rows = vars(z), margins = TRUE)`, e.g. UCB by Dept).
- ggplot2's "(all)" label is not formally documented; a test should catch any change.
- Compute y and w once for the whole layer, with the per-stratum zero rule (section 5).
  Margin values come from the strata only, never from the "(all)" panels' own data.
- Compute the Woolf and MH quantities inside ggfourfold; don't import vcdExtra. Test
  against `vcdExtra::woolf_test()` and `mantelhaen.test()` (vcdExtra in Suggests), allowing
  for the zero-rule difference.

## 8. Margin shading

MF's `margin_background()` (`issues/TASKS.md`, `dev/marginal-fourfold.R`,
`dev/marginal-fourfold.png`) gives the "(all)" panels a light background (`#F5EEDC`) through
a stat that looks up `"(all)"` in `layout$layout`. A theme can't do it, and an ordinary
`geom_rect()` layer makes `reshape_add_margins()` fail.

- This is how margin panels stand apart from the strata; adopt it.
- Since the geom must identify margin panels anyway, the shading could be a
  `geom_fourfold()` argument instead of a separate exported function. That would drop the
  "must come before `geom_fourfold()`" rule and a second detection path. Not yet tested
  (the geom draws in normalized panel coordinates; a full-panel rectangle drawn first in
  `draw_panel()` should work).
- **CRAN release:** MF's case for including it now is that it "does not touch
  `geom_fourfold()`". But shipping it alone would promote today's version: collapsed
  tables with the Holm problem. Recommendation: ship it together with the margin changes.

## 9. Changes to MF's TASKS entries

`issues/TASKS.md`, "Multi-way tables: pooling and homogeneity":

1. **"Marginal fourfold displays"** — "Works already … No package changes are needed" holds
   only for collapsed tables. Under this plan the margins become pooled estimates, which
   needs geom changes.
2. **Link to `woolf_test(decompose = TRUE)`** — the entry says Detergent's pooled log odds
   ratios "match the Woolf decomposition" and suggests showing that output with the plot.
   They match because `decompose = TRUE` computes Rows and Cols from the same collapsed
   counts: its `rows$observed` and `cols$observed` are exactly the collapsed log odds ratios
   (−0.852, −0.408; −0.166, −0.681, −0.867). vcdExtra's `issues/woolf.md` shows that
   construction is invalid, using Detergent as its real-data failure (residual −0.096). The
   quoted Rows and Cols p-values (.096, .069) should not go in the docs; the per-margin Woolf
   tests replace them.
3. **Holm and `all.max`** — Holm: agreed, exclude margin panels. `all.max`: MF suggests
   leaving margin panels out of the maximum; GK decided instead that margin panels require
   the fully standardized display (an error otherwise), so the `all.max` question does not
   arise (section 6).
4. **`margin_background()`** — adopt; shading as a geom argument is an option; ship with
   the margin changes rather than before (see [section 8](#8-margin-shading)).
5. **Reference ring (deferred)** — when revived, use the same estimator as the margin panels
   (MF's prototype uses MH over all strata). A margin panel now draws its own pooled odds
   ratio, so a per-margin ring would coincide with its sectors; only a ring at the corner
   value adds information there. That answers MF's open question ("one common θ₀ … or, in
   each (all) panel, the MH estimate over the strata it pools").

## 10. Implementation plan

1. **Margin detection** — helper using `layout$layout` and `layout$facet$params$margins`;
   map each margin panel to its strata. Tests for full, partial and single-variable margins,
   `facet_wrap()`, no margins, and a real level named "(all)" with margins off.
2. **Layer-level stratum quantities** — y, w per stratum with the per-stratum zero rule
   (as `vcd::fourfold()`); flag uninformative strata.
3. **Margin estimates** — `pooled = c("woolf", "mh")`: pooled log odds ratio, SE, interval,
   test of odds ratio = 1; Woolf Q, df, p for the strata pooled. Margin panels are drawn
   from the pooled odds ratio (fully standardized radii) and its interval.
4. **Holm** — adjust across stratum panels only; margin emphasis per the decision in
   section 11.
5. **Standardization** — informative error when margin panels are present and the display
   is not fully standardized (`margin = 1` or `2`, `"ind.max"`, `"all.max"`); tests for each
   combination, with both shapes.
6. **Margin-panel label** — no counts; `Pooled OR = …` placed as in section 6 (placement
   to confirm with MF, allowing for the overlap caveat).
7. **Computed variables** — new columns (names agreed by GK, 2026-09-28):
   - `margin`: logical, whether the panel is a margin panel (name may change, see
     section 11);
   - `pooled_method`: `"woolf"` or `"mh"` (`NA` in stratum panels);
   - `n_strata`: number of strata pooled (informative strata only, if MF agrees to leave
     the others out; section 5);
   - `woolf_q`, `woolf_df`, `woolf_p`: the Woolf homogeneity test of the strata pooled
     (`NA` in stratum panels, and `woolf_q`/`woolf_p` when `woolf_df` is 0).

   In margin panels the existing columns `odds_ratio`, `standard_error`, `conf_low`,
   `conf_high` and `p_value` hold the pooled values.
8. **Shading** — `margin_background()` or a geom argument.
9. **Docs** — roxygen (`pooled`, margins behaviour, ring caveat under heterogeneity,
   non-collapsibility), a vignette section, NEWS. Example data: see section 11.
10. **Tests** (in addition to those above):
    - margin values equal independently computed weighted means; corner equals
      `exp(woolf_test()$expected)` on a table without zeros; `"mh"` equals
      `mantelhaen.test()$estimate`; SEs and intervals;
    - identities S₀ = Q_R + S_R and S₀ = Q_C + S_C;
    - stratum panels identical with and without margins (odds ratios, rings, radii), and
      Holm-adjusted p-values with margins equal those without;
    - zero cells, uninformative strata, a margin with one or no informative strata;
    - R = 1 or C = 1; unnamed dimnames; `std`/`margin` combinations;
    - `shape = "square"` with margins.
11. **Verification** (per `CLAUDE.md`) — compare diffs and statistical, numerical and
    visual output before and after; run R CMD check and the extrachecks list.

Files: `R/geom-fourfold.R` (`.fourfold_compute_layer()`, draw code, docs), tests, vignette,
`NEWS.md`, possibly `R/margin-background.R`.

## 11. Outstanding decisions

- [ ] **Confirm with MF** that margin panels show a pooled estimate rather than collapsed
  tables, and that dropping `"collapsed"` (and with it the non-collapsibility / Simpson's
  paradox view) is acceptable. In vcd usage "marginal 2 × 2 tables" means summed tables,
  so he may have meant collapsed. Decision for GK/MF.
- [X] **Zero-cell rule** — per stratum, matching `vcd::fourfold()` (GK, 2026-09-28; see
  section 5). Whether vcdExtra's `woolf_test()` should also switch is a vcdExtra question
  (section 13).
- [ ] **Uninformative strata — question for MF** — leave strata with an empty row or column
  out of the margin estimates and the test's df, and flag them (proposed)? Do it within the
  margin feature, before the existing empty row/column drawing task (suggested), or after?
  See section 5.
- [X] **Standardization** — margin panels require the fully standardized display; error
  otherwise (GK, 2026-09-28; see section 6). A stand-in table remains possible later, and
  only then would MF's `all.max` exclusion apply.
- [ ] **Margin-panel label placement** — text decided (`Pooled OR = …`, no counts, because
  counts would mislead: non-collapsibility, and the drawn odds ratio is not the one the
  counts give). GK is fairly unsure about placement; tentatively along the top inside the
  frame, possibly split around the vertical line.
  MF may change it. The top-centre position collides with large upper quadrants (see
  section 6); top corners or a stacked label in the free corner are the alternatives.
  Optional second line (n, or the homogeneity p) not decided. Decision for GK/MF.
- [ ] **Margin colour emphasis** — which test (Woolf z for `"woolf"`, CMH for `"mh"`), and
  whether the margin panels' p-values are left unadjusted or Holm-adjusted as their own
  group of R + C + 1 tests (section 3).
- [ ] **Computed variables** — names agreed (GK, 2026-09-28): `margin`, `pooled_method`,
  `n_strata`, `woolf_q`, `woolf_df`, `woolf_p` (section 10, step 7). Still open:
  - `margin` clashes with the existing `geom_fourfold(margin = c(1, 2))` argument (which
    totals to equalise); `is_margin` would avoid the ambiguity;
  - whether to document these, and the existing columns, as public (a naming commitment
    once on CRAN);
  - how users reach them (`layer_data()` only, as today, or an exported stat);
  - whether anything about the Woolf test is drawn.
- [ ] **Argument name** `pooled`. (`"mh"` ships in the first version: GK, 2026-09-28.)
- [ ] **Shading** — separate `margin_background()` or a geom argument; CRAN timing
  (recommended: with the margin changes). Decision for GK.
- [ ] **Example data for docs** — Detergent (MF's; estimators agree), Titanic without the
  crew (needs the uninformative-strata rule), UCB by Dept (single-variable margins).
- [ ] **Reference ring** (deferred) — estimator consistency with `pooled` when revived.

## 12. Evidence

### Reviewer 2 simulation

Common odds ratio under homogeneity, 2000 replications per scenario. Bias on the log
scale; coverage of each estimator's own 95% Wald interval; test size at nominal 5%.

| Scenario | Woolf (0.5 per stratum) | Woolf (0.5 everywhere) | MH | Conditional MLE | Unconditional MLE | Woolf / BD size |
|---|---|---|---|---|---|---|
| 6 large strata, OR 3 | bias .000, cov 95.2 | .000 | .001, 95.2 | .001 | .003 | 5.0 / 5.4 |
| mixed sizes (600 to 12), OR 3 | −.001, 95.0 | −.011 | .004, 94.8 | .003 | .008 | 1.0 / 4.6 |
| 20 strata of 16, OR 3 | −.082, 96.8 | −.203, 91.5 | .010, 95.3 | .005, 95.5 | +.082 | 0.1 / 4.9 |
| 20 strata of 20, rare outcome | −.277, 93.1 | −.371, 82.3 | .001, 95.9 | −.004, 96.0 | +.053 | 0.0 / 2.8 |

- Ring-exclusion rates did not separate Woolf, MH and the conditional MLE (mixed sizes:
  8.4–8.9% of replications had at least one stratum ring excluding the reference). In the
  sparse design Woolf gave fewer exclusions (25.6% vs 29.8% for MH and 31.8% for the true
  value) because it shrinks toward 1.
- Reviewer 1, simulated at Titanic's stratum sizes: Woolf's test rejected 2.3% at nominal
  5% (mean Q 4.10 vs 5); corner log odds ratio bias −0.05.
- UCB, Fungicide, Detergent: Woolf and MH differ by 0.1–2.5%.

### Detergent (MF's example)

`aperm(vcdExtra::Detergent, c(3, 2, 1, 4))`: Preference × M_User × Temperature (R = 2) ×
Water_softness (C = 3). Log odds ratios, per-stratum zero rule:

| Margin | Collapsed | Woolf | MH | Woolf test, strata in this margin |
|---|---|---|---|---|
| High | −0.852 | −0.848 | −0.847 | Q = 1.2, df 2, p = .55 |
| Low | −0.408 | −0.406 | −0.406 | Q = 4.1, df 2, p = .13 |
| Soft | −0.166 | −0.170 | −0.171 | Q = 1.0, df 1, p = .33 |
| Medium | −0.681 | −0.659 | −0.659 | Q = 1.9, df 1, p = .17 |
| Hard | −0.867 | −0.862 | −0.862 | Q = 0.05, df 1, p = .83 |
| Corner | −0.575 | −0.564 | −0.564 | Q = 8.0, df 5, p = .16 |

### Scripts

The two reviews' R scripts were written to a temporary session directory and are not kept
in the repository (reviewer 1: `woolf_margins_check.R`; reviewer 2: `helpers.R`,
`01-examples.R`, `02-simulation.R`, `03-checks.R`).

## 13. Notes for vcdExtra

For GK/MF's work on `woolf_test()` (not ggfourfold changes):

- `decompose = TRUE` computes Rows and Cols from collapsed counts; see vcdExtra's
  `issues/woolf.md`.
- The whole-table 0.5 rule changes strata that have no zeros (Titanic Adult × 1st:
  72.46 → 64.34). ggfourfold uses the per-stratum rule (as `vcd::fourfold()`), so the two
  packages will disagree on tables with zeros unless `woolf_test()` switches. The
  whole-table rule is inherited from `vcd::woolf_test()`, and `vcd::loddsratio()` uses it
  too, so switching would depart from vcd there.
- Uninformative strata count toward the df (Titanic: 5 df, 3 informative; with the crew,
  an all-zero stratum enters with y = 0, w = 1/8).
- p-values use `1 - pchisq(...)`, which rounds small p-values to 0;
  `pchisq(..., lower.tail = FALSE)` avoids that.
- `breslow_day_test()` fails on the Titanic table ("No unique valid root in stratum 1").
  Noted only; Breslow–Day is out of scope for now.

## 14. Summary for MF

### The proposal in a nutshell

`facet_grid(R ~ C, margins = TRUE)` already draws the (R + 1) × (C + 1) grid from
`dev/fourfold-ideas.md`, with collapsed tables (summed counts) in the "(all)" panels, as in
`dev/marginal-fourfold.R`. The main proposal is that each "(all)" panel would instead show a
**pooled odds ratio** for the strata it covers: by default Woolf's estimate, the
inverse-variance weighted mean of the stratum log odds ratios.

The reason is that odds ratios are non-collapsible. A collapsed table can differ from every
stratum even when the strata agree and nothing is confounded: two strata that each have
odds ratio 4 can collapse to 2.03. Woolf's pooled estimate, by contrast, is exactly the
reference that Woolf's test measures departures from. The corner shows the overall pooled
value, and each row or column margin shows the pooled value for its own row or column. So
comparing the strata with their margins shows what Woolf's test is asking: can these
strata be pooled?

For example, in Titanic (without the crew), the adult strata have odds ratios of 72.5,
67.7 and 4.4 across the three classes. The collapsed table gives 12.6 and the Woolf pooled
value is 9.5, but Woolf's test for those three strata gives Q = 52.3 on 2 df, so pooling
them isn't justified.

### Decisions so far (GK, 2026-09-28)

**What the margin panels show**

- A pooled odds ratio, with `pooled = c("woolf", "mh")`: Woolf by default, Mantel–Haenszel
  as an alternative that is more robust with sparse strata. Both would be in the first
  version. There would be no option for collapsed tables.
- Each margin panel would also carry the Woolf homogeneity test of the strata it pools
  (C − 1 df for a row margin, R − 1 for a column margin, RC − 1 for the corner). These
  would be computed variables rather than drawn: `woolf_q`, `woolf_df`, `woolf_p`, along
  with `margin`, `pooled_method` and `n_strata`.

**How they are drawn**

- Only in the fully standardized display (the default). A pooled odds ratio has no counts
  behind it, so the other settings would give an informative error. This also means the
  `all.max` exclusion suggested in `issues/TASKS.md` wouldn't be needed.
- `Pooled OR = …` would be printed instead of counts. Summed counts could mislead: they
  describe the collapsed table, and their odds ratio isn't the one drawn (12.6 vs 9.5 in the
  Titanic example).
- Rings would keep their usual meaning: in a margin panel, the 95% interval of the pooled
  odds ratio. When the strata disagree, these rings are narrow around an average that means
  little, which the documentation would point out.

**Calculations**

- Margin panels would be left out of the Holm adjustment across strata. At present they
  are included: in the Detergent figure, High × Hard is drawn pale only because of this
  (adjusted p 0.034 without the margins, 0.051 with them).
- Zero cells: 0.5 added per stratum, as in `vcd::fourfold()` and the current geom.

**Set aside**

- An outline of the pooled odds ratio inside each stratum panel was tried as an idea and
  set aside as too busy. The reference ring remains deferred, as MF suggested.

### Questions where MF's view would be welcome

**The main question**

1. **Pooled estimate rather than collapsed tables.** The TASKS entries and the ring
   prototype use collapsed tables, partly to show non-collapsibility. This proposal would
   give up that view in favour of showing what Woolf's test is about. Does that seem
   reasonable? A related observation: the agreement with `woolf_test(decompose = TRUE)`
   noted in the TASKS entry comes about because that decomposition also builds its Rows
   and Cols terms from collapsed counts (see vcdExtra's `issues/woolf.md`).

**Statistical details**

2. **Strata with an empty row or column.** In Titanic, every 1st- and 2nd-class child
   survived, so those strata say nothing about the odds ratio. The 0.5 correction turns
   Child × 1st into 0.27 anyway, which pulls the 1st-class margin from 72.5 down to 53.2.
   The suggestion is to leave such strata out of the margins and the test's df, and to
   flag them. Would that work, or would another treatment be better? And could this be
   done as part of the margin feature, before the existing empty row/column drawing task in
   `issues/TASKS.md`, or would it be better after?
3. **Colour in the margin panels.** Each margin panel has its own test of pooled odds
   ratio = 1 (Woolf z-test, or CMH when `pooled = "mh"`). Should those p-values be left
   unadjusted, so each margin answers its own question, or Holm-adjusted as a group of
   their own (R + C + 1 tests)? On Detergent the choice changes no colours.

**Display**

4. **Where the label goes.** GK isn't sure about this one. The current idea is along the
   top inside the frame, possibly with `Pooled` and `OR = …` either side of the vertical
   line, but other placements are very welcome. A mock-up suggests the top centre can be
   covered by large upper quadrants, so the top corners, or a stacked label in whichever
   top corner is free, might work better. A second line (`n = …`, or the homogeneity
   p-value) is also a possibility.
5. **Shading.** `margin_background()` looks like a good way to set the margin panels apart.
   Since the geom will identify margin panels anyway, one option would be to make it a
   `geom_fourfold()` argument rather than a separate function. On timing, it might be
   simplest to release it together with the margin changes rather than before them.

**Interface and documentation**

6. **Computed variables.** `margin` shares its name with the `margin = c(1, 2)` argument,
   so `is_margin` might be clearer. Should these (and the existing columns such as
   `odds_ratio`) be documented as public? And would exporting a stat be worthwhile, so
   they can be used in other layers?
7. **Argument name.** Does `pooled` seem a good name for the choice of estimator?
8. **Example data.** Detergent is a natural choice, though the estimators agree there, so it
   wouldn't show the difference. Titanic without the crew shows it clearly but depends on
   question 2. UCB by Dept would show single-variable margins.

**For later**

9. **Reference ring.** If it is revived, it would probably make sense for it to use the
   same estimator as `pooled`. In margin panels, only a ring at the corner value would add
   information, since each margin panel already draws its own pooled value.

Sections 2–8 give the details and evidence behind each point. Some notes for vcdExtra's
`woolf_test()` are collected in section 13.
