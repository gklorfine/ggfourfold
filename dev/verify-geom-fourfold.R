# Numerical, API, and visual verification for geom_fourfold().
#
# Run from the package root with:
#   Rscript dev/verify-geom-fourfold.R
#
# Set FOURFOLD_GEOM_VERIFY_DIR to retain output in a chosen directory.

if (!requireNamespace("pkgload", quietly = TRUE) ||
    !requireNamespace("vcd", quietly = TRUE) ||
    !requireNamespace("gridExtra", quietly = TRUE) ||
    !requireNamespace("png", quietly = TRUE) ||
    !requireNamespace("svglite", quietly = TRUE)) {
  stop(
    "Verification requires pkgload, vcd, gridExtra, png, and svglite",
    call. = FALSE
  )
}

# The directory of this script when it is run with source() or Rscript,
# otherwise dev/ under the working directory. source() is checked first:
# when this file is sourced from another script run with Rscript, --file
# names that other script.
script_dir <- local({
  source_files <- vapply(
    sys.frames(),
    function(frame) {
      if (is.null(frame$ofile)) NA_character_ else frame$ofile
    },
    character(1)
  )
  source_files <- source_files[!is.na(source_files)]
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(source_files)) {
    file <- tail(source_files, 1)
    # With source(chdir = TRUE), a relative path no longer resolves from the
    # new working directory, which is the script's own.
    if (!file.exists(file)) file <- basename(file)
    dirname(normalizePath(file))
  } else if (length(file_arg)) {
    dirname(normalizePath(sub("^--file=", "", file_arg[1])))
  } else {
    normalizePath("dev")
  }
})
# load_all() also makes the internal helpers used below available.
pkgload::load_all(dirname(script_dir), quiet = TRUE)

expect_error <- function(expr, pattern) {
  error <- tryCatch(
    {
      force(expr)
      NULL
    },
    error = identity
  )
  if (is.null(error) || !grepl(pattern, conditionMessage(error))) {
    stop(
      sprintf(
        "Expected an error matching %s; got %s",
        dQuote(pattern),
        if (is.null(error)) "no error" else dQuote(conditionMessage(error))
      ),
      call. = FALSE
    )
  }
  invisible(error)
}

ucb <- as.data.frame(UCBAdmissions)

fourfold_plot <- function(data = ucb, ..., facet = TRUE) {
  p <- ggplot2::ggplot(
    data,
    ggplot2::aes(x = Gender, y = Admit, weight = Freq)
  ) + geom_fourfold(...)
  if (facet) {
    p <- p + ggplot2::facet_wrap(ggplot2::vars(Dept), ncol = 3)
  }
  p + theme_fourfold()
}

fourfold_data <- function(plot) {
  ggplot2::ggplot_build(plot)$data[[1]]
}

panel_rows <- function(data) {
  data[!duplicated(data$PANEL), , drop = FALSE]
}

# Reference values, computed without the package's closed-form solutions so
# that they check them independently.

# Iterative proportional fitting to unit row and column totals, which keeps
# the odds ratio: the default display (std = "margins", margin = c(1, 2)).
# As in vcd::fourfold(), 0.5 is added to every cell when any cell is zero.
# Fitting stops once the row totals are also 1 after a column step; strongly
# associated tables converge slowly and then hit the iteration limit rather
# than stopping early with a wrong table.
equal_margins <- function(tab) {
  if (any(tab == 0)) tab <- tab + 0.5
  for (iteration in seq_len(10000L)) {
    tab <- tab / rowSums(tab)
    tab <- t(t(tab) / colSums(tab))
    if (max(abs(rowSums(tab) - 1)) < 2e-16) {
      return(unname(tab))
    }
  }
  stop("iterative proportional fitting did not converge", call. = FALSE)
}

# The table with the row and column totals of `tab` and odds ratio `or`,
# found by root finding. The tolerance is absolute, which suits the
# count-sized tables used here.
table_with_or <- function(or, tab) {
  rows <- rowSums(tab)
  columns <- colSums(tab)
  cells <- function(x) {
    matrix(c(columns[1] - x, x, rows[1] - columns[1] + x, rows[2] - x), 2)
  }
  log_or <- function(x) {
    m <- cells(x)
    log(m[1, 1]) + log(m[2, 2]) - log(m[1, 2]) - log(m[2, 1]) - log(or)
  }
  lower <- max(0, columns[1] - rows[1])
  upper <- min(columns[1], rows[2])
  inset <- 1e-12 * (upper - lower)
  cells(stats::uniroot(
    log_or, c(lower + inset, upper - inset), tol = 1e-14
  )$root)
}

