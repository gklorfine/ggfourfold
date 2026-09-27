#' Default palette for fourfold displays
#'
#' `fourfold_palette()` returns the six colours used by [geom_fourfold()]. The
#' colours encode the direction and statistical strength of association and
#' are drawn directly by the geom rather than through a fill scale.
#' Entries 1-2 are used when `extended = FALSE`, entries 3-4 for an extended
#' display without adjusted significance, and entries 5-6 for an extended
#' display with adjusted significance. Within each pair, the geom assigns the
#' two colours according to the sign of association and cell diagonal.
#'
#' @return A character vector containing six hexadecimal colours.
#'
#' @examples
#' fourfold_palette()
#'
#' @export
fourfold_palette <- function() {
  c(
    "#99CCFF", "#6699CC",
    "#FFA0A0", "#A0A0FF",
    "#FF0000", "#000080"
  )
}

.fourfold_pt <- 72.27 / 25.4

# Side of a quarter-square with the area of a unit quarter-circle.
.fourfold_square_side <- sqrt(pi) / 2

# Normalized position of the counts drawn inside the frame corners.
.fourfold_count_offset <- 0.88

# Squares whose outer corner (or direction tick) extends beyond this
# normalized coordinate are taken to reach the counts inside the frame
# corners. At draw time the limit is lowered further when the measured count
# text extends below it (see makeContent.fourfold_counts()).
.fourfold_square_count_limit <- 0.80

# How far the squares, their confidence outlines, and direction ticks extend
# towards the frame corners in any panel of the layer. Counts never need to
# move for circles, so their reach is -Inf.
.fourfold_counts_reach <- function(
    data, shape = NULL, extended = NULL, ticks = NULL) {
  # Defaults match geom_fourfold() for direct use of GeomFourfold.
  if (is.null(shape)) shape <- "circle"
  if (is.null(extended)) extended <- TRUE
  if (is.null(ticks)) ticks <- 0.15
  if (shape != "square") {
    return(-Inf)
  }
  radii <- c(data$radius, data$conf_high_radius)
  reach <- max(radii, na.rm = TRUE) * .fourfold_square_side
  if (extended && ticks > 0) {
    tick_cell <- ifelse(data$odds_ratio > 1, data$cell %in% c(1L, 4L),
                        data$cell %in% c(2L, 3L))
    tick_reach <- data$radius[tick_cell] * .fourfold_square_side +
      ticks / sqrt(2)
    reach <- max(reach, tick_reach)
  }
  reach
}

# The count limit for text of the given height (in normalized units).
.fourfold_count_limit <- function(text_height) {
  min(.fourfold_square_count_limit, .fourfold_count_offset - text_height)
}

.fourfold_match_arg <- function(arg, choices, name) {
  tryCatch(
    match.arg(arg, choices),
    error = function(e) stop(conditionMessage(e), call. = FALSE)
  )
}

.fourfold_validate_params <- function(
    std, margin, conf_level, extended, ticks, p_adjust_method, palette,
    shape = "circle") {
  std <- .fourfold_match_arg(
    std, c("margins", "ind.max", "all.max"), "std"
  )
  shape <- .fourfold_match_arg(shape, c("circle", "square"), "shape")
  p_adjust_method <- .fourfold_match_arg(
    p_adjust_method, stats::p.adjust.methods, "p_adjust_method"
  )

  if (!(length(conf_level) == 1L && is.finite(conf_level) &&
        conf_level >= 0 && conf_level < 1)) {
    stop("conf_level must be a single number between 0 and 1", call. = FALSE)
  }
  if (!(length(extended) == 1L && !is.na(extended))) {
    stop("extended must be TRUE or FALSE", call. = FALSE)
  }
  if (!(length(ticks) == 1L && is.finite(ticks) && ticks >= 0)) {
    stop("ticks must be a single non-negative number", call. = FALSE)
  }
  if (length(palette) < 6L) {
    stop("palette must contain at least six colours", call. = FALSE)
  }
  tryCatch(
    grDevices::col2rgb(palette[seq_len(6L)]),
    error = function(e) stop("palette contains an invalid colour", call. = FALSE)
  )

  if (std == "margins") {
    valid_margin <- (length(margin) == 2L &&
      all(sort(margin) == c(1, 2))) ||
      (length(margin) == 1L && margin %in% c(1, 2))
    if (!valid_margin) {
      stop("incorrect margin specification", call. = FALSE)
    }
  }

  list(
    std = std,
    margin = margin,
    conf_level = conf_level,
    extended = isTRUE(extended),
    ticks = ticks,
    p_adjust_method = p_adjust_method,
    palette = palette,
    shape = shape
  )
}

