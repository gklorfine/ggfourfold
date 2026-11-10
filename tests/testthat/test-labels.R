# Tests of `labels = c("levels", "both")` in geom_fourfold(), written from
# dev/labels-spec.md. Self-contained: no helper of another test file is used.

# Helpers ------------------------------------------------------------------------

ucb_df <- as.data.frame(UCBAdmissions)

ucb_base <- function() {
  ggplot2::ggplot(ucb_df, ggplot2::aes(x = Gender, y = Admit, weight = Freq))
}

ucb_labels_plot <- function(..., labels = "both") {
  ucb_base() + geom_fourfold(labels = labels, ...)
}

small_df <- data.frame(
  g = factor(c("a", "a", "b", "b")),
  h = factor(c("u", "v", "u", "v")),
  w = c(1, 2, 30, 40)
)

# The gtable of a plot, built on a null device.
built_gtable <- function(plot) {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off())
  ggplot2::ggplotGrob(plot)
}

# The side labels a plot draws, read from the real grobs: a list with one
# element per panel, each a list with one element per fourfold display (layer)
# in the panel, each a named character vector (top, left, bottom, right). A
# panel that draws no display gives an empty list.
side_labels <- function(plot) {
  gtable <- built_gtable(plot)
  panels <- gtable$grobs[grepl("^panel", gtable$layout$name)]
  sides <- c("top", "left", "bottom", "right")
  lapply(panels, function(panel) {
    displays <- if (inherits(panel, "gTree")) {
      grid::getGrob(panel, "fourfold-panel", grep = TRUE, global = TRUE)
    }
    if (is.null(displays)) displays <- list()
    if (inherits(displays, "grob")) displays <- list(displays)
    lapply(displays, function(display) {
      out <- vapply(sides, function(side) {
        label <- grid::getGrob(display, paste0("fourfold-label-", side))
        if (is.null(label)) NA_character_ else as.character(label$label)
      }, character(1))
      stats::setNames(out, sides)
    })
  })
}

# The labels of the first display of the first panel.
first_labels <- function(plot) side_labels(plot)[[1]][[1]]

lab <- function(top, left, bottom, right) {
  c(top = top, left = left, bottom = bottom, right = right)
}

ucb_both <- lab(
  "Admit: Admitted", "Gender: Male", "Admit: Rejected", "Gender: Female"
)
ucb_levels <- lab("Admitted", "Male", "Rejected", "Female")

# The names of the grobs a panel draws, after forcing, without the labels, and
# the vertices of the four sectors: everything but the label strings.
display_signature <- function(plot) {
  gtable <- built_gtable(plot)
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off())
  grid::grid.newpage()
  grid::grid.draw(gtable)
  grid::grid.force()
  names <- grid::grid.ls(print = FALSE)$name
  names <- names[!grepl("fourfold-label", names)]
  # grid numbers anonymous grobs afresh in every build.
  names <- sub("[.][0-9]+$", "", names)
  panel <- gtable$grobs[grepl("^panel", gtable$layout$name)][[1]]
  display <- grid::getGrob(panel, "fourfold-panel", grep = TRUE)
  sectors <- lapply(1:4, function(i) {
    s <- grid::getGrob(display, paste0("fourfold-sector-", i))
    list(x = as.numeric(s$x), y = as.numeric(s$y))
  })
  list(names = names, sectors = sectors)
}

# The full content of everything a plot draws, as lines of text, after
# grid.force(): every field of every grob (recursively through gTrees), units,
# graphical parameters and viewports included, with the auto-numbering of grob
# names removed. Only the label strings of the four side labels (the `label`
# field of the gTree and of its forced text child) are masked: their position,
# rotation, justification, size and gpar are kept.
grob_dump <- function(plot, width = 6, height = 5) {
  gtable <- built_gtable(plot)
  grDevices::pdf(NULL, width = width, height = height)
  on.exit(grDevices::dev.off())
  grid::grid.newpage()
  forced <- grid::grid.force(gtable)
  fmt <- function(v) {
    if (is.null(v)) return("NULL")
    if (is.function(v) || is.environment(v)) return("<fn/env>")
    if (inherits(v, "viewport")) {
      fields <- c("name", "x", "y", "width", "height", "xscale", "yscale", "angle", "clip", "gp")
      return(paste(vapply(fields, function(f) paste0(f, "=", fmt(v[[f]])), ""), collapse = ";"))
    }
    if (grid::is.unit(v)) return(paste0("unit[", paste(as.character(v), collapse = ","), "]"))
    if (inherits(v, "gpar")) v <- unclass(v)
    paste(deparse(v, control = c("keepNA", "keepInteger", "niceNames", "digits17"),
      width.cutoff = 500L), collapse = " ")
  }
  lines <- character()
  walk <- function(g, depth, in_label) {
    name <- if (is.null(g$name)) "<NULL>" else as.character(g$name)
    in_label <- in_label || grepl("^fourfold-label-", name)
    ind <- strrep(" ", depth)
    lines <<- c(lines, paste0(ind, "GROB ", name, " [", paste(class(g), collapse = "/"), "]"))
    for (f in sort(setdiff(names(g), c("name", "children", "childrenOrder", "grobs", "vp")))) {
      v <- unclass(g)[[f]]
      if (f == ".ORIGINAL" && grid::is.grob(v)) next
      text <- if (in_label && f == "label") "<MASK>" else fmt(v)
      lines <<- c(lines, paste0(ind, "  ", f, " = ", text))
    }
    if (!is.null(g$vp)) lines <<- c(lines, paste0(ind, "  vp = ", fmt(g$vp)))
    kids <- if (is.list(g$children) && length(g$children)) {
      g$children[if (is.null(g$childrenOrder)) names(g$children) else g$childrenOrder]
    } else if (is.list(g$grobs)) {
      g$grobs
    }
    for (k in kids) if (grid::is.grob(k)) walk(k, depth + 1L, in_label)
  }
  walk(forced, 0L, FALSE)
  gsub("\\b([A-Za-z][A-Za-z_-]*)\\.[0-9]+\\b", "\\1.N", lines, perl = TRUE)
}

# A plot with the direct layer() use of the geom, as for the fallback.
direct_plot <- function(data, mapping, ..., params = list()) {
  ggplot2::ggplot(data, mapping) +
    ggplot2::layer(
      geom = GeomFourfold, stat = StatFourfold, position = "identity",
      params = params
    ) +
    geom_fourfold()[[2]] +
    list(...)
}

# Default path unchanged ------------------------------------------------------------

test_that("the default and labels = 'levels' return a layer and a coord only", {
  for (result in list(geom_fourfold(), geom_fourfold(labels = "levels"))) {
    expect_type(result, "list")
    expect_length(result, 2)
    expect_s3_class(result[[1]], "LayerInstance")
    expect_s3_class(result[[2]], "Coord")
  }
  expect_false(inherits(ucb_base() + geom_fourfold(), "fourfold_plot"))
  expect_false(inherits(ucb_base() + geom_fourfold(labels = "levels"), "fourfold_plot"))
  expect_identical(class(ucb_base() + geom_fourfold()), class(ucb_base()))
})

