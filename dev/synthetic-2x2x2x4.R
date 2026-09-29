# Synthetic 2 x 2 x 2 x 4 table for exploring the "(all)" margins.
#
# Treated (Yes/No) x Better (Yes/No), stratified by Sex (rows: Male, Female) and
# Age (columns: four 10-year groups). Designed so that:
#   - for Male, the log odds ratio goes from negative to positive with age;
#   - for Female, it also increases with age, but only slightly.
# Pooling over Age then hides the Male reversal, and pooling over Sex mixes two
# different age trends -- which is what the "(all)" panels should reveal.
#
# The table is generated deterministically: each stratum's 2 x 2 table is
# solved to have the target odds ratio and the given margins, then rounded to
# whole counts (so realized odds ratios differ slightly from the targets).
# See dev/synthetic-2x2x2x4.md for notes and open questions.
#
# In RStudio, source this file and print the plot objects. From the package
# root, the plots can be written to PNG files with:
#   Rscript dev/synthetic-2x2x2x4.R [output-dir]

devtools::load_all(".", quiet = TRUE)
library(ggplot2)
source("dev/margin-background.R")

# Design ------------------------------------------------------------------------
ages <- c("20-29", "30-39", "40-49", "50-59")

design <- expand.grid(
  Age = factor(ages, levels = ages),
  Sex = factor(c("Male", "Female"), levels = c("Male", "Female"))
)
# Target log odds ratios (Treated x Better) in each stratum
design$target_lor <- c(
  -1.00, -0.30, 0.40, 1.10,   # Male: negative to positive
   0.10,  0.25, 0.40, 0.55    # Female: increases, but not much
)
# Stratum sizes
design$n <- c(
  120, 150, 180, 200,         # Male
  140, 160, 170, 190          # Female
)

# Confounding knob: if TRUE, treatment becomes more common with age and
# improvement less common, so Age is associated with both Treated and Better,
# and pooling over Age distorts the association. If FALSE, all strata share
# the same margins, so pooling differences reflect heterogeneity only.
confound <- TRUE
if (confound) {
  design$p_treated <- rep(c(0.30, 0.45, 0.60, 0.75), 2)
  design$p_better  <- c(0.75, 0.62, 0.48, 0.35,
                        0.80, 0.67, 0.53, 0.40)   # Female slightly higher
} else {
  design$p_treated <- 0.5
  design$p_better  <- 0.55
}

# A 2 x 2 table [Treated, Better] with total n, P(Treated = Yes), P(Better = Yes)
# and odds ratio exp(lor). With the margins fixed, the table is determined by
# the (Yes, Yes) cell, found by root-finding on the log odds ratio.
table_with_margins <- function(n, p_treated, p_better, lor) {
  r1 <- round(n * p_treated)          # Treated = Yes
  r2 <- n - r1
  c1 <- round(n * p_better)           # Better = Yes
  cells <- function(x) c(x, r1 - x, c1 - x, r2 - c1 + x)  # n11, n12, n21, n22
  f <- function(x) {
    m <- cells(x)
    log(m[1]) + log(m[4]) - log(m[2]) - log(m[3]) - lor
  }
  lo <- max(0, c1 - r2) + 1e-6
  hi <- min(r1, c1) - 1e-6
  x <- round(stats::uniroot(f, c(lo, hi))$root)
  matrix(cells(x), 2, 2,
         dimnames = list(Treated = c("Yes", "No"), Better = c("Yes", "No")))
}

synth_table <- array(
  0, dim = c(2, 2, 2, 4),
  dimnames = list(Treated = c("Yes", "No"), Better = c("Yes", "No"),
                  Sex = c("Male", "Female"), Age = ages)
)
for (i in seq_len(nrow(design))) {
  d <- design[i, ]
  synth_table[, , as.character(d$Sex), as.character(d$Age)] <-
    table_with_margins(d$n, d$p_treated, d$p_better, d$target_lor)
}
synth_table <- as.table(synth_table)
synth <- as.data.frame(synth_table)   # long (frequency) form for ggplot

log_or <- function(tab) log(tab[1, 1] * tab[2, 2] / (tab[1, 2] * tab[2, 1]))
design$realized_lor <- apply(
  design, 1, function(d) log_or(synth_table[, , d[["Sex"]], d[["Age"]]])
)
print(design[, c("Sex", "Age", "n", "p_treated", "p_better",
                 "target_lor", "realized_lor")], digits = 3)

