# Mock-ups for the two open direction-tick items in issues/TASKS.md:
# "Square tick direction" and "Proposal: coloured direction ticks".
#
# The package draws ticks one way only, so each variant is made by editing the
# "fourfold-direction-ticks" grobs of a real display. Their coordinates are
# native drawing units (the frame spans -1 to 1), and for squares the ticks
# start at the outer corners of the two favoured cells.
#
# Edited ticks do not feed back into `counts = "auto"`, so the square sheet
# forces `counts = "inside"` to show whether each variant clears the counts.
#
# Run from the package root:
#   Rscript dev/tick-mockup.R [output-dir]

devtools::load_all(quiet = TRUE)
library(ggplot2)

args <- commandArgs(trailingOnly = TRUE)
out_dir <- if (length(args)) args[[1]] else tempdir()
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

ucb_all <- as.data.frame(UCBAdmissions)
ucb <- ucb_all[ucb_all$Dept %in% c("A", "B", "C"), ]
navy <- fourfold_palette()[6]

# Apply `fn` to every direction-tick grob in a built plot.
edit_ticks <- function(g, fn) {
  if (inherits(g, "gtable")) {
    g$grobs <- lapply(g$grobs, edit_ticks, fn)
    return(g)
  }
  if (identical(g$name, "fourfold-direction-ticks")) {
    return(fn(g))
  }
  if (inherits(g, "gTree") && length(g$children)) {
    g <- grid::setChildren(
      g, do.call(grid::gList, lapply(g$children, edit_ticks, fn))
    )
  }
  g
}

style <- function(colour = NULL, lwd_mult = 1) {
  function(g) {
    if (!is.null(colour)) g$gp$col <- colour
    g$gp$lwd <- g$gp$lwd * lwd_mult
    g
  }
}

native <- function(x) grid::unit(x, "native")

# Replace the diagonal ticks of squares by a new geometry built from the
# outer corners (cx, cy) of the two favoured squares.
reshape_square <- function(build, len = 0.15, colour = NULL, lwd_mult = 1) {
  function(g) {
    cx <- as.numeric(g$x0)
    cy <- as.numeric(g$y0)
    seg <- build(cx, cy, len)
    lwd <- g$gp$lwd * lwd_mult
    col <- if (is.null(colour)) g$gp$col else colour
    grid::segmentsGrob(
      native(seg$x0), native(seg$y0), native(seg$x1), native(seg$y1),
      gp = grid::gpar(col = col, lwd = lwd, lineend = "butt"),
      name = g$name
    )
  }
}

# Short ticks out from the midpoints of each square's two outer edges.
edge_midpoints <- function(cx, cy, len) {
  list(
    x0 = c(cx, cx / 2), y0 = c(cy / 2, cy),
    x1 = c(cx + sign(cx) * len, cx / 2), y1 = c(cy / 2, cy + sign(cy) * len)
  )
}

# The two outer edges continued past the corner (an open "crop mark").
edge_extensions <- function(cx, cy, len) {
  list(
    x0 = c(cx, cx), y0 = c(cy, cy),
    x1 = c(cx, cx + sign(cx) * len), y1 = c(cy + sign(cy) * len, cy)
  )
}

# The two outer edges of each favoured square, drawn heavier (no tick).
outer_edges <- function(cx, cy, len) {
  zero <- 0 * cx
  list(
    x0 = c(cx, cx), y0 = c(zero, cy),
    x1 = c(cx, zero), y1 = c(cy, cy)
  )
}

row_plot <- function(title, shape = "circle", ticks = 0.15, counts = "auto", data = ucb,
                     fn = identity) {
  p <- ggplot(data, aes(x = Gender, y = Admit, weight = Freq)) +
    geom_fourfold(shape = shape, ticks = ticks, counts = counts) +
    facet_wrap(vars(Dept), nrow = 1, labeller = label_both) +
    theme_fourfold() +
    ggtitle(title)
  edit_ticks(ggplotGrob(p), fn)
}

save_sheet <- function(rows, file, width = 9, row_height = 3.3) {
  sheet <- gridExtra::arrangeGrob(grobs = rows, ncol = 1)
  ragg::agg_png(
    file.path(out_dir, file),
    width = width, height = row_height * length(rows), units = "in", res = 110
  )
  grid::grid.draw(sheet)
  grDevices::dev.off()
  message("wrote ", file.path(out_dir, file))
}

# Sheet 1: tick geometry for squares ------------------------------------------