# Standardized cells and confidence-ring radii (rows: lower, upper) for each
# 2 x 2 stratum of a 2 x 2 x k table. Ring tables keep each stratum's
# observed totals, so strata must not have an entirely empty row or column.
fourfold_reference <- function(tables, conf_level = 0.95,
                               standardize = equal_margins) {
  strata <- lapply(seq_len(dim(tables)[3]), function(k) tables[, , k])
  confidence_radii <- lapply(strata, function(tab) {
    corrected <- if (any(tab == 0)) tab + 0.5 else tab
    log_or <- log(corrected[1, 1] * corrected[2, 2] /
                  (corrected[1, 2] * corrected[2, 1]))
    se <- sqrt(sum(1 / corrected))
    z <- stats::qnorm((1 + conf_level) / 2)
    limits <- exp(log_or + c(-1, 1) * z * se)
    t(vapply(limits, function(limit) {
      sqrt(c(standardize(table_with_or(limit, tab))))
    }, numeric(4)))
  })
  list(
    standardized = lapply(strata, standardize),
    confidence_radii = confidence_radii
  )
}

# Compares a plot's standardized cells and ring radii with a reference.
check_against_reference <- function(data, reference) {
  for (panel in seq_along(reference$standardized)) {
    candidate <- data[as.integer(data$PANEL) == panel, , drop = FALSE]
    candidate <- candidate[order(candidate$cell), ]
    stopifnot(
      isTRUE(all.equal(
        candidate$standardized,
        unname(c(reference$standardized[[panel]])),
        tolerance = 1e-13
      )),
      isTRUE(all.equal(
        candidate$conf_low_radius,
        unname(reference$confidence_radii[[panel]][1, ]),
        tolerance = 1e-13
      )),
      isTRUE(all.equal(
        candidate$conf_high_radius,
        unname(reference$confidence_radii[[panel]][2, ]),
        tolerance = 1e-13
      ))
    )
  }
}

# --- Numerical fidelity ----------------------------------------------------

built <- fourfold_data(fourfold_plot())
summary <- panel_rows(built)
reference <- fourfold_reference(UCBAdmissions)

manual_or <- apply(UCBAdmissions, 3, function(tab) {
  (tab[1, 1] * tab[2, 2]) / (tab[1, 2] * tab[2, 1])
})
manual_se <- apply(UCBAdmissions, 3, function(tab) sqrt(sum(1 / tab)))
manual_ci <- cbind(
  manual_or * exp(stats::qnorm(0.025) * manual_se),
  manual_or * exp(stats::qnorm(0.975) * manual_se)
)
manual_raw_p <- 2 * stats::pnorm(
  abs(log(manual_or)) / manual_se,
  lower.tail = FALSE
)
manual_adjusted_p <- stats::p.adjust(manual_raw_p, method = "holm")

stopifnot(
  identical(as.character(summary$PANEL), as.character(seq_len(6L))),
  isTRUE(all.equal(summary$odds_ratio, unname(manual_or), tolerance = 1e-13)),
  isTRUE(all.equal(summary$standard_error, unname(manual_se), tolerance = 1e-13)),
  isTRUE(all.equal(summary$conf_low, unname(manual_ci[, 1]), tolerance = 1e-13)),
  isTRUE(all.equal(summary$conf_high, unname(manual_ci[, 2]), tolerance = 1e-13)),
  isTRUE(all.equal(summary$p_value, unname(manual_raw_p), tolerance = 1e-13)),
  isTRUE(all.equal(summary$p_adjusted, unname(manual_adjusted_p), tolerance = 1e-13)),
  identical(summary$significant, unname(manual_adjusted_p < 0.05))
)

check_against_reference(built, reference)
for (panel in seq_len(6L)) {
  candidate <- built[as.integer(built$PANEL) == panel, , drop = FALSE]
  candidate <- candidate[order(candidate$cell), ]
  stopifnot(identical(candidate$count, unname(c(UCBAdmissions[, , panel]))))

  tab <- UCBAdmissions[, , panel]
  for (bound in c("conf_low", "conf_high")) {
    target_or <- candidate[[bound]][1]
    ring_table <- .fourfold_table_with_or_and_margins(target_or, tab)
    ring_or <- (ring_table[1, 1] * ring_table[2, 2]) /
      (ring_table[1, 2] * ring_table[2, 1])
    stopifnot(
      isTRUE(all.equal(
        unname(rowSums(ring_table)), unname(rowSums(tab)), tolerance = 1e-10
      )),
      isTRUE(all.equal(
        unname(colSums(ring_table)), unname(colSums(tab)), tolerance = 1e-10
      )),
      isTRUE(all.equal(unname(ring_or), target_or, tolerance = 1e-10))
    )
  }
}