test_that("the default path is pinned concretely", {
  result <- geom_fourfold()
  expect_identical(class(result), "list")
  expect_length(result, 2)
  expect_identical(result[[1]]$geom_params$labels, "levels")
  expect_false("label_names" %in% names(result[[1]]$geom_params))
  expect_identical(formals(geom_fourfold)$labels, quote(c("levels", "both")))
  expect_false(inherits(ucb_base() + result, "fourfold_plot"))
  explicit <- geom_fourfold(labels = "levels")
  expect_identical(class(explicit), "list")
  expect_false("label_names" %in% names(explicit[[1]]$geom_params))
})

test_that("the default path draws the bare levels", {
  expect_identical(first_labels(ucb_base() + geom_fourfold()), ucb_levels)
  expect_identical(first_labels(ucb_labels_plot(labels = "levels")), ucb_levels)
})

test_that("the built data are identical with and without labels = 'levels'", {
  expect_identical(
    ggplot2::layer_data(ucb_base() + geom_fourfold()),
    ggplot2::layer_data(ucb_base() + geom_fourfold(labels = "levels"))
  )
  faceted <- function(...) {
    ucb_base() + geom_fourfold(...) + ggplot2::facet_wrap(ggplot2::vars(Dept))
  }
  expect_identical(
    ggplot2::layer_data(faceted()), ggplot2::layer_data(faceted(labels = "levels"))
  )
})

test_that("the unevaluated default vector means 'levels'", {
  expect_identical(
    first_labels(ucb_base() + geom_fourfold(labels = c("levels", "both"))),
    ucb_levels
  )
  expect_length(geom_fourfold(labels = c("levels", "both")), 2)
})

# "both": basics ---------------------------------------------------------------------

test_that("labels = 'both' returns layer, coord and a fourfold_labels tagger", {
  result <- geom_fourfold(labels = "both")
  expect_type(result, "list")
  expect_length(result, 3)
  expect_s3_class(result[[1]], "LayerInstance")
  expect_s3_class(result[[2]], "Coord")
  expect_s3_class(result[[3]], "fourfold_labels")
  expect_identical(result[[1]]$geom_params$labels, "both")
  # The layer carries label_names, as NULL, not absent.
  expect_true("label_names" %in% names(result[[1]]$geom_params))
  expect_null(result[[1]]$geom_params$label_names)
})

test_that("adding the 'both' layer tags the plot once, and it stays a ggplot", {
  count_tag <- function(p) sum(class(p) == "fourfold_plot")
  p <- ucb_labels_plot()
  expect_identical(count_tag(p), 1L)
  expect_true(ggplot2::is_ggplot(p))
  expect_identical(class(p)[1], "fourfold_plot")

  two <- ucb_base() + geom_fourfold(labels = "both") + geom_fourfold(labels = "both")
  expect_identical(count_tag(two), 1L)
  expect_true(ggplot2::is_ggplot(two))

  more <- p + ggplot2::theme(legend.position = "top") +
    ggplot2::facet_wrap(ggplot2::vars(Dept)) +
    ggplot2::labs(title = "t") + theme_fourfold()
  expect_identical(count_tag(more), 1L)
  expect_true(ggplot2::is_ggplot(more))
  expect_identical(count_tag(more + geom_fourfold(labels = "both")), 1L)
})

test_that("the four labels read 'name: level' on the right sides", {
  expect_identical(first_labels(ucb_labels_plot()), ucb_both)
  # Reversing the data order does not change which level is on which side:
  # the first x level is on the left, the first y level on top.
  swapped <- ggplot2::ggplot(
    ucb_df, ggplot2::aes(x = Admit, y = Gender, weight = Freq)
  ) + geom_fourfold(labels = "both")
  expect_identical(
    first_labels(swapped),
    lab("Gender: Male", "Admit: Admitted", "Gender: Female", "Admit: Rejected")
  )
})

test_that("everything but the four label strings is drawn identically", {
  cases <- list(
    circle = list(),
    square_outside = list(shape = "square", counts = "outside"),
    not_extended = list(extended = FALSE),
    ind_max = list(std = "ind.max")
  )
  for (case in names(cases)) {
    args <- cases[[case]]
    both <- do.call(ucb_labels_plot, args)
    levels <- do.call(ucb_labels_plot, c(args, list(labels = "levels")))
    dump_both <- grob_dump(both)
    dump_levels <- grob_dump(levels)
    expect_gt(length(dump_both), 100)
    expect_identical(dump_both, dump_levels, info = case)
  }
  facet <- ggplot2::facet_wrap(ggplot2::vars(Dept))
  expect_identical(
    grob_dump(ucb_labels_plot() + facet), grob_dump(ucb_labels_plot(labels = "levels") + facet)
  )
  expect_identical(
    grob_dump(ucb_labels_plot(shape = "square") + facet + theme_fourfold()),
    grob_dump(ucb_labels_plot(shape = "square", labels = "levels") + facet + theme_fourfold())
  )
  # The dump is sensitive: a different palette or count is not identical.
  expect_false(identical(
    grob_dump(ucb_labels_plot()), grob_dump(ucb_labels_plot(palette = rep("red", 6)))
  ))
  expect_false(identical(
    grob_dump(ucb_labels_plot()), grob_dump(ucb_labels_plot(diagonal = FALSE))
  ))
})

test_that("labels = 'both' leaves the statistics and drawn pieces alone", {
  expect_identical(
    ggplot2::layer_data(ucb_labels_plot()),
    ggplot2::layer_data(ucb_labels_plot(labels = "levels"))
  )
  both <- display_signature(ucb_labels_plot())
  levels <- display_signature(ucb_labels_plot(labels = "levels"))
  expect_identical(both$names, levels$names)
  expect_identical(both$sectors, levels$sectors)
  # Likewise in facets, and only the label strings differ.
  facet <- ggplot2::facet_wrap(ggplot2::vars(Dept))
  expect_identical(
    ggplot2::layer_data(ucb_labels_plot() + facet),
    ggplot2::layer_data(ucb_labels_plot(labels = "levels") + facet)
  )
  expect_false(identical(
    first_labels(ucb_labels_plot()), first_labels(ucb_labels_plot(labels = "levels"))
  ))
})

# Where the names come from -----------------------------------------------------------