save_sheet(list(
  row_plot("S0. Squares today: diagonal ticks, counts = \"auto\" (moved outside)",
    shape = "square"),
  row_plot("S1. Same ticks, counts forced inside: they collide",
    shape = "square", counts = "inside"),
  row_plot("S2. Shorter diagonal ticks (0.06), counts inside",
    shape = "square", counts = "inside", ticks = 0.06),
  row_plot("S3. Ticks at the midpoints of the outer edges, counts inside",
    shape = "square", counts = "inside",
    fn = reshape_square(edge_midpoints, len = 0.1)),
  row_plot("S4. Outer edges extended past the corner, counts inside",
    shape = "square", counts = "inside",
    fn = reshape_square(edge_extensions, len = 0.1)),
  row_plot("S5. No tick: heavier outer edges on the favoured squares",
    shape = "square", counts = "inside",
    fn = reshape_square(outer_edges, lwd_mult = 3.5))
), "tick-mockup-squares.png")

# Sheet 2: tick colour, thickness, and length (circles) ------------------------

save_sheet(list(
  row_plot("C0. Today: frame colour (black), frame line width, length 0.15"),
  row_plot("C1. Black, 2.5x line width, length 0.15",
    fn = style(lwd_mult = 2.5)),
  row_plot("C2. palette[6] (navy), 2.5x line width, length 0.15",
    fn = style(navy, 2.5)),
  row_plot("C3. palette[6] (navy), 2.5x line width, length 0.25",
    ticks = 0.25, fn = style(navy, 2.5))
), "tick-mockup-circles.png")

# Sheet 3: the colour/width proposal applied to the square options -------------

save_sheet(list(
  row_plot("Q1. Squares, diagonal ticks: navy, 2.5x, counts = \"auto\"",
    shape = "square", fn = style(navy, 2.5)),
  row_plot("Q2. Squares, edge-midpoint ticks: navy, 2.5x, counts inside",
    shape = "square", counts = "inside",
    fn = reshape_square(edge_midpoints, len = 0.1, colour = navy,
      lwd_mult = 2.5)),
  row_plot("Q3. Squares, extended edges: navy, 2.5x, counts inside",
    shape = "square", counts = "inside",
    fn = reshape_square(edge_extensions, len = 0.1, colour = navy,
      lwd_mult = 2.5))
), "tick-mockup-colour-squares.png")

# Sheet 4: thick ticks centred on the corner (half inside the cell) -----------
#
# The layer is drawn with `ticks` = half the total length, so the outward half
# is real and `counts = "auto"` decides placement from it; the inward half is
# then added by reflecting each tick's end through its start.

half_inside <- function(colour = NULL, lwd_mult = 2.5) {
  function(g) {
    x0 <- as.numeric(g$x0)
    y0 <- as.numeric(g$y0)
    g$x0 <- native(2 * x0 - as.numeric(g$x1))
    g$y0 <- native(2 * y0 - as.numeric(g$y1))
    if (!is.null(colour)) g$gp$col <- colour
    g$gp$lwd <- g$gp$lwd * lwd_mult
    g$gp$lineend <- "butt"
    g
  }
}

save_sheet(list(
  row_plot("H1. Squares: black, 2.5x, total length 0.15 half inside, counts = \"auto\"",
    shape = "square", ticks = 0.075, fn = half_inside()),
  row_plot("H2. Same, counts forced inside",
    shape = "square", ticks = 0.075, counts = "inside", fn = half_inside()),
  row_plot("H3. Squares: total length 0.2 half inside, counts = \"auto\"",
    shape = "square", ticks = 0.1, fn = half_inside()),
  row_plot("H4. Circles: black, 2.5x, total length 0.15 half inside, counts = \"auto\"",
    ticks = 0.075, fn = half_inside())
), "tick-mockup-half-inside.png")

# Sheet 5: only the horizontal outer edge extended past the corner ------------

horizontal_extension <- function(cx, cy, len) {
  list(x0 = cx, y0 = cy, x1 = cx + sign(cx) * len, y1 = cy)
}

save_sheet(list(
  row_plot("P1. Horizontal edge extended 0.1: navy, 2.5x, counts inside",
    shape = "square", counts = "inside",
    fn = reshape_square(horizontal_extension, len = 0.1, colour = navy,
      lwd_mult = 2.5)),
  row_plot("P2. Horizontal edge extended 0.15: black, 2.5x, counts inside",
    shape = "square", counts = "inside",
    fn = reshape_square(horizontal_extension, len = 0.15, lwd_mult = 2.5)),
  row_plot("P3. As P1, Depts D-F",
    shape = "square", counts = "inside",
    data = ucb_all[ucb_all$Dept %in% c("D", "E", "F"), ],
    fn = reshape_square(horizontal_extension, len = 0.1, colour = navy,
      lwd_mult = 2.5))
), "tick-mockup-horizontal.png")