# The maximum-based standardizations must use panel and layer maxima,
# respectively.
ind_data <- fourfold_data(fourfold_plot(std = "ind.max", conf_level = 0))
all_data <- fourfold_data(fourfold_plot(std = "all.max", conf_level = 0))
for (panel in seq_len(6L)) {
  ind_panel <- ind_data[as.integer(ind_data$PANEL) == panel, ]
  all_panel <- all_data[as.integer(all_data$PANEL) == panel, ]
  tab <- UCBAdmissions[, , panel]
  stopifnot(
    isTRUE(all.equal(ind_panel$standardized, unname(c(tab / max(tab))))),
    isTRUE(all.equal(
      all_panel$standardized,
      unname(c(tab / max(UCBAdmissions)))
    ))
  )
}

# One-margin standardization follows prop.table() in the selected direction.
for (selected_margin in 1:2) {
  margin_data <- fourfold_data(fourfold_plot(
    margin = selected_margin, conf_level = 0
  ))
  for (panel in seq_len(6L)) {
    observed <- margin_data[as.integer(margin_data$PANEL) == panel, ]$standardized
    expected <- c(prop.table(UCBAdmissions[, , panel], selected_margin))
    stopifnot(isTRUE(all.equal(observed, unname(expected), tolerance = 1e-13)))
  }
}

# Rings keep the observed totals under every standardization. The default
# display depends only on the odds ratio, so it cannot show which totals the
# rings were built from.
ring_standardizations <- list(
  list(args = list(margin = 1), standardize = function(m) prop.table(m, 1)),
  list(args = list(margin = 2), standardize = function(m) prop.table(m, 2)),
  list(args = list(std = "ind.max"), standardize = function(m) m / max(m)),
  list(
    args = list(std = "all.max"),
    standardize = function(m) m / max(UCBAdmissions)
  )
)
for (setting in ring_standardizations) {
  check_against_reference(
    fourfold_data(do.call(fourfold_plot, setting$args)),
    fourfold_reference(UCBAdmissions, standardize = setting$standardize)
  )
}

# p-value adjustment is layer-wide and honors alternative methods.
bonferroni <- panel_rows(fourfold_data(fourfold_plot(
  p_adjust_method = "bonferroni"
)))
stopifnot(isTRUE(all.equal(
  bonferroni$p_adjusted,
  unname(stats::p.adjust(manual_raw_p, method = "bonferroni")),
  tolerance = 1e-13
)))

no_conf_plot <- fourfold_plot(conf_level = 0)
no_conf <- fourfold_data(no_conf_plot)
no_extended <- fourfold_data(fourfold_plot(extended = FALSE))
stopifnot(
  all(is.na(no_conf$conf_low_radius)),
  all(is.na(no_conf$conf_high_radius)),
  all(is.na(no_conf$p_adjusted)),
  all(no_conf$palette_index %in% 1:2),
  all(is.finite(no_extended$conf_low_radius)),
  all(is.finite(no_extended$conf_high_radius)),
  all(is.na(no_extended$p_adjusted)),
  all(no_extended$palette_index %in% 1:2)
)
# A null device, so that no Rplots.pdf is written to the working directory.
grDevices::pdf(NULL)
invisible(ggplot2::ggplotGrob(no_conf_plot))
invisible(grDevices::dev.off())

# Zero cells receive vcd's Haldane-Anscombe correction for inference.
zero <- data.frame(
  X = factor(c("x1", "x1", "x2", "x2"), levels = c("x1", "x2")),
  Y = factor(c("y1", "y2", "y1", "y2"), levels = c("y1", "y2")),
  Freq = c(0, 5, 10, 20)
)
zero_plot <- ggplot2::ggplot(
  zero, ggplot2::aes(X, Y, weight = Freq)
) + geom_fourfold() + theme_fourfold()
zero_data <- fourfold_data(zero_plot)
corrected <- matrix(zero$Freq, 2, 2) + 0.5
stopifnot(
  isTRUE(all.equal(
    zero_data$odds_ratio[1],
    (corrected[1, 1] * corrected[2, 2]) /
      (corrected[1, 2] * corrected[2, 1])
  )),
  isTRUE(all.equal(zero_data$standard_error[1], sqrt(sum(1 / corrected))))
)

