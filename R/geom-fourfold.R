#' @include fourfold-palette.R
NULL

.fourfold_match_arg <- function(arg, choices, name) {
  tryCatch(
    match.arg(arg, choices),
    error = function(e) {
      choices <- encodeString(choices, quote = "\"")
      n <- length(choices)
      stop(
        sprintf(
          "`%s` must be one of %s%s or %s", name,
          paste(choices[-n], collapse = ", "), if (n > 2L) "," else "",
          choices[n]
        ),
        call. = FALSE
      )
    }
  )
}

# The defaults of geom_fourfold(), resolved, for direct use of the ggproto
# objects with ggplot2::layer().
.fourfold_defaults <- list(
  std = "margins", margin = c(1, 2), conf_level = 0.95, extended = TRUE,
  ticks = 0.15, p_adjust_method = "holm", shape = "circle", counts = "auto",
  palette = fourfold_palette(), na.rm = FALSE
)

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

# For circles, enlarge the count box towards the centre by 0.04 on each axis
# (half the square rule's nominal 0.08 clearance). This leaves breathing room
# around arcs without treating a diagonal tick as a whole circular outline.
.fourfold_circle_count_clearance <- 0.04

# Layer-wide outline reach (square side or circle radius) and diagonal tick
# endpoint coordinate. Only finite radii of nonblank panels contribute.
.fourfold_counts_reach <- function(
    data, shape = NULL, extended = NULL, ticks = NULL) {
  if (is.null(shape)) shape <- .fourfold_defaults$shape
  if (is.null(extended)) extended <- .fourfold_defaults$extended
  if (is.null(ticks)) ticks <- .fourfold_defaults$ticks
  data <- data[!is.na(data$odds_ratio), , drop = FALSE]
  radii <- c(data$radius, data$conf_low_radius, data$conf_high_radius)
  multiplier <- if (shape == "square") .fourfold_square_side else 1
  reach <- max(c(-Inf, radii[is.finite(radii)])) * multiplier
  tick_reach <- -Inf
  if (extended && ticks > 0) {
    tick_cell <- ifelse(
      data$odds_ratio > 1, data$cell %in% c(1L, 4L),
      data$cell %in% c(2L, 3L)
    )
    tick_multiplier <- if (shape == "square") .fourfold_square_side else 1 / sqrt(2)
    tick_reach <- data$radius[tick_cell] * tick_multiplier + ticks / sqrt(2)
    tick_reach <- max(c(-Inf, tick_reach[is.finite(tick_reach)]))
  }
  c(outline = reach, tick = tick_reach)
}

# The values that place counts alike in every panel of a layer: the outline
# and tick reach, and the count labels to measure (see
# makeContent.fourfold_counts()). Blank panels draw no sectors or ticks and
# must not affect placement.
.fourfold_counts_params <- function(data, shape, extended, ticks) {
  reach <- .fourfold_counts_reach(data, shape, extended, ticks)
  list(
    counts_reach = unname(reach["outline"]),
    counts_tick_reach = unname(reach["tick"]),
    counts_labels = unique(as.character(data$count[!is.na(data$odds_ratio)]))
  )
}

# The count limit for text of the given height (in normalized units).
.fourfold_count_limit <- function(text_height) {
  min(.fourfold_square_count_limit, .fourfold_count_offset - text_height)
}

# Each panel draws one table, so the drawing properties are fixed for the
# layer. A mapping in the layer itself is an error, including one to a computed
# variable with after_stat(), after_scale(), or stage(); one inherited from the
# plot is left unused, since it may be meant for other layers (the stat drops
# ordinary mappings, and GeomFourfold drops the computed ones).
.fourfold_fixed_aes <- c("colour", "linewidth", "alpha", "size", "family")

# aes() has already standardized names such as color and lwd. A NULL entry, as
# in aes(colour = NULL), removes an inherited mapping and is allowed.
.fourfold_check_mapping <- function(mapping) {
  # Anything other than an aes() mapping is left to ggplot2's own checks.
  if (!ggplot2::is_mapping(mapping)) {
    return(invisible())
  }
  mapped <- intersect(names(mapping), .fourfold_fixed_aes)
  mapped <- mapped[!vapply(mapped, function(name) is.null(mapping[[name]]),
                           logical(1))]
  if (length(mapped)) {
    mapped <- paste0("`", mapped, "`")
    if (length(mapped) > 1L) {
      mapped <- paste(
        paste(mapped[-length(mapped)], collapse = ", "),
        mapped[length(mapped)],
        sep = if (length(mapped) > 2L) ", and " else " and "
      )
    }
    stop(
      sprintf(
        paste0(
          "%s cannot be mapped in geom_fourfold(), which draws one table per ",
          "panel; set colour, linewidth, and alpha as fixed arguments, e.g. ",
          "`geom_fourfold(colour = \"grey30\")`, and text size and font with ",
          "`theme_fourfold()`"
        ),
        mapped
      ),
      call. = FALSE
    )
  }
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
    fit <- prop.table(tab, margin)
    # A row (margin = 1) or column (margin = 2) with a zero total has no
    # proportions, so only that row or column is drawn from the table with 0.5
    # added to every cell.
    empty <- apply(tab, margin, sum) == 0
    if (any(empty)) {
      corrected <- prop.table(.fourfold_odds(tab)$corrected, margin)
      if (margin == 1) {
        fit[empty, ] <- corrected[empty, ]
      } else {
        fit[, empty] <- corrected[, empty]
      }
    }
    return(fit)
  }
  if (std == "ind.max") {
    return(tab / max(tab))
  }
  tab / all_max
}

