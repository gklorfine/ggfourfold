# Mock-up (2026-10-08): instead of two direction ticks, one straight black
# line through the centre along the diagonal the association favours.
#   Circles: the line runs from tick tip to tick tip (each end where the
#            current tick ends, radius + `ticks`).
#   Squares: the line stops short of the corner counts (at `square_end` on
#            each axis), so `counts = "auto"` can keep the counts inside.
# Each row is compared with the current ticks (C2/S2).
#
# Run from the package root:
#   Rscript dev/old/tick-line-mockup.R [output-dir]
# Writes tick-line-mockup.png.

devtools::load_all(quiet = TRUE)
library(ggplot2)

args <- commandArgs(trailingOnly = TRUE)
out_dir <- if (length(args)) args[[1]] else tempdir()

ucb <- as.data.frame(UCBAdmissions)
ucb <- ucb[ucb$Dept %in% c("A", "B", "C"), ]

# Squares' line end on each axis. The count text starts at about 0.75 (see
# .fourfold_count_limit()), so 0.70 leaves room for the line's width.
square_end <- 0.70

native <- function(x) grid::unit(x, "native")

edit_panels <- function(g, fn) {
  if (inherits(g, "gtable")) {
    g$grobs <- lapply(g$grobs, edit_panels, fn)
    return(g)
  }
  if (inherits(g, "gTree") && startsWith(g$name %||% "", "fourfold-panel")) {
    return(fn(g))
  }
  if (inherits(g, "gTree") && length(g$children)) {
    g <- grid::setChildren(
      g, do.call(grid::gList, lapply(g$children, edit_panels, fn))
    )
  }
  g
}

# Replace the two ticks by one line. The ticks' end points give the diagonal
# and, for circles, where the line ends. `lwd` multiplies the outline width.
through_line <- function(shape, lwd = 1) {
  function(panel) {
    kids <- panel$children
    i <- which(names(kids) == "fourfold-direction-ticks")
    if (!length(i)) return(panel)
    tick <- kids[[i]]
    x1 <- as.numeric(tick$x1)
    y1 <- as.numeric(tick$y1)
    if (shape == "square") {
      x1 <- sign(x1) * square_end
      y1 <- sign(y1) * square_end
    }
    frame_lwd <- kids[["fourfold-frame"]]$gp$lwd
    kids[[i]] <- grid::segmentsGrob(
      native(x1[1]), native(y1[1]), native(x1[2]), native(y1[2]),
      gp = grid::gpar(col = "black", lwd = frame_lwd * lwd, lineend = "butt"),
      name = "fourfold-direction-ticks"
    )
    grid::setChildren(panel, do.call(grid::gList, kids))
  }
}

card <- function(title, shape, fn = identity, ticks = 0.15) {
  p <- ggplot(ucb, aes(x = Gender, y = Admit, weight = Freq)) +
    geom_fourfold(shape = shape, ticks = ticks) +
    facet_wrap(vars(Dept), nrow = 1, labeller = label_both) +
    theme_fourfold() +
    labs(title = title) +
    theme(
      plot.title = element_text(face = "bold", size = 13),
      plot.background = element_rect(colour = "grey75", linewidth = 0.6)
    )
  edit_panels(ggplotGrob(p), fn)
}

# For squares, a negligible tick length keeps the tick grob (it carries the
# diagonal) while `counts = "auto"` sees only the squares themselves.
sheet <- gridExtra::arrangeGrob(
  card("Circles: current (C2, navy ticks)", "circle"),
  card("Circles: black line, tick tip to tick tip, outline width", "circle",
    through_line("circle")),
  card("Circles: black line, tick tip to tick tip, 2.5x", "circle",
    through_line("circle", 2.5)),
  card("Squares: current (S2, navy ticks)", "square"),
  card("Squares: black line to 0.70, outline width", "square",
    through_line("square"), ticks = 1e-6),
  card("Squares: black line to 0.70, 2.5x", "square",
    through_line("square", 2.5), ticks = 1e-6),
  ncol = 1
)

ragg::agg_png(file.path(out_dir, "tick-line-mockup.png"),
  width = 10, height = 6 * 3.6, units = "in", res = 100)
grid::grid.draw(sheet)
invisible(grDevices::dev.off())
message("wrote tick-line-mockup.png to ", out_dir)
