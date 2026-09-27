# Visual check of count placement for geom_fourfold(shape = "square").
#
# Counts stay inside the frame corners unless a square, confidence outline, or
# direction tick in any panel of the layer reaches them; then the counts in
# every panel move just outside the frame corners. The layer-wide reach is
# computed in GeomFourfold$setup_data() (.fourfold_counts_reach()); the limit
# it is compared with is 0.80, lowered at draw time to (0.88 - text height)
# when the measured count text extends further (makeContent.fourfold_counts()).
# The text is responsive to panel size, so the decision can depend on the size
# the plot is drawn at.
#
# In RStudio, open the ggfourfold project, source this file, and print the
# plot objects one at a time. From the package root, all plots can also be
# written to PNG files with:
#   Rscript dev/square-counts.R [output-dir]

devtools::load_all(".", quiet = TRUE)
library(ggplot2)

ucb <- as.data.frame(UCBAdmissions)

ucb_plot <- function(..., title) {
  ggplot(ucb, aes(x = Gender, y = Admit, weight = Freq)) +
    geom_fourfold(shape = "square", ...) +
    facet_wrap(vars(Dept), ncol = 3, labeller = label_both) +
    labs(title = title) +
    theme_fourfold()
}

# A single, strongly associated table: margin-standardized diagonal cells
# approach radius 1, so its squares reach the corners.
strong <- data.frame(
  x = factor(c("a", "a", "b", "b")),
  y = factor(c("yes", "no", "yes", "no"), levels = c("yes", "no")),
  Freq = c(90, 5, 8, 95)
)

plots <- list(
  # expected: outside -- the squares are well short of the corners, but the
  # diagonal direction ticks run into the corner counts
  margins = ucb_plot(title = "std = \"margins\": counts outside (ticks)"),
  # expected: inside at 7 x 5 in -- without ticks nothing reaches the corners
  margins_no_ticks = ucb_plot(
    ticks = 0, title = "std = \"margins\", ticks = 0"
  ),
  # expected: outside -- each panel's largest cell has radius 1
  ind_max = ucb_plot(std = "ind.max", title = "std = \"ind.max\": counts outside"),
  # expected: outside -- the panel holding the largest cell reaches the corner
  all_max = ucb_plot(std = "all.max", title = "std = \"all.max\": counts outside"),
  # expected: outside, decided by the single strong table
  strong = ggplot(strong, aes(x = x, y = y, weight = Freq)) +
    geom_fourfold(shape = "square") +
    labs(title = "Strong association: counts outside") +
    theme_fourfold(),
  # reference: circles never move their counts
  circle_ind_max = ggplot(ucb, aes(x = Gender, y = Admit, weight = Freq)) +
    geom_fourfold(std = "ind.max") +
    facet_wrap(vars(Dept), ncol = 3, labeller = label_both) +
    labs(title = "Circles, std = \"ind.max\": counts inside") +
    theme_fourfold()
)

# Draw a plot at a given size and report the layer's reach, the count font
# size and measured limit, and where the counts were placed in each panel.
count_placement <- function(p, width = 7, height = 5) {
  grDevices::pdf(NULL, width = width, height = height)
  on.exit(grDevices::dev.off())
  print(p)
  grid::grid.force()
  counts <- grid::grid.get("fourfold-counts", global = TRUE)
  if (inherits(counts, "gTree")) counts <- list(counts)
  outside <- vapply(counts, function(g) g$outside, logical(1))
  data.frame(
    reach = round(counts[[1]]$reach, 3),
    fontsize = round(counts[[1]]$children[[1]]$gp$fontsize, 1),
    limit = round(counts[[1]]$count_limit, 3),
    counts = if (all(outside)) "outside" else if (!any(outside)) "inside" else "mixed"
  )
}

placement <- do.call(rbind, lapply(plots, count_placement))
# The same no-tick display on a small device: larger relative text lowers
# the limit below the squares' reach, so the counts move outside.
placement <- rbind(
  placement,
  small_no_ticks = count_placement(plots$margins_no_ticks, 3.5, 2.5)
)
print(placement)

args <- commandArgs(trailingOnly = TRUE)
if (!interactive()) {
  out_dir <- if (length(args)) args[1] else tempdir()
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  for (name in names(plots)) {
    ggsave(
      file.path(out_dir, paste0("square-counts-", name, ".png")),
      plots[[name]], width = 7, height = 5, dpi = 120
    )
  }
  ggsave(
    file.path(out_dir, "square-counts-small_no_ticks.png"),
    plots$margins_no_ticks, width = 3.5, height = 2.5, dpi = 240
  )
  message("Plots written to ", normalizePath(out_dir))
}