.fourfold_odds <- function(tab) {
  corrected <- tab
  if (any(corrected == 0)) {
    corrected <- corrected + 0.5
  }
  list(
    or = (corrected[1, 1] * corrected[2, 2]) /
      (corrected[1, 2] * corrected[2, 1]),
    se = sqrt(sum(1 / corrected)),
    corrected = corrected
  )
}

.fourfold_standardize <- function(tab, std, margin, all_max) {
  if (std == "margins") {
    if (length(margin) == 2L) {
      root_or <- sqrt(.fourfold_odds(tab)$or)
      u <- root_or / (1 + root_or)
      return(matrix(c(u, 1 - u, 1 - u, u), nrow = 2L))
    }
    return(prop.table(tab, margin))
  }
  if (std == "ind.max") {
    return(tab / max(tab))
  }
  tab / all_max
}

.fourfold_table_with_or_and_margins <- function(or, tab) {
  first_row <- rowSums(tab)[1]
  second_row <- rowSums(tab)[2]
  first_column <- colSums(tab)[1]

  if (or == 1) {
    x <- first_column * second_row / (first_row + second_row)
  } else if (is.infinite(or)) {
    x <- max(0, first_column - first_row)
  } else {
    a <- or - 1
    b <- or * (first_row - first_column) + second_row + first_column
    cc <- -first_column * second_row
    x <- (-b + sqrt(b^2 - 4 * a * cc)) / (2 * a)
  }

  matrix(
    c(
      first_column - x, x,
      first_row - first_column + x, second_row - x
    ),
    nrow = 2L
  )
}

.fourfold_panel_table <- function(data, panel, layout, na.rm) {
  incomplete <- is.na(data$x) | is.na(data$y) | is.na(data$weight)
  if (any(incomplete)) {
    if (!na.rm) {
      warning(
        sprintf(
          "Removed %d row%s containing missing fourfold values in panel %s.",
          sum(incomplete), if (sum(incomplete) == 1L) "" else "s", panel
        ),
        call. = FALSE
      )
    }
    data <- data[!incomplete, , drop = FALSE]
  }
  if (!nrow(data)) {
    stop(sprintf("fourfold panel %s contains no complete observations", panel),
         call. = FALSE)
  }
  if (any(!is.finite(data$weight)) || any(data$weight < 0)) {
    stop(sprintf("fourfold weights in panel %s must be finite and non-negative",
                 panel), call. = FALSE)
  }

  panel_scales <- layout$get_scales(as.integer(panel))
  x_labels <- panel_scales$x$get_labels()
  y_labels <- panel_scales$y$get_labels()
  if (length(x_labels) != 2L || length(y_labels) != 2L) {
    stop(
      sprintf(
        "fourfold panels require exactly two x levels and two y levels; panel %s has %d and %d",
        panel, length(x_labels), length(y_labels)
      ),
      call. = FALSE
    )
  }

  x_index <- as.integer(data$x)
  y_index <- as.integer(data$y)
  if (any(!x_index %in% 1:2) || any(!y_index %in% 1:2)) {
    stop(sprintf("fourfold panel %s contains invalid mapped levels", panel),
         call. = FALSE)
  }

  tab <- matrix(
    0, nrow = 2L, ncol = 2L,
    dimnames = list(as.character(y_labels), as.character(x_labels))
  )
  for (i in seq_len(nrow(data))) {
    tab[y_index[i], x_index[i]] <-
      tab[y_index[i], x_index[i]] + data$weight[i]
  }
  if (sum(tab) <= 0) {
    stop(sprintf("fourfold panel %s must have a positive total", panel),
         call. = FALSE)
  }

  list(
    panel = panel,
    table = tab,
    x_labels = as.character(x_labels),
    y_labels = as.character(y_labels)
  )
}

