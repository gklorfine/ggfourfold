# NOTE (2026-10-08): the package now draws the LC2/LS2 line from
# dev/old/tick-line-swatches.R, so the cards marked "current" show the earlier
# direction ticks. The mock-ups edit the grob "fourfold-direction-ticks", which
# the package no longer has (it is "fourfold-diagonal").
#
# NOTE (2026-10-07): the cards were drawn against the pre-change ticks (1x black
# line width). C0/S0 "today" refer to that version, before C2/S2 were adopted as
# the package default, so the restyle factors here multiply the old 1x black
# ticks; re-running this script on the current package multiplies the new ones.
#
# Swatch sheet of every direction-tick option tried so far, for MF: one
# labelled card per option, each showing UCB Dept A (significant, odds ratio
# > 1) and Dept C (not significant, odds ratio < 1). See the "Square tick
# direction" and "coloured direction ticks" items in issues/TASKS.md, and
# dev/old/tick-mockup.R for the working sheets these came from.
#
# Options are mocked up by editing each panel's "fourfold-direction-ticks"
# grob. Where the package itself can place the counts for an option (a style
# change, or a diagonal tick of a given length), `counts = "auto"` decides.
# For new geometries the package does not know about yet, the counts are
# forced inside to show whether the mark clears them; these cards say so.
#
# Run from the package root:
#   Rscript dev/old/tick-swatches.R [output-dir]
# Writes tick-swatches.pdf and tick-swatches.png.

devtools::load_all(quiet = TRUE)
library(ggplot2)

args <- commandArgs(trailingOnly = TRUE)
out_dir <- if (length(args)) args[[1]] else tempdir()
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

ucb <- as.data.frame(UCBAdmissions)
ucb <- ucb[ucb$Dept %in% c("A", "C"), ]
navy <- fourfold_palette()[6]
green <- "#009E73"

# The frame spans -1 to 1; horizontal marks stop this far inside it.
frame_cap <- 0.96

native <- function(x) grid::unit(x, "native")

# Editing -----------------------------------------------------------------------

# Apply `fn` to every fourfold panel gTree of a built plot.
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

# Replace a panel's direction ticks by `draw(t)`, where `t` holds the two
# ticks as drawn by the package (start x0, y0 on the cell's outline, or the
# square's outer corner; end x1, y1), the favoured cells' fills, and the
# ticks' colour and line width.
restyle <- function(draw) {
  function(panel) {
    kids <- panel$children
    i <- which(names(kids) == "fourfold-direction-ticks")
    if (!length(i)) return(panel)
    tick <- kids[[i]]
    t <- list(
      x0 = as.numeric(tick$x0), y0 = as.numeric(tick$y0),
      x1 = as.numeric(tick$x1), y1 = as.numeric(tick$y1),
      col = tick$gp$col, lwd = tick$gp$lwd
    )
    # Cells 1-4 are top-left, bottom-left, top-right, bottom-right.
    cell <- ifelse(t$x0 < 0, ifelse(t$y0 > 0, 1L, 2L), ifelse(t$y0 > 0, 3L, 4L))
    t$fill <- vapply(
      cell, function(k) kids[[paste0("fourfold-sector-", k)]]$gp$fill, ""
    )
    new <- draw(t)
    new$name <- "fourfold-direction-ticks"
    kids[[i]] <- new
    grid::setChildren(panel, do.call(grid::gList, kids))
  }
}

segs <- function(x0, y0, x1, y1, col, lwd) {
  grid::segmentsGrob(
    native(x0), native(y0), native(x1), native(y1),
    gp = grid::gpar(col = col, lwd = lwd, lineend = "butt")
  )
}

# Options -----------------------------------------------------------------------

# The package's own ticks, recoloured and/or thickened.
tick_style <- function(col = NULL, lwd = 1) {
  restyle(function(t) {
    segs(t$x0, t$y0, t$x1, t$y1, col %||% t$col, t$lwd * lwd)
  })
}

# Ticks coloured like the cells they mark.
tick_fill <- function(lwd = 2.5) {
  restyle(function(t) segs(t$x0, t$y0, t$x1, t$y1, t$fill, t$lwd * lwd))
}

# Ticks centred on the outline: drawn with half the length as `ticks`, then
# reflected through their start so the other half lies inside the cell.
tick_half_inside <- function(lwd = 2.5) {
  restyle(function(t) {
    segs(2 * t$x0 - t$x1, 2 * t$y0 - t$y1, t$x1, t$y1, t$col, t$lwd * lwd)
  })
}

