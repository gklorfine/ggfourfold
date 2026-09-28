# Exploration: marginal fourfold displays for 2 x 2 x R x C tables.
#
# See the "Marginal plots" idea in dev/fourfold-ideas.md. For a 2 x 2 x R x C
# table, facet_grid(R ~ C, margins = TRUE) adds the marginal tables:
#   - the "(all)" column: pooled over C, one table per level of R;
#   - the "(all)" row:    pooled over R, one table per level of C;
#   - the corner:         pooled over both R and C.
# Comparing these with the strata shows the effect of pooling, which relates
# to vcdExtra::woolf_test(decompose = TRUE) (rows, columns, residual).
#
# A prototype reference ring (not in the package) is drawn in every panel at
# the Mantel-Haenszel common odds ratio over all R x C strata:
#   - in stratum panels, sectors that depart from the ring show departures
#     from homogeneity of the odds ratios;
#   - in "(all)" panels, a departure shows that collapsing changes the odds
#     ratio (non-collapsibility), even if the strata were homogeneous.
# With both margins equated (std = "margins"), a table with odds ratio theta
# has quadrant radii sqrt(p) (diagonal) and sqrt(1 - p) (off-diagonal), with
# p = sqrt(theta) / (1 + sqrt(theta)), so the ring depends only on theta.
#
# In RStudio, source this file and print the plot objects. From the package
# root, the plots can be written to PNG files with:
#   Rscript dev/marginal-fourfold.R [output-dir]

devtools::load_all(".", quiet = TRUE)
library(ggplot2)
library(grid)

# Data: Preference x M_User by Temperature (R = 2) x Water_softness (C = 3) ----
data(Detergent, package = "vcdExtra")
det_table <- aperm(Detergent, c(3, 2, 1, 4))
det <- as.data.frame(det_table)

print(vcdExtra::woolf_test(det_table, decompose = TRUE))

# Odds ratios: strata, margins, and Mantel-Haenszel common odds ratios --------
mh_or <- function(tab) {
  unname(stats::mantelhaen.test(tab, correct = FALSE)$estimate)
}
strata <- array(det_table, dim = c(2, 2, 6))
theta_mh <- mh_or(strata)

log_or <- function(tab) log(tab[1, 1] * tab[2, 2] / (tab[1, 2] * tab[2, 1]))
collapse <- function(margin) apply(det_table, c(1, 2, margin), sum)

pooling <- rbind(
  data.frame(
    table = paste("Temperature =", dimnames(det_table)$Temperature),
    pooled_over = "Water_softness",
    marginal_log_or = apply(det_table, 3, function(t) log_or(apply(t, 1:2, sum))),
    mh_log_or = apply(det_table, 3, function(t) log(mh_or(t)))
  ),
  data.frame(
    table = paste("Water_softness =", dimnames(det_table)$Water_softness),
    pooled_over = "Temperature",
    marginal_log_or = apply(det_table, 4, function(t) log_or(apply(t, 1:2, sum))),
    mh_log_or = apply(det_table, 4, function(t) log(mh_or(t)))
  ),
  data.frame(
    table = "All", pooled_over = "both",
    marginal_log_or = log_or(apply(det_table, 1:2, sum)),
    mh_log_or = log(theta_mh)
  )
)
# Marginal (collapsed) vs Mantel-Haenszel log odds ratio for the strata pooled:
# similar values mean that pooling does not distort the association.
pooling$difference <- pooling$marginal_log_or - pooling$mh_log_or
rownames(pooling) <- NULL
print(pooling, digits = 3)

# Background for the margin panels ---------------------------------------------
# A theme can't do this (panel.background applies to every panel), and an
# ordinary layer can't either: margins = TRUE copies every layer's rows into
# the "(all)" panels, and data that already contain "(all)" make
# reshape_add_margins() fail with a duplicated factor level. Instead, this stat
# looks up each panel's facet values in the layout and returns a full-panel
# rectangle only for panels where any facet variable is "(all)".
StatMarginPanels <- ggproto("StatMarginPanels", Stat,
  compute_layer = function(self, data, params, layout) {
    lay <- layout$layout
    vars <- setdiff(names(lay), c("PANEL", "ROW", "COL", "SCALE_X", "SCALE_Y"))
    is_margin <- Reduce(`|`, lapply(lay[vars], function(v) {
      as.character(v) == "(all)"
    }))
    data.frame(PANEL = lay$PANEL[is_margin],
               xmin = -Inf, xmax = Inf, ymin = -Inf, ymax = Inf)
  }
)