# Sheet 6: horizontal extensions at double the length of sheet 5 -------------

ucb_def <- ucb_all[ucb_all$Dept %in% c("D", "E", "F"), ]
save_sheet(list(
  row_plot("P4. Horizontal edge extended 0.2: navy, 2.5x, counts inside",
    shape = "square", counts = "inside",
    fn = reshape_square(horizontal_extension, len = 0.2, colour = navy,
      lwd_mult = 2.5)),
  row_plot("P5. As P4, Depts D-F",
    shape = "square", counts = "inside", data = ucb_def,
    fn = reshape_square(horizontal_extension, len = 0.2, colour = navy,
      lwd_mult = 2.5)),
  row_plot("P6. Horizontal edge extended 0.3: black, 2.5x, counts inside",
    shape = "square", counts = "inside",
    fn = reshape_square(horizontal_extension, len = 0.3, lwd_mult = 2.5)),
  row_plot("P7. As P6, Depts D-F",
    shape = "square", counts = "inside", data = ucb_def,
    fn = reshape_square(horizontal_extension, len = 0.3, lwd_mult = 2.5))
), "tick-mockup-horizontal-double.png")

# Sheet 7: horizontal extensions styled to belong to the square ---------------
#
# These need each favoured cell's fill, so they edit the whole panel: the tick
# grob gives the outer corners and the "fourfold-sector-<cell>" grobs give the
# fills (cells 1-4 are top-left, bottom-left, top-right, bottom-right).

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

# `draw(cx, cy, fill, lwd)` returns a grob for one favoured cell.
restyle_extension <- function(draw) {
  function(panel) {
    kids <- panel$children
    i <- which(names(kids) == "fourfold-direction-ticks")
    if (!length(i)) return(panel)
    tick <- kids[[i]]
    cx <- as.numeric(tick$x0)
    cy <- as.numeric(tick$y0)
    cell <- ifelse(cx < 0, ifelse(cy > 0, 1L, 2L), ifelse(cy > 0, 3L, 4L))
    fills <- vapply(
      cell, function(k) kids[[paste0("fourfold-sector-", k)]]$gp$fill, ""
    )
    new <- lapply(seq_along(cx), function(j) {
      draw(cx[j], cy[j], fills[j], tick$gp$lwd)
    })
    kids[[i]] <- grid::gTree(
      children = do.call(grid::gList, new), name = "fourfold-direction-ticks"
    )
    grid::setChildren(panel, do.call(grid::gList, kids))
  }
}

# A line of the cell's fill colour.
fill_line <- function(len, lwd_mult) {
  function(cx, cy, fill, lwd) {
    grid::segmentsGrob(
      native(cx), native(cy), native(cx + sign(cx) * len), native(cy),
      gp = grid::gpar(col = fill, lwd = lwd * lwd_mult, lineend = "butt")
    )
  }
}

# A thin tab of the cell's fill, outlined like the square, along its edge.
fill_tab <- function(len, height) {
  function(cx, cy, fill, lwd) {
    x <- c(cx, cx + sign(cx) * len)
    y <- c(cy, cy - sign(cy) * height)
    grid::polygonGrob(
      native(x[c(1, 2, 2, 1)]), native(y[c(1, 1, 2, 2)]),
      gp = grid::gpar(col = "black", fill = fill, lwd = lwd)
    )
  }
}

all_plot <- function(title, fn) {
  p <- ggplot(ucb_all, aes(x = Gender, y = Admit, weight = Freq)) +
    geom_fourfold(shape = "square", counts = "inside") +
    facet_wrap(vars(Dept), nrow = 2, labeller = label_both) +
    theme_fourfold() +
    ggtitle(title)
  edit_panels(ggplotGrob(p), fn)
}

save_sheet(list(
  all_plot("V1. Black, frame line width: a plain continuation of the edge",
    restyle_extension(function(cx, cy, fill, lwd) {
      grid::segmentsGrob(native(cx), native(cy),
        native(cx + sign(cx) * 0.2), native(cy), gp = grid::gpar(lwd = lwd))
    })),
  all_plot("V2. The cell's own fill colour, 2.5x",
    restyle_extension(fill_line(0.2, 2.5))),
  all_plot("V3. A thin tab in the cell's fill, outlined like the square",
    restyle_extension(fill_tab(0.2, 0.05)))
), "tick-mockup-horizontal-blend.png", row_height = 6)