test_that("the mapping may be in ggplot(), in the geom, or split between the two", {
  p1 <- ggplot2::ggplot(ucb_df, ggplot2::aes(Gender, Admit, weight = Freq)) +
    geom_fourfold(labels = "both")
  p2 <- ggplot2::ggplot(ucb_df) +
    geom_fourfold(ggplot2::aes(Gender, Admit, weight = Freq), labels = "both")
  p3 <- ggplot2::ggplot(ucb_df, ggplot2::aes(x = Gender, weight = Freq)) +
    geom_fourfold(ggplot2::aes(y = Admit), labels = "both")
  p4 <- ggplot2::ggplot(ucb_df, ggplot2::aes(y = Admit, weight = Freq)) +
    geom_fourfold(ggplot2::aes(x = Gender), labels = "both")
  for (p in list(p1, p2, p3, p4)) expect_identical(first_labels(p), ucb_both)
})

test_that("a layer mapping overrides the plot mapping", {
  p <- ggplot2::ggplot(
    transform(ucb_df, G2 = Gender), ggplot2::aes(Admit, Admit, weight = Freq)
  ) + geom_fourfold(ggplot2::aes(x = G2, y = Admit), labels = "both")
  expect_identical(
    first_labels(p),
    lab("Admit: Admitted", "G2: Male", "Admit: Rejected", "G2: Female")
  )
})

test_that("inherit.aes = FALSE uses the layer mapping alone", {
  p <- ggplot2::ggplot(ucb_df, ggplot2::aes(Dept, Dept, weight = Freq)) +
    geom_fourfold(
      ggplot2::aes(x = Gender, y = Admit, weight = Freq),
      labels = "both", inherit.aes = FALSE
    )
  expect_identical(first_labels(p), ucb_both)
})

test_that(".data pronoun mappings give the variable name", {
  p <- ggplot2::ggplot(
    ucb_df, ggplot2::aes(x = .data$Gender, y = .data[["Admit"]], weight = Freq)
  ) + geom_fourfold(labels = "both")
  expect_identical(first_labels(p), ucb_both)
})

test_that("a non-syntactic column name is labeled without backticks", {
  df <- data.frame(
    `Financial gain` = factor(c("No", "No", "Yes", "Yes")),
    Killer = factor(c("Innocent", "Killer", "Innocent", "Killer")),
    n = c(10, 3, 5, 8),
    check.names = FALSE
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(`Financial gain`, Killer, weight = n)) +
    geom_fourfold(labels = "both")
  expect_identical(
    first_labels(p),
    lab("Killer: Innocent", "Financial gain: No", "Killer: Killer", "Financial gain: Yes")
  )
  expect_false(any(grepl("`", first_labels(p), fixed = TRUE)))
})

test_that("an expression is labeled with its text", {
  df <- data.frame(g = c(1, 1, 2, 2), h = factor(c("u", "v", "u", "v")), w = 1:4)
  p <- ggplot2::ggplot(df, ggplot2::aes(x = factor(g), y = h, weight = w)) +
    geom_fourfold(labels = "both")
  expect_identical(
    first_labels(p),
    lab("h: u", "factor(g): 1", "h: v", "factor(g): 2")
  )
})

test_that("labs() and scale names do not change the variable name", {
  p <- ucb_labels_plot() + ggplot2::labs(x = "Something", y = "Other")
  expect_identical(first_labels(p), ucb_both)
  p <- ucb_labels_plot() +
    ggplot2::scale_x_discrete(name = "Something") +
    ggplot2::scale_y_discrete(name = "Other")
  expect_identical(first_labels(p), ucb_both)
  p <- ucb_labels_plot() + ggplot2::labs(x = NULL, y = NULL) + theme_fourfold()
  expect_identical(first_labels(p), ucb_both)
})

test_that("scale labels rename the level part", {
  p <- ucb_labels_plot() +
    ggplot2::scale_x_discrete(labels = c("Men", "Women")) +
    ggplot2::scale_y_discrete(labels = c("Yes", "No"))
  expect_identical(
    first_labels(p),
    lab("Admit: Yes", "Gender: Men", "Admit: No", "Gender: Women")
  )
  levels <- ucb_labels_plot(labels = "levels") +
    ggplot2::scale_x_discrete(labels = c("Men", "Women"))
  expect_identical(first_labels(levels)[["left"]], "Men")
})

test_that("the names are resolved at add time, before any build", {
  names_of <- function(plot) plot@layers[[1]]$geom_params$label_names
  p <- ucb_labels_plot()
  expect_identical(names_of(p), c(x = "Gender", y = "Admit"))
  expect_null(names_of(ggplot2::ggplot(ucb_df) + geom_fourfold(labels = "both")))
  expect_identical(
    names_of(ggplot2::ggplot(ucb_df) +
      geom_fourfold(ggplot2::aes(Dept, Gender, weight = Freq), labels = "both")),
    c(x = "Dept", y = "Gender")
  )
  late <- ggplot2::ggplot(ucb_df) + geom_fourfold(labels = "both") +
    ggplot2::aes(Gender, Admit, weight = Freq)
  expect_null(names_of(late))
  expect_identical(first_labels(late), ucb_both)
  # The user's own layer object is untouched by adding it.
  g <- geom_fourfold(labels = "both")
  p <- ucb_base() + g
  expect_null(g[[1]]$geom_params$label_names)
  expect_identical(names_of(p), c(x = "Gender", y = "Admit"))
  expect_false(identical(p@layers[[1]], g[[1]]))
})

test_that("aes() added after the layer gives the right names", {
  p <- ggplot2::ggplot(ucb_df) + geom_fourfold(labels = "both") +
    ggplot2::aes(x = Gender, y = Admit, weight = Freq)
  expect_no_message(labels <- first_labels(p))
  expect_identical(labels, ucb_both)
})

test_that("aes() replaced after the layer gives the new names", {
  df <- transform(ucb_df, G2 = Gender, A2 = Admit)
  p <- ggplot2::ggplot(df, ggplot2::aes(Gender, Admit, weight = Freq)) +
    geom_fourfold(labels = "both")
  expect_identical(first_labels(p), ucb_both)
  replaced <- p + ggplot2::aes(x = G2, y = A2)
  expect_identical(
    first_labels(replaced),
    lab("A2: Admitted", "G2: Male", "A2: Rejected", "G2: Female")
  )
  # Replacing a single aesthetic.
  one <- p + ggplot2::aes(x = G2)
  expect_identical(
    first_labels(one),
    lab("Admit: Admitted", "G2: Male", "Admit: Rejected", "G2: Female")
  )
})

test_that("one plot object reused with two mappings is labeled for each", {
  df <- transform(ucb_df, G2 = Gender, A2 = Admit)
  base <- ggplot2::ggplot(df, ggplot2::aes(Gender, Admit, weight = Freq)) +
    geom_fourfold(labels = "both")
  other <- base + ggplot2::aes(x = G2, y = A2)
  want_base <- ucb_both
  want_other <- lab("A2: Admitted", "G2: Male", "A2: Rejected", "G2: Female")
  # Either order of building, and building repeatedly.
  expect_identical(first_labels(base), want_base)
  expect_identical(first_labels(other), want_other)
  expect_identical(first_labels(other), want_other)
  expect_identical(first_labels(base), want_base)
  fresh_base <- ggplot2::ggplot(df, ggplot2::aes(Gender, Admit, weight = Freq)) +
    geom_fourfold(labels = "both")
  fresh_other <- fresh_base + ggplot2::aes(x = G2, y = A2)
  expect_identical(first_labels(fresh_other), want_other)
  expect_identical(first_labels(fresh_base), want_base)
})