# Tests and pooling -------------------------------------------------------------
if (requireNamespace("vcdExtra", quietly = TRUE)) {
  print(vcdExtra::woolf_test(synth_table, decompose = TRUE))
}

mh_lor <- function(tab) {
  log(unname(stats::mantelhaen.test(tab, correct = FALSE)$estimate))
}
pooled <- function(dims) apply(synth_table, c(1, 2, dims), sum)
pooling <- rbind(
  data.frame(
    table = paste("Sex =", dimnames(synth_table)$Sex),
    pooled_over = "Age",
    marginal_lor = apply(synth_table, 3, function(t) log_or(apply(t, 1:2, sum))),
    mh_lor = apply(synth_table, 3, mh_lor)
  ),
  data.frame(
    table = paste("Age =", ages),
    pooled_over = "Sex",
    marginal_lor = apply(synth_table, 4, function(t) log_or(apply(t, 1:2, sum))),
    mh_lor = apply(synth_table, 4, mh_lor)
  ),
  data.frame(
    table = "All", pooled_over = "both",
    marginal_lor = log_or(apply(synth_table, 1:2, sum)),
    mh_lor = mh_lor(array(synth_table, c(2, 2, 8)))
  )
)
# marginal_lor: odds ratio of the collapsed table; mh_lor: Mantel-Haenszel
# common odds ratio of the strata pooled. With confound = TRUE these differ
# (non-collapsibility); with confound = FALSE they should nearly agree.
pooling$difference <- pooling$marginal_lor - pooling$mh_lor
rownames(pooling) <- NULL
print(pooling, digits = 3)

# Marginal fourfold display ------------------------------------------------------
synth_plot <- ggplot(synth, aes(x = Better, y = Treated, weight = Freq)) +
  margin_background() +
  geom_fourfold() +
  facet_grid(Sex ~ Age, margins = TRUE) +
  labs(
    title = "Synthetic: improvement by treatment, by sex and age",
    subtitle = "Rows: Sex   Columns: Age   (all), shaded: pooled"
  ) +
  theme_fourfold(base_size = 11)

# Log odds ratios by age: the "plot the odds ratio directly" view ----------------
lor_df <- do.call(rbind, lapply(c(dimnames(synth_table)$Sex, "(all)"), function(s) {
  tabs <- if (s == "(all)") apply(synth_table, c(1, 2, 4), sum) else synth_table[, , s, ]
  data.frame(
    Sex = s, Age = factor(ages, levels = ages),
    lor = apply(tabs, 3, log_or),
    se = apply(tabs, 3, function(t) sqrt(sum(1 / t)))
  )
}))
lor_df$Sex <- factor(lor_df$Sex, levels = c("Male", "Female", "(all)"))
lor_plot <- ggplot(lor_df, aes(Age, lor, colour = Sex, group = Sex)) +
  geom_hline(yintercept = 0, colour = "grey50") +
  geom_pointrange(aes(ymin = lor - 1.96 * se, ymax = lor + 1.96 * se),
                  position = position_dodge(width = 0.3)) +
  geom_line(aes(linetype = Sex == "(all)"),
            position = position_dodge(width = 0.3), show.legend = FALSE) +
  scale_colour_manual(values = c(Male = "#0072B2", Female = "#D55E00",
                                 `(all)` = "grey30")) +
  labs(y = "log odds ratio (Treated x Better)", x = "Age",
       title = "Log odds ratios with 95% intervals; (all) = pooled over sex") +
  theme_bw(base_size = 11)

args <- commandArgs(trailingOnly = TRUE)
if (!interactive()) {
  out_dir <- if (length(args)) args[1] else tempdir()
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  ggsave(file.path(out_dir, "synthetic-fourfold.png"), synth_plot,
         width = 10, height = 6.5, dpi = 120)
  ggsave(file.path(out_dir, "synthetic-lor.png"), lor_plot,
         width = 7, height = 4.5, dpi = 120)
  message("Plots written to ", normalizePath(out_dir))
} else {
  print(synth_plot)
  print(lor_plot)
}
