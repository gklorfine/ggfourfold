# Synthetic 2 × 2 × 2 × 4 table for exploring "(all)" margins

Not yet a TASK: a sandbox for working out what marginal fourfold displays
(`facet_grid(margins = TRUE)`) should show, on data with a known structure.

**Files**

- `dev/synthetic-2x2x2x4.R`: generates the table and runs the exploration.
- `dev/margin-background.R`: `margin_background()`, shared with
  `dev/marginal-fourfold.R`.

Run `Rscript dev/synthetic-2x2x2x4.R <dir>` to write the PNGs, or source the file in
RStudio.

## Aim (MF)

- **Variables:** Treated (Yes/No) × Better (Yes/No), stratified by Sex (rows: Male,
  Female) and Age (columns: 20–29, 30–39, 40–49, 50–59).
- **Male:** log odds ratios go from negative to positive with age.
- **Female:** log odds ratios also increase with age, but not by much.

## How the table is generated

Deterministic, with no random sampling. For each stratum, the design sets:

- a target log odds ratio;
- a stratum size `n`;
- the margins P(Treated = Yes) and P(Better = Yes).

With the margins fixed, the 2 × 2 table is determined by its (Yes, Yes) cell. That cell
is found by root-finding on the log odds ratio, then rounded, so realized log odds ratios
are within about 0.05 of the targets.

| Sex    | 20–29 | 30–39 | 40–49 | 50–59 |
|--------|------:|------:|------:|------:|
| Male   | −1.00 | −0.30 |  0.40 |  1.10 |
| Female |  0.10 |  0.25 |  0.40 |  0.55 |

The **`confound` knob** controls how the margins change with age:

- `TRUE` (default): treatment becomes more common with age (30% → 75%) and improvement
  less common (75% → 35%, slightly higher for Female). Age is then associated with both
  Treated and Better, which is what makes collapsing over Age misleading.
- `FALSE`: all strata share the same margins, so any difference between pooled and
  stratified odds ratios reflects heterogeneity only.

## What the current version shows (`confound = TRUE`)

- **Woolf decomposition:** overall p = .024; Rows (Sex) p = .66; Cols (Age) p = .011;
  Residual p = .20. The heterogeneity is mainly across age, as designed.
- **Pooling over Age is misleading (Simpson's paradox):**
  - Every Female stratum has a positive log odds ratio (0.09 to 0.50; Mantel–Haenszel
    0.33), yet the collapsed Female table gives −0.15.
  - For Male, the collapsed table gives −0.25 against a Mantel–Haenszel estimate of +0.17.
  - In the display, the blue diagonal of the Female strata flips to the other diagonal in
    the Female "(all)" panel.
- **Pooling over Sex is harmless:** within each age group the collapsed and
  Mantel–Haenszel log odds ratios agree to within 0.004, because Sex is not confounded
  with the margins.
- **Only one panel reaches significance:** only (all) × 50–59 is drawn in the intense
  colours. The strata are small (120–200), and the Holm adjustment runs over all 15
  panels, including 7 non-independent margin panels.
- **The log odds ratio plot** (`lor_plot`, "plot the odds ratio directly", as for
  CoalMiners in DDAR §4.4) shows the Male and Female age trends more clearly than the
  fourfold array does. The fourfold array is better at showing direction and pooling
  reversals.

## Ideas for developing it

1. **Separate the two stories.** Compare `confound = TRUE` and `FALSE` side by side:
   heterogeneity only, versus heterogeneity plus non-collapsibility. It may be clearer to
   make these two named variants, or two datasets.
   
2. **Show the confounding itself.** With the default `std = "margins"`, both margins are
   equated, so the changing treatment and improvement rates across age are invisible;
   only the odds ratios show. Try `std = "ind.max"` or `margin = 1`/`2` on the same
   facets to see *why* pooling over age misleads, e.g. older strata have more treated
   and fewer improved.
   
3. **Sample size knob.** Scale `n` (e.g. ×3) so that the extreme Male strata are
   significant after adjustment. The current sizes show how pooling creates or hides
   significance.
   
4. **Reference ring.** Try `add_reference_ring()` from `dev/marginal-fourfold.R`, both with
   one common Mantel–Haenszel θ and, in each "(all)" panel, with the Mantel–Haenszel
   estimate of the strata it pools. Pooling over Age should visibly miss its own
   Mantel–Haenszel ring. This could settle the open question in that TASKS entry.
   
5. **Tests to pair with the plot.**
   - `woolf_test(decompose = TRUE)`.
   - A trend test for the log odds ratio across ordered Age, e.g. weighted regression of
     log odds ratio on age midpoints by Sex, as for CoalMiners in DDAR.
   - A Sex × Age interaction on the log odds ratio: the four-way term
     Treated:Better:Sex:Age, tested by comparing the saturated loglinear model with
     `[TBS][TBA][TSA][BSA]` (T = Treated, B = Better, S = Sex, A = Age). This is the
     likelihood-ratio counterpart of the Woolf "Residual" component.
     
6. **A package dataset?** If it proves useful, turn it into a documented example dataset
   (e.g. `TreatAge`), with a plausible story. Keep it clearly labelled as synthetic, and
   decide whether to ship the generator or just the table.
   
7. **Multiple-testing behaviour with margins.** Here 8 strata become 15 panels; the TASKS
   item on excluding "(all)" panels from the Holm adjustment and `all.max` applies
   directly.