test_that("one layer object reused in two plots is labeled for each, unmutated", {
  df <- transform(ucb_df, G2 = Gender, A2 = Admit)
  p1 <- ggplot2::ggplot(df, ggplot2::aes(Gender, Admit, weight = Freq))
  p2 <- ggplot2::ggplot(df, ggplot2::aes(G2, A2, weight = Freq))
  want2 <- lab("A2: Admitted", "G2: Male", "A2: Rejected", "G2: Female")
  for (order in list(1:2, 2:1)) {
    g <- geom_fourfold(labels = "both")
    a <- p1 + g
    b <- p2 + g
    plots <- list(a, b)
    wants <- list(ucb_both, want2)
    for (i in order) expect_identical(first_labels(plots[[i]]), wants[[i]])
    for (i in order) expect_identical(first_labels(plots[[i]]), wants[[i]])
    expect_null(g[[1]]$geom_params$label_names)
    expect_identical(g[[1]]$geom_params$labels, "both")
  }
  # Plot layers are not the user's layer object once built.
  g <- geom_fourfold(labels = "both")
  a <- p1 + g
  invisible(ggplot2::layer_data(a))
  expect_null(g[[1]]$geom_params$label_names)
})

test_that("a levels layer and a both layer in one plot each draw their own labels", {
  plot <- ucb_base() +
    geom_fourfold(labels = "levels") +
    geom_fourfold(labels = "both")
  shown <- side_labels(plot)[[1]]
  expect_length(shown, 2)
  expect_identical(shown[[1]], ucb_levels)
  expect_identical(shown[[2]], ucb_both)
  # In the other order, and with separate mappings.
  reverse <- ucb_base() +
    geom_fourfold(labels = "both") +
    geom_fourfold(labels = "levels")
  shown <- side_labels(reverse)[[1]]
  expect_identical(shown[[1]], ucb_both)
  expect_identical(shown[[2]], ucb_levels)
  # Separate mappings on the same two levels of each axis (the layers share
  # the scales, so each axis needs the same two categories in both layers).
  two <- data.frame(
    p = factor(c("a", "a", "b", "b")), q = factor(c("a", "b", "a", "b")),
    r = factor(c("u", "v", "u", "v")), s = factor(c("u", "v", "v", "u")),
    w = c(5, 6, 7, 8)
  )
  two$p <- factor(two$p, levels = c("a", "b"))
  separate <- ggplot2::ggplot(two) +
    geom_fourfold(ggplot2::aes(p, r, weight = w), labels = "both") +
    geom_fourfold(
      ggplot2::aes(q, s, weight = w), labels = "both", inherit.aes = FALSE
    )
  shown <- side_labels(separate)[[1]]
  expect_length(shown, 2)
  expect_identical(shown[[1]], lab("r: u", "p: a", "r: v", "p: b"))
  expect_identical(shown[[2]], lab("s: u", "q: a", "s: v", "q: b"))
})

# Facets and options ------------------------------------------------------------------

test_that("every panel of a facet_wrap() or facet_grid() carries the labels", {
  wrap <- side_labels(ucb_labels_plot() + ggplot2::facet_wrap(ggplot2::vars(Dept)))
  expect_length(wrap, 6)
  for (panel in wrap) {
    expect_length(panel, 1)
    expect_identical(panel[[1]], ucb_both)
  }
  grid_cols <- side_labels(
    ucb_labels_plot() + ggplot2::facet_grid(cols = ggplot2::vars(Dept))
  )
  expect_length(grid_cols, 6)
  for (panel in grid_cols) expect_identical(panel[[1]], ucb_both)
  grid_both <- side_labels(
    ucb_labels_plot() + ggplot2::facet_grid(Dept ~ .)
  )
  expect_length(grid_both, 6)
  for (panel in grid_both) expect_identical(panel[[1]], ucb_both)
  # A facet added before the layer.
  early <- ggplot2::ggplot(ucb_df, ggplot2::aes(Gender, Admit, weight = Freq)) +
    ggplot2::facet_wrap(ggplot2::vars(Dept)) + geom_fourfold(labels = "both")
  for (panel in side_labels(early)) expect_identical(panel[[1]], ucb_both)
})

test_that("labels = 'both' works with the shape, counts, extended and std options", {
  for (shape in c("circle", "square")) {
    expect_identical(first_labels(ucb_labels_plot(shape = shape)), ucb_both, info = shape)
  }
  for (counts in c("auto", "inside", "outside", "none")) {
    expect_identical(first_labels(ucb_labels_plot(counts = counts)), ucb_both, info = counts)
  }
  expect_identical(first_labels(ucb_labels_plot(extended = FALSE)), ucb_both)
  expect_identical(first_labels(ucb_labels_plot(std = "ind.max")), ucb_both)
  expect_identical(first_labels(ucb_labels_plot(std = "all.max")), ucb_both)
  expect_identical(first_labels(ucb_labels_plot() + theme_fourfold()), ucb_both)
  expect_identical(
    first_labels(ucb_labels_plot(shape = "square", counts = "outside") + theme_fourfold()),
    ucb_both
  )
})

test_that("layer_data(), print() and ggsave() succeed on a tagged plot", {
  plot <- ucb_labels_plot() + ggplot2::facet_wrap(ggplot2::vars(Dept)) + theme_fourfold()
  expect_no_error(data <- ggplot2::layer_data(plot))
  expect_identical(nrow(data), 24L)
  grDevices::pdf(NULL)
  expect_no_error(print(plot))
  grDevices::dev.off()
  pdf_file <- tempfile(fileext = ".pdf")
  on.exit(unlink(pdf_file), add = TRUE)
  expect_no_error(ggplot2::ggsave(pdf_file, plot, width = 6, height = 4))
  expect_true(file.exists(pdf_file))
  expect_gt(file.size(pdf_file), 0)
})

# Fallback --------------------------------------------------------------------------

fallback_text <- paste0(
  "`labels = \"both\"` could not find the names of the `x` and `y` variables, ",
  "so only the levels are shown. Add everything that `geom_fourfold()` returns ",
  "to the plot, not the layer alone."
)

test_that("direct layer() use with labels = 'both' draws the levels and says so", {
  plot <- direct_plot(
    ucb_df, ggplot2::aes(Gender, Admit, weight = Freq),
    params = list(labels = "both")
  )
  messages <- testthat::capture_messages(shown <- first_labels(plot))
  expect_length(messages, 1)
  expect_identical(shown, ucb_levels)
  expect_identical(messages, paste0(fallback_text, "\n"))
  expect_match(messages, "Add everything that `geom_fourfold()` returns", fixed = TRUE)
})