# Duplicate long-form rows aggregate, and an absent combination becomes zero.
duplicated_ucb <- rbind(
  transform(ucb, Freq = Freq / 2),
  transform(ucb, Freq = Freq / 2)
)
duplicate_data <- fourfold_data(fourfold_plot(duplicated_ucb))
stopifnot(identical(duplicate_data$count, built$count))

one_missing <- ucb[!(ucb$Dept == "A" & ucb$Gender == "Male" &
                     ucb$Admit == "Admitted"), ]
missing_data <- fourfold_data(fourfold_plot(one_missing))
stopifnot(missing_data$count[missing_data$PANEL == 1 &
                             missing_data$cell == 1] == 0)

# Raw observations use weight = 1.
raw <- data.frame(
  X = factor(c("x1", "x1", "x2", "x2", "x2")),
  Y = factor(c("y1", "y1", "y1", "y2", "y2"))
)
raw_data <- fourfold_data(
  ggplot2::ggplot(raw, ggplot2::aes(X, Y)) +
    geom_fourfold(conf_level = 0) + theme_fourfold()
)
stopifnot(identical(raw_data$count, c(2, 0, 1, 2)))

# --- Faceting and API behavior --------------------------------------------

facet_variants <- list(
  rows = ggplot2::facet_grid(rows = ggplot2::vars(Dept)),
  columns = ggplot2::facet_grid(cols = ggplot2::vars(Dept)),
  wrap = ggplot2::facet_wrap(ggplot2::vars(Dept), ncol = 3),
  wrap_both = ggplot2::facet_wrap(
    ggplot2::vars(Dept), ncol = 3, labeller = ggplot2::label_both
  )
)
base_layer <- ggplot2::ggplot(
  ucb, ggplot2::aes(Gender, Admit, weight = Freq)
) + geom_fourfold() + theme_fourfold()
for (facet in facet_variants) {
  facet_summary <- panel_rows(fourfold_data(base_layer + facet))
  stopifnot(isTRUE(all.equal(
    facet_summary$odds_ratio, summary$odds_ratio, tolerance = 1e-13
  )))
}

two_way <- rbind(
  transform(ucb, Period = "Before"),
  transform(ucb, Period = "After", Freq = Freq * 2)
)
two_way$Period <- factor(two_way$Period, c("Before", "After"))
two_way_plot <- ggplot2::ggplot(
  two_way, ggplot2::aes(Gender, Admit, weight = Freq)
) + geom_fourfold() +
  ggplot2::facet_grid(
    rows = ggplot2::vars(Period), cols = ggplot2::vars(Dept)
  ) + theme_fourfold()
two_way_summary <- panel_rows(fourfold_data(two_way_plot))
stopifnot(
  nrow(two_way_summary) == 12L,
  isTRUE(all.equal(
    two_way_summary$odds_ratio[1:6],
    two_way_summary$odds_ratio[7:12],
    tolerance = 1e-13
  ))
)

# Theme-derived geom text changes with base_size and carries base_family.
theme_sizes <- vapply(c(8, 12, 20), function(size) {
  unique(fourfold_data(base_layer + theme_fourfold(size))$size)
}, numeric(1))
theme_family <- unique(fourfold_data(
  base_layer + theme_fourfold(base_family = "mono")
)$family)
responsive_sizes <- vapply(c(8, 12, 20), function(size) {
  .fourfold_responsive_size(
    panel_width = 180,
    panel_height = 180,
    relative_size = 0.066 * size / 12,
    minimum_size = size * 5 / 6
  )
}, numeric(1))
stopifnot(
  all(diff(theme_sizes) > 0),
  isTRUE(all.equal(theme_sizes / theme_sizes[2], c(8, 12, 20) / 12)),
  all(diff(responsive_sizes) > 0),
  isTRUE(all.equal(
    responsive_sizes / responsive_sizes[2], c(8, 12, 20) / 12
  )),
  identical(theme_family, "mono")
)

custom_palette <- rev(fourfold_palette())
palette_plot <- fourfold_plot(palette = custom_palette)
stopifnot(identical(
  palette_plot$layers[[1]]$geom_params$palette,
  custom_palette
))

