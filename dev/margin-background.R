# margin_background(): shade the "(all)" panels of facet_grid(margins = TRUE).
#
# Shared by dev/marginal-fourfold.R and dev/synthetic-2x2x2x4.R. See the TASKS
# entry "Shade the margin panels: `margin_background()`".
#
# A theme can't do this (panel.background applies to every panel), and an
# ordinary layer can't either: margins = TRUE copies every layer's rows into
# the "(all)" panels, and data that already contain "(all)" make
# reshape_add_margins() fail with a duplicated factor level. Instead, this stat
# looks up each panel's facet values in the layout and returns a full-panel
# rectangle only for panels where any facet variable is "(all)".

StatMarginPanels <- ggplot2::ggproto("StatMarginPanels", ggplot2::Stat,
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
  ggplot2::layer(
    stat = StatMarginPanels, geom = "rect", position = "identity",
    mapping = NULL, data = NULL, inherit.aes = FALSE, show.legend = FALSE,
    params = list(fill = fill, colour = NA)
  )
}