test_that("the realistic trigger, the layer added without the tagger, falls back", {
  plot <- ucb_base() + geom_fourfold(labels = "both")[[1]]
  expect_null(plot@layers[[1]]$geom_params$label_names)
  expect_false(inherits(plot, "fourfold_plot"))
  messages <- testthat::capture_messages(shown <- first_labels(plot))
  expect_length(messages, 1)
  expect_match(messages, "Add everything that `geom_fourfold()` returns", fixed = TRUE)
  expect_identical(shown, ucb_levels)
})

test_that("the fallback message is once per layer per build, never per panel", {
  faceted <- direct_plot(
    ucb_df, ggplot2::aes(Gender, Admit, weight = Freq),
    ggplot2::facet_wrap(ggplot2::vars(Dept)),
    params = list(labels = "both")
  )
  messages <- testthat::capture_messages(shown <- side_labels(faceted))
  expect_length(messages, 1)
  for (panel in shown) expect_identical(panel[[1]], ucb_levels)
  # Every build gives one: two builds, two messages.
  first <- testthat::capture_messages(invisible(ggplot2::layer_data(faceted)))
  second <- testthat::capture_messages(invisible(ggplot2::layer_data(faceted)))
  expect_length(first, 1)
  expect_length(second, 1)
  # Two fallback layers give two messages (not deduplicated across layers).
  layer <- function() {
    ggplot2::layer(
      geom = GeomFourfold, stat = StatFourfold, position = "identity",
      params = list(labels = "both")
    )
  }
  two <- ucb_base() + layer() + layer() + geom_fourfold()[[2]]
  messages <- testthat::capture_messages(shown <- side_labels(two))
  expect_length(messages, 2)
  expect_identical(shown[[1]][[1]], ucb_levels)
  expect_identical(shown[[1]][[2]], ucb_levels)
  # Once a tagger is added to the plot, every "both" fourfold layer in it gets
  # its names resolved, a layer() made by hand included (spec: the helper acts
  # on every layer whose geom_params$labels is "both"): no fallback.
  mixed <- ucb_base() + layer() + geom_fourfold(labels = "both")
  # Resolved at add time, before any build, for every "both" layer.
  expect_identical(
    mixed@layers[[1]]$geom_params$label_names, c(x = "Gender", y = "Admit")
  )
  expect_identical(
    mixed@layers[[2]]$geom_params$label_names, c(x = "Gender", y = "Admit")
  )
  expect_no_message(shown <- side_labels(mixed))
  expect_identical(shown[[1]][[1]], ucb_both)
  expect_identical(shown[[1]][[2]], ucb_both)
})

test_that("unusable label_names fall back to the levels with one message", {
  bad <- list(
    na_pair = c(x = NA_character_, y = NA_character_),
    one_na = c(x = "Gender", y = NA_character_),
    unnamed = c("a", "b"),
    duplicated_name = c(x = "a", x = "b", y = "c"),
    length_one = c(x = "Gender"),
    length_three = c(x = "a", y = "b", z = "c"),
    empty_name = c(x = "", y = "A"),
    wrong_names = c(a = "Gender", b = "Admit"),
    number = c(x = 1, y = 2),
    list_value = list(x = "a", y = "b"),
    logical = TRUE
  )
  for (case in names(bad)) {
    plot <- ucb_base() + ggplot2::layer(
      geom = GeomFourfold, stat = StatFourfold, position = "identity",
      params = list(labels = "both", label_names = bad[[case]])
    ) + geom_fourfold()[[2]]
    messages <- testthat::capture_messages(shown <- first_labels(plot))
    expect_length(messages, 1)
    expect_identical(shown, ucb_levels, info = case)
  }
  # Usable names given this way are used.
  good <- ucb_base() + ggplot2::layer(
    geom = GeomFourfold, stat = StatFourfold, position = "identity",
    params = list(labels = "both", label_names = c(x = "G", y = "A"))
  ) + geom_fourfold()[[2]]
  expect_no_message(shown <- first_labels(good))
  expect_identical(shown, lab("A: Admitted", "G: Male", "A: Rejected", "G: Female"))
  # The names are taken by name, not by position.
  swapped <- ucb_base() + ggplot2::layer(
    geom = GeomFourfold, stat = StatFourfold, position = "identity",
    params = list(labels = "both", label_names = c(y = "A", x = "G"))
  ) + geom_fourfold()[[2]]
  expect_no_message(shown <- first_labels(swapped))
  expect_identical(shown, lab("A: Admitted", "G: Male", "A: Rejected", "G: Female"))
})

test_that("a normal 'both' plot emits no message and no warning", {
  plots <- list(
    ucb_labels_plot(),
    ucb_labels_plot() + ggplot2::facet_wrap(ggplot2::vars(Dept)),
    ucb_labels_plot() + theme_fourfold()
  )
  for (plot in plots) {
    expect_no_message(expect_no_warning(side_labels(plot)))
    expect_no_message(expect_no_warning(ggplot2::layer_data(plot)))
  }
})

test_that("the resolved names are NULL when x or y has no mapping", {
  names_of <- function(plot) plot@layers[[1]]$geom_params$label_names
  df_plot <- ggplot2::ggplot(ucb_df, ggplot2::aes(Gender, Admit, weight = Freq))
  # An explicit NULL removes the inherited aesthetic.
  expect_null(names_of(df_plot + geom_fourfold(ggplot2::aes(y = NULL), labels = "both")))
  expect_null(names_of(df_plot + geom_fourfold(ggplot2::aes(x = NULL), labels = "both")))
  # No inheritance and no layer mapping, or only one of the two aesthetics.
  expect_null(names_of(df_plot + geom_fourfold(labels = "both", inherit.aes = FALSE)))
  expect_null(names_of(
    df_plot + geom_fourfold(ggplot2::aes(x = Gender), labels = "both", inherit.aes = FALSE)
  ))
  expect_null(names_of(
    df_plot + geom_fourfold(ggplot2::aes(y = Admit), labels = "both", inherit.aes = FALSE)
  ))
  # Only the plot's x, and a layer y: complete when inherited.
  half <- ggplot2::ggplot(ucb_df, ggplot2::aes(Gender, weight = Freq))
  expect_null(names_of(half + geom_fourfold(labels = "both")))
  expect_identical(
    names_of(half + geom_fourfold(ggplot2::aes(y = Admit), labels = "both")),
    c(x = "Gender", y = "Admit")
  )
  expect_null(names_of(ggplot2::ggplot(ucb_df) + geom_fourfold(labels = "both")))
})