# User input errors are caught at construction or build time.
expect_error(geom_fourfold(conf_level = 1), "conf_level")
expect_error(geom_fourfold(ticks = -1), "ticks")
expect_error(geom_fourfold(palette = "red"), "six colours")
expect_error(geom_fourfold(palette = rep("not-a-colour", 6)), "invalid colour")
expect_error(geom_fourfold(margin = 3), "margin")

bad_levels <- transform(ucb, Gender = as.character(Gender))
bad_levels$Gender[1] <- "Unknown"
expect_error(
  fourfold_data(fourfold_plot(bad_levels)),
  "exactly two x levels"
)
negative <- ucb
negative$Freq[1] <- -1
expect_error(
  fourfold_data(fourfold_plot(negative)),
  "finite and non-negative"
)
zero_total <- transform(ucb[ucb$Dept == "A", ], Freq = 0)
expect_error(
  fourfold_data(fourfold_plot(zero_total, facet = FALSE)),
  "positive total"
)

# --- Rendering and clearance checks ---------------------------------------

out_dir <- Sys.getenv(
  "FOURFOLD_GEOM_VERIFY_DIR",
  unset = file.path(tempdir(), "geom-fourfold-verification")
)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
font_cache <- file.path(out_dir, "fontconfig-cache")
dir.create(font_cache, recursive = TRUE, showWarnings = FALSE)
Sys.setenv(XDG_CACHE_HOME = font_cache)

display_order <- c("A", "C", "E", "B", "D", "F")
visual_ucb <- transform(
  ucb,
  Dept = factor(Dept, levels = display_order)
)
visual_plot <- ggplot2::ggplot(
  visual_ucb,
  ggplot2::aes(Gender, Admit, weight = Freq)
) + geom_fourfold() +
  ggplot2::facet_wrap(
    ggplot2::vars(Dept), ncol = 3, labeller = ggplot2::label_both
  ) +
  ggplot2::labs(title = "test") +
  theme_fourfold()

render_png_and_measure <- function(plot, filename, width, height, dpi) {
  path <- file.path(out_dir, filename)
  grDevices::png(path, width = width, height = height, res = dpi, bg = "white")
  grid::grid.newpage()
  grid::grid.draw(ggplot2::ggplotGrob(plot))
  grid::grid.force()

  viewports <- grid::grid.ls(
    viewports = TRUE, grobs = FALSE, print = FALSE
  )$name
  panel_viewport <- grep("^panel[.-]", viewports, value = TRUE)[1]
  if (is.na(panel_viewport)) {
    invisible(grDevices::dev.off())
    stop("could not locate a facet panel viewport", call. = FALSE)
  }
  grid::seekViewport(panel_viewport)
  panel_width_pt <- grid::convertWidth(
    grid::unit(1, "npc"), "points", valueOnly = TRUE
  )
  panel_height_pt <- grid::convertHeight(
    grid::unit(1, "npc"), "points", valueOnly = TRUE
  )
  panel_width_px <- grid::convertWidth(
    grid::unit(1, "npc"), "inches", valueOnly = TRUE
  ) * dpi
  panel_height_px <- grid::convertHeight(
    grid::unit(1, "npc"), "inches", valueOnly = TRUE
  ) * dpi
  fontsize <- max(10, min(panel_width_pt, panel_height_pt) * 0.066)
  text <- grid::textGrob("Rejected", gp = grid::gpar(fontsize = fontsize))
  text_height_px <- grid::convertHeight(
    grid::grobHeight(text), "inches", valueOnly = TRUE
  ) * dpi
  text_width_px <- grid::convertWidth(
    grid::grobWidth(text), "inches", valueOnly = TRUE
  ) * dpi
  x_scale <- panel_width_px / 2.6
  y_scale <- panel_height_px / 2.6
  clearances <- c(
    label_from_frame_x = 0.16 * x_scale - text_height_px / 2,
    label_from_frame_y = 0.16 * y_scale - text_height_px / 2,
    label_from_panel_x = 0.14 * x_scale - text_height_px / 2,
    label_from_panel_y = 0.14 * y_scale - text_height_px / 2,
    horizontal_label_fit = panel_width_px - text_width_px - 8,
    vertical_label_fit = panel_height_px - text_width_px - 8
  )
  grid::upViewport(0)
  invisible(grDevices::dev.off())

  if (any(clearances < 4)) {
    stop(
      sprintf(
        "%s has a label clearance below 4 px: %s",
        filename,
        paste(names(clearances), round(clearances, 1), collapse = ", ")
      ),
      call. = FALSE
    )
  }
  clearances
}