# Short ticks out from the midpoints of each square's two outer edges.
edge_midpoints <- function(len = 0.1, lwd = 2.5) {
  restyle(function(t) {
    cx <- t$x0
    cy <- t$y0
    segs(
      c(cx, cx / 2), c(cy / 2, cy),
      c(cx + sign(cx) * len, cx / 2), c(cy / 2, cy + sign(cy) * len),
      t$col, t$lwd * lwd
    )
  })
}

# Both outer edges continued past the corner.
crop_marks <- function(len = 0.1, lwd = 2.5) {
  restyle(function(t) {
    cx <- t$x0
    cy <- t$y0
    segs(
      c(cx, cx), c(cy, cy),
      c(cx, cx + sign(cx) * len), c(cy + sign(cy) * len, cy),
      t$col, t$lwd * lwd
    )
  })
}

# Only the horizontal outer edge continued past the corner, stopping short of
# the frame. `col = "fill"` uses the cell's fill.
horizontal <- function(len = 0.2, lwd = 1, col = NULL) {
  restyle(function(t) {
    cx <- t$x0
    cy <- t$y0
    end <- sign(cx) * pmin(abs(cx) + len, frame_cap)
    colour <- if (identical(col, "fill")) t$fill else col %||% t$col
    segs(cx, cy, end, cy, colour, t$lwd * lwd)
  })
}

# A thin tab of the cell's fill, outlined like the square, along the
# horizontal outer edge.
horizontal_tab <- function(len = 0.2, height = 0.05) {
  restyle(function(t) {
    grobs <- lapply(seq_along(t$x0), function(j) {
      cx <- t$x0[j]
      cy <- t$y0[j]
      x <- c(cx, sign(cx) * min(abs(cx) + len, frame_cap))
      y <- c(cy, cy - sign(cy) * height)
      grid::polygonGrob(
        native(x[c(1, 2, 2, 1)]), native(y[c(1, 1, 2, 2)]),
        gp = grid::gpar(col = t$col[1], fill = t$fill[j], lwd = t$lwd)
      )
    })
    grid::gTree(children = do.call(grid::gList, grobs))
  })
}

# No tick: the favoured squares' two outer edges drawn heavier.
heavy_edges <- function(lwd = 3.5) {
  restyle(function(t) {
    cx <- t$x0
    cy <- t$y0
    zero <- 0 * cx
    segs(c(cx, cx), c(zero, cy), c(cx, zero), c(cy, cy), t$col, t$lwd * lwd)
  })
}

# Cards -------------------------------------------------------------------------

card <- function(code, title, note = NULL, fn = identity, shape = "circle",
                 ticks = 0.15, counts = "auto", std = "margins") {
  forced <- counts == "inside"
  subtitle <- paste(c(
    note,
    if (forced) "Counts forced inside (not yet known to counts = \"auto\")"
    else "Counts placed by counts = \"auto\""
  ), collapse = "\n")
  p <- ggplot(ucb, aes(x = Gender, y = Admit, weight = Freq)) +
    geom_fourfold(shape = shape, ticks = ticks, counts = counts, std = std) +
    facet_wrap(vars(Dept), nrow = 1, labeller = label_both) +
    theme_fourfold() +
    labs(title = paste0(code, "  ", title), subtitle = subtitle) +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 11, colour = "grey30"),
      plot.background = element_rect(colour = "grey75", linewidth = 0.6),
      plot.margin = margin(8, 10, 8, 10)
    )
  edit_panels(ggplotGrob(p), fn)
}

circle_cards <- list(
  card("C0", "Today", "Frame colour and line width, length 0.15"),
  card("C1", "Black, thicker", "2.5x line width, length 0.15",
    tick_style(lwd = 2.5)),
  card("C2", "Navy, thicker", "palette[6], 2.5x line width",
    tick_style(navy, 2.5)),
  card("C3", "Cell's fill colour", "2.5x line width; pale when not significant",
    tick_fill()),
  card("C4", "Green, thicker", "#009E73, 2.5x line width",
    tick_style(green, 2.5)),
  card("C5", "Navy, thicker, longer", "palette[6], 2.5x line width, length 0.25",
    tick_style(navy, 2.5), ticks = 0.25),
  card("C6", "Half inside the circle", "Black, 2.5x, length 0.15 centred on the arc",
    tick_half_inside(), ticks = 0.075)
)