test_that("a missing x or y mapping stops in the stat, with its message", {
  half <- ggplot2::ggplot(ucb_df, ggplot2::aes(Gender, weight = Freq))
  expect_error(
    ggplot2::layer_data(half + geom_fourfold(labels = "both")), "y"
  )
  expect_error(
    ggplot2::layer_data(
      ggplot2::ggplot(ucb_df, ggplot2::aes(Gender, Admit, weight = Freq)) +
        geom_fourfold(ggplot2::aes(y = NULL), labels = "both")
    ),
    "y"
  )
  # The same error as with the default labels.
  plain <- tryCatch(
    ggplot2::layer_data(half + geom_fourfold()), error = conditionMessage
  )
  with_labels <- tryCatch(
    ggplot2::layer_data(half + geom_fourfold(labels = "both")),
    error = conditionMessage
  )
  expect_type(plain, "character")
  expect_identical(with_labels, plain)
})

test_that(".fourfold_label_names() resolves the effective mapping", {
  df_plot <- ggplot2::ggplot(ucb_df, ggplot2::aes(Gender, Admit, weight = Freq))
  names_for <- function(...) {
    layer <- geom_fourfold(labels = "both", ...)[[1]]
    .fourfold_label_names(layer, df_plot)
  }
  expect_identical(names_for(), c(x = "Gender", y = "Admit"))
  expect_identical(
    names_for(ggplot2::aes(x = Dept)), c(x = "Dept", y = "Admit")
  )
  expect_identical(
    names_for(ggplot2::aes(x = Dept, y = Dept)), c(x = "Dept", y = "Dept")
  )
  expect_identical(
    names_for(ggplot2::aes(x = .data$Dept)), c(x = "Dept", y = "Admit")
  )
  expect_identical(
    names_for(ggplot2::aes(x = factor(Dept))), c(x = "factor(Dept)", y = "Admit")
  )
  expect_null(names_for(ggplot2::aes(x = NULL)))
  expect_null(names_for(ggplot2::aes(y = NULL)))
  expect_null(names_for(inherit.aes = FALSE))
  expect_null(names_for(ggplot2::aes(x = Gender), inherit.aes = FALSE))
  expect_identical(
    names_for(ggplot2::aes(x = Dept, y = Gender), inherit.aes = FALSE),
    c(x = "Dept", y = "Gender")
  )
  expect_identical(
    .fourfold_label_names(geom_fourfold(labels = "both")[[1]], ggplot2::ggplot()),
    NULL
  )
})

test_that("direct layer() use without labels is as before", {
  plot <- direct_plot(ucb_df, ggplot2::aes(Gender, Admit, weight = Freq))
  expect_no_message(shown <- first_labels(plot))
  expect_identical(shown, ucb_levels)
  plot <- direct_plot(
    ucb_df, ggplot2::aes(Gender, Admit, weight = Freq),
    ggplot2::facet_wrap(ggplot2::vars(Dept)), params = list(labels = "levels")
  )
  expect_no_message(shown <- side_labels(plot))
  for (panel in shown) expect_identical(panel[[1]], ucb_levels)
  expect_false(inherits(plot, "fourfold_plot"))
  # Names supplied without labels do not turn labels on.
  named <- ucb_base() + ggplot2::layer(
    geom = GeomFourfold, stat = StatFourfold, position = "identity",
    params = list(label_names = c(x = "G", y = "A"))
  ) + geom_fourfold()[[2]]
  expect_no_message(shown <- first_labels(named))
  expect_identical(shown, ucb_levels)
  expect_identical(.fourfold_defaults$labels, "levels")
})

# Validation ------------------------------------------------------------------------

test_that("an invalid labels value is an error naming the argument and choices", {
  pattern <- '`labels` must be one of "levels" or "both"'
  expect_error(geom_fourfold(labels = "nope"), pattern, fixed = TRUE)
  expect_error(geom_fourfold(labels = 1), pattern, fixed = TRUE)
  expect_error(geom_fourfold(labels = NA), pattern, fixed = TRUE)
  expect_error(geom_fourfold(labels = NA_character_), pattern, fixed = TRUE)
  expect_error(geom_fourfold(labels = TRUE), pattern, fixed = TRUE)
  expect_error(geom_fourfold(labels = c("both", "levels")), pattern, fixed = TRUE)
  expect_error(geom_fourfold(labels = character(0)), pattern, fixed = TRUE)
  expect_error(geom_fourfold(labels = list("both")), pattern, fixed = TRUE)
  expect_error(geom_fourfold(labels = "Both"), pattern, fixed = TRUE)
})

test_that("labels is validated in the same style as shape and counts", {
  shape_error <- tryCatch(geom_fourfold(shape = "nope"), error = conditionMessage)
  labels_error <- tryCatch(geom_fourfold(labels = "nope"), error = conditionMessage)
  expect_match(shape_error, "^`shape` must be one of")
  expect_match(labels_error, "^`labels` must be one of")
  # Same call-free style.
  expect_null(tryCatch(geom_fourfold(labels = "nope"), error = conditionCall))
})

test_that("labels = NULL and partial matches follow match.arg() like shape", {
  # match.arg(NULL, choices) is choices[1]; geom_fourfold(shape = NULL) is "circle".
  expect_no_error(geom_fourfold(shape = NULL))
  expect_length(geom_fourfold(labels = NULL), 2)
  expect_identical(first_labels(ucb_base() + geom_fourfold(labels = NULL)), ucb_levels)
  # Partial matching: "b" -> "both", "l" -> "levels", as for shape = "sq".
  expect_no_error(geom_fourfold(shape = "sq"))
  expect_length(geom_fourfold(labels = "b"), 3)
  expect_length(geom_fourfold(labels = "l"), 2)
  expect_identical(first_labels(ucb_base() + geom_fourfold(labels = "b")), ucb_both)
})

# Further edge cases ----------------------------------------------------------------

test_that("a level that is empty or contains ': ' is pasted verbatim", {
  df <- data.frame(
    g = factor(c("a: b", "a: b", "c", "c")),
    h = factor(c("", "v", "", "v"), levels = c("", "v")),
    w = 1:4
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(g, h, weight = w)) + geom_fourfold(labels = "both")
  expect_identical(
    first_labels(p),
    lab("h: ", "g: a: b", "h: v", "g: c")
  )
})

test_that("a variable name that contains ': ' is pasted verbatim", {
  df <- data.frame(
    `a: b` = factor(c("x", "x", "y", "y")), h = factor(c("u", "v", "u", "v")),
    w = 1:4, check.names = FALSE
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(`a: b`, h, weight = w)) +
    geom_fourfold(labels = "both")
  expect_identical(first_labels(p), lab("h: u", "a: b: x", "h: v", "a: b: y"))
})