# Add before geom_fourfold() so that the display is drawn on top.
margin_background <- function(fill = "#F5EEDC") {
  layer(stat = StatMarginPanels, geom = "rect", position = "identity",
        mapping = NULL, data = NULL, inherit.aes = FALSE, show.legend = FALSE,
        params = list(fill = fill, colour = NA))
}

# Marginal fourfold display ----------------------------------------------------
marginal_plot <- ggplot(det, aes(x = M_User, y = Preference, weight = Freq)) +
  margin_background() +
  geom_fourfold() +
  facet_grid(Temperature ~ Water_softness, margins = TRUE) +
  labs(
    title = "Detergent: brand preference by previous use of Brand M",
    subtitle = "Rows: Temperature   Columns: Water softness   (all), shaded: pooled"
  ) +
  theme_fourfold(base_size = 11)

# Note: with margins = TRUE the "(all)" panels are part of the layer, so the
# Holm adjustment is over 12 panels (6 strata + 6 non-independent marginal
# tables), and std = "all.max" would scale by the pooled corner table.
panel_stats <- merge(
  ggplot_build(marginal_plot)$layout$layout[,
    c("PANEL", "Temperature", "Water_softness")],
  unique(layer_data(marginal_plot, 2)[,
    c("PANEL", "odds_ratio", "p_value", "p_adjusted")])
)
print(panel_stats[order(panel_stats$PANEL), ], digits = 3)

# Prototype: add a dashed reference ring at odds ratio `theta` to every panel.
# Returns a gtable (draw with grid::grid.draw()).
add_reference_ring <- function(plot, theta, colour = "#009E73", lwd = 2,
                               lty = "22") {
  p <- sqrt(theta) / (1 + sqrt(theta))
  # cells 1-4: top-left (n11), bottom-left (n21), top-right (n12),
  # bottom-right (n22), with the angles used by GeomFourfold
  radius <- sqrt(c(p, 1 - p, 1 - p, p))
  from <- c(90, 180, 0, 270)
  arcs <- do.call(gList, lapply(1:4, function(cell) {
    angle <- seq(from[cell], from[cell] + 90, length.out = 100) * pi / 180
    linesGrob(
      unit(radius[cell] * cos(angle), "native"),
      unit(radius[cell] * sin(angle), "native"),
      gp = gpar(col = colour, lwd = lwd, lty = lty)
    )
  }))
  ring <- gTree(children = arcs, name = "reference-ring")
  g <- ggplotGrob(plot)
  for (i in grep("^panel", g$layout$name)) {
    g$grobs[[i]] <- addGrob(g$grobs[[i]], ring, gPath("fourfold-panel"),
                            grep = TRUE, global = TRUE)
  }
  g
}

marginal_ring <- add_reference_ring(
  marginal_plot +
    labs(caption = sprintf(
      "Dashed green ring: Mantel-Haenszel common odds ratio over the 6 strata (%.2f)",
      theta_mh
    )),
  theta_mh
)

args <- commandArgs(trailingOnly = TRUE)
if (!interactive()) {
  out_dir <- if (length(args)) args[1] else tempdir()
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  ggsave(file.path(out_dir, "marginal-fourfold.png"), marginal_plot,
         width = 8, height = 7, dpi = 120)
  ggsave(file.path(out_dir, "marginal-fourfold-ring.png"), marginal_ring,
         width = 8, height = 7, dpi = 120)
  message("Plots written to ", normalizePath(out_dir))
} else {
  print(marginal_plot)
  grid.newpage()
  grid.draw(marginal_ring)
}