# The second-row, first-column cell of the 2 x 2 table with odds ratio `or`,
# row totals `first_row` and `second_row`, and first column total
# `first_column`: the root of (or - 1) x^2 + b x - first_column * second_row
# that keeps all four cells non-negative. Each branch writes the discriminant
# as a sum of non-negative terms and chooses the form of the root without
# cancellation; for odds ratios above 1 the equation is divided by `or`, so
# that nothing overflows.
.fourfold_cell_with_or <- function(or, first_row, second_row, first_column) {
  if (or <= 1) {
    b <- or * first_row + (1 - or) * first_column + second_row
    root <- sqrt(
      ((1 - or) * first_column - second_row)^2 +
        or * first_row * (2 * ((1 - or) * first_column + second_row) +
                            or * first_row)
    )
    x <- if (b + root > 0) {
      2 * first_column * second_row / (b + root)
    } else {
      0
    }
  } else {
    inverse <- 1 / or
    a <- 1 - inverse
    b <- first_row - first_column + inverse * (second_row + first_column)
    product <- inverse * first_column * second_row
    root <- sqrt(b^2 + 4 * a * product)
    x <- if (b < 0) {
      (-b + root) / (2 * a)
    } else if (b + root > 0) {
      2 * product / (b + root)
    } else {
      0
    }
  }
  # Rounding can leave x just outside the range that keeps all four cells
  # non-negative.
  min(max(x, first_column - first_row, 0), first_column, second_row)
}

.fourfold_table_with_or_and_margins <- function(or, tab) {
  # The solution scales with the table, so it is found for proportions, which
  # keeps the products of totals below from over- or underflowing.
  total <- sum(tab)
  rows <- unname(rowSums(tab)) / total
  columns <- unname(colSums(tab)) / total
  # Each cell is solved for directly rather than as a difference of totals, so
  # that small cells keep their precision. Swapping the rows moves the first
  # cell to the solved position, swapping the columns the fourth, and
  # swapping both the third; a single swap inverts the odds ratio.
  total * matrix(
    c(
      .fourfold_cell_with_or(1 / or, rows[2], rows[1], columns[1]),
      .fourfold_cell_with_or(or, rows[1], rows[2], columns[1]),
      .fourfold_cell_with_or(or, rows[2], rows[1], columns[2]),
      .fourfold_cell_with_or(1 / or, rows[1], rows[2], columns[2])
    ),
    nrow = 2L
  )
}

# Counts are placed by mapped scale position, so each category must sit at its
# own position 1, 2, ... in limits order. Continuous scales use the raw values
# as positions, and a discrete scale's `palette` can move categories.
.fourfold_check_positions <- function(scale, aesthetic, panel) {
  # Numeric data on a discrete scale also keep their raw values as positions;
  # the scale then has a continuous range but no discrete one. (With free
  # scales, an empty discrete range can be character(0) rather than NULL.)
  if (!scale$is_discrete() ||
      (!length(scale$range$range) && !is.null(scale$range_c$range))) {
    stop(
      sprintf(
        paste0(
          "fourfold %s in panel %s must be categorical (a factor, character, ",
          "or logical variable), not continuous; convert numeric codes with ",
          "`factor()`"
        ),
        aesthetic, panel
      ),
      call. = FALSE
    )
  }
  categories <- scale$get_limits()
  categories <- categories[!is.na(categories)]
  # Data are matched to the limits as character, so numeric limits work.
  positions <- as.numeric(scale$map(as.character(categories)))
  if (!identical(positions, as.numeric(seq_along(categories)))) {
    stop(
      sprintf(
        paste0(
          "fourfold %s categories in panel %s, (%s), are at positions (%s) ",
          "but must be at (%s); use `limits`, not a scale `palette`, to ",
          "reorder categories"
        ),
        aesthetic, panel,
        paste(encodeString(as.character(categories), quote = "\""),
              collapse = ", "),
        paste(positions, collapse = ", "),
        paste(seq_along(categories), collapse = ", ")
      ),
      call. = FALSE
    )
  }
  invisible()
}

# Counts are placed by scale position (limits order), but labels come in
# breaks order, so breaks that reorder or omit categories would detach the
# labels from their counts.
.fourfold_check_breaks <- function(scale, aesthetic, panel) {
  if (!scale$is_discrete()) {
    return(invisible())
  }
  # The missing-value category is not one of the table's categories.
  categories <- as.character(scale$get_limits())
  categories <- categories[!is.na(categories)]
  breaks <- as.character(scale$get_breaks())
  breaks <- breaks[!is.na(breaks)]
  if (!identical(breaks, categories)) {
    describe <- function(values) {
      if (!length(values)) {
        return("empty")
      }
      values <- encodeString(values, quote = "\"")
      paste0("(", paste(values, collapse = ", "), ")")
    }
    stop(
      sprintf(
        paste0(
          "fourfold %s breaks in panel %s are %s but must be the %s ",
          "categories in order, %s; use `limits` to reorder categories and ",
          "`labels` to rename them"
        ),
        aesthetic, panel, describe(breaks), aesthetic, describe(categories)
      ),
      call. = FALSE
    )
  }
  invisible()
}

