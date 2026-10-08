# NOTE (2026-10-08): LC2/LS2 were adopted. The package draws them as one bordered
# rectangle (arguments `diagonal`, `diagonal.length`, `diagonal.fill` and
# `diagonal.width`; see issues/TASKS.md), not as the two stacked strokes
# mocked up here, and with the squares' stub 0.02 per axis, not 0.03 as in LS2.
# The mock-ups edit the grob "fourfold-direction-ticks", which the package no
# longer has (it is "fourfold-diagonal"), so re-running this on the current
# package draws no mock-up.
#
# Swatches (2026-10-08): one straight line through the centre along the
# diagonal the association favours, instead of two direction ticks, in three
# styles. Each card shows UCBAdmissions Depts A (significant, odds ratio > 1),
# B (not significant, > 1) and C (not significant, < 1).
#   Circles: the line runs from tick tip to tick tip (each end where the
#            current tick ends, radius + `ticks`).
#   Squares: the line stops at `square_end` on each axis, short of the corner
#            counts, so `counts = "auto"` keeps the counts inside. LS2
#            instead ends a fixed `stub` past each square's corner, with
#            the counts placed by `counts = "auto"`.
# See also dev/old/tick-line-mockup.R (black line at two widths).
#
# Run from the package root:
#   Rscript dev/old/tick-line-swatches.R [output-dir]
# Writes tick-line-swatches.png and tick-line-swatches.pdf.

devtools::load_all(quiet = TRUE)
library(ggplot2)

args <- commandArgs(trailingOnly = TRUE)
out_dir <- if (length(args)) args[[1]] else tempdir()

ucb <- as.data.frame(UCBAdmissions)
ucb <- ucb[ucb$Dept %in% c("A", "B", "C"), ]
green <- "#009E73"

# Squares' line end on each axis. The count text starts at about 0.75 (see
# .fourfold_count_limit()), so 0.70 leaves room for the line's width.
square_end <- 0.70

# LS2 instead ends this far past each favoured square's outer corner on each
# axis: about the most that keeps UCB Dept A's counts inside (its corner is
# at 0.703 and the counts start at about 0.75).
stub <- 0.03

# Line width, as a multiple of the outline width, and the outline drawn
# around the white line on each side (also in outline widths).
line_width <- 2.5
outline <- 1

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

# Replace the two ticks by one line from (x[1], y[1]) to (x[2], y[2]). The
# ticks' end points give the diagonal and, for circles, where the line ends.
# `fill` is the line's colour; `edge`, if given, outlines it, including its
# ends (the outline line is extended along the 45-degree diagonal, which is
# 45 degrees on the page because the panel has unit aspect ratio).
through_line <- function(shape, fill, edge = NULL) {
  function(panel) {
    kids <- panel$children
    i <- which(names(kids) == "fourfold-direction-ticks")
    if (!length(i)) return(panel)
    tick <- kids[[i]]
    x <- as.numeric(tick$x1)
    y <- as.numeric(tick$y1)
    if (shape == "square") {
      x <- sign(x) * square_end
      y <- sign(y) * square_end
    }
    frame_lwd <- kids[["fourfold-frame"]]$gp$lwd
    lwd <- frame_lwd * line_width
    seg <- function(x0, y0, x1, y1, col, lwd) {
      grid::segmentsGrob(x0, y0, x1, y1,
        gp = grid::gpar(col = col, lwd = lwd, lineend = "butt"))
    }
    line <- seg(native(x[1]), native(y[1]), native(x[2]), native(y[2]),
      fill, lwd)
    if (!is.null(edge)) {
      edge_lwd <- lwd + 2 * outline * frame_lwd
      # Extend each end by the outline's thickness (lwd units are 1/96 in).
      grow <- grid::unit(outline * frame_lwd / 96 / sqrt(2), "inches")
      dx <- sign(x) * grow
      dy <- sign(y) * grow
      under <- seg(native(x[1]) + dx[1], native(y[1]) + dy[1],
        native(x[2]) + dx[2], native(y[2]) + dy[2], edge, edge_lwd)
      line <- grid::gTree(children = grid::gList(under, line))
    }
    line$name <- "fourfold-direction-ticks"
    kids[[i]] <- line
    grid::setChildren(panel, do.call(grid::gList, kids))
  }
}