test_that("weights with a zero cell still label", {
  p <- ggplot2::ggplot(small_df, ggplot2::aes(g, h, weight = w)) +
    geom_fourfold(labels = "both")
  zero <- transform(small_df, w = c(0, 2, 30, 40))
  pz <- ggplot2::ggplot(zero, ggplot2::aes(g, h, weight = w)) +
    geom_fourfold(labels = "both")
  want <- lab("h: u", "g: a", "h: v", "g: b")
  expect_identical(first_labels(p), want)
  expect_identical(first_labels(pz), want)
  # Individual-level data, no weight.
  rows <- small_df[rep(1:4, c(1, 2, 3, 4)), c("g", "h")]
  pr <- ggplot2::ggplot(rows, ggplot2::aes(g, h)) + geom_fourfold(labels = "both")
  expect_identical(first_labels(pr), want)
})

test_that("a panel without data draws no labels and the others keep theirs", {
  data <- ucb_df
  data$Freq[data$Dept == "C"] <- NA
  plot <- ggplot2::ggplot(data, ggplot2::aes(Gender, Admit, weight = Freq)) +
    geom_fourfold(labels = "both", na.rm = TRUE) +
    ggplot2::facet_wrap(ggplot2::vars(Dept))
  shown <- side_labels(plot)
  expect_length(shown, 6)
  drawn <- Filter(length, shown)
  expect_length(drawn, 5)
  for (panel in drawn) expect_identical(panel[[1]], ucb_both)
  expect_identical(sum(lengths(shown) == 0L), 1L)
})

test_that("a blank (all-zero) panel still carries its labels", {
  data <- rbind(ucb_df, transform(ucb_df[ucb_df$Dept == "A", ], Dept = "G", Freq = 0))
  plot <- ggplot2::ggplot(data, ggplot2::aes(Gender, Admit, weight = Freq)) +
    geom_fourfold(labels = "both") + ggplot2::facet_wrap(ggplot2::vars(Dept))
  shown <- side_labels(plot)
  # (Seven panels in a 3 x 3 layout leave two cells without a panel display.)
  expect_gte(sum(lengths(shown) > 0L), 6)
  # Whatever a blank panel draws for its levels, the same panel under "levels"
  # differs from it exactly by the names.
  levels <- side_labels(
    ggplot2::ggplot(data, ggplot2::aes(Gender, Admit, weight = Freq)) +
      geom_fourfold() + ggplot2::facet_wrap(ggplot2::vars(Dept))
  )
  expect_length(shown, length(levels))
  for (i in seq_along(shown)) {
    expect_length(shown[[i]], length(levels[[i]]))
    if (length(levels[[i]])) {
      expect_identical(shown[[i]][[1]], ucb_both, info = i)
      expect_identical(levels[[i]][[1]], ucb_levels, info = i)
    }
  }
})

test_that("a layer without rows is drawn with labels = 'both' without error", {
  plot <- ggplot2::ggplot(ucb_df[0, ], ggplot2::aes(Gender, Admit, weight = Freq)) +
    geom_fourfold(labels = "both")
  expect_no_error(ggplot2::layer_data(plot))
  expect_no_error(built_gtable(plot))
})

test_that("a plot built after being modified with the data replaced is relabeled", {
  p <- ucb_labels_plot()
  q <- p
  q@data <- transform(ucb_df, Gender = factor(Gender, labels = c("M", "F")))
  expect_identical(
    first_labels(q),
    lab("Admit: Admitted", "Gender: M", "Admit: Rejected", "Gender: F")
  )
  expect_identical(first_labels(p), ucb_both)
})

test_that("names are resolved on the plot's layer at add time, not on the user's", {
  g <- geom_fourfold(labels = "both")
  p <- ucb_base() + g
  expect_identical(class(p)[1], "fourfold_plot")
  expect_identical(
    p@layers[[1]]$geom_params$label_names, c(x = "Gender", y = "Admit")
  )
  expect_null(g[[1]]$geom_params$label_names)
  invisible(ggplot2::layer_data(p))
  invisible(built_gtable(p))
  expect_null(g[[1]]$geom_params$label_names)
  # Built twice, same labels, same data.
  expect_identical(first_labels(p), first_labels(p))
  expect_identical(ggplot2::layer_data(p), ggplot2::layer_data(p))
})

test_that("further additions do not copy a layer whose names are unchanged", {
  p <- ucb_labels_plot()
  layer <- p@layers[[1]]
  expect_identical(p@layers[[1]]$geom_params$label_names, c(x = "Gender", y = "Admit"))
  same <- list(
    p + geom_fourfold(labels = "both"),
    p + ggplot2::theme(legend.position = "top"),
    p + ggplot2::facet_wrap(ggplot2::vars(Dept)),
    p + theme_fourfold()
  )
  for (i in seq_along(same)) {
    expect_true(rlang::is_reference(same[[i]]@layers[[1]], layer), info = i)
  }
  # Building and resolving again leaves the layer alone too.
  resolved <- .fourfold_resolve_label_names(p)
  expect_true(rlang::is_reference(resolved@layers[[1]], layer))
  twice <- .fourfold_resolve_label_names(resolved)
  expect_true(rlang::is_reference(twice@layers[[1]], layer))
  # A changed mapping gives a different layer with the new names.
  changed <- p + ggplot2::aes(x = Dept)
  resolved <- .fourfold_resolve_label_names(changed)
  expect_false(rlang::is_reference(resolved@layers[[1]], layer))
  expect_identical(
    resolved@layers[[1]]$geom_params$label_names, c(x = "Dept", y = "Admit")
  )
  # The layer the plot holds is not changed by that.
  expect_identical(layer$geom_params$label_names, c(x = "Gender", y = "Admit"))
  # Layers that are not "both" are never copied.
  levels <- ucb_base() + geom_fourfold()
  expect_true(rlang::is_reference(
    .fourfold_resolve_label_names(levels)@layers[[1]], levels@layers[[1]]
  ))
})

test_that("an NA level label stays NA with labels = 'both', on either axis", {
  fun_x <- function(x) c(NA, "F")
  fun_y <- function(x) c(NA, "R")
  cases <- list(
    x = list(scale = ggplot2::scale_x_discrete(labels = fun_x),
             na = "left", other = "right", text = "Gender: F",
             rest = c("top", "bottom")),
    y = list(scale = ggplot2::scale_y_discrete(labels = fun_y),
             na = "top", other = "bottom", text = "Admit: R",
             rest = c("left", "right"))
  )
  for (axis in names(cases)) {
    case <- cases[[axis]]
    # ggplot2 warns about the cells it cannot place; the same for both.
    shown <- suppressWarnings(first_labels(ucb_labels_plot() + case$scale))
    bare <- suppressWarnings(first_labels(ucb_labels_plot(labels = "levels") + case$scale))
    expect_identical(shown[[case$other]], case$text, info = axis)
    expect_identical(shown[[case$na]], bare[[case$na]], info = axis)
    expect_false(any(grepl("Gender: NA|Admit: NA", shown)), info = axis)
    expect_identical(shown[case$rest], ucb_both[case$rest], info = axis)
  }
})