# Missing values of a mapped category: a discrete scale maps them to its own
# missing-value category, after the table's categories, unless
# `na.translate = FALSE` leaves them NA.
.fourfold_missing_category <- function(position, scale, aesthetic, panel) {
  missing_position <- as.numeric(scale$map(NA))
  # A scale palette could place it on a table category.
  categories <- scale$get_limits()
  categories <- as.character(categories[!is.na(categories)])
  if (any(missing_position %in% as.numeric(scale$map(categories)))) {
    stop(
      sprintf(
        paste0(
          "fourfold %s in panel %s maps missing values to the position of ",
          "a category; use `limits`, not a scale `palette`, to reorder ",
          "categories"
        ),
        aesthetic, panel
      ),
      call. = FALSE
    )
  }
  is.na(position) | position %in% missing_position
}

# Returns NULL for a panel without a known table, which is left empty.
.fourfold_panel_table <- function(data, panel, layout, na.rm) {
  panel_scales <- layout$get_scales(as.integer(panel))
  .fourfold_check_positions(panel_scales$x, "x", panel)
  .fourfold_check_positions(panel_scales$y, "y", panel)
  .fourfold_check_breaks(panel_scales$x, "x", panel)
  .fourfold_check_breaks(panel_scales$y, "y", panel)

  # A row with a missing x or y cannot be placed and is removed. A row with a
  # missing weight can be placed, but its cell's count, and so the panel's
  # table, is unknown; it is not a zero count.
  incomplete <- .fourfold_missing_category(data$x, panel_scales$x, "x", panel) |
    .fourfold_missing_category(data$y, panel_scales$y, "y", panel)
  unknown <- !incomplete & is.na(data$weight)
  weight <- data$weight[!is.na(data$weight)]
  if (any(!is.finite(weight)) || any(weight < 0)) {
    stop(sprintf("fourfold weights in panel %s must be finite and non-negative",
                 panel), call. = FALSE)
  }
  if (any(unknown)) {
    if (!na.rm) {
      warning(
        sprintf(
          paste0(
            "Left fourfold panel %s empty: %d row%s ha%s a missing weight, ",
            "so the panel's table is unknown."
          ),
          panel, sum(unknown), if (sum(unknown) == 1L) "" else "s",
          if (sum(unknown) == 1L) "s" else "ve"
        ),
        call. = FALSE
      )
    }
    return(NULL)
  }
  if (any(incomplete)) {
    if (!na.rm) {
      warning(
        sprintf(
          paste0(
            "Removed %d row%s containing missing values or values outside the ",
            "scale range in fourfold panel %s%s."
          ),
          sum(incomplete), if (sum(incomplete) == 1L) "" else "s", panel,
          if (all(incomplete)) ", leaving it empty" else ""
        ),
        call. = FALSE
      )
    }
    data <- data[!incomplete, , drop = FALSE]
  }
  if (!nrow(data)) {
    return(NULL)
  }

  # Labels follow the breaks, which include the missing-value category; the
  # other breaks are the table's categories, as checked above.
  x_labels <- panel_scales$x$get_labels()[!is.na(panel_scales$x$get_breaks())]
  y_labels <- panel_scales$y$get_labels()[!is.na(panel_scales$y$get_breaks())]
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
  # Panels without a known table get no rows, so ggplot2 leaves them empty and
  # they take no part in all.max standardization or the p-value adjustment.
  prepared <- Filter(Negate(is.null), prepared)
  if (!length(prepared)) {
    return(data.frame())
  }
  all_max <- max(vapply(prepared, function(x) max(x$table), numeric(1)))

  # A panel whose four counts are all zero has nothing to estimate or
  # standardize; it is drawn blank, with no odds ratio, and is left out of the
  # p-value adjustment (p.adjust() ignores missing p-values).
  empty <- vapply(prepared, function(x) all(x$table == 0), logical(1))
  inference <- lapply(prepared, function(x) .fourfold_odds(x$table))
  for (i in which(empty)) {
    inference[[i]]$or <- NA_real_
    inference[[i]]$se <- NA_real_
  }
  # With positive cells the odds ratio is finite and positive unless the
  # weights over- or underflow in double precision.
  for (i in seq_along(prepared)) {
    if (!empty[i] && !is.finite(log(inference[[i]]$or))) {
      stop(
        sprintf(
          paste(
            "the odds ratio in fourfold panel %s cannot be computed: the",
            "weights are too large or too small"
          ),
          prepared[[i]]$panel
        ),
        call. = FALSE
      )
    }
  }
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
    fit <- if (empty[i]) {
      matrix(0, nrow = 2L, ncol = 2L)
    } else {
      .fourfold_standardize(tab, std, margin, all_max)
    }
    ci <- c(NA_real_, NA_real_)
    ci_radii <- matrix(NA_real_, nrow = 2L, ncol = 4L)
    if (conf_level > 0 && !empty[i]) {
      ci <- inference[[i]]$or * exp(
        stats::qnorm(c((1 - conf_level) / 2, (1 + conf_level) / 2)) *
          inference[[i]]$se
      )
      # Rings keep the observed row and column totals. With an entirely empty
      # row or column those totals admit no other odds ratio, so the rings
      # use the totals of the table with 0.5 added to every cell, rescaled to
      # the observed total so that std = "all.max" keeps the counts' scale.
      ring_base <- if (any(rowSums(tab) == 0) || any(colSums(tab) == 0)) {
        corrected <- inference[[i]]$corrected
        corrected * (sum(tab) / sum(corrected))
      } else {
        tab
      }
      for (bound in 1:2) {
        if (std == "margins" && length(margin) == 2L) {
          # This display depends only on the odds ratio, so each ring is drawn
          # at its confidence limit directly. A ring table at a limit of 0 or
          # Inf has zero cells, which would otherwise get the 0.5 correction
          # again.
          root_limit <- sqrt(ci[bound])
          u <- if (is.infinite(root_limit)) 1 else root_limit / (1 + root_limit)
          ci_radii[bound, ] <- sqrt(c(u, 1 - u, 1 - u, u))
        } else {
          confidence_table <- .fourfold_table_with_or_and_margins(
            ci[bound], ring_base
          )
          ci_radii[bound, ] <- sqrt(c(.fourfold_standardize(
            confidence_table, std, margin, all_max
          )))
        }
      }
    }

    # An empty panel gets a valid but unused palette index, so that ggplot2
    # does not drop its rows as missing.
    emphasize <- if (extended && conf_level > 0 && !empty[i]) {
      2L * (1L + (adjusted_p[i] < 1 - conf_level))
    } else {
      0L
    }
    positive <- !empty[i] && unname(inference[[i]]$or > 1)
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

#' @rdname geom_fourfold
#' @name geom_fourfold
#' @format NULL
#' @usage NULL
#' @export
StatFourfold <- ggplot2::ggproto(
  "StatFourfold", ggplot2::Stat,
  required_aes = c("x", "y"),
  default_aes = ggplot2::aes(weight = 1),
  extra_params = c(
    "na.rm", "std", "margin", "conf_level", "extended",
    "p_adjust_method"
  ),
  setup_params = function(data, params) {
    # Defaults match geom_fourfold() for direct use with ggplot2::layer().
    for (name in c("std", "margin", "conf_level", "extended",
                   "p_adjust_method", "na.rm")) {
      if (is.null(params[[name]])) {
        params[[name]] <- .fourfold_defaults[[name]]
      }
    }
    params
  },
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
# the frame corners unless the layer's sectors, outlines or ticks reach the
# measured count text, and otherwise just outside the corners.
#' @exportS3Method grid::makeContent
makeContent.fourfold_counts <- function(x) {
  panel_width <- grid::convertWidth(
    grid::unit(1, "npc"), "points", valueOnly = TRUE
  )
  panel_height <- grid::convertHeight(
    grid::unit(1, "npc"), "points", valueOnly = TRUE
  )
  # A plot too small for its layout squeezes its panels to nothing, where
  # native units cannot be measured, so the counts are left out (the labels
  # still draw, collapsed with the panel).
  if (panel_width <= 0 || panel_height <= 0) {
    return(grid::setChildren(x, grid::gList()))
  }
  gp <- grid::gpar(
    col = x$colour,
    fontfamily = x$family,
    fontsize = .fourfold_responsive_size(
      panel_width, panel_height, x$relative_size, x$minimum_size
    ),
    lineheight = 1
  )
  # A native scale is reversed when the coordinate system reverses its axis:
  # native heights are then negative, and the corners swap sides.
  viewport <- grid::current.viewport()
  x_direction <- sign(diff(viewport$xscale))
  y_direction <- sign(diff(viewport$yscale))
  text_height <- max(vapply(
    x$labels,
    function(label) {
      abs(grid::convertHeight(
        grid::grobHeight(grid::textGrob(label, gp = gp)),
        "native", valueOnly = TRUE
      ))
    },
    numeric(1)
  ))
  # Recorded on the drawn grob for inspection (see dev/square-counts.R).
  x$count_limit <- .fourfold_count_limit(text_height)
  if (x$shape == "circle") {
    # Use the layer's labels so a wider count in one facet moves all facets.
    # An entirely blank layer has no reach; measure its own zero labels.
    measure_labels <- if (length(x$measure_labels)) x$measure_labels else x$labels
    # Clamp at the axes for text extending past the centre of a small panel.
    inner <- vapply(measure_labels, function(label) {
      text <- grid::textGrob(label, gp = gp)
      dimensions <- c(
        abs(grid::convertWidth(grid::grobWidth(text), "native", valueOnly = TRUE)),
        abs(grid::convertHeight(grid::grobHeight(text), "native", valueOnly = TRUE))
      )
      pmax(0, .fourfold_count_offset - dimensions -
             .fourfold_circle_count_clearance)
    }, numeric(2))
    x$count_limit <- min(sqrt(colSums(inner^2)))
    tick_limit <- min(apply(inner, 2, max))
  } else {
    tick_limit <- x$count_limit
  }
  x$outside <- switch(x$counts,
    auto = isTRUE(x$reach > x$count_limit || x$tick_reach > tick_limit),
    inside = FALSE,
    outside = TRUE
  )
  outside <- x$outside

  offset <- if (outside) 1.02 else .fourfold_count_offset
  count_x <- c(-1, -1, 1, 1) * offset
  count_y <- c(1, -1, 1, -1) * offset
  # Justification is in screen terms, so it flips with a reversed axis.
  count_hjust <- if (x_direction > 0) c(0, 0, 1, 1) else c(1, 1, 0, 0)
  count_vjust <- if (y_direction > 0) c(1, 0, 1, 0) else c(0, 1, 0, 1)
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

# Cartesian coordinates only rescale each axis, so the drawing's shape
# survives; the others (and coord_flip(), which transposes the table) do not.
.fourfold_check_coord <- function(coord) {
  if (inherits(coord, "CoordFlip")) {
    stop(
      paste0(
        "fourfold displays do not support coord_flip(); swap the x and y ",
        "aesthetics instead, which transposes each table with the same odds ",
        "ratio"
      ),
      call. = FALSE
    )
  }
  if (!inherits(coord, "CoordCartesian") || inherits(coord, "CoordSf")) {
    name <- switch(
      class(coord)[1],
      CoordSf = "coord_sf()",
      CoordTransform = "coord_transform()",
      CoordPolar = "coord_polar()",
      CoordRadial = "coord_radial()",
      class(coord)[1]
    )
    stop(
      sprintf(
        paste0(
          "fourfold displays need a Cartesian coordinate system such as ",
          "coord_cartesian(), not %s"
        ),
        name
      ),
      call. = FALSE
    )
  }
  invisible()
}

#' @rdname geom_fourfold
#' @name geom_fourfold
#' @format NULL
#' @usage NULL
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
  extra_params = c("na.rm", "palette", "ticks", "extended", "shape", "counts"),
  draw_key = ggplot2::draw_key_blank,
  setup_params = function(data, params) {
    # Layer-wide values, so that every facet places its counts alike: this
    # sees the whole layer's data, draw_panel() only its own panel's.
    counts_params <- .fourfold_counts_params(
      data,
      shape = params$shape,
      extended = params$extended,
      ticks = params$ticks
    )
    params[names(counts_params)] <- counts_params
    params
  },
  setup_data = function(data, params) {
    # Drawing properties are fixed for the layer: drop any mapped with
    # after_stat() and inherited from the plot (see .fourfold_fixed_aes).
    data <- data[setdiff(names(data), .fourfold_fixed_aes)]
    # The extent of the drawing, as for geom_tile(), so that the default scale
    # expansion leaves room for the labels (local -1.3 to 1.3; see
    # draw_panel()).
    if (nrow(data)) {
      data$xmin <- 0.2
      data$xmax <- 2.8
      data$ymin <- 0.2
      data$ymax <- 2.8
    }
    data
  },
  use_defaults = function(self, data, params = list(),
                          modifiers = ggplot2::aes(), default_aes = NULL,
                          theme = NULL, ...) {
    # Likewise drop after_scale() and stage() modifications of them.
    modifiers <- modifiers[setdiff(names(modifiers), .fourfold_fixed_aes)]
    ggplot2::ggproto_parent(ggplot2::Geom, self)$use_defaults(
      data, params, modifiers,
      default_aes = default_aes, theme = theme, ...
    )
  },
  # Defaults match geom_fourfold() for direct use with ggplot2::layer().
  draw_panel = function(
      data, panel_params, coord, palette = .fourfold_defaults$palette,
      ticks = .fourfold_defaults$ticks, extended = .fourfold_defaults$extended,
      shape = .fourfold_defaults$shape, counts = .fourfold_defaults$counts,
      counts_reach = NULL, counts_tick_reach = NULL, counts_labels = NULL,
      na.rm = FALSE) {
    .fourfold_check_coord(coord)
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

    # A panel whose four counts are all zero is drawn blank: frame, axes,
    # labels, and counts only.
    blank <- all(data$count == 0)

    angle_from <- c(90, 180, 0, 270)
    angle_to <- c(180, 270, 90, 360)
    if (!blank) {
      for (cell in seq_len(4L)) {
        add(.fourfold_sector_grob(
          data$radius[cell], angle_from[cell], angle_to[cell],
          fill = palette[data$palette_index[cell]],
          colour = colour, alpha = alpha, lwd = lwd, shape = shape,
          name = paste0("fourfold-sector-", cell)
        ))
      }
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

    if (extended && ticks > 0 && !blank) {
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

    if (counts != "none") {
      # setup_params() gives the layer-wide values; without them, as when
      # draw_panel() is called directly, the panel is placed on its own.
      own <- .fourfold_counts_params(data, shape, extended, ticks)
      if (is.null(counts_reach)) counts_reach <- own$counts_reach
      if (is.null(counts_tick_reach)) counts_tick_reach <- own$counts_tick_reach
      if (is.null(counts_labels)) counts_labels <- own$counts_labels
      add(grid::gTree(
        labels = as.character(data$count),
        measure_labels = counts_labels,
        reach = counts_reach,
        tick_reach = counts_tick_reach,
        shape = shape,
        counts = counts,
        relative_size = relative_size,
        minimum_size = minimum_size,
        colour = scales::alpha(colour, alpha),
        family = family,
        name = "fourfold-counts",
        cl = "fourfold_counts"
      ))
    }

    # The drawing's local (u, v) is x = 1.5 + u, y = 1.5 - v in data units, so
    # its frame spans the four unit cells. A Cartesian coordinate system
    # rescales each axis separately, and a viewport scale puts local -1 and 1
    # where the frame corners fall (reversed axes give reversed scales).
    corners <- coord$transform(
      data.frame(x = c(0.5, 2.5), y = c(2.5, 0.5)), panel_params
    )
    x_per_unit <- 2 / diff(corners$x)
    y_per_unit <- 2 / diff(corners$y)
    # Rounded to remove floating-point noise, so that the default coordinate
    # system gives exactly c(-1.3, 1.3).
    xscale <- round(c(-1 - corners$x[1] * x_per_unit,
                      -1 + (1 - corners$x[1]) * x_per_unit), 10)
    yscale <- round(c(-1 - corners$y[1] * y_per_unit,
                      -1 + (1 - corners$y[1]) * y_per_unit), 10)
    grid::gTree(
      children = do.call(grid::gList, grobs),
      vp = grid::viewport(xscale = xscale, yscale = yscale, clip = "off"),
      # Unique, as grid draws a gTree's children by name: two fourfold layers
      # in one panel would otherwise both draw the first.
      name = grid::grobName(prefix = "fourfold-panel")
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
#' second at the bottom (see the Coordinate systems section). Set factor levels
#' explicitly when their order matters.
#' Alternatively, reorder categories with the `limits` argument of
#' [ggplot2::scale_x_discrete()] or [ggplot2::scale_y_discrete()], and rename
#' them with `labels`. Scale `breaks` that reorder or omit categories, and a
#' scale `palette` that moves them, are errors.
#'
#' One panel must contain exactly one 2-by-2 table. Use
#' [ggplot2::facet_grid()] or [ggplot2::facet_wrap()] to display stratified
#' tables. Duplicate `x`/`y` combinations within a panel are summed and cells
#' with no rows are completed with zero counts. For missing values, see the
#' Missing values section.
#'
#' Odds ratios, Wald confidence intervals, and extended-display p-values match
#' the calculations in `vcd::fourfold()`. If any observed cell is zero, 0.5 is
#' added to all four cells for inference; see the Zero counts section for how
#' such tables are drawn. P-values are adjusted across all panels in the
#' layer that have one. A panel whose counts are all zero has none, whereas
#' `vcd::fourfold()` counts it with a p-value of 1, so in a layer with such a
#' panel the adjusted p-values differ from those it gives. Confidence
#' intervals themselves are not adjusted.
#'
#' With `shape = "square"`, each cell is drawn as a quarter-square with the
#' same area as the corresponding quarter-circle (side
#' \eqn{r\sqrt{\pi}/2}{r * sqrt(pi) / 2} for radius \eqn{r}), so the two
#' shapes display a table with identical areas. Confidence rings
#' become nested square outlines.
#'
#' With `counts = "auto"`, cell counts stay inside the frame corners unless
#' a sector, either confidence outline, or a direction tick comes close to the
#' count text. Both shapes use the largest drawing extent across the layer; circles
#' also account for the width of the layer's count labels. Counts then move
#' just outside the frame corners. Clearance is measured at draw time, so
#' placement can differ between panels of different physical sizes.
#' Use `counts = "inside"` or `"outside"` to force the placement, or `"none"`
#' to hide counts without affecting any statistics. Outside counts can collide
#' with category labels or neighbouring panels at small sizes; use larger
#' panels, more panel spacing, smaller text, or `counts = "inside"`.
#'
#' The six semantic fill colours are supplied by `palette`; they are not mapped
#' through a ggplot2 fill scale. Typography and layout defaults are controlled
#' by [theme_fourfold()].
#'
#' @section Aesthetics:
#' `geom_fourfold()` understands the following aesthetics:
#'
#' - `x` (required): a categorical variable (factor, character, or logical)
#'   with exactly two levels. Convert numeric codes, such as 0/1, with
#'   `factor()`.
#' - `y` (required): a categorical variable with exactly two levels.
#' - `weight`: non-negative cell frequencies; defaults to `1`.
#'
#' Each panel draws one table, so its drawing properties are set for the whole
#' layer rather than mapped: give `colour`, `linewidth`, and `alpha` as fixed
#' arguments, for example `geom_fourfold(colour = "grey30")`. Text `size` and
#' `family` are inherited from the plot theme, such as [theme_fourfold()], and
#' can also be given as fixed arguments. Fill colours are set with `palette`.
#' Mapping any of these five in `geom_fourfold()` is an error, including a
#' mapping to a computed variable with [ggplot2::after_stat()],
#' [ggplot2::after_scale()], or [ggplot2::stage()]. Any such mapping inherited
#' from [ggplot2::ggplot()] is ignored, since it may be meant for other layers.
#' The exception is an inherited `after_stat()` mapping to a variable that
#' `geom_fourfold()` does not compute, such as `after_stat(n)` for
#' [ggplot2::geom_count()]: ggplot2 evaluates it before the layer can ignore
#' it, so it stops the plot. Use `inherit.aes = FALSE` in `geom_fourfold()`, or
#' move the mapping to the layer that uses it.
#'
#' @section Coordinate systems:
#' The display is drawn in the plot's coordinate system, so axes, gridlines,
#' and other layers agree with it. The first `x` level is at position 1 and the
#' second at position 2, and likewise for `y`; the display fills the square
#' from 0.5 to 2.5 on both axes, and each cell's quadrant is centred on its
#' category position.
#'
#' `geom_fourfold()` therefore also adds
#' `coord_cartesian(reverse = "y", ratio = 1)` to the plot, as
#' [ggplot2::geom_sf()] adds [ggplot2::coord_sf()]. Reversing the `y` axis
#' keeps the first `y` level at the top, as in `vcd::fourfold()`, for every
#' layer; reversing the `y` scale with `limits` would instead reorder the
#' table. The unit `ratio` keeps circles round under any theme. Both axes span
#' the same range by default, so it also makes the panels square. A theme's
#' `aspect.ratio` overrides `ratio`: it fixes the panel's shape, and circles
#' become ellipses when the ranges of the axes differ (see the Missing values
#' section).
#'
#' A coordinate system that you add to the plot replaces this one, as usual in
#' ggplot2. Add yours after the last `geom_fourfold()` in the plot: a later
#' `geom_fourfold()` replaces your coordinate system with its own, with
#' ggplot2's message. Without `reverse = "y"`, the first `y` level is drawn at
#' the bottom, as for any ggplot2 layer. To keep it at the top and the circles
#' round, add `coord_cartesian(reverse = "y", ratio = 1, ...)`: without
#' `ratio`, the display stretches to fill the panel, so circles become
#' ellipses wherever the panel is not square.
#' Common additions such as [ggplot2::coord_fixed()] and
#' [ggplot2::coord_equal()] also replace the default, and draw the first `y`
#' level at the bottom unless reversed. Any `reverse` setting is drawn
#' correctly. `GeomFourfold` and `StatFourfold` are the ggproto objects behind
#' `geom_fourfold()`. Used directly with [ggplot2::layer()], they take the
#' defaults of `geom_fourfold()`, and `GeomFourfold` adds no coordinate system
#' and follows the one the plot has.
#'
#' The coordinate system must be Cartesian, such as [ggplot2::coord_cartesian()]
#' or [ggplot2::coord_fixed()]. [ggplot2::coord_flip()] is an error: swap the
#' `x` and `y` aesthetics instead, which transposes each table and keeps its
#' odds ratio. So are [ggplot2::coord_sf()], [ggplot2::coord_transform()], and
#' polar coordinates, which would distort the areas that carry the display's
#' meaning. Because of the fixed `ratio`, ggplot2 does not allow free facet
#' scales (`scales = "free"`) with the default coordinate system. To use them,
#' add your own coordinate system without `ratio` after `geom_fourfold()`,
#' such as `coord_cartesian(reverse = "y")`. Then `facet_grid(space = "free")`
#' also works, including with [theme_fourfold()], which sets no aspect ratio;
#' it shares widths among columns (heights among rows) in proportion to the
#' ranges of their axes. Free scales and free space are therefore possible
#' only with your own coordinate system without `ratio`, and the displays are
#' then round only where a panel happens to be square.
#'
#' The display is not clipped to the panel, so that counts outside the frame
#' stay whole. Zooming with the `xlim` and `ylim` of the coordinate system
#' therefore does not crop it, and the display can then extend over
#' neighbouring panels and strips.
#'
#' @section Annotations:
#' A point or label that another layer, such as [ggplot2::geom_point()],
#' [ggplot2::geom_text()], or [ggplot2::annotate()], places at an `x` level and
#' a `y` level is drawn at the centre of that cell's quadrant. This is a fixed
#' position, the same in every panel, not the centre of the sector, whose size
#' varies with the data. See the examples.
#'
#' @section Zero counts:
#' If any cell of a panel's table is zero, 0.5 is added to all four cells
#' before the odds ratio, its standard error, and the confidence interval are
#' computed, as in `vcd::fourfold()`. The count labels always show the
#' observed counts.
#'
#' A panel whose four counts are all zero, such as an empty stratum in a
#' faceted display, is drawn blank: only its frame, axes, labels, and zero
#' counts are shown, with no sectors, rings, or direction tick. It has no odds
#' ratio, confidence interval, or p-value (they are `NA`) and is left out of
#' the p-value adjustment, so it does not change the other panels.
#' (With the default `margin = c(1, 2)`, `vcd::fourfold()` instead draws such
#' a stratum from the corrected table, as four equal quarter-circles.) A facet
#' level with no rows at all, for example with `drop = FALSE`, is left empty
#' by ggplot2 as usual, without a frame or counts.
#'
#' Each confidence ring shows the table that has the observed row and column
#' totals and an odds ratio equal to one confidence limit, standardized like
#' the data. With the default `margin = c(1, 2)`, which depends only on the
#' odds ratio, this is the fully standardized table at that limit. With the
#' other `std` and `margin` settings, if a whole row or column is zero, the
#' observed totals admit no other table, so the rings of that panel are built
#' from the row and column totals of the table with 0.5 added to every cell,
#' rescaled to the observed total (which matters only for `std = "all.max"`).
#' Panels with isolated zero cells, but no empty row or column, keep the
#' observed totals for their rings.
#'
#' A table with an empty row or column contains no information about the odds
#' ratio: with an empty row, for example, nothing is known about how that row
#' would split between the columns. Its odds ratio and p-value exist only
#' because of the correction. With an empty row, the odds ratio is the ratio
#' of the two counts in the other row, each plus 0.5, so it reflects how that
#' row splits rather than an association. The rings are correspondingly wide,
#' but the p-value can still fall below the significance level, so the colour,
#' significance shading, and direction tick of such a panel say nothing about
#' an association.
#'
#' The sectors show the observed table wherever the standardization can use
#' it:
#'
#' - With `std = "margins"` and the default `margin = c(1, 2)`, the sectors
#'   depend only on the odds ratio, which already includes the correction.
#' - With `margin = 1`, a row that is entirely zero has no proportions, so it
#'   is drawn from the corrected table, as two equal quarter-circles. The
#'   other row keeps its observed proportions. The same applies to an empty
#'   column with `margin = 2`. An empty column with `margin = 1`, or an empty
#'   row with `margin = 2`, keeps its observed proportions and so has no
#'   sectors, except in a cell it shares with an empty row (or column) that is
#'   drawn from the corrected table.
#' - With `std = "ind.max"` or `"all.max"`, the sectors show the observed
#'   counts, so an empty row or column has no sectors. Its rings still come
#'   from the corrected totals, so they need not match the sectors.
#'
#' Weights that are very small but not zero, such as the remainder of
#' floating-point arithmetic (`0.1 + 0.2 - 0.3`), count as observations, so a
#' row or column of them is not empty and its rings keep the observed totals.
#' Where the standardization keeps such a row or column near zero
#' (`std = "ind.max"` or `"all.max"`, `margin = 2` for a row, or `margin = 1`
#' for a column), its near-zero totals leave almost no room for other odds
#' ratios, so the rings lie on the sectors, as if the estimate were precise.
#' An exactly empty row or column gets the wide rings described above
#' instead. Round such weights, for example with `round(w, 8)`, if they are
#' meant to be zero.
#'
#' @section Missing values:
#' A row with a missing `x` or `y` cannot be placed in the table and is
#' removed; a panel with no rows left is left empty. Values that the `limits`
#' of a discrete scale exclude become missing and are removed the same way,
#' with the same warning. A row with a missing `weight` but known `x` and `y`
#' is different: its cell's count, and so the panel's table, is unknown.
#' Counting it as zero would change the odds ratio, so its whole panel is left
#' empty instead. (`vcd::fourfold()` likewise draws no table with a missing
#' count; it stops with an error.) A cell with no rows at all is still a zero
#' count.
#'
#' An empty panel has no frame, counts, or labels, so it cannot be mistaken
#' for a panel whose counts are all zero, and it looks the same as a facet
#' level with no rows. It has no rows in the layer data and takes no part in
#' `std = "all.max"` or the p-value adjustment, so the other panels are drawn
#' exactly as if its stratum were not in the data. (With
#' `facet_grid(margins = TRUE)`, the margin panels that pool that stratum are
#' unknown too, and are also left empty.) With `na.rm = FALSE`, the default, a
#' warning names each panel that lost rows or was left empty; with
#' `na.rm = TRUE`, these warnings are not given. With free scales, which need
#' a coordinate system you add without `ratio` (see the Coordinate systems
#' section), ggplot2 itself may still warn about the axes of an empty panel
#' ("Position guide is perpendicular to the intended axis"), as it does for
#' its own layers.
#'
#' A missing `x` or `y` keeps a place for missing values on its axis, as for
#' every geom, because ggplot2 trains position scales before the stat runs.
#' The display removes those rows, but the axis stays wider, so the panels that
#' share that scale are wider (or taller) than the display, with space beside
#' it. With the default coordinate system the display stays round, and the
#' counts and statistics are not affected.
#' `scale_x_discrete(na.translate = FALSE)` (`scale_y_discrete()` for `y`)
#' removes that place.
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
#'   `std = "margins"`. Use `c(1, 2)` for both margins, `1` for the `y` (row)
#'   margin, or `2` for the `x` (column) margin, as in [vcd::fourfold()].
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
#' @param counts Placement of cell counts: `"auto"` (the default) moves counts
#'   outside when the drawing approaches them; `"inside"` always uses the inside
#'   corners, even if overlapped; `"outside"` always uses the outside corners;
#'   `"none"` hides the counts.
#' @param palette Character vector of at least six valid colours in the
#'   semantic order used by [fourfold_palette()], which also provides
#'   built-in palettes such as `fourfold_palette("okabe-ito")`.
#' @param na.rm If `FALSE`, the default, rows with a missing `x` or `y` are
#'   removed, and panels with a missing `weight` are left empty, with a
#'   warning. If `TRUE`, this is done silently. See the Missing values section.
#' @param show.legend Logical indicating whether this layer should be included
#'   in legends. The default is `FALSE` because the semantic fills are not a
#'   mapped aesthetic.
#' @param inherit.aes If `FALSE`, override rather than combine with the plot's
#'   default aesthetic mappings.
#'
#' @return A list of a ggplot2 layer and a default coordinate system,
#'   `coord_cartesian(reverse = "y", ratio = 1)`, which can be added to a
#'   [ggplot2::ggplot()] object (see the Coordinate systems section).
#'
#' @references
#' Friendly, M. (1994a). *A fourfold display for 2 by 2 by k tables*
#' (Technical Report No. 217). York University, Psychology Department.
#' <http://datavis.ca/papers/4fold/4fold.pdf>
#'
#' Friendly, M. (1994b). SAS/IML graphics for fourfold displays.
#' *Observations*, *3*(4), 47--56.
#'
#' Friendly, M., & Meyer, D. (2016). *Discrete Data Analysis with R:
#' Visualization and Modeling Techniques for Categorical and Count Data*
#' (Section 4.4). Chapman & Hall/CRC. <http://ddar.datavis.ca>
#'
#' Meyer, D., Zeileis, A., Hornik, K., & Friendly, M. (2026). *vcd:
#' Visualizing Categorical Data* (R package).
#' \doi{10.32614/CRAN.package.vcd}
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
#' # Other layers are placed by category: a label in the Male-Admitted cell
#' ggplot2::ggplot(
#'   subset(ucb, Dept == "A"),
#'   ggplot2::aes(x = Gender, y = Admit, weight = Freq)
#' ) +
#'   geom_fourfold() +
#'   ggplot2::annotate("label", x = "Male", y = "Admitted", label = "Male") +
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
    counts = c("auto", "inside", "outside", "none"),
    palette = fourfold_palette(),
    na.rm = FALSE,
    show.legend = FALSE,
    inherit.aes = TRUE) {
  .fourfold_check_mapping(mapping)
  counts <- .fourfold_match_arg(
    counts, c("auto", "inside", "outside", "none"), "counts"
  )
  validated <- .fourfold_validate_params(
    std, margin, conf_level, extended, ticks, p_adjust_method, palette,
    shape
  )
  layer <- ggplot2::layer(
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
        counts = counts,
        na.rm = na.rm
      ),
      list(...)
    )
  )
  # As geom_sf() adds coord_sf(): keeps the first row on top, with unit ratio.
  list(
    layer,
    ggplot2::coord_cartesian(reverse = "y", ratio = 1, default = TRUE)
  )
}