# LS2: a white line with a black outline that ends `stub` past each favoured
# square's outer corner on each axis. The package draws ticks of length
# `stub * sqrt(2)` as wide as the outlined line (see stub_card()), so
# `counts = "auto"` places the counts by exactly what is drawn: the black
# line ends at the ticks' end points with the ticks' width, and the white
# line on top stops one outline short of each end.
stub_line <- function(panel) {
  kids <- panel$children
  i <- which(names(kids) == "fourfold-direction-ticks")
  if (!length(i)) return(panel)
  tick <- kids[[i]]
  x <- as.numeric(tick$x1)
  y <- as.numeric(tick$y1)
  frame_lwd <- kids[["fourfold-frame"]]$gp$lwd
  edge_lwd <- tick$gp$lwd
  white_lwd <- frame_lwd * line_width
  shrink <- grid::unit((edge_lwd - white_lwd) / 2 / 96 / sqrt(2), "inches")
  seg <- function(x0, y0, x1, y1, col, lwd) {
    grid::segmentsGrob(x0, y0, x1, y1,
      gp = grid::gpar(col = col, lwd = lwd, lineend = "butt"))
  }
  line <- grid::gTree(
    children = grid::gList(
      seg(native(x[1]), native(y[1]), native(x[2]), native(y[2]),
        "black", edge_lwd),
      seg(native(x[1]) - sign(x[1]) * shrink, native(y[1]) - sign(y[1]) * shrink,
        native(x[2]) - sign(x[2]) * shrink, native(y[2]) - sign(y[2]) * shrink,
        "white", white_lwd)
    ),
    name = "fourfold-direction-ticks"
  )
  kids[[i]] <- line
  grid::setChildren(panel, do.call(grid::gList, kids))
}

card <- function(code, title, shape, fn = identity, ticks = NULL,
                 tick.linewidth = NULL) {
  # For squares, a negligible tick length keeps the tick grob (it carries
  # the diagonal) while `counts = "auto"` sees only the squares themselves.
  ticks <- ticks %||%
    if (shape == "square" && !identical(fn, identity)) 1e-6 else 0.15
  p <- ggplot(ucb, aes(x = Gender, y = Admit, weight = Freq)) +
    geom_fourfold(shape = shape, ticks = ticks,
      tick.linewidth = tick.linewidth) +
    facet_wrap(vars(Dept), nrow = 1, labeller = label_both) +
    theme_fourfold() +
    labs(title = paste0(code, "  ", title)) +
    theme(
      plot.title = element_text(face = "bold", size = 13),
      plot.background = element_rect(colour = "grey75", linewidth = 0.6),
      plot.margin = margin(8, 10, 8, 10)
    )
  edit_panels(ggplotGrob(p), fn)
}

styles <- list(
  list(code = "0", title = "Current (navy ticks, 2.5x)", fill = NULL),
  list(code = "1", title = "Black line, 2.5x", fill = "black"),
  list(code = "2", title = "White line, 2.5x, black outline", fill = "white",
    edge = "black"),
  list(code = "3", title = paste0("Green line (", green, "), 2.5x"),
    fill = green)
)

cards <- unlist(lapply(styles, function(s) {
  lapply(c("circle", "square"), function(shape) {
    code <- paste0(if (shape == "circle") "LC" else "LS", s$code)
    if (code == "LS2") {
      # theme_fourfold()'s line width is 0.28 mm.
      return(card(code,
        sprintf("White line, black outline, %.2f past each corner", stub),
        shape, stub_line, ticks = stub * sqrt(2),
        tick.linewidth = (line_width + 2 * outline) * 0.28))
    }
    fn <- if (is.null(s$fill)) identity else through_line(shape, s$fill, s$edge)
    card(code, s$title, shape, fn)
  })
}), recursive = FALSE)

heading <- function(text, size) {
  grid::textGrob(text, x = 0.01, hjust = 0,
    gp = grid::gpar(fontsize = size, fontface = "bold"))
}
sheet <- gridExtra::arrangeGrob(
  heading("ggfourfold: lines through the direction of association", 18),
  heading("Quarter-circles (left) and squares (right)", 12),
  gridExtra::arrangeGrob(grobs = cards, ncol = 2,
    padding = grid::unit(0.15, "in")),
  ncol = 1,
  heights = grid::unit(c(0.5, 0.35, 4 * 3.4), "in")
)
width <- 18
height <- 0.5 + 0.35 + 4 * 3.4 + 0.2

ragg::agg_png(file.path(out_dir, "tick-line-swatches.png"),
  width = width, height = height, units = "in", res = 100)
grid::grid.draw(sheet)
invisible(grDevices::dev.off())

grDevices::cairo_pdf(file.path(out_dir, "tick-line-swatches.pdf"),
  width = width, height = height)
grid::grid.draw(sheet)
invisible(grDevices::dev.off())

message("wrote tick-line-swatches.png and .pdf to ", out_dir)