clearance <- rbind(
  rstudio_small = render_png_and_measure(
    visual_plot, "fourfold-rstudio-small.png",
    width = 1000, height = 700, dpi = 144
  ),
  rstudio_hidpi = render_png_and_measure(
    visual_plot, "fourfold-rstudio-hidpi.png",
    width = 1300, height = 948, dpi = 192
  ),
  export_144dpi = render_png_and_measure(
    visual_plot, "fourfold-export-144dpi.png",
    width = 1728, height = 1224, dpi = 144
  ),
  export_300dpi = render_png_and_measure(
    visual_plot, "fourfold-export-300dpi.png",
    width = 3600, height = 2550, dpi = 300
  )
)

# Side-by-side visual reference. Render both plots at full size first so vcd's
# multi-panel grob is not distorted when placed into a half-width viewport.
vcd_path <- file.path(out_dir, "fourfold-vcd-reference.png")
candidate_path <- file.path(out_dir, "fourfold-facet-reference.png")
grDevices::png(vcd_path, width = 900, height = 900, res = 144, bg = "white")
grid::grid.newpage()
grid::grid.draw(vcd::fourfold(
  UCBAdmissions, newpage = FALSE, return_grob = TRUE
))
invisible(grDevices::dev.off())
grDevices::png(
  candidate_path, width = 900, height = 900, res = 144, bg = "white"
)
grid::grid.newpage()
grid::grid.draw(ggplot2::ggplotGrob(
  visual_plot + ggplot2::labs(title = NULL)
))
invisible(grDevices::dev.off())

comparison_path <- file.path(out_dir, "fourfold-vcd-comparison.png")
grDevices::png(
  comparison_path, width = 1800, height = 950, res = 144, bg = "white"
)
grid::grid.newpage()
gridExtra::grid.arrange(
  grid::rasterGrob(png::readPNG(vcd_path), interpolate = FALSE),
  grid::rasterGrob(png::readPNG(candidate_path), interpolate = FALSE),
  ncol = 2,
  top = grid::textGrob(
    "vcd::fourfold()                         geom_fourfold() + facets",
    gp = grid::gpar(fontsize = 13)
  )
)
invisible(grDevices::dev.off())

# Vector exports. PDF is rasterized for native-size inspection; SVG is checked
# structurally because the available legacy ImageMagick reader ignores the
# standards-valid svglite stylesheet that supplies default fills and strokes.
pdf_path <- file.path(out_dir, "fourfold-export.pdf")
svg_path <- file.path(out_dir, "fourfold-export.svg")
ggplot2::ggsave(pdf_path, visual_plot, width = 12, height = 8.5, device = cairo_pdf)
ggplot2::ggsave(
  svg_path, visual_plot, width = 12, height = 8.5, device = svglite::svglite
)
if (file.info(pdf_path)$size <= 0 || file.info(svg_path)$size <= 0) {
  stop("vector export produced an empty file", call. = FALSE)
}
svg_source <- readLines(svg_path, warn = FALSE)
stopifnot(
  any(grepl("fill: none;", svg_source, fixed = TRUE)),
  any(grepl("stroke: #000000;", svg_source, fixed = TRUE)),
  any(grepl("fill: #FF0000;", svg_source, fixed = TRUE)),
  any(grepl("fill: #000080;", svg_source, fixed = TRUE)),
  any(grepl("fill: #FFA0A0;", svg_source, fixed = TRUE)),
  any(grepl("fill: #A0A0FF;", svg_source, fixed = TRUE)),
  sum(grepl("<polygon", svg_source, fixed = TRUE)) >= 72L,
  sum(grepl("<line", svg_source, fixed = TRUE)) >= 100L,
  sum(grepl("<text", svg_source, fixed = TRUE)) >= 54L,
  any(grepl(">Admitted</text>", svg_source, fixed = TRUE)),
  any(grepl(">Female</text>", svg_source, fixed = TRUE)),
  any(grepl(">512</text>", svg_source, fixed = TRUE))
)

pdftoppm <- Sys.which("pdftoppm")
if (nzchar(pdftoppm)) {
  status <- system2(
    pdftoppm,
    c("-png", "-singlefile", "-r", "144", pdf_path,
      file.path(out_dir, "fourfold-export-pdf-rendered"))
  )
  if (status != 0) stop("could not rasterize PDF export", call. = FALSE)
}
message("Minimum label clearances (pixels):")
print(round(clearance, 1))
message("All geom_fourfold() numerical, API, and rendering checks passed.")
message("Verification output: ", normalizePath(out_dir))