.fourfold_compute_layer <- function(
    data, layout, std, margin, conf_level, extended, p_adjust_method, na.rm) {
  if (is.null(data$weight)) {
    data$weight <- 1
  }
  panels <- split(data, data$PANEL, drop = TRUE)
  prepared <- Map(
    function(panel_data, panel) {
      .fourfold_panel_table(panel_data, panel, layout, na.rm)
    },
    panels,
    names(panels)
  )
  all_max <- max(vapply(prepared, function(x) max(x$table), numeric(1)))

  inference <- lapply(prepared, function(x) .fourfold_odds(x$table))
  raw_p <- rep(NA_real_, length(prepared))
  adjusted_p <- rep(NA_real_, length(prepared))
  if (conf_level > 0 && extended) {
    raw_p <- vapply(
      inference,
      function(x) 2 * stats::pnorm(abs(log(x$or)) / x$se, lower.tail = FALSE),
      numeric(1)
    )
    adjusted_p <- stats::p.adjust(raw_p, method = p_adjust_method)
  }

  panel_levels <- levels(data$PANEL)
  result <- vector("list", length(prepared))
  for (i in seq_along(prepared)) {
    item <- prepared[[i]]
    tab <- item$table
    fit <- .fourfold_standardize(tab, std, margin, all_max)
    ci <- c(NA_real_, NA_real_)
    ci_radii <- matrix(NA_real_, nrow = 2L, ncol = 4L)
    if (conf_level > 0) {
      ci <- inference[[i]]$or * exp(
        stats::qnorm(c((1 - conf_level) / 2, (1 + conf_level) / 2)) *
          inference[[i]]$se
      )
      for (bound in 1:2) {
        confidence_table <- .fourfold_table_with_or_and_margins(ci[bound], tab)
        ci_radii[bound, ] <- sqrt(c(.fourfold_standardize(
          confidence_table, std, margin, all_max
        )))
      }
    }

    emphasize <- if (extended && conf_level > 0) {
      2L * (1L + (adjusted_p[i] < 1 - conf_level))
    } else {
      0L
    }
    positive <- unname(inference[[i]]$or > 1)
    palette_index <- unname(c(
      1L + positive + emphasize,
      2L - positive + emphasize,
      2L - positive + emphasize,
      1L + positive + emphasize
    ))

    result[[i]] <- data.frame(
      row.names = seq_len(4L),
      PANEL = factor(item$panel, levels = panel_levels),
      group = seq_len(4L),
      cell = seq_len(4L),
      x = structure(c(1, 1, 2, 2), class = c("mapped_discrete", "numeric")),
      y = structure(c(1, 2, 1, 2), class = c("mapped_discrete", "numeric")),
      x_index = c(1L, 1L, 2L, 2L),
      y_index = c(1L, 2L, 1L, 2L),
      x_label = c(
        item$x_labels[1], item$x_labels[1],
        item$x_labels[2], item$x_labels[2]
      ),
      y_label = c(
        item$y_labels[1], item$y_labels[2],
        item$y_labels[1], item$y_labels[2]
      ),
      count = unname(c(tab)),
      standardized = unname(c(fit)),
      radius = unname(sqrt(c(fit))),
      conf_low_radius = unname(ci_radii[1, ]),
      conf_high_radius = unname(ci_radii[2, ]),
      odds_ratio = unname(inference[[i]]$or),
      standard_error = unname(inference[[i]]$se),
      conf_low = unname(ci[1]),
      conf_high = unname(ci[2]),
      p_value = unname(raw_p[i]),
      p_adjusted = unname(adjusted_p[i]),
      significant = if (is.na(adjusted_p[i])) NA else
        adjusted_p[i] < 1 - conf_level,
      palette_index = palette_index,
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, result)
}

StatFourfold <- ggplot2::ggproto(
  "StatFourfold", ggplot2::Stat,
  required_aes = c("x", "y"),
  default_aes = ggplot2::aes(weight = 1),
  extra_params = c(
    "na.rm", "std", "margin", "conf_level", "extended",
    "p_adjust_method"
  ),
  compute_layer = function(self, data, params, layout) {
    .fourfold_compute_layer(
      data = data,
      layout = layout,
      std = params$std,
      margin = params$margin,
      conf_level = params$conf_level,
      extended = params$extended,
      p_adjust_method = params$p_adjust_method,
      na.rm = params$na.rm
    )
  }
)

.fourfold_sector_grob <- function(
    radius, from, to, fill = "transparent", colour = "black",
    alpha = NA_real_, lwd = 1, shape = "circle", name = NULL) {
  if (shape == "square") {
    # Quarter-square with the same area as the quarter-circle of this radius.
    side <- radius * .fourfold_square_side
    middle <- 2 * pi * (from + to) / 2 / 360
    sx <- sign(round(cos(middle), 8))
    sy <- sign(round(sin(middle), 8))
    x <- c(0, sx, sx, 0) * side
    y <- c(0, 0, sy, sy) * side
  } else {
    angle <- 2 * pi * seq(from, to, length.out = 300L) / 360
    x <- c(cos(angle), 0) * radius
    y <- c(sin(angle), 0) * radius
  }
  grid::polygonGrob(
    x = grid::unit(x, "native"),
    y = grid::unit(y, "native"),
    gp = grid::gpar(
      fill = scales::alpha(fill, alpha),
      col = scales::alpha(colour, alpha),
      lwd = lwd,
      linejoin = "round"
    ),
    name = name
  )
}

.fourfold_responsive_text_grob <- function(
    label, x, y, hjust = 0.5, vjust = 0.5, angle = 0,
    relative_size, minimum_size, colour, alpha, family, fontface = 1,
    name = NULL) {
  grid::gTree(
    label = label,
    x = grid::unit(x, "native"),
    y = grid::unit(y, "native"),
    hjust = hjust,
    vjust = vjust,
    angle = angle,
    relative_size = relative_size,
    minimum_size = minimum_size,
    colour = scales::alpha(colour, alpha),
    family = family,
    fontface = fontface,
    name = name,
    cl = "fourfold_responsive_text"
  )
}

# Register the delayed text-sizing method when this file is placed in R/.
#' @importFrom grid convertHeight convertWidth
#' @importFrom grid gList gpar makeContent setChildren textGrob unit
#' @exportS3Method grid::makeContent
makeContent.fourfold_responsive_text <- function(x) {
  panel_width <- grid::convertWidth(
    grid::unit(1, "npc"), "points", valueOnly = TRUE
  )
  panel_height <- grid::convertHeight(
    grid::unit(1, "npc"), "points", valueOnly = TRUE
  )
  fontsize <- .fourfold_responsive_size(
    panel_width, panel_height, x$relative_size, x$minimum_size
  )
  child <- grid::textGrob(
    label = x$label,
    x = x$x,
    y = x$y,
    hjust = x$hjust,
    vjust = x$vjust,
    rot = x$angle,
    gp = grid::gpar(
      col = x$colour,
      fontfamily = x$family,
      fontface = x$fontface,
      fontsize = fontsize,
      lineheight = 1
    ),
    name = paste0(x$name, "-text")
  )
  grid::setChildren(x, grid::gList(child))
}

# Counts are placed when drawn, once the responsive text size is known: inside
# the frame corners unless the layer's squares or ticks reach the measured
# count text, and otherwise just outside the corners.
#' @exportS3Method grid::makeContent
makeContent.fourfold_counts <- function(x) {
  panel_width <- grid::convertWidth(
    grid::unit(1, "npc"), "points", valueOnly = TRUE
  )
  panel_height <- grid::convertHeight(
    grid::unit(1, "npc"), "points", valueOnly = TRUE
  )
  gp <- grid::gpar(
    col = x$colour,
    fontfamily = x$family,
    fontsize = .fourfold_responsive_size(
      panel_width, panel_height, x$relative_size, x$minimum_size
    ),
    lineheight = 1
  )
  text_height <- max(vapply(
    x$labels,
    function(label) {
      grid::convertHeight(
        grid::grobHeight(grid::textGrob(label, gp = gp)),
        "native", valueOnly = TRUE
      )
    },
    numeric(1)
  ))
  # Recorded on the drawn grob for inspection (see dev/square-counts.R).
  x$count_limit <- .fourfold_count_limit(text_height)
  x$outside <- isTRUE(x$reach > x$count_limit)
  outside <- x$outside

  offset <- if (outside) 1.02 else .fourfold_count_offset
  count_x <- c(-1, -1, 1, 1) * offset
  count_y <- c(1, -1, 1, -1) * offset
  count_hjust <- c(0, 0, 1, 1)
  count_vjust <- c(1, 0, 1, 0)
  if (outside) {
    count_hjust <- 1 - count_hjust
    count_vjust <- 1 - count_vjust
  }
  children <- lapply(seq_len(4L), function(cell) {
    grid::textGrob(
      label = x$labels[cell],
      x = grid::unit(count_x[cell], "native"),
      y = grid::unit(count_y[cell], "native"),
      hjust = count_hjust[cell],
      vjust = count_vjust[cell],
      gp = gp,
      name = paste0("fourfold-count-", cell)
    )
  })
  grid::setChildren(x, do.call(grid::gList, children))
}

.fourfold_responsive_size <- function(
    panel_width, panel_height, relative_size, minimum_size) {
  max(minimum_size, min(panel_width, panel_height) * relative_size)
}

.fourfold_segments_grob <- function(x0, y0, x1, y1, colour, alpha, lwd,
                                    name = NULL) {
  grid::segmentsGrob(
    x0 = grid::unit(x0, "native"),
    y0 = grid::unit(y0, "native"),
    x1 = grid::unit(x1, "native"),
    y1 = grid::unit(y1, "native"),
    gp = grid::gpar(col = scales::alpha(colour, alpha), lwd = lwd),
    name = name
  )
}

#' @rdname geom_fourfold
#' @name geom_fourfold
#' @format A `GeomFourfold` ggproto object.
#' @importFrom ggplot2 aes draw_key_blank from_theme Geom ggproto
#' @importFrom grid gList gpar gTree polygonGrob
#' @importFrom grid rectGrob segmentsGrob unit viewport
#' @importFrom scales alpha
#' @export
GeomFourfold <- ggplot2::ggproto(
  "GeomFourfold", ggplot2::Geom,
  required_aes = c(
    "cell", "count", "radius", "palette_index",
    "x_index", "y_index", "x_label", "y_label"
  ),
  default_aes = ggplot2::aes(
    colour = ggplot2::from_theme(ink),
    linewidth = ggplot2::from_theme(linewidth),
    size = ggplot2::from_theme(fontsize),
    family = ggplot2::from_theme(family),
    alpha = NA
  ),
  extra_params = c("na.rm", "palette", "ticks", "extended", "shape"),
  draw_key = ggplot2::draw_key_blank,
  setup_data = function(data, params) {
    # One layer-wide value, so that every facet places its counts alike.
    data$counts_reach <- .fourfold_counts_reach(
      data,
      shape = params$shape,
      extended = params$extended,
      ticks = params$ticks
    )
    data
  },
  draw_panel = function(
      data, panel_params, coord, palette, ticks, extended,
      shape = "circle", na.rm = FALSE) {
    data <- data[order(data$cell), , drop = FALSE]
    colour <- data$colour[1]
    alpha <- data$alpha[1]
    family <- data$family[1]
    base_size <- data$size[1] * .fourfold_pt
    lwd <- data$linewidth[1] * .fourfold_pt

    grobs <- list()
    add <- function(grob) {
      grobs[[length(grobs) + 1L]] <<- grob
    }

    angle_from <- c(90, 180, 0, 270)
    angle_to <- c(180, 270, 90, 360)
    for (cell in seq_len(4L)) {
      add(.fourfold_sector_grob(
        data$radius[cell], angle_from[cell], angle_to[cell],
        fill = palette[data$palette_index[cell]],
        colour = colour, alpha = alpha, lwd = lwd, shape = shape,
        name = paste0("fourfold-sector-", cell)
      ))
    }

    if (any(is.finite(data$conf_low_radius))) {
      for (bound in c("conf_low_radius", "conf_high_radius")) {
        for (cell in seq_len(4L)) {
          add(.fourfold_sector_grob(
            data[[bound]][cell], angle_from[cell], angle_to[cell],
            fill = "transparent", colour = colour, alpha = alpha, lwd = lwd,
            shape = shape, name = paste0("fourfold-", bound, "-", cell)
          ))
        }
      }
    }

    if (extended && ticks > 0) {
      if (data$odds_ratio[1] > 1) {
        cells <- c(1L, 4L)
        angles <- c(3 * pi / 4, -pi / 4)
      } else {
        cells <- c(3L, 2L)
        angles <- c(pi / 4, -3 * pi / 4)
      }
      radii <- data$radius[cells]
      if (shape == "square") {
        # Start the diagonal ticks at the outer corners of the squares.
        radii <- radii * .fourfold_square_side * sqrt(2)
      }
      add(.fourfold_segments_grob(
        radii * cos(angles), radii * sin(angles),
        (radii + ticks) * cos(angles), (radii + ticks) * sin(angles),
        colour, alpha, lwd, "fourfold-direction-ticks"
      ))
    }

    add(.fourfold_segments_grob(
      c(-1, 0), c(0, -1), c(1, 0), c(0, 1),
      colour, alpha, lwd, "fourfold-axes"
    ))
    major <- seq(-0.8, 0.8, by = 0.2)
    minor <- seq(-0.9, 0.9, by = 0.2)
    add(.fourfold_segments_grob(
      c(major, minor, rep(-0.02, length(major)), rep(-0.01, length(minor))),
      c(rep(-0.02, length(major)), rep(-0.01, length(minor)), major, minor),
      c(major, minor, rep(0.02, length(major)), rep(0.01, length(minor))),
      c(rep(0.02, length(major)), rep(0.01, length(minor)), major, minor),
      colour, alpha, lwd * 0.8, "fourfold-axis-ticks"
    ))
    add(grid::rectGrob(
      x = grid::unit(-1, "native"),
      y = grid::unit(-1, "native"),
      width = grid::unit(2, "native"),
      height = grid::unit(2, "native"),
      just = c("left", "bottom"),
      gp = grid::gpar(
        fill = "transparent", col = scales::alpha(colour, alpha), lwd = lwd
      ),
      name = "fourfold-frame"
    ))

    relative_size <- 0.066 * base_size / 12
    minimum_size <- base_size * 5 / 6
    label_offset <- 1.16
    x_labels <- data$x_label[match(1:2, data$x_index)]
    y_labels <- data$y_label[match(1:2, data$y_index)]
    outer <- list(
      list(y_labels[1], 0, label_offset, 0),
      list(x_labels[1], -label_offset, 0, 90),
      list(y_labels[2], 0, -label_offset, 0),
      list(x_labels[2], label_offset, 0, 90)
    )
    outer_names <- c("top", "left", "bottom", "right")
    for (i in seq_along(outer)) {
      add(.fourfold_responsive_text_grob(
        label = outer[[i]][[1]], x = outer[[i]][[2]], y = outer[[i]][[3]],
        angle = outer[[i]][[4]], relative_size = relative_size,
        minimum_size = minimum_size, colour = colour, alpha = alpha,
        family = family, name = paste0("fourfold-label-", outer_names[i])
      ))
    }

    add(grid::gTree(
      labels = as.character(data$count),
      reach = data$counts_reach[1],
      relative_size = relative_size,
      minimum_size = minimum_size,
      colour = scales::alpha(colour, alpha),
      family = family,
      name = "fourfold-counts",
      cl = "fourfold_counts"
    ))

    grid::gTree(
      children = do.call(grid::gList, grobs),
      vp = grid::viewport(
        xscale = c(-1.3, 1.3), yscale = c(-1.3, 1.3), clip = "off"
      ),
      name = "fourfold-panel"
    )
  }
)

#' Fourfold displays for 2-by-2 tables
#'
#' `geom_fourfold()` draws a fourfold display in each ggplot2 panel. Sector
#' radii represent cell frequencies after the selected standardization, while
#' sector colours, confidence rings, and direction ticks show the direction
#' and strength of association.
#'
#' @details
#' Map the two-level horizontal variable to `x`, the two-level vertical
#' variable to `y`, and cell frequencies to `weight`. When `weight` is omitted,
#' each row counts as one observation. The first `x` level is drawn on the left
#' and the second on the right; the first `y` level is drawn at the top and the
#' second at the bottom. Set factor levels explicitly when their order matters.
#'
#' One panel must contain exactly one 2-by-2 table. Use
#' [ggplot2::facet_grid()] or [ggplot2::facet_wrap()] to display stratified
#' tables. Duplicate `x`/`y` combinations within a panel are summed and missing
#' cells are completed with zero counts.
#'
#' Odds ratios, Wald confidence intervals, and extended-display p-values match
#' the calculations in `vcd::fourfold()`. If any observed cell is zero, 0.5 is
#' added to all four cells for inference. P-values are adjusted across all
#' panels in the layer. Confidence intervals themselves are not adjusted.
#'
#' With `shape = "square"`, each cell is drawn as a quarter-square with the
#' same area as the corresponding quarter-circle (side
#' \eqn{r\sqrt{\pi}/2}{r * sqrt(pi) / 2} for radius \eqn{r}), so the two
#' shapes display a table with identical areas. Confidence rings
#' become nested square outlines. Cell counts stay inside the frame corners
#' unless a square, confidence outline, or direction tick in any panel of the
#' layer would reach them, as is always the case with `std = "ind.max"`; the
#' counts in every panel are then placed just outside the frame corners.
#'
#' The six semantic fill colours are supplied by `palette`; they are not mapped
#' through a ggplot2 fill scale. Typography and layout defaults are controlled
#' by [theme_fourfold()].
#'
#' @section Aesthetics:
#' `geom_fourfold()` understands the following aesthetics:
#'
#' - `x` (required): a variable with exactly two levels.
#' - `y` (required): a variable with exactly two levels.
#' - `weight`: non-negative cell frequencies; defaults to `1`.
#' - `colour`, `linewidth`, `alpha`, `size`, and `family`: fixed or mapped
#'   drawing properties. `size` and `family` default to values inherited from
#'   the plot theme.
#'
#' @param mapping Set of aesthetic mappings created by [ggplot2::aes()]. If
#'   supplied and `inherit.aes = TRUE`, these are combined with the plot's
#'   default mappings.
#' @param data The data to display in this layer. If `NULL`, the default, the
#'   data are inherited from the plot.
#' @param ... Other arguments passed to [ggplot2::layer()], typically fixed
#'   aesthetics such as `colour` or `linewidth`.
#' @param std Standardization method. `"margins"` fixes the selected margins,
#'   `"ind.max"` divides each panel by its largest cell, and `"all.max"`
#'   divides every panel by the largest cell in the complete layer.
#' @param margin Integer vector selecting the table margins when
#'   `std = "margins"`. Use `c(1, 2)` for both margins, `1` for the `y` margin,
#'   or `2` for the `x` margin.
#' @param conf_level Confidence level in `[0, 1)`. Set to `0` to suppress
#'   confidence rings.
#' @param extended If `TRUE`, use adjusted p-values to emphasize association
#'   and draw direction ticks.
#' @param ticks Non-negative length of the association direction ticks in the
#'   geom's normalized panel coordinates.
#' @param p_adjust_method Method passed to [stats::p.adjust()] for adjustment
#'   across panels. Defaults to `"holm"`, the first value in
#'   [stats::p.adjust.methods].
#' @param shape Shape of the cell sectors: `"circle"` (the default, as in
#'   `vcd::fourfold()`) draws quarter-circles; `"square"` draws
#'   quarter-squares of equal area.
#' @param palette Character vector of at least six valid colours in the
#'   semantic order used by `fourfold_palette()`.
#' @param na.rm If `FALSE`, the default, missing observations are removed with
#'   a warning. If `TRUE`, they are removed silently.
#' @param show.legend Logical indicating whether this layer should be included
#'   in legends. The default is `FALSE` because the semantic fills are not a
#'   mapped aesthetic.
#' @param inherit.aes If `FALSE`, override rather than combine with the plot's
#'   default aesthetic mappings.
#'
#' @return A ggplot2 layer that can be added to a [ggplot2::ggplot()] object.
#'
#' @references
#' Friendly, M. (1994). *A fourfold display for 2 by 2 by k tables*
#' (Technical Report No. 217). York University, Psychology Department.
#' <http://datavis.ca/papers/4fold/4fold.pdf>
#'
#' @seealso [theme_fourfold()], [fourfold_palette()],
#'   [ggplot2::facet_grid()], and [ggplot2::facet_wrap()]
#'
#' @examples
#' ucb <- as.data.frame(UCBAdmissions)
#'
#' ggplot2::ggplot(
#'   ucb,
#'   ggplot2::aes(x = Gender, y = Admit, weight = Freq)
#' ) +
#'   geom_fourfold() +
#'   ggplot2::facet_wrap(ggplot2::vars(Dept), ncol = 3) +
#'   ggplot2::labs(title = "Berkeley admissions") +
#'   theme_fourfold()
#'
#' # Quarter-squares of equal area instead of quarter-circles
#' ggplot2::ggplot(
#'   ucb,
#'   ggplot2::aes(x = Gender, y = Admit, weight = Freq)
#' ) +
#'   geom_fourfold(shape = "square") +
#'   ggplot2::facet_wrap(ggplot2::vars(Dept), ncol = 3) +
#'   theme_fourfold()
#'
#' @importFrom grDevices col2rgb
#' @importFrom ggplot2 aes ggproto layer Stat
#' @importFrom stats p.adjust p.adjust.methods pnorm qnorm
#' @export
geom_fourfold <- function(
    mapping = NULL,
    data = NULL,
    ...,
    std = c("margins", "ind.max", "all.max"),
    margin = c(1, 2),
    conf_level = 0.95,
    extended = TRUE,
    ticks = 0.15,
    p_adjust_method = stats::p.adjust.methods,
    shape = c("circle", "square"),
    palette = fourfold_palette(),
    na.rm = FALSE,
    show.legend = FALSE,
    inherit.aes = TRUE) {
  validated <- .fourfold_validate_params(
    std, margin, conf_level, extended, ticks, p_adjust_method, palette,
    shape
  )
  ggplot2::layer(
    data = data,
    mapping = mapping,
    stat = StatFourfold,
    geom = GeomFourfold,
    position = "identity",
    show.legend = show.legend,
    inherit.aes = inherit.aes,
    params = c(
      list(
        std = validated$std,
        margin = validated$margin,
        conf_level = validated$conf_level,
        extended = validated$extended,
        ticks = validated$ticks,
        p_adjust_method = validated$p_adjust_method,
        palette = validated$palette,
        shape = validated$shape,
        na.rm = na.rm
      ),
      list(...)
    )
  )
}