square_cards <- list(
  card("S0", "Diagonal, today", "Frame colour and line width, length 0.15",
    shape = "square"),
  card("S1", "Diagonal, black, thicker", "2.5x line width, length 0.15",
    tick_style(lwd = 2.5), shape = "square"),
  card("S2", "Diagonal, navy, thicker", "palette[6], 2.5x line width",
    tick_style(navy, 2.5), shape = "square"),
  card("S3", "Diagonal, shorter", "Frame line width, length 0.06",
    shape = "square", ticks = 0.06),
  card("S4", "Diagonal, half inside", "Black, 2.5x, length 0.15 centred on the corner",
    tick_half_inside(), shape = "square", ticks = 0.075),
  card("S5", "Edge midpoints", "Black, 2.5x, two ticks per cell, length 0.1",
    edge_midpoints(), shape = "square", counts = "inside"),
  card("S6", "Corner extensions", "Black, 2.5x, both outer edges extended 0.1",
    crop_marks(), shape = "square", counts = "inside"),
  card("S7", "Horizontal edge extended", "Black, frame line width, length 0.2",
    horizontal(lwd = 1), shape = "square", counts = "inside"),
  card("S8", "Horizontal edge, 1.5x", "Black, 1.5x line width, length 0.2",
    horizontal(lwd = 1.5), shape = "square", counts = "inside"),
  card("S9", "Horizontal edge, 2x", "Black, 2x line width, length 0.2",
    horizontal(lwd = 2), shape = "square", counts = "inside"),
  card("S10", "Horizontal edge, navy", "palette[6], 2.5x line width, length 0.2",
    horizontal(lwd = 2.5, col = navy), shape = "square", counts = "inside"),
  card("S11", "Horizontal edge, cell's fill", "2.5x line width, length 0.2",
    horizontal(lwd = 2.5, col = "fill"), shape = "square", counts = "inside"),
  card("S12", "Horizontal tab", "Cell's fill, outlined; adds a little filled area",
    horizontal_tab(), shape = "square", counts = "inside"),
  card("S13", "Heavier outer edges, no tick", "Black, 3.5x line width",
    heavy_edges(), shape = "square", counts = "inside"),
  card("S14", "S7 with large squares",
    "std = \"ind.max\"; stops short of the frame, so it can vanish\nCounts outside because the squares reach the corners",
    horizontal(lwd = 1), shape = "square", std = "ind.max"),
  card("S15", "S2 with large squares", "std = \"ind.max\"; diagonal, navy, 2.5x",
    tick_style(navy, 2.5), shape = "square", std = "ind.max")
)

# Sheet -------------------------------------------------------------------------

heading <- function(text, size = 16) {
  grid::textGrob(text, x = 0.01, hjust = 0, gp = grid::gpar(fontsize = size,
    fontface = "bold"))
}
blurb <- function(text) {
  grid::textGrob(text, x = 0.01, hjust = 0, gp = grid::gpar(fontsize = 10,
    col = "grey25"))
}
grid_of <- function(cards) {
  n <- length(cards)
  cards <- c(cards, rep(list(grid::nullGrob()), (-n) %% 3))
  gridExtra::arrangeGrob(grobs = cards, ncol = 3,
    padding = grid::unit(0.15, "in"))
}

card_h <- 3.3
rows_c <- ceiling(length(circle_cards) / 3)
rows_s <- ceiling(length(square_cards) / 3)
sheet <- gridExtra::arrangeGrob(
  heading("ggfourfold: direction-tick swatches", 20),
  blurb(paste(
    "Each card shows UCBAdmissions Dept A (significant, odds ratio > 1) and",
    "Dept C (not significant, odds ratio < 1). Reply with the codes you like."
  )),
  heading("Circles"),
  grid_of(circle_cards),
  heading("Squares"),
  grid_of(square_cards),
  ncol = 1,
  heights = grid::unit(
    c(0.5, 0.35, 0.45, rows_c * card_h, 0.45, rows_s * card_h), "in"
  )
)
width <- 14
height <- 0.5 + 0.35 + 0.45 + 0.45 + (rows_c + rows_s) * card_h + 0.3

grDevices::cairo_pdf(file.path(out_dir, "tick-swatches.pdf"),
  width = width, height = height)
grid::grid.draw(sheet)
invisible(grDevices::dev.off())

ragg::agg_png(file.path(out_dir, "tick-swatches.png"),
  width = width, height = height, units = "in", res = 100)
grid::grid.draw(sheet)
invisible(grDevices::dev.off())

message("wrote tick-swatches.pdf and tick-swatches.png to ", out_dir)