test_that("label_names passed to geom_fourfold() is discarded without a warning", {
  expect_no_warning(expect_no_message(
    g <- geom_fourfold(labels = "both", label_names = c(x = "A", y = "B"))
  ))
  expect_no_warning(expect_no_message(p <- ucb_base() + g))
  expect_no_warning(expect_no_message(shown <- first_labels(p)))
  expect_identical(shown, ucb_both)
  expect_no_warning(expect_no_message(ggplot2::layer_data(p)))
  # Also with the levels default.
  expect_no_warning(geom_fourfold(label_names = c(x = "A", y = "B")))
  expect_identical(
    first_labels(ucb_base() + geom_fourfold(label_names = c(x = "A", y = "B"))),
    ucb_levels
  )
})

test_that("the labels are those vcd::fourfold() draws for a table", {
  skip_on_cran()
  skip_if_not_installed("vcd")
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off())
  vcd::fourfold(UCBAdmissions[, , 1], newpage = TRUE)
  grobs <- grid::grid.get(grid::gPath("."), grep = TRUE, global = TRUE)
  texts <- Filter(function(g) inherits(g, "text"), grobs)
  texts <- Filter(function(g) any(grepl(": ", g$label, fixed = TRUE)), texts)
  # Pick the side of each by geometry (the display is centred on 0).
  side_of <- function(g) {
    x <- as.numeric(g$x)[1]
    y <- as.numeric(g$y)[1]
    rot <- g$rot %% 180
    if (isTRUE(rot == 0) && y > 0) "top"
    else if (isTRUE(rot == 0) && y < 0) "bottom"
    else if (isTRUE(rot == 90) && x < 0) "left"
    else if (isTRUE(rot == 90) && x > 0) "right"
    else NA_character_
  }
  sides <- vapply(texts, side_of, "")
  if (!setequal(sides, c("top", "left", "bottom", "right")) || anyDuplicated(sides)) {
    skip("could not identify one vcd label per side by geometry")
  }
  vcd_labels <- vapply(texts, function(g) paste(g$label, collapse = "|"), "")
  names(vcd_labels) <- sides
  expect_identical(
    vcd_labels[c("top", "left", "bottom", "right")],
    c(top = "Admit: Admitted", left = "Gender: Male",
      bottom = "Admit: Rejected", right = "Gender: Female")
  )
  expect_identical(first_labels(ucb_labels_plot()), vcd_labels[c("top", "left", "bottom", "right")])
})

# Copies of layers -----------------------------------------------------------------

two_df <- data.frame(
  p = factor(c("a", "a", "b", "b")), q = factor(c("a", "b", "a", "b")),
  r = factor(c("u", "v", "u", "v")), s = factor(c("u", "v", "v", "u")),
  w = c(5, 6, 7, 8)
)

test_that("several both layers each keep their own mapping, names and data", {
  plot <- ggplot2::ggplot(two_df) +
    geom_fourfold(ggplot2::aes(p, r, weight = w), labels = "both")[[1]] +
    geom_fourfold(
      ggplot2::aes(q, s, weight = w), labels = "both", inherit.aes = FALSE
    )
  shown <- side_labels(plot)[[1]]
  expect_length(shown, 2)
  expect_identical(shown[[1]], lab("r: u", "p: a", "r: v", "p: b"))
  expect_identical(shown[[2]], lab("s: u", "q: a", "s: v", "q: b"))
  alone1 <- ggplot2::ggplot(two_df) +
    geom_fourfold(ggplot2::aes(p, r, weight = w), labels = "levels")
  alone2 <- ggplot2::ggplot(two_df) +
    geom_fourfold(ggplot2::aes(q, s, weight = w), labels = "levels")
  # Cells (a,u), (a,v), (b,u), (b,v) of p x r: 5, 6, 7, 8; of q x s the
  # counts are 5 (a,u), 7 (a,v), 8 (b,u), 6 (b,v), in the order of the rows.
  expect_identical(ggplot2::layer_data(plot, 1)$count, ggplot2::layer_data(alone1)$count)
  expect_identical(ggplot2::layer_data(plot, 2)$count, ggplot2::layer_data(alone2)$count)
  expect_identical(sort(ggplot2::layer_data(plot, 1)$count), c(5, 6, 7, 8))
  expect_false(identical(
    ggplot2::layer_data(plot, 1)$count, ggplot2::layer_data(plot, 2)$count
  ))
  expect_identical(
    ggplot2::layer_data(plot, 1)[order(ggplot2::layer_data(plot, 1)$x_label,
                                       ggplot2::layer_data(plot, 1)$y_label), "count"],
    c(5, 6, 7, 8)
  )
  expect_identical(
    ggplot2::layer_data(plot, 2)[order(ggplot2::layer_data(plot, 2)$x_label,
                                       ggplot2::layer_data(plot, 2)$y_label), "count"],
    c(5, 7, 8, 6)
  )
  expect_identical(
    unname(vapply(plot@layers, function(l) rlang::as_label(l$mapping$x), "")),
    c("p", "q")
  )
})

test_that("a both layer followed by a non-fourfold layer builds and is labeled", {
  plot <- ggplot2::ggplot(two_df) + geom_fourfold(labels = "both") +
    ggplot2::geom_point(ggplot2::aes(p, r), inherit.aes = FALSE) +
    ggplot2::aes(p, r, weight = w)
  expect_no_error(shown <- side_labels(plot))
  expect_identical(shown[[1]][[1]], lab("r: u", "p: a", "r: v", "p: b"))
  expect_no_error(ggplot2::layer_data(plot, 1))
})

test_that("replacing only the y mapping, or only the x mapping, renames that axis", {
  df <- transform(ucb_df, A2 = Admit, G2 = Gender)
  p <- ggplot2::ggplot(df, ggplot2::aes(Gender, Admit, weight = Freq)) +
    geom_fourfold(labels = "both")
  y_only <- p + ggplot2::aes(y = A2)
  expect_identical(
    first_labels(y_only),
    lab("A2: Admitted", "Gender: Male", "A2: Rejected", "Gender: Female")
  )
  expect_identical(first_labels(p), ucb_both)
  x_only <- p + ggplot2::aes(x = G2)
  expect_identical(
    first_labels(x_only),
    lab("Admit: Admitted", "G2: Male", "Admit: Rejected", "G2: Female")
  )
  expect_identical(first_labels(p), ucb_both)
  # And the resolved parameter on the rebuilt layers.
  expect_identical(
    .fourfold_resolve_label_names(y_only)@layers[[1]]$geom_params$label_names,
    c(x = "Gender", y = "A2")
  )
  expect_identical(
    .fourfold_resolve_label_names(x_only)@layers[[1]]$geom_params$label_names,
    c(x = "G2", y = "Admit")
  )
})
