fourfold_data <- data.frame(
  x = factor(c("a", "a", "b", "b")),
  y = factor(c("u", "v", "u", "v")),
  w = c(1, 2, 30, 40)
)

fourfold_plot <- function(...) {
  ggplot2::ggplot(fourfold_data, ggplot2::aes(x, y, weight = w)) +
    geom_fourfold() +
    list(...)
}

cells <- function(plot) {
  ggplot2::layer_data(plot)[, c("x_label", "y_label", "count")]
}

ucb_plot <- function(...) {
  ggplot2::ggplot(
    as.data.frame(UCBAdmissions),
    ggplot2::aes(x = Gender, y = Admit, weight = Freq)
  ) +
    geom_fourfold() +
    list(...)
}

# The UCB admissions with geom_fourfold(...), unlike ucb_plot(), whose
# arguments are further plot components.
ucb_layer <- function(...) {
  ggplot2::ggplot(
    as.data.frame(UCBAdmissions),
    ggplot2::aes(x = Gender, y = Admit, weight = Freq)
  ) +
    geom_fourfold(...)
}

test_that("breaks that reorder categories are an error", {
  expect_error(
    ggplot2::layer_data(
      fourfold_plot(ggplot2::scale_x_discrete(breaks = c("b", "a")))
    ),
    'x breaks in panel 1 are ("b", "a") but must be the x categories in order, ("a", "b")',
    fixed = TRUE
  )
  expect_error(
    ggplot2::layer_data(
      fourfold_plot(ggplot2::scale_y_discrete(breaks = c("v", "u")))
    ),
    'y breaks in panel 1 are ("v", "u") but must be the y categories in order, ("u", "v")',
    fixed = TRUE
  )
  expect_error(
    ggplot2::layer_data(fourfold_plot(
      ggplot2::scale_x_discrete(breaks = c("b", "a"), labels = c("B", "A"))
    )),
    'x breaks in panel 1 are ("b", "a")',
    fixed = TRUE
  )
  expect_error(
    ggplot2::layer_data(fourfold_plot(ggplot2::scale_x_discrete(breaks = rev))),
    'x breaks in panel 1 are ("b", "a")',
    fixed = TRUE
  )
  expect_error(
    ggplot2::layer_data(fourfold_plot(
      ggplot2::scale_x_discrete(limits = c("b", "a"), breaks = c("a", "b"))
    )),
    'x breaks in panel 1 are ("a", "b") but must be the x categories in order, ("b", "a")',
    fixed = TRUE
  )
})

test_that("breaks that omit categories are an error", {
  expect_error(
    ggplot2::layer_data(fourfold_plot(ggplot2::scale_x_discrete(breaks = "a"))),
    'x breaks in panel 1 are ("a") but must be the x categories in order, ("a", "b")',
    fixed = TRUE
  )
  expect_error(
    ggplot2::layer_data(fourfold_plot(ggplot2::scale_y_discrete(breaks = "v"))),
    'y breaks in panel 1 are ("v") but must be the y categories in order, ("u", "v")',
    fixed = TRUE
  )
  expect_error(
    ggplot2::layer_data(fourfold_plot(ggplot2::scale_x_discrete(breaks = NULL))),
    'x breaks in panel 1 are empty but must be the x categories in order, ("a", "b")',
    fixed = TRUE
  )
})

test_that("the breaks error points to limits and labels", {
  expect_error(
    ggplot2::layer_data(
      fourfold_plot(ggplot2::scale_x_discrete(breaks = c("b", "a")))
    ),
    "use `limits` to reorder categories and `labels` to rename them",
    fixed = TRUE
  )
})

test_that("the breaks error quotes categories", {
  comma_data <- data.frame(
    x = factor(c("a, b", "a, b", "c", "c")),
    y = factor(c("u", "v", "u", "v")),
    w = 1:4
  )
  expect_error(
    ggplot2::layer_data(
      ggplot2::ggplot(comma_data, ggplot2::aes(x, y, weight = w)) +
        geom_fourfold() +
        ggplot2::scale_x_discrete(breaks = c("c", "a, b"))
    ),
    'are ("c", "a, b") but must be the x categories in order, ("a, b", "c")',
    fixed = TRUE
  )
})

test_that("breaks are checked in faceted displays", {
  expect_error(
    ggplot2::layer_data(ucb_plot(
      ggplot2::facet_wrap(ggplot2::vars(Dept)),
      ggplot2::scale_x_discrete(breaks = c("Female", "Male"))
    )),
    'x breaks in panel 1 are ("Female", "Male")',
    fixed = TRUE
  )
  expect_error(
    ggplot2::layer_data(ucb_plot(
      ggplot2::facet_grid(cols = ggplot2::vars(Dept)),
      ggplot2::scale_y_discrete(breaks = c("Rejected", "Admitted"))
    )),
    'y breaks in panel 1 are ("Rejected", "Admitted")',
    fixed = TRUE
  )
  expect_identical(
    ggplot2::layer_data(ucb_plot(
      ggplot2::facet_wrap(ggplot2::vars(Dept)),
      ggplot2::scale_x_discrete(breaks = c("Male", "Female"))
    )),
    ggplot2::layer_data(ucb_plot(ggplot2::facet_wrap(ggplot2::vars(Dept))))
  )
})

test_that("breaks are checked against each panel's categories with free scales", {
  free_data <- data.frame(
    g = rep(1:3, each = 4),
    x = factor(
      c("a", "a", "b", "b", "a", "a", "b", "b", "b", "b", "c", "c"),
      levels = c("a", "b", "c")
    ),
    y = factor(rep(c("u", "v"), 6)),
    w = 1:12
  )
  plot <- ggplot2::ggplot(free_data, ggplot2::aes(x, y, weight = w)) +
    geom_fourfold() +
    ggplot2::facet_wrap(ggplot2::vars(g), scales = "free_x")
  expect_error(
    ggplot2::layer_data(plot + ggplot2::scale_x_discrete(breaks = c("a", "c", "b"))),
    'x breaks in panel 3 are ("c", "b") but must be the x categories in order, ("b", "c")',
    fixed = TRUE
  )
  expect_identical(
    ggplot2::layer_data(plot + ggplot2::scale_x_discrete(breaks = c("a", "b", "c"))),
    ggplot2::layer_data(plot)
  )
})

test_that("breaks matching the categories leave the display unchanged", {
  default <- ggplot2::layer_data(fourfold_plot())
  expect_identical(
    ggplot2::layer_data(
      fourfold_plot(ggplot2::scale_x_discrete(breaks = c("a", "b")))
    ),
    default
  )
  expect_identical(
    ggplot2::layer_data(
      fourfold_plot(ggplot2::scale_y_discrete(breaks = c("u", "v")))
    ),
    default
  )
  # Breaks outside the categories are dropped by the scale.
  expect_identical(
    ggplot2::layer_data(
      fourfold_plot(ggplot2::scale_x_discrete(breaks = c("a", "b", "z")))
    ),
    default
  )
})

test_that("limits reorder categories with their counts", {
  expect_identical(
    cells(fourfold_plot(ggplot2::scale_x_discrete(limits = c("b", "a")))),
    data.frame(
      x_label = c("b", "b", "a", "a"),
      y_label = c("u", "v", "u", "v"),
      count = c(30, 40, 1, 2)
    )
  )
  expect_identical(
    cells(fourfold_plot(ggplot2::scale_y_discrete(limits = c("v", "u")))),
    data.frame(
      x_label = c("a", "a", "b", "b"),
      y_label = c("v", "u", "v", "u"),
      count = c(2, 1, 40, 30)
    )
  )
  expect_identical(
    cells(fourfold_plot(
      ggplot2::scale_x_discrete(limits = c("b", "a"), breaks = c("b", "a"))
    )),
    cells(fourfold_plot(ggplot2::scale_x_discrete(limits = c("b", "a"))))
  )
})

test_that("labels rename categories without moving counts", {
  expected <- data.frame(
    x_label = c("A", "A", "B", "B"),
    y_label = c("u", "v", "u", "v"),
    count = c(1, 2, 30, 40)
  )
  expect_identical(
    cells(fourfold_plot(ggplot2::scale_x_discrete(labels = c("A", "B")))),
    expected
  )
  expect_identical(
    cells(fourfold_plot(
      ggplot2::scale_x_discrete(labels = c(b = "B", a = "A"))
    )),
    expected
  )
  expect_identical(
    cells(fourfold_plot(ggplot2::scale_y_discrete(labels = c("U", "V"))))$y_label,
    c("U", "V", "U", "V")
  )
})

test_that("logical and character variables pass the breaks check", {
  logical_data <- fourfold_data
  logical_data$x <- c(TRUE, TRUE, FALSE, FALSE)
  expect_identical(
    cells(ggplot2::ggplot(logical_data, ggplot2::aes(x, y, weight = w)) +
            geom_fourfold()),
    data.frame(
      x_label = c("FALSE", "FALSE", "TRUE", "TRUE"),
      y_label = c("u", "v", "u", "v"),
      count = c(30, 40, 1, 2)
    )
  )
  character_data <- fourfold_data
  character_data$x <- as.character(character_data$x)
  expect_identical(
    ggplot2::layer_data(
      ggplot2::ggplot(character_data, ggplot2::aes(x, y, weight = w)) +
        geom_fourfold()
    ),
    ggplot2::layer_data(fourfold_plot())
  )
})

test_that("continuous x and y are an error", {
  numeric_data <- data.frame(
    x = c(1, 1, 2, 2),
    y = c(1, 2, 1, 2),
    w = c(1, 2, 30, 40)
  )
  continuous_error <- paste0(
    "x in panel 1 must be categorical (a factor, character, or logical ",
    "variable), not continuous; convert numeric codes with `factor()`"
  )
  plot <- ggplot2::ggplot(numeric_data, ggplot2::aes(x, factor(y), weight = w)) +
    geom_fourfold()
  expect_error(ggplot2::layer_data(plot), continuous_error, fixed = TRUE)
  # Previously drawn with the counts for x = 1 under the label "2".
  expect_error(
    ggplot2::layer_data(plot + ggplot2::scale_x_continuous(breaks = c(2, 1))),
    continuous_error,
    fixed = TRUE
  )
  expect_error(
    ggplot2::layer_data(plot + ggplot2::scale_x_binned()),
    continuous_error,
    fixed = TRUE
  )
  # Previously 1.5 was truncated to 1, putting every count in one column.
  uneven_data <- numeric_data
  uneven_data$x <- c(1, 1, 1.5, 1.5)
  expect_error(
    ggplot2::layer_data(
      ggplot2::ggplot(uneven_data, ggplot2::aes(x, factor(y), weight = w)) +
        geom_fourfold() +
        ggplot2::scale_x_continuous(breaks = c(1, 2))
    ),
    continuous_error,
    fixed = TRUE
  )
  expect_error(
    ggplot2::layer_data(
      ggplot2::ggplot(numeric_data, ggplot2::aes(factor(x), y, weight = w)) +
        geom_fourfold()
    ),
    "y in panel 1 must be categorical",
    fixed = TRUE
  )
  date_data <- numeric_data
  date_data$x <- as.Date("2020-01-01") + c(0, 0, 366, 366)
  expect_error(
    ggplot2::layer_data(
      ggplot2::ggplot(date_data, ggplot2::aes(x, factor(y), weight = w)) +
        geom_fourfold()
    ),
    continuous_error,
    fixed = TRUE
  )
})

test_that("numeric codes converted with factor() work", {
  coded_data <- data.frame(
    x = c(0, 0, 1, 1),
    y = factor(c("u", "v", "u", "v")),
    w = c(1, 2, 30, 40)
  )
  expect_identical(
    cells(ggplot2::ggplot(coded_data, ggplot2::aes(factor(x), y, weight = w)) +
            geom_fourfold()),
    data.frame(
      x_label = c("0", "0", "1", "1"),
      y_label = c("u", "v", "u", "v"),
      count = c(1, 2, 30, 40)
    )
  )
})

test_that("a scale palette that moves categories is an error", {
  expect_error(
    ggplot2::layer_data(fourfold_plot(
      ggplot2::scale_x_discrete(palette = function(n) rev(seq_len(n)))
    )),
    paste0(
      'x categories in panel 1, ("a", "b"), are at positions (2, 1) but must ',
      "be at (1, 2); use `limits`, not a scale `palette`, to reorder categories"
    ),
    fixed = TRUE
  )
  expect_error(
    ggplot2::layer_data(fourfold_plot(
      ggplot2::scale_y_discrete(palette = function(n) rev(seq_len(n)))
    )),
    'y categories in panel 1, ("u", "v"), are at positions (2, 1)',
    fixed = TRUE
  )
  expect_error(
    ggplot2::layer_data(fourfold_plot(
      ggplot2::scale_x_discrete(palette = function(n) c(1, 1.5))
    )),
    "are at positions (1, 1.5) but must be at (1, 2)",
    fixed = TRUE
  )
  expect_error(
    ggplot2::layer_data(ucb_plot(
      ggplot2::facet_wrap(ggplot2::vars(Dept)),
      ggplot2::scale_x_discrete(palette = function(n) rev(seq_len(n)))
    )),
    'x categories in panel 1, ("Male", "Female"), are at positions (2, 1)',
    fixed = TRUE
  )
})

test_that("a missing-value category inside the limits is an error", {
  # Counts for "b" would otherwise be placed at position 3.
  expect_error(
    ggplot2::layer_data(fourfold_plot(
      ggplot2::scale_x_discrete(limits = c("a", NA, "b"))
    )),
    'x categories in panel 1, ("a", "b"), are at positions (1, 3)',
    fixed = TRUE
  )
})

test_that("a palette that keeps categories in place leaves the display unchanged", {
  expect_identical(
    ggplot2::layer_data(
      fourfold_plot(ggplot2::scale_x_discrete(palette = seq_len))
    ),
    ggplot2::layer_data(fourfold_plot())
  )
})

test_that("numeric limits on a discrete scale work", {
  # ggplot2 warns about numeric limits but matches them to the data as text.
  numeric_limits <- suppressWarnings(ggplot2::scale_x_discrete(limits = c(2, 1)))
  coded_data <- data.frame(
    x = factor(c(1, 1, 2, 2)),
    y = factor(c("u", "v", "u", "v")),
    w = c(1, 2, 30, 40)
  )
  plot <- ggplot2::ggplot(coded_data, ggplot2::aes(x, y, weight = w)) +
    geom_fourfold()
  expect_identical(
    ggplot2::layer_data(plot + numeric_limits),
    ggplot2::layer_data(plot + ggplot2::scale_x_discrete(limits = c("2", "1")))
  )
  expect_identical(
    cells(plot + numeric_limits)$count,
    c(30, 40, 1, 2)
  )
})

test_that("numeric data on a discrete scale are an error", {
  numeric_data <- data.frame(
    x = c(1, 1, 2, 2),
    y = factor(c("u", "v", "u", "v")),
    w = c(1, 2, 30, 40)
  )
  plot <- ggplot2::ggplot(numeric_data, ggplot2::aes(x, y, weight = w)) +
    geom_fourfold()
  # Previously drawn with the counts for x = 1 under the label "2".
  expect_error(
    ggplot2::layer_data(plot + ggplot2::scale_x_discrete(limits = c("2", "1"))),
    "x in panel 1 must be categorical",
    fixed = TRUE
  )
  expect_error(
    ggplot2::layer_data(plot + ggplot2::scale_x_discrete()),
    "x in panel 1 must be categorical",
    fixed = TRUE
  )
  # Continuous values from other layers do not affect categorical data.
  expect_identical(
    ggplot2::layer_data(
      fourfold_plot(ggplot2::annotate("text", x = 1.5, y = 1.5, label = "note"))
    ),
    ggplot2::layer_data(fourfold_plot())
  )
})

# Zero counts ------------------------------------------------------------------

# A single panel from a 2 x 2 matrix with rows u, v (y) and columns a, b (x),
# so that matrix(layer_data(...)$column, 2) has the same layout.
table_plot <- function(tab, ...) {
  table_data <- data.frame(
    x = factor(c("a", "a", "b", "b")),
    y = factor(c("u", "v", "u", "v")),
    w = c(tab)
  )
  ggplot2::ggplot(table_data, ggplot2::aes(x, y, weight = w)) +
    geom_fourfold(...)
}

# The table with the row and column totals of `tab` and odds ratio `or`, found
# by root finding rather than by the package's closed-form solution.
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

ring_radii <- function(ring_tables, standardize) {
  lapply(ring_tables, function(ring) unname(sqrt(c(standardize(ring)))))
}

empty_row <- matrix(c(0, 5, 0, 1), 2)
empty_column <- matrix(c(0, 0, 10, 20), 2)
isolated_zero <- matrix(c(0, 5, 3, 4), 2)

std_settings <- list(
  list(), list(margin = 1), list(margin = 2),
  list(std = "ind.max"), list(std = "all.max")
)

test_that("an empty row or column gives finite radii without warnings", {
  # The last two would over- and underflow products of totals in the ring
  # solver if it did not work with proportions.
  tables <- list(
    empty_row, empty_column, matrix(c(0, 0, 0, 5), 2),
    matrix(c(0, 1e200, 0, 1e200), 2), matrix(c(0, 1e-200, 0, 1e-200), 2)
  )
  for (tab in tables) {
    for (setting in std_settings) {
      plot <- do.call(table_plot, c(list(tab), setting))
      expect_no_warning(built <- ggplot2::layer_data(plot))
      expect_true(all(is.finite(unlist(
        built[c("radius", "conf_low_radius", "conf_high_radius")]
      ))))
      expect_no_warning(ggplot2::ggplotGrob(plot))
    }
  }
})

test_that("rings of an empty row or column use the 0.5-corrected totals", {
  for (tab in list(empty_row, empty_column)) {
    # Rescaled to the observed total, which matters only for all.max.
    corrected <- (tab + 0.5) * sum(tab) / (sum(tab) + 2)
    built <- ggplot2::layer_data(table_plot(tab))
    limits <- c(built$conf_low[1], built$conf_high[1])
    # The default display depends only on the odds ratio.
    u <- sqrt(limits) / (1 + sqrt(limits))
    fitted <- function(u) sqrt(c(u, 1 - u, 1 - u, u))
    expect_equal(built$conf_low_radius, fitted(u[1]))
    expect_equal(built$conf_high_radius, fitted(u[2]))

    rings <- lapply(limits, table_with_or, tab = corrected)
    standardizers <- list(
      function(m) prop.table(m, 1),
      function(m) prop.table(m, 2),
      function(m) m / max(m),
      function(m) m / max(tab)
    )
    for (i in seq_along(standardizers)) {
      built <- ggplot2::layer_data(
        do.call(table_plot, c(list(tab), std_settings[[i + 1]]))
      )
      expected <- ring_radii(rings, standardizers[[i]])
      expect_equal(built$conf_low_radius, expected[[1]], tolerance = 1e-8)
      expect_equal(built$conf_high_radius, expected[[2]], tolerance = 1e-8)
    }
  }
})

test_that("an empty row is the only row drawn from the corrected table", {
  built <- ggplot2::layer_data(table_plot(empty_row, margin = 1))
  expect_equal(
    matrix(built$standardized, 2),
    rbind(c(0.5, 0.5), c(5, 1) / 6)
  )
  built <- ggplot2::layer_data(table_plot(empty_column, margin = 2))
  expect_equal(
    matrix(built$standardized, 2),
    cbind(c(0.5, 0.5), c(10, 20) / 30)
  )
})

test_that("sectors otherwise show the observed table", {
  # The standardization divides by non-zero totals, so the observed
  # proportions or counts are drawn although the rings use corrected totals.
  cases <- list(
    list(empty_row, list(margin = 2), prop.table(empty_row, 2)),
    list(empty_column, list(margin = 1), prop.table(empty_column, 1)),
    list(empty_row, list(std = "ind.max"), empty_row / 5),
    list(empty_row, list(std = "all.max"), empty_row / 5)
  )
  for (case in cases) {
    built <- ggplot2::layer_data(do.call(table_plot, c(case[1], case[[2]])))
    expect_equal(matrix(built$standardized, 2), unname(case[[3]]))
  }
})

test_that("rings of other tables keep the observed totals", {
  # Tables with an isolated zero are not changed by the empty row or column
  # fallback, although the 0.5 correction applies to their inference.
  for (tab in list(isolated_zero, matrix(c(10, 30, 20, 20), 2))) {
    standardizers <- list(
      function(m) prop.table(m, 1),
      function(m) prop.table(m, 2),
      function(m) m / max(m),
      function(m) m / max(tab)
    )
    for (i in seq_along(standardizers)) {
      built <- ggplot2::layer_data(
        do.call(table_plot, c(list(tab), std_settings[[i + 1]]))
      )
      rings <- lapply(c(built$conf_low[1], built$conf_high[1]),
                      table_with_or, tab = tab)
      expected <- ring_radii(rings, standardizers[[i]])
      expect_equal(built$conf_low_radius, expected[[1]], tolerance = 1e-8)
      expect_equal(built$conf_high_radius, expected[[2]], tolerance = 1e-8)
    }
  }
})

test_that("near-zero weights give finite rings", {
  tables <- list(
    matrix(c(1e-10, 5, 1e-10, 1), 2),
    matrix(c(0.1 + 0.2 - 0.3, 5, 0, 1), 2),
    matrix(c(0, 5, 1e-15, 1), 2)
  )
  for (tab in tables) {
    for (setting in std_settings) {
      plot <- do.call(table_plot, c(list(tab), setting))
      expect_no_warning(built <- ggplot2::layer_data(plot))
      radii <- unlist(built[c("radius", "conf_low_radius", "conf_high_radius")])
      expect_true(all(is.finite(radii)))
      if (is.null(setting$std)) expect_true(all(radii <= 1 + 1e-12))
    }
  }
})

test_that("faceted tables with empty rows draw every panel", {
  titanic <- as.data.frame(Titanic[c("1st", "2nd", "3rd"), , , ])
  for (margin in list(c(1, 2), 1)) {
    plot <- ggplot2::ggplot(
      titanic, ggplot2::aes(Sex, Survived, weight = Freq)
    ) +
      geom_fourfold(margin = margin) +
      ggplot2::facet_grid(Age ~ Class)
    expect_no_warning(built <- ggplot2::layer_data(plot))
    expect_no_warning(ggplot2::ggplotGrob(plot))
    expect_false(anyNA(built[c("x_label", "y_label", "radius",
                               "conf_low_radius", "conf_high_radius")]))
  }
})

test_that("ring tables keep small cells precise", {
  # Previously the small cells of the first table came out as 0 at its own
  # confidence limits, and odds ratios of 0 and Inf need the boundary cells.
  cases <- list(
    list(matrix(c(1e9, 1, 1, 1e9), 2), c(6.25e16, 1.6e19)),
    list(matrix(c(1e-3, 3e-3, 2e-3, 5e-4), 2), c(1e-6, 0.08, 1e6)),
    list(matrix(c(1, 1e9, 1e12, 1), 2), c(1e-30, 1, 1e30)),
    list(matrix(c(3, 5, 2, 7), 2), c(1e-300, 0.5, 1, 2, 1e300))
  )
  for (case in cases) {
    tab <- case[[1]]
    for (or in case[[2]]) {
      ring <- .fourfold_table_with_or_and_margins(or, tab)
      expect_true(all(ring > 0))
      expect_equal(ring[1, 1] * ring[2, 2] / (ring[1, 2] * ring[2, 1]), or,
                   tolerance = 1e-10)
      expect_equal(rowSums(ring), unname(rowSums(tab)), tolerance = 1e-12)
      expect_equal(colSums(ring), unname(colSums(tab)), tolerance = 1e-12)
    }
  }
  tab <- matrix(c(3, 5, 2, 7), 2)
  expect_equal(.fourfold_table_with_or_and_margins(0, tab),
               matrix(c(0, 8, 5, 4), 2))
  expect_equal(.fourfold_table_with_or_and_margins(Inf, tab),
               matrix(c(5, 3, 0, 9), 2))
})

test_that("all.max rings of an empty row stay on the scale of the counts", {
  for (tab in list(matrix(c(0, 1, 0, 1), 2), matrix(c(0, 1e-6, 0, 2e-6), 2))) {
    built <- ggplot2::layer_data(table_plot(tab, std = "all.max"))
    expect_true(max(built$conf_low_radius, built$conf_high_radius) <= 1)
  }
})

test_that("default rings are drawn at confidence limits of 0 and Inf", {
  # A cell below about 1e-5 without an exact zero gives the interval [0, Inf].
  built <- ggplot2::layer_data(table_plot(c(1e-7, 5, 3, 1)))
  expect_identical(c(built$conf_low[1], built$conf_high[1]), c(0, Inf))
  expect_equal(built$conf_low_radius, c(0, 1, 1, 0))
  expect_equal(built$conf_high_radius, c(1, 0, 0, 1))
})

test_that("odds ratios that over- or underflow are an error", {
  for (weights in list(c(1e200, 1e200, 1e-200, 1e200),
                       c(1e-200, 1, 1, 1e-200))) {
    for (conf_level in c(0.95, 0)) {
      expect_error(
        ggplot2::layer_data(table_plot(weights, conf_level = conf_level)),
        "the odds ratio in fourfold panel 1 cannot be computed",
        fixed = TRUE
      )
    }
  }
})

# Names of the grobs drawn in a single-panel plot.
panel_grob_names <- function(plot) {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off())
  built <- ggplot2::ggplotGrob(plot)
  panel <- built$grobs[[which(built$layout$name == "panel")]]
  grid::grid.ls(panel, print = FALSE)$name
}

test_that("a panel whose counts are all zero is drawn blank", {
  for (setting in c(std_settings, list(list(shape = "square")))) {
    plot <- do.call(table_plot, c(list(matrix(0, 2, 2)), setting))
    expect_no_warning(built <- ggplot2::layer_data(plot))
    expect_identical(built$count, c(0, 0, 0, 0))
    expect_identical(built$radius, c(0, 0, 0, 0))
    expect_true(all(is.na(unlist(built[c(
      "conf_low_radius", "conf_high_radius", "odds_ratio", "standard_error",
      "conf_low", "conf_high", "p_value", "p_adjusted", "significant"
    )]))))
    expect_false(anyNA(built$palette_index))
    expect_no_warning(drawn <- panel_grob_names(plot))
    expect_true(all(c("fourfold-frame", "fourfold-axes", "fourfold-counts")
                    %in% drawn))
    expect_false(any(grepl("sector|conf|diagonal", drawn)))
  }
})

test_that("an empty panel leaves the other panels unchanged", {
  ucb <- as.data.frame(UCBAdmissions)
  empty_department <- transform(ucb[ucb$Dept == "A", ], Dept = "G", Freq = 0)
  plot <- function(data) {
    ggplot2::ggplot(data, ggplot2::aes(Gender, Admit, weight = Freq)) +
      geom_fourfold(std = "all.max", shape = "square") +
      ggplot2::facet_wrap(ggplot2::vars(Dept))
  }
  expect_no_warning(with_empty <- ggplot2::layer_data(
    plot(rbind(ucb, empty_department))
  ))
  without <- ggplot2::layer_data(plot(ucb))
  # The Holm adjustment and the layer-wide count placement ignore it. Values
  # must be identical; only the class of x and y is lost by row subsetting.
  others <- with_empty[with_empty$PANEL != 7, ]
  for (column in setdiff(names(without), "PANEL")) {
    expect_identical(unclass(others[[column]]), unclass(without[[column]]))
  }
  expect_true(all(is.na(with_empty$p_adjusted[with_empty$PANEL == 7])))
})

test_that("faceted Titanic with the crew draws every panel", {
  plot <- ggplot2::ggplot(
    as.data.frame(Titanic), ggplot2::aes(Sex, Survived, weight = Freq)
  ) +
    geom_fourfold() +
    ggplot2::facet_grid(Age ~ Class)
  expect_no_warning(built <- ggplot2::layer_data(plot))
  expect_no_warning(ggplot2::ggplotGrob(plot))
  blank <- ave(built$count, built$PANEL, FUN = sum) == 0
  expect_equal(sum(blank), 4)
  expect_true(all(is.na(built$odds_ratio[blank])))
  expect_false(anyNA(built$odds_ratio[!blank]))
})

# Drawing properties -----------------------------------------------------------

test_that("mapping a drawing property in the layer is an error", {
  mappings <- list(
    ggplot2::aes(colour = x), ggplot2::aes(color = x),
    ggplot2::aes(linewidth = w), ggplot2::aes(lwd = w),
    ggplot2::aes(alpha = w), ggplot2::aes(size = w), ggplot2::aes(family = y)
  )
  for (mapping in mappings) {
    expect_error(
      geom_fourfold(mapping),
      "cannot be mapped in geom_fourfold(), which draws one table per panel",
      fixed = TRUE
    )
  }
  expect_error(
    geom_fourfold(ggplot2::aes(colour = x, size = w)),
    "`colour` and `size` cannot be mapped",
    fixed = TRUE
  )
  expect_error(
    geom_fourfold(ggplot2::aes(colour = x, alpha = w, size = w)),
    "`colour`, `alpha`, and `size` cannot be mapped",
    fixed = TRUE
  )
  # So are mappings to computed variables, which would otherwise work.
  computed <- list(
    ggplot2::aes(colour = ggplot2::after_stat(significant)),
    ggplot2::aes(colour = ggplot2::after_stat(PANEL)),
    ggplot2::aes(linewidth = ggplot2::after_stat(odds_ratio)),
    ggplot2::aes(alpha = ggplot2::after_scale(0.3)),
    ggplot2::aes(colour = ggplot2::stage(x, after_scale = "red"))
  )
  for (mapping in computed) {
    expect_error(geom_fourfold(mapping), "cannot be mapped in geom_fourfold()",
                 fixed = TRUE)
  }
  # Other aesthetics are unaffected, and aes(colour = NULL) removes an
  # inherited mapping as usual.
  expect_s3_class(
    geom_fourfold(ggplot2::aes(x, y, weight = w))[[1]], "LayerInstance"
  )
  expect_s3_class(
    geom_fourfold(ggplot2::aes(colour = NULL))[[1]], "LayerInstance"
  )
  # Something other than a mapping gets ggplot2's own error.
  expect_error(geom_fourfold(data.frame(size = 1)), "must be created by")
})

test_that("drawing properties mapped in ggplot() are ignored", {
  unmapped <- ggplot2::ggplot(fourfold_data, ggplot2::aes(x, y, weight = w)) +
    geom_fourfold()
  mapped <- ggplot2::ggplot(
    fourfold_data,
    ggplot2::aes(x, y, weight = w, colour = x, linewidth = w, alpha = w,
                 size = w)
  ) +
    geom_fourfold()
  expect_no_warning(built <- ggplot2::layer_data(mapped))
  expect_identical(built, ggplot2::layer_data(unmapped))
  # So are inherited mappings to computed variables.
  inherited <- list(
    ggplot2::aes(colour = ggplot2::after_stat(significant)),
    ggplot2::aes(colour = ggplot2::after_stat(PANEL)),
    ggplot2::aes(alpha = ggplot2::after_scale(0.4)),
    ggplot2::aes(colour = ggplot2::stage(x, after_scale = "red"))
  )
  for (mapping in inherited) {
    computed <- ggplot2::ggplot(fourfold_data, ggplot2::aes(x, y, weight = w)) +
      mapping + geom_fourfold()
    expect_no_warning(computed_data <- ggplot2::layer_data(computed))
    expect_identical(computed_data, ggplot2::layer_data(unmapped))
  }
  # The mapping still reaches another layer that uses it.
  with_text <- mapped + ggplot2::geom_text(ggplot2::aes(label = w))
  expect_no_warning(text <- ggplot2::layer_data(with_text, 2))
  expect_length(unique(text$colour), 2)
  expect_identical(ggplot2::layer_data(with_text, 1), built)
})

test_that("fixed drawing properties are applied", {
  plot <- table_plot(
    matrix(c(1, 2, 3, 4), 2),
    colour = "red", linewidth = 2, alpha = 0.5, size = 7, family = "mono"
  )
  built <- ggplot2::layer_data(plot)
  expect_identical(unique(built$colour), "red")
  expect_identical(unique(built$linewidth), 2)
  expect_identical(unique(built$alpha), 0.5)
  expect_identical(unique(built$size), 7)
  expect_identical(unique(built$family), "mono")
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off())
  drawn <- ggplot2::ggplotGrob(plot)
  panel <- drawn$grobs[[which(drawn$layout$name == "panel")]]
  frame <- grid::getGrob(panel, "fourfold-frame", grep = TRUE, global = TRUE)
  # The alpha is for the fills only (see the alpha test below).
  expect_identical(frame$gp$col, "red")
  expect_equal(frame$gp$lwd, 2 * ggplot2::.pt)
})

# Missing values ---------------------------------------------------------------

missing_plot <- function(data, ...,
                         facet = ggplot2::facet_wrap(ggplot2::vars(Dept))) {
  ggplot2::ggplot(data, ggplot2::aes(Gender, Admit, weight = Freq)) +
    geom_fourfold(...) +
    facet
}

# Layer data without PANEL (renumbered when a stratum is dropped), row names,
# or the class that row subsetting removes from x and y.
same_values <- function(with_missing, without) {
  for (column in setdiff(names(without), "PANEL")) {
    expect_identical(unclass(with_missing[[column]]), unclass(without[[column]]))
  }
}

test_that("rows with a missing x or y are removed, as with na.rm in ggplot2", {
  ucb <- as.data.frame(UCBAdmissions)
  extra <- list(
    data.frame(Admit = "Admitted", Gender = NA, Dept = "A", Freq = 5),
    data.frame(Admit = NA, Gender = "Female", Dept = "B", Freq = 5)
  )
  without <- ggplot2::layer_data(missing_plot(ucb))
  for (row in extra) {
    with_missing <- rbind(ucb, row)
    panel <- if (is.na(row$Gender)) 1 else 2
    expect_warning(
      built <- ggplot2::layer_data(missing_plot(with_missing)),
      sprintf(
        paste0(
          "^Removed 1 row containing missing values or values outside the ",
          "scale range in fourfold panel %d\\.$"
        ),
        panel
      )
    )
    same_values(built, without)
    expect_no_warning(
      built <- ggplot2::layer_data(missing_plot(with_missing, na.rm = TRUE))
    )
    same_values(built, without)
  }

  # An explicit NA level, a logical variable, and individual-level data.
  with_level <- rbind(ucb, extra[[1]])
  with_level$Gender <- addNA(with_level$Gender)
  same_values(
    ggplot2::layer_data(missing_plot(with_level, na.rm = TRUE)), without
  )
  logical <- transform(ucb, Gender = Gender == "Male")
  same_values(
    ggplot2::layer_data(missing_plot(rbind(logical, extra[[1]]), na.rm = TRUE)),
    ggplot2::layer_data(missing_plot(logical))
  )
  individual <- ucb[rep(seq_len(nrow(ucb)), ucb$Freq),
                    c("Admit", "Gender", "Dept")]
  individual <- individual[seq(1, nrow(individual), by = 7), ]
  missing <- seq(1, nrow(individual), by = 11)
  with_missing <- individual
  with_missing$Gender[missing[c(TRUE, FALSE)]] <- NA
  with_missing$Admit[missing[c(FALSE, TRUE)]] <- NA
  individual_plot <- function(data) {
    ggplot2::ggplot(data, ggplot2::aes(Gender, Admit)) +
      geom_fourfold(na.rm = TRUE) +
      ggplot2::facet_wrap(ggplot2::vars(Dept))
  }
  same_values(
    ggplot2::layer_data(individual_plot(with_missing)),
    ggplot2::layer_data(individual_plot(individual[-missing, ]))
  )
})

test_that("values outside a discrete scale's limits are removed like missing values", {
  data <- data.frame(
    x = c("a", "a", "b", "b", "c", "c"), y = c("u", "v", "u", "v", "u", "v"),
    w = c(5, 2, 3, 9, 4, 4), stringsAsFactors = FALSE
  )
  # Rows with x (or y) "c" lie outside the limits of the scale of that axis.
  limited_plot <- function(data, axis, na.rm = FALSE, limits = TRUE) {
    mapping <- if (axis == "x") ggplot2::aes(x, y, weight = w) else
      ggplot2::aes(y, x, weight = w)
    scale <- if (axis == "x") ggplot2::scale_x_discrete else
      ggplot2::scale_y_discrete
    ggplot2::ggplot(data, mapping) +
      geom_fourfold(na.rm = na.rm) +
      if (limits) scale(limits = c("a", "b"))
  }
  for (axis in c("x", "y")) {
    without <- ggplot2::layer_data(
      limited_plot(data[1:4, ], axis, limits = FALSE)
    )
    expect_warning(
      built <- ggplot2::layer_data(limited_plot(data, axis)),
      paste0(
        "^Removed 2 rows containing missing values or values outside the ",
        "scale range in fourfold panel 1\\.$"
      )
    )
    same_values(built, without)
    expect_no_warning(
      built <- ggplot2::layer_data(limited_plot(data, axis, na.rm = TRUE))
    )
    same_values(built, without)
  }
})

test_that("labels skip the missing-value category", {
  with_missing <- rbind(
    as.data.frame(UCBAdmissions),
    data.frame(Admit = "Admitted", Gender = NA, Dept = "A", Freq = 5)
  )
  labelled <- function(...) {
    unique(ggplot2::layer_data(
      missing_plot(with_missing, na.rm = TRUE) + ggplot2::scale_x_discrete(...)
    )$x_label)
  }
  expect_identical(labelled(), c("Male", "Female"))
  expect_identical(labelled(labels = c("M", "F")), c("M", "F"))
  expect_identical(labelled(labels = c(Female = "F")), c("Male", "F"))
  expect_identical(labelled(labels = toupper), c("MALE", "FEMALE"))
  expect_identical(labelled(limits = c("Female", "Male")), c("Female", "Male"))
  expect_identical(labelled(na.translate = FALSE), c("Male", "Female"))
})

test_that("a missing value is never drawn as a category with free scales", {
  ucb <- as.data.frame(UCBAdmissions)
  ucb$Gender <- as.character(ucb$Gender)
  free <- ggplot2::facet_wrap(ggplot2::vars(Dept), scales = "free_x")
  # Without its Female rows, panel 3's scale has one category, as it would
  # without the rows; the missing value used to be drawn as a second one.
  females <- ucb$Dept == "C" & ucb$Gender == "Female"
  with_missing <- ucb
  with_missing$Gender[females] <- NA
  expect_error(
    ggplot2::layer_data(missing_plot(with_missing, na.rm = TRUE, facet = free)),
    "panel 3 has 1 and 2"
  )
  expect_error(
    ggplot2::layer_data(missing_plot(ucb[!females, ], facet = free)),
    "panel 3 has 1 and 2"
  )
  # With fixed scales the Female column is empty, as without the rows.
  same_values(
    ggplot2::layer_data(missing_plot(with_missing, na.rm = TRUE)),
    ggplot2::layer_data(missing_plot(ucb[!females, ]))
  )

  # A panel whose x values are all missing is left empty.
  with_missing <- ucb
  with_missing$Gender[ucb$Dept == "C"] <- NA
  expect_warning(
    built <- ggplot2::layer_data(missing_plot(with_missing, facet = free)),
    paste0(
      "Removed 4 rows containing missing values or values outside the scale ",
      "range in fourfold panel 3, leaving it empty."
    )
  )
  expect_false(3 %in% built$PANEL)
  expect_equal(nrow(built), 20)
})

test_that("a missing weight leaves its panel empty rather than counting zero", {
  ucb <- as.data.frame(UCBAdmissions)
  settings <- list(
    list(), list(std = "all.max", shape = "square"),
    list(std = "ind.max", shape = "square"), list(margin = 1),
    list(conf_level = 0), list(p_adjust_method = "none")
  )
  for (missing in list(1, 2, which(ucb$Dept == "C"), c(1, 2))) {
    with_missing <- ucb
    with_missing$Freq[missing] <- NA
    stratum <- unique(ucb$Dept[missing])
    for (setting in settings) {
      expect_warning(
        built <- ggplot2::layer_data(
          do.call(missing_plot, c(list(with_missing), setting))
        ),
        sprintf(
          paste0(
            "^Left fourfold panel %d empty: %d %s a missing ",
            "weight, so the panel's table is unknown\\.$"
          ),
          match(stratum, levels(ucb$Dept)), length(missing),
          if (length(missing) == 1L) "row has" else "rows have"
        )
      )
      # The other panels, including the p-value adjustment and all.max
      # standardization, are as if the stratum were not in the data.
      without <- ggplot2::layer_data(do.call(
        missing_plot, c(list(droplevels(ucb[ucb$Dept != stratum, ])), setting)
      ))
      same_values(built, without)
      expect_no_warning(ggplot2::layer_data(
        do.call(missing_plot, c(list(with_missing, na.rm = TRUE), setting))
      ))
    }
  }

  # NaN is missing too; a row whose x is also missing is simply removed.
  with_missing <- ucb
  with_missing$Freq[1] <- NaN
  expect_false(1 %in% suppressWarnings(
    ggplot2::layer_data(missing_plot(with_missing))$PANEL
  ))
  with_missing$Gender[1] <- NA
  expect_warning(
    built <- ggplot2::layer_data(missing_plot(with_missing)),
    "Removed 1 row containing"
  )
  expect_equal(built$count[built$PANEL == 1], c(0, 313, 89, 19))
})

test_that("invalid weights are an error even in a panel left empty", {
  ucb <- as.data.frame(UCBAdmissions)
  for (invalid in c(-1, Inf)) {
    with_missing <- ucb
    with_missing$Freq[1:2] <- c(NA, invalid)
    expect_error(
      ggplot2::layer_data(missing_plot(with_missing, na.rm = TRUE)),
      "fourfold weights in panel 1 must be finite and non-negative"
    )
  }
})

test_that("empty panels and an empty layer are drawn without errors", {
  ucb <- as.data.frame(UCBAdmissions)
  for (shape in c("circle", "square")) {
    for (missing in list(ucb$Dept == "C", TRUE)) {
      with_missing <- ucb
      with_missing$Freq[missing] <- NA
      plot <- missing_plot(with_missing, shape = shape, na.rm = TRUE) +
        theme_fourfold()
      expect_no_warning(built <- ggplot2::layer_data(plot))
      expect_equal(nrow(built), if (isTRUE(missing)) 0 else 20)
      grDevices::pdf(NULL)
      expect_no_error(ggplot2::ggplotGrob(plot))
      grDevices::dev.off()
    }
  }
  # Not a frame or zero counts: an empty panel draws nothing at all.
  single <- ucb[ucb$Dept == "A", ]
  single$Freq[1] <- NA
  plot <- ggplot2::ggplot(single, ggplot2::aes(Gender, Admit, weight = Freq)) +
    geom_fourfold(na.rm = TRUE)
  expect_false(any(grepl("fourfold", panel_grob_names(plot))))
})


test_that("invalid weights on rows with missing categories remain errors", {
  for (axis in c("Gender", "Admit")) {
    for (invalid in c(-5, Inf, -Inf)) {
      for (remove in c(FALSE, TRUE)) {
        data <- as.data.frame(UCBAdmissions)
        data[[axis]][1] <- NA
        data$Freq[1] <- invalid
        expect_error(
          ggplot2::layer_data(missing_plot(data, na.rm = remove)),
          "fourfold weights in panel 1 must be finite and non-negative"
        )
      }
    }
  }
})

test_that("a palette cannot map missing values onto a real category", {
  for (axis in c("x", "y")) {
    data <- as.data.frame(UCBAdmissions)
    data[[if (axis == "x") "Gender" else "Admit"]][1] <- NA
    scale <- if (axis == "x") ggplot2::scale_x_discrete else
      ggplot2::scale_y_discrete
    expect_error(
      ggplot2::layer_data(
        missing_plot(data, na.rm = TRUE) + scale(palette = function(n) c(1, 2, 1))
      ),
      paste0("fourfold ", axis, " in panel 1 maps missing values to the position of a category")
    )
  }
})

test_that("an unknown table takes precedence over removed category rows", {
  data <- as.data.frame(UCBAdmissions)
  data$Gender[1] <- NA
  data$Freq[2] <- NA
  expect_warning(
    built <- ggplot2::layer_data(missing_plot(data, na.rm = FALSE)),
    "^Left fourfold panel 1 empty: 1 row has a missing weight, so the panel's table is unknown\\.$"
  )
  expect_false(1 %in% built$PANEL)
  same_values(
    built,
    ggplot2::layer_data(missing_plot(droplevels(data[data$Dept != "A", ])))
  )
})

# Coordinate systems -----------------------------------------------------------

# Dept A of UCBAdmissions, with a point at each cell's category position
# (Gender level, Admit level) in a layer after the display. `fourfold` gives
# the arguments of geom_fourfold(), `...` anything else to add.
cell_plot <- function(..., fourfold = list()) {
  ucb <- as.data.frame(UCBAdmissions)
  ggplot2::ggplot(
    ucb[ucb$Dept == "A", ], ggplot2::aes(Gender, Admit, weight = Freq)
  ) +
    do.call(geom_fourfold, fourfold) +
    ggplot2::geom_point(ggplot2::aes(Gender, Admit)) +
    list(...)
}

# The gtable of a plot, as drawn on a null device.
drawn_gtable <- function(plot) {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off())
  ggplot2::ggplotGrob(plot)
}

# What a single-panel plot draws: the panel, the viewport of the fourfold
# display, the positions of the points of a geom_point() layer (in npc of the
# panel), and, if asked, the display's count grobs once their text is placed.
drawn_plot <- function(plot, counts = FALSE) {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off())
  gtable <- ggplot2::ggplotGrob(plot)
  panel <- gtable$grobs[[which(gtable$layout$name == "panel")]]
  display <- grid::getGrob(panel, "fourfold-panel", grep = TRUE)
  shown <- list(panel = panel, vp = display$vp)
  points <- grid::getGrob(panel, "geom_point", grep = TRUE)
  if (!is.null(points)) {
    shown$points <- cbind(x = as.numeric(points$x), y = as.numeric(points$y))
  }
  if (counts) {
    grid::grid.newpage()
    grid::grid.draw(gtable)
    grid::grid.force()
    shown$counts <- grid::grid.get("fourfold-counts")
  }
  shown
}

# Position in npc of a local coordinate of the display on a viewport scale.
to_npc <- function(local, scale) (local - scale[1]) / (scale[2] - scale[1])

# Coordinate systems, with the sides of the Male and Admitted cell (the first
# level of each axis) and the native scales the display is then drawn on.
orientations <- list(
  default = list(
    coord = NULL, male_left = TRUE, admitted_top = TRUE,
    xscale = c(-1.3, 1.3), yscale = c(-1.3, 1.3)
  ),
  none = list(
    coord = ggplot2::coord_cartesian(), male_left = TRUE, admitted_top = FALSE,
    xscale = c(-1.3, 1.3), yscale = c(1.3, -1.3)
  ),
  x = list(
    coord = ggplot2::coord_cartesian(reverse = "x"),
    male_left = FALSE, admitted_top = FALSE,
    xscale = c(1.3, -1.3), yscale = c(1.3, -1.3)
  ),
  y = list(
    coord = ggplot2::coord_cartesian(reverse = "y"),
    male_left = TRUE, admitted_top = TRUE,
    xscale = c(-1.3, 1.3), yscale = c(-1.3, 1.3)
  ),
  xy = list(
    coord = ggplot2::coord_cartesian(reverse = "xy"),
    male_left = FALSE, admitted_top = TRUE,
    xscale = c(1.3, -1.3), yscale = c(-1.3, 1.3)
  )
)

test_that("geom_fourfold() adds its layer and a default coordinate system", {
  added <- geom_fourfold()
  expect_type(added, "list")
  expect_length(added, 2)
  expect_s3_class(added[[1]], "LayerInstance")
  expect_s3_class(added[[2]], "CoordCartesian")
  expect_identical(added[[2]]$reverse, "y")
  expect_equal(added[[2]]$ratio, 1)
  expect_true(added[[2]]$default)
  expect_identical(added[[1]]$geom, GeomFourfold)

  plot <- ggplot2::ggplot(fourfold_data, ggplot2::aes(x, y, weight = w)) +
    geom_fourfold()
  expect_length(plot$layers, 1)
  expect_s3_class(plot$coordinates, "CoordCartesian")
  expect_identical(plot$coordinates$reverse, "y")
  expect_equal(plot$coordinates$ratio, 1)
  expect_true(plot$coordinates$default)
})

test_that("the layer reports the extent of the drawing and keeps its statistics", {
  ucb <- as.data.frame(UCBAdmissions)
  built <- ggplot2::layer_data(
    ggplot2::ggplot(
      ucb[ucb$Dept == "A", ], ggplot2::aes(Gender, Admit, weight = Freq)
    ) +
      geom_fourfold()
  )
  # (ggplot2 gives them the class of the discrete scale.)
  expect_identical(as.numeric(built$xmin), rep(0.2, 4))
  expect_identical(as.numeric(built$xmax), rep(2.8, 4))
  expect_identical(as.numeric(built$ymin), rep(0.2, 4))
  expect_identical(as.numeric(built$ymax), rep(2.8, 4))
  # The statistics are those of the table: Dept A of UCBAdmissions.
  expect_identical(built$count, c(512, 313, 89, 19))
  expect_identical(built$x_label, c("Male", "Male", "Female", "Female"))
  expect_identical(built$y_label, c("Admitted", "Rejected", "Admitted", "Rejected"))
  expect_equal(built$odds_ratio, rep(512 * 19 / (313 * 89), 4))
  expect_equal(built$standardized, c(0.3714414, 0.6285586, 0.6285586, 0.3714414),
               tolerance = 1e-6)
  expect_equal(built$radius, sqrt(built$standardized))
  expect_equal(built$conf_low_radius[1], 0.5599721, tolerance = 1e-6)
  expect_equal(built$conf_high_radius[1], 0.6582200, tolerance = 1e-6)
  expect_equal(built$conf_low[1], 0.2086756, tolerance = 1e-6)
  expect_equal(built$conf_high[1], 0.5843954, tolerance = 1e-6)
  expect_equal(built$p_value[1], 6.208742e-05, tolerance = 1e-6)
  expect_identical(built$palette_index, c(5L, 6L, 6L, 5L))
  expect_true(all(built$significant))

  # The statistics do not depend on the coordinate system.
  for (orientation in orientations) {
    other <- ggplot2::layer_data(ggplot2::ggplot(
      ucb[ucb$Dept == "A", ], ggplot2::aes(Gender, Admit, weight = Freq)
    ) + geom_fourfold() + orientation$coord)
    expect_identical(other, built)
  }

  # An empty layer reports nothing.
  empty <- ggplot2::layer_data(
    ggplot2::ggplot(
      transform(ucb[ucb$Dept == "A", ], Freq = NA),
      ggplot2::aes(Gender, Admit, weight = Freq)
    ) + geom_fourfold(na.rm = TRUE)
  )
  expect_equal(nrow(empty), 0)
})

test_that("by default the display fills the viewport it always had", {
  for (theme in list(ggplot2::theme_grey(), theme_fourfold())) {
    shown <- drawn_plot(cell_plot(theme))
    expect_equal(shown$vp$xscale, c(-1.3, 1.3))
    expect_equal(shown$vp$yscale, c(-1.3, 1.3))
    # The display is not clipped (grid stores clip = "off" as NA).
    expect_true(is.na(shown$vp$clip))
  }
  # In every panel, with fixed scales.
  ucb <- as.data.frame(UCBAdmissions)
  for (facet in list(
    ggplot2::facet_wrap(ggplot2::vars(Dept)),
    ggplot2::facet_grid(. ~ Dept, margins = TRUE),
    ggplot2::facet_grid(Dept ~ ., margins = TRUE)
  )) {
    plot <- ucb_plot(facet, theme_fourfold())
    expect_no_error(gtable <- drawn_gtable(plot))
    panels <- gtable$grobs[grepl("^panel", gtable$layout$name)]
    expect_gte(length(panels), 6)
    for (panel in panels) {
      display <- grid::getGrob(panel, "fourfold-panel", grep = TRUE)
      expect_equal(display$vp$xscale, c(-1.3, 1.3))
      expect_equal(display$vp$yscale, c(-1.3, 1.3))
      expect_true(is.na(display$vp$clip))
    }
  }
})

test_that("the display's viewport follows the orientation and zoom", {
  for (orientation in orientations) {
    shown <- drawn_plot(cell_plot(orientation$coord))
    expect_equal(shown$vp$xscale, orientation$xscale)
    expect_equal(shown$vp$yscale, orientation$yscale)
    # Clipping is off in every orientation, so that counts outside the frame
    # stay whole (grid stores clip = "off" as NA; "inherit" would be FALSE).
    expect_true(is.na(shown$vp$clip))
  }
  # Limits on a discrete axis get ggplot2's discrete expansion of 0.6 on each
  # side, so the frame (2 wide) takes 2 of 3.2 units: native +-1.6.
  zoom <- drawn_plot(cell_plot(
    ggplot2::coord_cartesian(reverse = "y", xlim = c(0.5, 2.5))
  ))
  expect_equal(zoom$vp$xscale, c(-1.6, 1.6))
  expect_equal(zoom$vp$yscale, c(-1.3, 1.3))
  expect_true(is.na(zoom$vp$clip))
  expand <- drawn_plot(cell_plot(
    ggplot2::coord_cartesian(reverse = "y", xlim = c(0.5, 2.5), expand = FALSE)
  ))
  expect_equal(expand$vp$xscale, c(-1, 1))
  expect_equal(expand$vp$yscale, c(-1.3, 1.3))
})

test_that("points at category positions land in the fourfold quadrants", {
  coords <- c(
    orientations,
    list(
      zoom = list(
        coord = ggplot2::coord_cartesian(reverse = "y", xlim = c(0.5, 2.5)),
        male_left = TRUE, admitted_top = TRUE
      ),
      fixed = list(
        coord = ggplot2::coord_fixed(), male_left = TRUE, admitted_top = FALSE
      ),
      clipped = list(
        coord = ggplot2::coord_cartesian(reverse = "xy", clip = "off"),
        male_left = FALSE, admitted_top = TRUE
      )
    )
  )
  for (name in names(coords)) {
    orientation <- coords[[name]]
    plot <- cell_plot(orientation$coord)
    shown <- drawn_plot(plot)
    cells <- ggplot2::layer_data(plot, 2)
    expect_equal(nrow(cells), 4)
    expect_setequal(paste(cells$x, cells$y), c("1 1", "1 2", "2 1", "2 2"))

    # Each point is at the center of its cell's quadrant: local (+-0.5, +-0.5),
    # with the first level of x at u = -0.5 and the first level of y at
    # v = +0.5.
    local <- cbind(u = as.numeric(cells$x) - 1.5, v = 1.5 - as.numeric(cells$y))
    centres <- cbind(
      x = to_npc(local[, "u"], shown$vp$xscale),
      y = to_npc(local[, "v"], shown$vp$yscale)
    )
    expect_equal(shown$points, centres, ignore_attr = TRUE, info = name)

    # The Male-Admitted point (x = 1, y = 1) is on the side expected for the
    # orientation, and the labels of the first levels are on its sides.
    male_admitted <- which(cells$x == 1 & cells$y == 1)
    centre <- c(to_npc(0, shown$vp$xscale), to_npc(0, shown$vp$yscale))
    expect_identical(
      unname(shown$points[male_admitted, "x"] < centre[1]),
      orientation$male_left, info = name
    )
    expect_identical(
      unname(shown$points[male_admitted, "y"] > centre[2]),
      orientation$admitted_top, info = name
    )
    left <- grid::getGrob(shown$panel, "fourfold-label-left")
    top <- grid::getGrob(shown$panel, "fourfold-label-top")
    expect_identical(left$label, "Male")
    expect_identical(top$label, "Admitted")
    expect_identical(
      to_npc(as.numeric(left$x), shown$vp$xscale) < centre[1], orientation$male_left,
      info = name
    )
    expect_identical(
      to_npc(as.numeric(top$y), shown$vp$yscale) > centre[2], orientation$admitted_top,
      info = name
    )
  }

  # Without any reversal, the first row is at the bottom, as in ggplot2: the
  # default is the display with the first y level at the top.
  default <- drawn_plot(cell_plot())
  expect_equal(
    unname(default$points[, "y"][c(1, 3)]), rep(0.5 + 0.5 / 2.6, 2)
  )
  expect_equal(
    unname(default$points[, "y"][c(2, 4)]), rep(0.5 - 0.5 / 2.6, 2)
  )
  expect_equal(
    unname(default$points[, "x"][c(1, 2)]), rep(0.5 - 0.5 / 2.6, 2)
  )
})

test_that("the first y level is on top by default and at the bottom without reversal", {
  for (case in list(list(NULL, TRUE), list(ggplot2::coord_cartesian(), FALSE))) {
    shown <- drawn_plot(cell_plot(case[[1]]))
    top <- grid::getGrob(shown$panel, "fourfold-label-top")
    bottom <- grid::getGrob(shown$panel, "fourfold-label-bottom")
    expect_identical(top$label, "Admitted")
    expect_identical(bottom$label, "Rejected")
    expect_identical(to_npc(as.numeric(top$y), shown$vp$yscale) > 0.5, case[[2]])
    expect_identical(to_npc(as.numeric(bottom$y), shown$vp$yscale) < 0.5, case[[2]])
  }
})

test_that("a coordinate system added after geom_fourfold() replaces the default", {
  base <- ggplot2::ggplot(fourfold_data, ggplot2::aes(x, y, weight = w))
  expect_identical((base + geom_fourfold())$coordinates$reverse, "y")
  expect_no_message(plot <- base + geom_fourfold() + ggplot2::coord_cartesian())
  expect_identical(plot$coordinates$reverse, "none")
  expect_null(plot$coordinates$ratio)
  expect_false(isTRUE(plot$coordinates$default))
  expect_no_message(
    plot <- base + geom_fourfold() +
      ggplot2::coord_cartesian(reverse = "x", clip = "off")
  )
  expect_identical(plot$coordinates$reverse, "x")
  # More layers added with the default do not disturb it, and a plot with two
  # of them has no message.
  expect_no_message(plot <- base + geom_fourfold() + geom_fourfold())
  expect_true(plot$coordinates$default)
  expect_length(plot$layers, 2)
})

test_that("a coordinate system added before geom_fourfold() is replaced", {
  base <- ggplot2::ggplot(fourfold_data, ggplot2::aes(x, y, weight = w))
  expect_message(
    plot <- base + ggplot2::coord_cartesian(reverse = "x") + geom_fourfold(),
    "Coordinate system already present"
  )
  expect_identical(plot$coordinates$reverse, "y")
  expect_equal(plot$coordinates$ratio, 1)
  expect_true(plot$coordinates$default)
  shown <- drawn_plot(plot)
  expect_equal(shown$vp$xscale, c(-1.3, 1.3))
  expect_equal(shown$vp$yscale, c(-1.3, 1.3))
})

test_that("coordinate systems other than Cartesian are an error when drawn", {
  plot <- ucb_plot()
  expect_error(
    drawn_gtable(plot + ggplot2::coord_flip()),
    "fourfold displays do not support coord_flip()", fixed = TRUE
  )
  expect_error(
    drawn_gtable(plot + ggplot2::coord_flip()),
    "swap the x and y aesthetics instead", fixed = TRUE
  )
  others <- list(
    coord_polar = ggplot2::coord_polar(),
    coord_radial = ggplot2::coord_radial(),
    coord_transform = ggplot2::coord_transform()
  )
  for (name in names(others)) {
    bad <- plot + others[[name]]
    # Only the drawing of the display is affected, not the statistics.
    expect_no_error(ggplot2::layer_data(bad))
    expect_error(
      drawn_gtable(bad),
      sprintf(
        "fourfold displays need a Cartesian coordinate system such as coord_cartesian(), not %s()",
        name
      ),
      fixed = TRUE
    )
  }
  expect_no_error(ggplot2::layer_data(plot + ggplot2::coord_flip()))

  # Cartesian coordinate systems with a fixed ratio work.
  for (coord in list(ggplot2::coord_fixed(), ggplot2::coord_equal(),
                     ggplot2::coord_fixed(ratio = 2))) {
    expect_no_error(shown <- drawn_plot(cell_plot(coord)))
    expect_equal(shown$vp$xscale, c(-1.3, 1.3))
  }
})

test_that("free facet scales are an error with the default coordinate system", {
  ucb <- as.data.frame(UCBAdmissions)
  free <- list(
    ggplot2::facet_wrap(ggplot2::vars(Dept), scales = "free"),
    ggplot2::facet_wrap(ggplot2::vars(Dept), scales = "free_x"),
    ggplot2::facet_wrap(ggplot2::vars(Dept), scales = "free_y"),
    ggplot2::facet_grid(. ~ Dept, scales = "free")
  )
  for (facet in free) {
    plot <- ucb_plot(facet)
    expect_no_error(ggplot2::layer_data(plot))
    expect_error(drawn_gtable(plot), "can't use free scales", fixed = TRUE)
  }
  # With a coordinate system without a fixed ratio they are drawn.
  expect_no_error(drawn_gtable(
    ucb_plot(free[[1]], ggplot2::coord_cartesian(reverse = "y"))
  ))
})

# The size in inches of the first panel as drawn on a 7 by 7 inch device, and
# the lengths of its x and y ranges in data units.
panel_inches <- function(plot) {
  grDevices::pdf(NULL, width = 7, height = 7)
  on.exit(grDevices::dev.off())
  gtable <- ggplot2::ggplotGrob(plot)
  grid::grid.newpage()
  grid::grid.draw(gtable)
  grid::grid.force()
  listing <- grid::grid.ls(viewports = TRUE, grobs = FALSE, print = FALSE)
  name <- grep("^panel\\.", listing$name, value = TRUE)[1]
  grid::downViewport(name)
  params <- ggplot2::ggplot_build(plot)$layout$panel_params[[1]]
  c(
    width = grid::convertWidth(grid::unit(1, "npc"), "in", valueOnly = TRUE),
    height = grid::convertHeight(grid::unit(1, "npc"), "in", valueOnly = TRUE),
    x_range = diff(params$x.range), y_range = diff(params$y.range)
  )
}

test_that("theme_fourfold() sets no aspect ratio", {
  expect_null(theme_fourfold()$aspect.ratio)
  expect_null(theme_fourfold(base_size = 8)$aspect.ratio)
  expect_equal(theme_fourfold(aspect.ratio = 0.5)$aspect.ratio, 0.5)
})

test_that("panels are square with the default coordinate system", {
  for (theme in list(theme_fourfold(), ggplot2::theme_grey())) {
    gtable <- drawn_gtable(
      ucb_plot(ggplot2::facet_wrap(ggplot2::vars(Dept), ncol = 3), theme)
    )
    panels <- grepl("^panel", gtable$layout$name)
    expect_true(isTRUE(gtable$respect))
    widths <- as.numeric(gtable$widths[gtable$layout$l[panels]])
    heights <- as.numeric(gtable$heights[gtable$layout$t[panels]])
    expect_true(all(grid::unitType(gtable$widths[gtable$layout$l[panels]]) ==
                      "null"))
    expect_true(all(grid::unitType(gtable$heights[gtable$layout$t[panels]]) ==
                      "null"))
    expect_equal(widths, rep(1, 6))
    expect_equal(heights, rep(1, 6))
  }
})

test_that("a missing x keeps the display round in a wider panel", {
  ucb <- as.data.frame(UCBAdmissions)
  ucb$Gender <- as.character(ucb$Gender)
  ucb <- rbind(
    ucb[ucb$Dept == "A", ],
    data.frame(Admit = "Admitted", Gender = NA, Dept = "A", Freq = 5)
  )
  plot <- ggplot2::ggplot(ucb, ggplot2::aes(Gender, Admit, weight = Freq)) +
    geom_fourfold(na.rm = TRUE) +
    theme_fourfold()
  size <- panel_inches(plot)
  # The axis keeps a place for the missing value: x spans 3.4, y 2.6.
  expect_equal(unname(size[c("x_range", "y_range")]), c(3.4, 2.6))
  # One data unit has the same length on both axes, so the panel is wider.
  expect_equal(
    unname(size["width"] / size["x_range"]),
    unname(size["height"] / size["y_range"])
  )
  expect_gt(size[["width"]], size[["height"]])
  # Removing that place makes the panel square again.
  size <- panel_inches(
    plot + ggplot2::scale_x_discrete(na.translate = FALSE)
  )
  expect_equal(unname(size[["width"]]), unname(size[["height"]]))
  # A theme's aspect ratio fixes the panel's shape and squashes the display.
  size <- panel_inches(plot + ggplot2::theme(aspect.ratio = 1))
  expect_equal(unname(size[["width"]]), unname(size[["height"]]))
  expect_false(isTRUE(all.equal(
    unname(size["width"] / size["x_range"]),
    unname(size["height"] / size["y_range"])
  )))
})

test_that("counts are placed inward in every orientation, outward outside", {
  cells_of <- function(plot) {
    cells <- ggplot2::layer_data(plot, 1)
    cells[order(cells$cell), ]
  }
  settings <- list(
    inside = list(),
    outside = list(std = "ind.max", shape = "square")
  )
  for (setting in names(settings)) {
    for (name in names(orientations)) {
      info <- paste(setting, name)
      plot <- cell_plot(orientations[[name]]$coord, fourfold = settings[[setting]])
      shown <- drawn_plot(plot, counts = TRUE)
      counts <- shown$counts
      layer <- cells_of(plot)
      points <- ggplot2::layer_data(plot, 2)
      outside <- setting == "outside"
      expect_identical(counts$outside, outside, info = info)
      expect_gt(counts$count_limit, 0)
      limit <- if (counts$shape == "square") 0.8 else sqrt(2) * 0.88
      expect_lte(counts$count_limit, limit)

      centre_x <- to_npc(0, shown$vp$xscale)
      centre_y <- to_npc(0, shown$vp$yscale)
      for (cell in 1:4) {
        text <- grid::getGrob(counts, paste0("fourfold-count-", cell))
        expect_identical(text$label, as.character(layer$count[cell]), info = info)
        u <- as.numeric(text$x)
        v <- as.numeric(text$y)
        # In the quadrant of the cell, inside the frame unless outside it.
        expect_identical(sign(u), c(-1, -1, 1, 1)[cell], info = info)
        expect_identical(sign(v), c(1, -1, 1, -1)[cell], info = info)
        expect_identical(abs(u) > 1 && abs(v) > 1, outside, info = info)
        expect_identical(abs(u) < 1 && abs(v) < 1, !outside, info = info)
        # Towards the middle of the display, or away from it when outside.
        left <- to_npc(u, shown$vp$xscale) < centre_x
        bottom <- to_npc(v, shown$vp$yscale) < centre_y
        inward_h <- if (left) 0 else 1
        inward_v <- if (bottom) 0 else 1
        expect_identical(
          text$hjust, if (outside) 1 - inward_h else inward_h, info = info
        )
        expect_identical(
          text$vjust, if (outside) 1 - inward_v else inward_v, info = info
        )
        # And in the screen quadrant of the point at the cell's position.
        point <- which(points$x == layer$x_index[cell] &
                         points$y == layer$y_index[cell])
        expect_length(point, 1)
        expect_identical(
          unname(shown$points[point, "x"] < centre_x), left, info = info
        )
        expect_identical(
          unname(shown$points[point, "y"] < centre_y), bottom, info = info
        )
      }
    }
  }
})

test_that("the count limit does not depend on the orientation on small panels", {
  # On a small device the text is tall compared with the frame, so the limit
  # below which squares and ticks leave the counts alone is well under 0.8, the
  # value it would take if the (negative) native text height of a reversed
  # axis were not made positive.
  limits <- function(plot, size) {
    grDevices::pdf(NULL, width = size, height = size)
    on.exit(grDevices::dev.off())
    gtable <- ggplot2::ggplotGrob(plot)
    grid::grid.newpage()
    grid::grid.draw(gtable)
    grid::grid.force()
    counts <- grid::grid.get("fourfold-counts", grep = TRUE, global = TRUE)
    expect_length(counts, 6)
    list(
      limit = vapply(counts, function(x) x$count_limit, numeric(1)),
      outside = vapply(counts, function(x) x$outside, logical(1))
    )
  }
  ucb <- as.data.frame(UCBAdmissions)
  cases <- list(
    squares = list(
      fourfold = list(shape = "square"), theme = theme_fourfold(), size = 2.5
    ),
    large_text = list(
      fourfold = list(std = "ind.max"), theme = theme_fourfold(base_size = 22),
      size = 3
    )
  )
  for (case in names(cases)) {
    setting <- cases[[case]]
    # Square panels, so that only the orientation differs.
    shown <- lapply(names(orientations), function(name) {
      coord <- if (name == "default") {
        NULL
      } else {
        ggplot2::coord_cartesian(reverse = name, ratio = 1)
      }
      plot <- ggplot2::ggplot(ucb, ggplot2::aes(Gender, Admit, weight = Freq)) +
        do.call(geom_fourfold, setting$fourfold) +
        ggplot2::facet_wrap(ggplot2::vars(Dept)) +
        setting$theme +
        coord
      limits(plot, setting$size)
    })
    names(shown) <- names(orientations)
    reference <- shown$default
    expect_lt(max(reference$limit), 0.8)
    expect_gt(min(reference$limit), 0)
    for (name in names(shown)) {
      expect_identical(shown[[name]]$limit, reference$limit, info = paste(case, name))
      expect_identical(shown[[name]]$outside, reference$outside, info = paste(case, name))
    }
  }
  # The squares of the first case reach the counts: they are placed outside.
  expect_true(all(limits(
    ggplot2::ggplot(ucb, ggplot2::aes(Gender, Admit, weight = Freq)) +
      geom_fourfold(shape = "square") +
      ggplot2::facet_wrap(ggplot2::vars(Dept)) + theme_fourfold(),
    2.5
  )$outside))
})

# Count placement --------------------------------------------------------------

test_that("auto counts clear both confidence bounds and circular arcs", {
  negative <- matrix(c(2, 5, 5, 2), 2)
  plot <- table_plot(negative, shape = "square", diagonal = FALSE) + theme_fourfold()
  counts <- drawn_plot(plot, counts = TRUE)$counts
  expect_true(counts$outside)
  expect_gt(counts$reach, 0.8)
  expect_false(drawn_plot(
    table_plot(negative, shape = "square", diagonal = FALSE, conf_level = 0) +
      theme_fourfold(), counts = TRUE
  )$counts$outside)
  expect_true(drawn_plot(
    cell_plot(fourfold = list(std = "ind.max", diagonal = FALSE)) + theme_fourfold(),
    counts = TRUE
  )$counts$outside)
  expect_false(drawn_plot(cell_plot() + theme_fourfold(), counts = TRUE)$counts$outside)
})

test_that("count options change only text placement in every orientation", {
  for (shape in c("circle", "square")) {
    for (orientation in names(orientations)) {
      reference <- NULL
      for (mode in c("auto", "inside", "outside", "none")) {
        info <- paste(shape, orientation, mode)
        plot <- cell_plot(orientations[[orientation]]$coord,
          fourfold = list(shape = shape, std = "ind.max", counts = mode)) +
          theme_fourfold()
        data <- ggplot2::layer_data(plot)
        if (is.null(reference)) reference <- data
        expect_identical(data, reference, info = info)
        shown <- drawn_plot(plot, counts = TRUE)
        counts <- shown$counts
        if (mode == "none") {
          expect_null(counts, info = info)
          expect_null(grid::getGrob(shown$panel, "fourfold-count-", grep = TRUE), info = info)
          next
        }
        outside <- mode != "inside"
        expect_identical(counts$outside, outside, info = info)
        for (text in counts$children) {
          expect_equal(abs(as.numeric(text$x)), if (outside) 1.02 else 0.88, info = info)
          expect_equal(abs(as.numeric(text$y)), if (outside) 1.02 else 0.88, info = info)
          left <- to_npc(as.numeric(text$x), shown$vp$xscale) < to_npc(0, shown$vp$xscale)
          bottom <- to_npc(as.numeric(text$y), shown$vp$yscale) < to_npc(0, shown$vp$yscale)
          expect_equal(text$hjust, if (outside) as.numeric(left) else as.numeric(!left), info = info)
          expect_equal(text$vjust, if (outside) as.numeric(bottom) else as.numeric(!bottom), info = info)
        }
      }
    }
  }
  for (invalid in list("unknown", NA_character_, c("inside", "outside"), 1)) {
    expect_error(
      geom_fourfold(counts = invalid),
      '`counts` must be one of "auto", "inside", "outside", or "none"',
      fixed = TRUE
    )
  }
  expect_identical(geom_fourfold(counts = "ins")[[1]]$geom_params$counts, "inside")
})

test_that("an Okabe-Ito display keeps the layer data and fills by palette index", {
  ucb <- as.data.frame(UCBAdmissions)
  plot <- function(palette) {
    ggplot2::ggplot(ucb, ggplot2::aes(x = Admit, y = Gender, weight = Freq)) +
      geom_fourfold(palette = palette) +
      ggplot2::facet_wrap(ggplot2::vars(Dept))
  }
  default <- ggplot2::layer_data(plot(fourfold_palette()))
  okabe_ito <- ggplot2::layer_data(plot(fourfold_palette("okabe-ito")))
  expect_identical(okabe_ito, default)
  sector_fills <- function(palette) {
    panels <- ggplot2::layer_grob(plot(palette))
    vapply(panels, function(panel) {
      sectors <- grid::getGrob(
        panel, "fourfold-sector", grep = TRUE, global = TRUE
      )
      fills <- vapply(sectors, function(sector) sector$gp$fill, character(1))
      paste(toupper(substr(fills, 1, 7)), collapse = " ")
    }, character(1))
  }
  palette <- fourfold_palette("okabe-ito")
  expected <- vapply(split(okabe_ito$palette_index, okabe_ito$PANEL), function(index) {
    paste(palette[index], collapse = " ")
  }, character(1))
  expect_identical(unname(sector_fills(palette)), unname(expected))
  # Department A is significant, so it alone uses the third pair.
  expect_identical(okabe_ito$palette_index[okabe_ito$PANEL == 1], c(5L, 6L, 6L, 5L))
  expect_true(all(okabe_ito$palette_index[okabe_ito$PANEL != 1] %in% 3:4))
})

test_that("an invalid choice names its argument", {
  expect_error(
    geom_fourfold(std = "max"),
    '`std` must be one of "margins", "ind.max", or "all.max"',
    fixed = TRUE
  )
  expect_error(
    geom_fourfold(shape = "x"),
    '`shape` must be one of "circle" or "square"',
    fixed = TRUE
  )
  expect_error(
    geom_fourfold(p_adjust_method = "sidak"),
    paste0(
      '`p_adjust_method` must be one of "holm", "hochberg", "hommel", ',
      '"bonferroni", "BH", "BY", "fdr", or "none"'
    ),
    fixed = TRUE
  )
  expect_error(
    geom_fourfold(counts = "both"),
    '`counts` must be one of "auto", "inside", "outside", or "none"',
    fixed = TRUE
  )
  expect_error(geom_fourfold(shape = c("square", "circle")), "`shape` must be")
  expect_error(geom_fourfold(std = 1), "`std` must be")
})

# The parameters GeomFourfold$setup_params() computes for a built plot.
counts_params <- function(plot) {
  params <- ggplot2::ggplot_build(plot)$plot$layers[[1]]$computed_geom_params
  params[c("counts_reach", "counts_tick_reach", "counts_labels")]
}

test_that("the layer-wide count values are parameters, not layer data", {
  plot <- table_plot(matrix(c(2, 5, 5, 2), 2), shape = "square")
  data <- ggplot2::layer_data(plot)
  expect_false(any(c("counts_reach", "counts_tick_reach", "counts_labels") %in%
                     names(data)))
  params <- counts_params(plot)
  expect_identical(
    params,
    .fourfold_counts_params(data, shape = "square", extended = TRUE, length = NULL)
  )
  expect_identical(params$counts_labels, c("2", "5"))
  counts <- drawn_plot(plot + theme_fourfold(), counts = TRUE)$counts
  expect_identical(counts$reach, params$counts_reach)
  expect_identical(counts$tick_reach, params$counts_tick_reach)
  expect_identical(counts$measure_labels, params$counts_labels)
  # They are computed for every layer, not taken from the layer's arguments.
  expect_identical(
    counts_params(table_plot(
      matrix(c(2, 5, 5, 2), 2), shape = "square", counts_reach = -Inf,
      counts_tick_reach = -Inf, counts_labels = "1"
    )),
    params
  )
})

test_that("blank and empty panels contribute no outline or tick reach", {
  for (shape in c("circle", "square")) {
    blank <- table_plot(matrix(0, 2, 2), shape = shape, diagonal.length = 10)
    expect_identical(
      counts_params(blank),
      list(counts_reach = -Inf, counts_tick_reach = -Inf,
           counts_labels = character())
    )
    expect_false(drawn_plot(blank + theme_fourfold(), counts = TRUE)$counts$outside)
    data <- ggplot2::layer_data(blank)
    expect_identical(unname(.fourfold_counts_reach(data[FALSE, ], shape)), c(-Inf, -Inf))

    # A blank panel leaves the layer's values as they are without it.
    ucb <- as.data.frame(UCBAdmissions)
    with_blank <- rbind(ucb, transform(ucb[ucb$Dept == "A", ], Dept = "G", Freq = 0))
    ucb_counts <- function(data) {
      counts_params(
        ggplot2::ggplot(data, ggplot2::aes(Gender, Admit, weight = Freq)) +
          geom_fourfold(shape = shape, diagonal.length = 10) +
          ggplot2::facet_wrap(ggplot2::vars(Dept))
      )
    }
    expect_identical(ucb_counts(with_blank), ucb_counts(ucb))
  }
})

test_that("a panel without the layer-wide count values is placed on its own", {
  # A subclass whose setup_params() leaves them out, so that draw_panel() uses
  # its defaults: the panel with the largest count reaches its counts, the
  # others do not.
  Plain <- ggplot2::ggproto(
    NULL, GeomFourfold, setup_params = function(data, params) params
  )
  plot_with <- function(geom) {
    ggplot2::ggplot(
      data.frame(
        x = factor(rep(c("a", "a", "b", "b"), 2)),
        y = factor(rep(c("u", "v"), 4)),
        g = rep(1:2, each = 4),
        w = c(90, 5, 8, 95, 2, 3, 4, 5)
      ),
      ggplot2::aes(x, y, weight = w)
    ) +
      ggplot2::layer(
        geom = geom, stat = StatFourfold, position = "identity",
        params = list(
          std = "all.max", margin = c(1, 2), conf_level = 0.95,
          extended = TRUE, diagonal = FALSE, p_adjust_method = "holm",
          palette = fourfold_palette(), shape = "circle", counts = "auto",
          na.rm = FALSE
        )
      ) +
      ggplot2::facet_wrap(ggplot2::vars(g)) +
      ggplot2::coord_cartesian(reverse = "y", ratio = 1) +
      theme_fourfold()
  }
  placed <- function(plot) {
    grDevices::pdf(NULL, width = 7, height = 4)
    on.exit(grDevices::dev.off())
    print(plot)
    grid::grid.force()
    vapply(grid::grid.get("fourfold-counts", global = TRUE),
           function(x) x$outside, logical(1))
  }
  expect_identical(placed(plot_with(GeomFourfold)), c(TRUE, TRUE))
  expect_identical(placed(plot_with(Plain)), c(TRUE, FALSE))
})

test_that("circle clearance measures width and distinguishes diagonal ticks", {
  # Measure actual text on a fixed physical viewport; no plot layout involved.
  grDevices::pdf(NULL, width = 7, height = 7)
  grid::pushViewport(grid::viewport(xscale = c(-1.3, 1.3), yscale = c(-1.3, 1.3)))
  on.exit({
    grid::popViewport()
    grDevices::dev.off()
  })
  draw_counts <- function(label, reach, tick = -Inf) {
    makeContent.fourfold_counts(grid::gTree(
      labels = rep(label, 4), measure_labels = label,
      reach = reach, tick_reach = tick, shape = "circle", counts = "auto",
      relative_size = 0.066, minimum_size = 10, colour = "black", family = "",
      name = "fourfold-counts", cl = "fourfold_counts"
    ))
  }
  narrow <- draw_counts("1", 0.95)
  wide <- draw_counts("123456", 0.95)
  expect_false(narrow$outside)
  expect_true(wide$outside)
  expect_lt(wide$count_limit, narrow$count_limit)
  # A diagonal endpoint at 0.70 misses the height of the box, even though a
  # circle passing through that endpoint reaches the wide box's inner corner.
  expect_false(draw_counts("123456", 0, 0.70)$outside)
  expect_true(draw_counts("123456", sqrt(2) * 0.70)$outside)
  expect_true(draw_counts("123456", 0, 0.9)$outside)
})

test_that("circle count widths and reach are shared across facets", {
  data <- as.data.frame(UCBAdmissions)
  data$Freq[data$Dept == "B"] <- 1
  plot <- ggplot2::ggplot(data, ggplot2::aes(Gender, Admit, weight = Freq)) +
    geom_fourfold(std = "ind.max", diagonal = FALSE) +
    ggplot2::facet_wrap(ggplot2::vars(Dept)) + theme_fourfold()
  grDevices::pdf(NULL, width = 7, height = 5)
  on.exit(grDevices::dev.off())
  print(plot)
  grid::grid.force()
  counts <- grid::grid.get("fourfold-counts", global = TRUE)
  expect_length(counts, 6)
  expect_true(all(vapply(counts, function(x) x$outside, logical(1))))
  expect_length(unique(vapply(counts, function(x) x$count_limit, numeric(1))), 1)
})

# The forced fourfold-counts grobs of a plot printed on a null device of the
# given size in inches.
counts_printed <- function(plot, width, height) {
  grDevices::pdf(NULL, width = width, height = height)
  on.exit(grDevices::dev.off())
  print(plot)
  grid::grid.force()
  grid::grid.get("fourfold-counts", global = TRUE)
}

test_that("a plot too small for its layout is drawn without counts", {
  for (setting in list(list(), list(shape = "square", std = "ind.max"))) {
    plot <- ggplot2::ggplot(
      as.data.frame(Titanic), ggplot2::aes(Sex, Survived, weight = Freq)
    ) +
      do.call(geom_fourfold, setting) +
      ggplot2::facet_grid(Age ~ Class, margins = TRUE) +
      theme_fourfold()
    # The panels have no size, so their counts have nothing to be placed in.
    expect_no_error(small <- counts_printed(plot, width = 1.5, height = 4))
    expect_length(small, 15)
    expect_true(all(vapply(small, function(x) length(x$children), 1L) == 0L))
    normal <- counts_printed(plot, width = 9, height = 6)
    expect_length(normal, 15)
    expect_true(all(vapply(normal, function(x) length(x$children), 1L) == 4L))
  }
})

test_that("two fourfold layers in one panel are both drawn", {
  plot <- ggplot2::ggplot(fourfold_data, ggplot2::aes(x, y, weight = w)) +
    geom_fourfold(std = "ind.max") +
    geom_fourfold(shape = "square", conf_level = 0)
  gtable <- drawn_gtable(plot)
  panel <- gtable$grobs[[which(gtable$layout$name == "panel")]]
  displays <- grid::getGrob(panel, "fourfold-panel", grep = TRUE, global = TRUE)
  expect_length(displays, 2)
  names <- vapply(displays, function(x) x$name, character(1))
  expect_true(all(startsWith(names, "fourfold-panel")))
  expect_length(unique(names), 2)
  # The first layer draws circle sectors, the second square sectors.
  vertices <- vapply(displays, function(x) {
    length(grid::getGrob(x, "fourfold-sector-1")$x)
  }, 1L)
  expect_identical(vertices, c(301L, 4L))
  # Each layer draws its own display, not a copy of the first.
  expect_identical(
    vapply(displays, function(x) !is.null(grid::getGrob(x, "fourfold-conf_low_radius-1")), TRUE),
    c(TRUE, FALSE)
  )
})

test_that("the shared defaults are those geom_fourfold() resolves to", {
  layer <- geom_fourfold()[[1]]
  resolved <- c(layer$stat_params, layer$geom_params)
  expect_true(all(names(.fourfold_defaults) %in% names(resolved)))
  for (name in names(resolved)) {
    expect_identical(resolved[[name]], .fourfold_defaults[[name]], info = name)
  }
})

test_that("a layer built from the geom and stat has the defaults of geom_fourfold()", {
  expect_true(inherits(StatFourfold, "Stat"))
  ucb <- ggplot2::ggplot(
    as.data.frame(UCBAdmissions), ggplot2::aes(Gender, Admit, weight = Freq)
  ) +
    ggplot2::facet_wrap(ggplot2::vars(Dept))
  from_layer <- function(...) {
    ggplot2::layer(
      geom = GeomFourfold, stat = StatFourfold, position = "identity", ...
    )
  }
  expect_identical(
    ggplot2::layer_data(ucb + from_layer()),
    ggplot2::layer_data(ucb + geom_fourfold())
  )
  # Parameters given to layer() override the defaults.
  expect_identical(
    ggplot2::layer_data(ucb + from_layer(params = list(std = "ind.max"))),
    ggplot2::layer_data(ucb + geom_fourfold(std = "ind.max"))
  )
  expect_false(identical(
    ggplot2::layer_data(ucb + from_layer(params = list(std = "ind.max"))),
    ggplot2::layer_data(ucb + from_layer())
  ))

  # It draws the same display as geom_fourfold(), panel by panel: the fill and
  # outline of the sectors, and the direction line (not the grob names).
  displays <- function(layer) {
    gtable <- drawn_gtable(
      ucb + layer + ggplot2::coord_cartesian(reverse = "y", ratio = 1) +
        theme_fourfold()
    )
    lapply(gtable$grobs[grepl("^panel", gtable$layout$name)], function(panel) {
      display <- grid::getGrob(panel, "fourfold-panel", grep = TRUE)
      sectors <- lapply(1:4, function(i) {
        sector <- grid::getGrob(display, paste0("fourfold-sector-", i))
        list(fill = sector$gp$fill, x = as.numeric(sector$x),
             y = as.numeric(sector$y))
      })
      line <- grid::getGrob(display, "fourfold-diagonal")
      # The line's end points (in native units) and
      # style, before it is drawn.
      segments <- list(
        ends = c(line$x, line$y), fill = line$fill, colour = line$colour,
        lwd = line$lwd, width = line$width
      )
      list(sectors = sectors, line = segments)
    })
  }
  expect_length(displays(from_layer()), 6)
  expect_identical(displays(from_layer()), displays(geom_fourfold()[[1]]))

  # It is drawn, and its counts are placed, as those of geom_fourfold().
  drawn_counts <- function(layer) {
    counts <- counts_printed(
      ucb + layer + ggplot2::coord_cartesian(reverse = "y", ratio = 1) +
        theme_fourfold(),
      width = 7, height = 5
    )
    list(
      outside = vapply(counts, function(x) x$outside, logical(1)),
      labels = lapply(counts, function(x) x$labels)
    )
  }
  expect_length(drawn_counts(from_layer())$outside, 6)
  expect_identical(drawn_counts(from_layer()), drawn_counts(geom_fourfold()[[1]]))
})

# Diagonal line ----------------------------------------------------------------

# The grobs of a plot's panels: the diagonal line (NULL where none is drawn)
# and the frame, whose line width is the layer's.
panel_displays <- function(plot) {
  gtable <- drawn_gtable(plot)
  panels <- gtable$grobs[grepl("^panel", gtable$layout$name)]
  # Unused cells of a facet layout hold empty grobs.
  panels <- panels[!vapply(panels, inherits, logical(1), "zeroGrob")]
  lapply(panels, function(panel) {
    display <- grid::getGrob(panel, "fourfold-panel", grep = TRUE)
    list(
      diagonal = grid::getGrob(display, "fourfold-diagonal"),
      frame = grid::getGrob(display, "fourfold-frame"),
      display = display
    )
  })
}

# The RGBA values of colors, so that spellings of a color compare equal.
rgba <- function(colour) grDevices::col2rgb(colour, alpha = TRUE)

ucb_diagonal <- function(..., theme = theme_fourfold()) {
  panel_displays(
    ggplot2::ggplot(
      as.data.frame(UCBAdmissions),
      ggplot2::aes(x = Gender, y = Admit, weight = Freq)
    ) +
      geom_fourfold(...) + ggplot2::facet_wrap(ggplot2::vars(Dept)) + theme
  )
}

# The band of a diagonal line as it is drawn on a `width` by `height` inch
# viewport whose native scales span the given ranges (a square one with the
# display's scales by default): its polygon, whose corners are in inches, and
# the line's end points in inches, found independently of the polygon from the
# grob's native end points. NULL if nothing is drawn.
band_of <- function(diagonal, xscale = c(-1.3, 1.3), yscale = c(-1.3, 1.3),
                    width = 5, height = 5) {
  grDevices::pdf(NULL, width = max(width, height), height = max(width, height))
  on.exit(grDevices::dev.off())
  grid::pushViewport(grid::viewport(
    width = grid::unit(width, "inches"), height = grid::unit(height, "inches"),
    xscale = xscale, yscale = yscale
  ))
  drawn <- makeContent.fourfold_diagonal(diagonal)
  polygon <- grid::getGrob(drawn, "fourfold-diagonal-band")
  ends <- cbind(
    x = grid::convertX(grid::unit(diagonal$x, "native"), "inches", valueOnly = TRUE),
    y = grid::convertY(grid::unit(diagonal$y, "native"), "inches", valueOnly = TRUE)
  )
  if (is.null(polygon)) return(NULL)
  list(
    corners = cbind(x = as.numeric(polygon$x), y = as.numeric(polygon$y)),
    gp = polygon$gp, ends = ends, centre = c(width, height) / 2,
    native_per_inch = c(abs(diff(xscale)) / width, abs(diff(yscale)) / height)
  )
}

# The geometry of a band, in inches: the middle of its short edges (the
# starts of its long edges, in the order of its end points), the distance
# between its long edges, its length, and where its border's outer edge ends
# along the line, which is half the border beyond the short edges.
band_geometry <- function(band, border) {
  corners <- band$corners
  start <- (corners[1, ] + corners[4, ]) / 2
  end <- (corners[2, ] + corners[3, ]) / 2
  along <- (end - start) / sqrt(sum((end - start)^2))
  list(
    start = start, end = end, along = along,
    across = sqrt(sum((corners[1, ] - corners[4, ])^2)),
    length = sqrt(sum((end - start)^2)),
    outer_start = start - along * border / 2,
    outer_end = end + along * border / 2
  )
}

# The first panel of a plot of one table (as table_plot() makes it), with the
# radii of its four cells and its odds ratio.
table_diagonal <- function(tab, ...) {
  plot <- table_plot(matrix(tab, 2), ...) + theme_fourfold()
  data <- ggplot2::layer_data(plot)
  data <- data[order(data$cell), ]
  c(panel_displays(plot)[[1]], list(radius = data$radius, or = data$odds_ratio[1]))
}

# A table of each odds ratio: above one, below it, and exactly one.
diagonal_tables <- list(
  above = c(30, 5, 8, 40), below = c(5, 30, 40, 8), one = c(20, 10, 40, 20)
)

# theme_fourfold()'s line width, in grid units (1/96 inch), and what 1 mm of
# `linewidth` is in inches.
frame_lwd <- 0.28 * 72.27 / 25.4
mm <- 72.27 / 25.4 / 96

test_that("the diagonal line is one band through the center", {
  for (shape in c("circle", "square")) {
    for (name in names(diagonal_tables)) {
      info <- paste(shape, name)
      shown <- table_diagonal(diagonal_tables[[name]], shape = shape)
      expect_identical(
        c(shown$or > 1, shown$or < 1, shown$or == 1),
        c(name == "above", name == "below", name == "one")
      )
      # One gTree with the band in it, a polygon as geom_rect() draws.
      expect_s3_class(shown$diagonal, "gTree")
      band <- band_of(shown$diagonal)
      expect_identical(nrow(band$corners), 4L)
      geometry <- band_geometry(band, frame_lwd / 96)
      # Through the center of the display, with the ends on opposite sides.
      to_center <- function(point) point - band$centre
      first <- unname(to_center(geometry$start))
      second <- unname(to_center(geometry$end))
      expect_equal(first[1] * second[2] - first[2] * second[1], 0, info = info)
      expect_lt(sum(first * second), 0)
      # Along the diagonal of the cells with more cases than expected: from
      # the top left to the bottom right when the odds ratio is above one,
      # and from the bottom left to the top right otherwise (including 1).
      if (shown$or > 1) {
        expect_lt(first[1], 0)
        expect_gt(first[2], 0)
        expect_equal(first[1], -first[2], info = info)
        expect_gt(second[1], 0)
      } else {
        expect_gt(first[1], 0)
        expect_gt(first[2], 0)
        expect_equal(first[1], first[2], info = info)
        expect_lt(second[1], 0)
      }
      # Drawn like a rectangle: the layer's color on its border, with miter joins.
      expect_identical(rgba(band$gp$col), rgba("black"))
      expect_identical(rgba(band$gp$fill), rgba("white"))
      expect_equal(band$gp$lwd, frame_lwd)
      expect_identical(band$gp$linejoin, "mitre")
    }
  }
})

test_that("the line ends past each favored sector, along the diagonal", {
  side <- sqrt(pi) / 2
  border <- frame_lwd / 96
  for (std in c("margins", "ind.max", "all.max")) {
    for (shape in c("circle", "square")) {
      for (name in names(diagonal_tables)) {
        info <- paste(shape, name, std)
        shown <- table_diagonal(diagonal_tables[[name]], shape = shape, std = std)
        band <- band_of(shown$diagonal)
        geometry <- band_geometry(band, border)
        # The border's outer edge ends at the end points.
        expect_equal(geometry$outer_start, band$ends[1, ], info = info)
        expect_equal(geometry$outer_end, band$ends[2, ], info = info)
        # In local units, as the display's: 2.6 per 5 inches.
        local <- function(point) (point - band$centre) * band$native_per_inch
        ends <- rbind(local(band$ends[1, ]), local(band$ends[2, ]))
        # The favored cells: 1 and 4 (the first end is cell 1's) when the odds
        # ratio is above one, else 3 and 2.
        cells <- if (shown$or > 1) c(1, 4) else c(3, 2)
        radii <- shown$radius[cells]
        along_diagonal <- sqrt(rowSums(ends^2))
        if (shape == "circle") {
          # 0.15 past each sector's arc.
          expect_equal(along_diagonal, radii + 0.15, info = info)
        } else {
          # A stub of 0.02 on each axis (0.02 * sqrt(2) along the diagonal) past
          # each square's outer corner.
          expect_equal(abs(ends[, 1]), radii * side + 0.02, info = info)
          expect_equal(abs(ends[, 2]), radii * side + 0.02, info = info)
        }
        if (std == "ind.max") {
          # The sectors differ, and so do the ends.
          expect_gt(abs(diff(along_diagonal)), 0.01)
        }
      }
    }
  }
  # An explicit length is the distance along the diagonal for either shape.
  for (shape in c("circle", "square")) {
    for (length in c(0.3, 1e-3, 0)) {
      shown <- table_diagonal(
        c(30, 5, 8, 40), shape = shape, diagonal.length = length, std = "ind.max"
      )
      band <- band_of(shown$diagonal)
      ends <- rbind(
        (band$ends[1, ] - band$centre) * band$native_per_inch,
        (band$ends[2, ] - band$centre) * band$native_per_inch
      )
      radii <- shown$radius[c(1, 4)] * (if (shape == "circle") 1 else side * sqrt(2))
      expect_equal(sqrt(rowSums(ends^2)), radii + length, info = paste(shape, length))
      # A length of 0 is still a line: only `diagonal = FALSE` omits it.
      expect_s3_class(shown$diagonal, "gTree")
    }
  }
  # Zero cells use the cells of the table's corrected odds ratio.
  shown <- table_diagonal(c(0, 10, 12, 40), shape = "square")
  expect_lt(shown$or, 1)
  band <- band_of(shown$diagonal)
  expect_equal(unname((band$ends[1, ] - band$centre)[1]),
               unname((band$ends[1, ] - band$centre)[2]))
  expect_gt(band$ends[1, 1], band$centre[1])
})

test_that("the band is a rectangle of the given width inside its border", {
  border <- frame_lwd / 96
  for (shape in c("circle", "square")) {
    for (shown in ucb_diagonal(shape = shape)) {
      expect_equal(shown$frame$gp$lwd, frame_lwd)
      band <- band_of(shown$diagonal)
      geometry <- band_geometry(band, border)
      # Long edges one interior width plus one border apart, so that, with
      # the border centered on them, the interior is 2.5 line widths wide and
      # each side of it has a border.
      expect_equal(geometry$across, 2.5 * border + border)
      # A rectangle: the short edges are perpendicular to the long ones.
      corners <- band$corners
      expect_equal(sum((corners[2, ] - corners[1, ]) * (corners[3, ] - corners[2, ])), 0)
      expect_equal(sum((corners[2, ] - corners[1, ]) * (corners[4, ] - corners[1, ])), 0)
      expect_gt(geometry$length, 0)
    }
  }
})

test_that("the band is exact on the page whatever the native units per inch", {
  border <- frame_lwd / 96
  for (name in names(orientations)) {
    for (size in list(c(5, 5), c(7, 3), c(3, 7), c(6, 1.5))) {
      info <- paste(name, toString(size))
      shown <- panel_displays(
        cell_plot(orientations[[name]]$coord) + theme_fourfold()
      )[[1]]
      xscale <- shown$display$vp$xscale
      yscale <- shown$display$vp$yscale
      expect_identical(xscale, orientations[[name]]$xscale, info = info)
      band <- band_of(shown$diagonal, xscale, yscale, size[1], size[2])
      geometry <- band_geometry(band, border)
      # The ends of the border's outer edge are the line's end points on the
      # page (found from their native positions), the band is perpendicular
      # to the line there, and its widths are physical: the same on every
      # side, whatever the native units per inch on each axis.
      expect_equal(geometry$outer_start, band$ends[1, ], info = info)
      expect_equal(geometry$outer_end, band$ends[2, ], info = info)
      expect_equal(geometry$across, 3.5 * border, info = info)
      line <- band$ends[2, ] - band$ends[1, ]
      expect_equal(unname(geometry$along),
                   unname(line / sqrt(sum(line^2))), info = info)
      corners <- band$corners
      expect_equal(
        sum((corners[2, ] - corners[1, ]) * (corners[4, ] - corners[1, ])), 0,
        info = info
      )
      expect_equal(geometry$length, sqrt(sum(line^2)) - border, info = info)
    }
  }
})

test_that("the line's width follows the layer's line width", {
  default_theme <- ucb_diagonal(theme = ggplot2::theme_grey())[[1]]
  expect_equal(default_theme$frame$gp$lwd, 0.5 * 72.27 / 25.4)
  widths <- function(shown) {
    band <- band_of(shown$diagonal)
    border <- shown$frame$gp$lwd / 96
    c(across = band_geometry(band, border)$across / border, lwd = band$gp$lwd)
  }
  expect_equal(widths(default_theme)[["across"]], 3.5)
  expect_equal(widths(default_theme)[["lwd"]], 0.5 * 72.27 / 25.4)
  for (width in c(0.1, 1, 2)) {
    shown <- ucb_diagonal(linewidth = width)[[1]]
    expect_equal(shown$frame$gp$lwd, width * 72.27 / 25.4)
    expect_equal(widths(shown)[["across"]], 3.5)
    expect_equal(widths(shown)[["lwd"]], width * 72.27 / 25.4)
  }
  # The border is in the layer's color, which the fill is not.
  shown <- ucb_diagonal(colour = "red")[[1]]
  band <- band_of(shown$diagonal)
  expect_identical(rgba(band$gp$col), rgba("red"))
  expect_identical(rgba(band$gp$fill), rgba("white"))
  # No other palette color draws it.
  shown <- ucb_diagonal(palette = fourfold_palette("okabe-ito"))[[1]]
  expect_identical(rgba(band_of(shown$diagonal)$gp$fill), rgba("white"))
  # With no line width, every line of the display is a hairline, the band's
  # border too, and its interior (2.5 times nothing) has no width either, so
  # its end points are those of the line.
  shown <- ucb_diagonal(linewidth = 0)[[1]]
  band <- band_of(shown$diagonal)
  expect_identical(band$gp$lwd, 0)
  expect_equal(band_geometry(band, 0)$across, 0)
  expect_equal(band_geometry(band, 0)$outer_start, band$ends[1, ])
  # With a width given, it is the band's interior alone: a hairline border.
  shown <- ucb_diagonal(linewidth = 0, diagonal.width = 1)[[1]]
  band <- band_of(shown$diagonal)
  expect_equal(band_geometry(band, 0)$across, mm)
  # Only the line is styled like this: the axes and frame are in the layer's
  # color.
  shown <- ucb_diagonal()[[1]]
  expect_identical(rgba(shown$frame$gp$col), rgba("black"))
  axes <- grid::getGrob(shown$display, "fourfold-axes")
  expect_identical(rgba(axes$gp$col), rgba("black"))
  sector <- grid::getGrob(shown$display, "fourfold-sector-1")
  expect_identical(rgba(sector$gp$col), rgba("black"))
})

test_that("the line is drawn after the sectors and rings, before the axes", {
  display <- ucb_diagonal()[[1]]$display
  names <- grid::childNames(display)
  line <- match("fourfold-diagonal", names)
  expect_gt(line, max(grep("sector|conf_", names)))
  expect_lt(line, match("fourfold-axes", names))
  expect_lt(line, match("fourfold-axis-ticks", names))
  expect_lt(line, match("fourfold-frame", names))
})

test_that("diagonal.fill, diagonal.width and diagonal.length style the line", {
  default <- ucb_diagonal()
  styled <- ucb_diagonal(
    diagonal.fill = "orange", diagonal.width = 0.5, diagonal.length = 0.3
  )
  border <- frame_lwd / 96
  for (i in seq_along(default)) {
    band <- band_of(styled[[i]]$diagonal)
    expect_identical(rgba(band$gp$fill), rgba("orange"))
    # The border is the layer's, wherever the line is styled; the interior's
    # width is given in mm and the border is outside it on each side.
    expect_identical(rgba(band$gp$col), rgba("black"))
    expect_equal(band$gp$lwd, frame_lwd)
    expect_equal(
      band_geometry(band, border)$across, 0.5 * mm + border
    )
    # Longer than the default, at the same angle.
    base <- band_of(default[[i]]$diagonal)
    expect_gt(sum((band$ends[2, ] - band$ends[1, ])^2),
              sum((base$ends[2, ] - base$ends[1, ])^2))
    expect_equal(
      abs(det(rbind(band$ends[2, ] - band$ends[1, ], base$ends[2, ] - base$ends[1, ]))) /
        (sqrt(sum((band$ends[2, ] - band$ends[1, ])^2)) *
           sqrt(sum((base$ends[2, ] - base$ends[1, ])^2))),
      0, tolerance = 1e-8
    )
    # Nothing else is drawn differently.
    for (name in c("fourfold-frame", "fourfold-axes", "fourfold-sector-1",
                   "fourfold-conf_low_radius-4")) {
      expect_identical(
        grid::getGrob(styled[[i]]$display, name),
        grid::getGrob(default[[i]]$display, name),
        info = name
      )
    }
  }
  # A width of its own, given in mm whatever the layer's linewidth.
  shown <- ucb_diagonal(linewidth = 1, diagonal.width = 0.2)[[1]]
  band <- band_of(shown$diagonal)
  expect_equal(shown$frame$gp$lwd, 72.27 / 25.4)
  expect_equal(band_geometry(band, mm)$across, (0.2 + 1) * mm)
  # A width of 0 leaves the borders only, meeting: one line of the layer's
  # color twice the layer's width wide, as the interior is nothing.
  shown <- ucb_diagonal(diagonal.width = 0)[[1]]
  band <- band_of(shown$diagonal)
  expect_equal(band_geometry(band, border)$across, border)
  expect_equal(band$gp$lwd, frame_lwd)
  # The fill is a color like any other, and a numeric one is a palette index.
  expect_identical(
    rgba(band_of(ucb_diagonal(diagonal.fill = "black")[[1]]$diagonal)$gp$fill),
    rgba("black")
  )
  expect_identical(
    rgba(band_of(ucb_diagonal(diagonal.fill = 2)[[1]]$diagonal)$gp$fill), rgba(2)
  )
  # A missing or transparent fill leaves the band hollow: a border only.
  for (fill in list(NA, NA_character_, NA_real_, "transparent")) {
    band <- band_of(ucb_diagonal(diagonal.fill = fill)[[1]]$diagonal)
    expect_true(is.na(band$gp$fill) || rgba(band$gp$fill)[4, 1] == 0)
    expect_identical(rgba(band$gp$col), rgba("black"))
    expect_equal(band$gp$lwd, frame_lwd)
    expect_identical(nrow(band$corners), 4L)
  }
})

test_that("a line no longer than its border is not drawn, and never inverted", {
  border <- 4  # grid line widths: 4 / 96 inch
  inch <- border / 96
  # Ends 0.5 and 0.1 inch from the center on a diagonal, 5 inch square.
  scale_per_inch <- 2.6 / 5
  make <- function(a, b) {
    .fourfold_diagonal_grob(
      c(-a, b) * scale_per_inch / sqrt(2), c(a, -b) * scale_per_inch / sqrt(2),
      fill = "white", colour = "black", lwd = border, width = 10
    )
  }
  # Longer than the border: the band runs from end to end less half a border at
  # each, in the same direction as the line.
  for (total in c(0.6, 0.1, 2 * inch, 1.5 * inch)) {
    band <- band_of(make(total / 2, total / 2))
    expect_false(is.null(band))
    geometry <- band_geometry(band, inch)
    expect_equal(geometry$length, total - inch)
    expect_gt(sum(geometry$along * (band$ends[2, ] - band$ends[1, ])), 0)
  }
  # Just longer than the border, the band is as short as it gets; not longer
  # than it, nothing is drawn.
  band <- band_of(make(inch / 2 + 1e-6, inch / 2 + 1e-6))
  expect_false(is.null(band))
  expect_lt(band_geometry(band, inch)$length, 1e-4)
  expect_null(band_of(make(inch / 2 * 0.999, inch / 2 * 0.999)))
  expect_null(band_of(make(inch / 4, inch / 4)))
  expect_null(band_of(make(0, 0)))
  # Without a border, only a line of no length is not drawn.
  zero_border <- .fourfold_diagonal_grob(
    c(-0.1, 0.1), c(0.1, -0.1), "white", "black", lwd = 0, width = 10
  )
  expect_false(is.null(band_of(zero_border)))
  expect_null(band_of(.fourfold_diagonal_grob(
    c(0.1, 0.1), c(0.1, 0.1), "white", "black", lwd = 0, width = 10
  )))
  expect_null(.fourfold_diagonal_corners(c(0, 0), c(0, 0), 1, 0))
  expect_null(.fourfold_diagonal_corners(c(0, NA), c(0, 1), 1, 0))
  # In a plot: tiny sectors, no extension and a tiny panel draw nothing, with
  # no error or warning, and with a longer line something is drawn.
  tiny <- table_plot(matrix(c(1e-4, 40, 40, 1e-4), 2), std = "all.max",
                     diagonal.length = 0) + theme_fourfold()
  expect_no_warning(drawn <- panel_displays(tiny)[[1]])
  expect_s3_class(drawn$diagonal, "gTree")
  expect_no_error(counts_printed(tiny, width = 0.4, height = 0.4))
})

test_that("the line is omitted unless asked for, and there is a table", {
  expect_true(all(vapply(ucb_diagonal(), function(x) !is.null(x$diagonal), TRUE)))
  for (shape in c("circle", "square")) {
    for (shown in list(
      ucb_diagonal(extended = FALSE, shape = shape),
      ucb_diagonal(diagonal = FALSE, shape = shape),
      ucb_diagonal(
        diagonal = FALSE, diagonal.fill = "red", diagonal.width = 3,
        diagonal.length = 1, shape = shape
      ),
      ucb_diagonal(
        extended = FALSE, diagonal.fill = "red", diagonal.width = 3,
        shape = shape
      )
    )) {
      expect_true(all(vapply(shown, function(x) is.null(x$diagonal), TRUE)))
    }
  }
  # A line of no length is still drawn, and so is one with a transparent fill.
  for (setting in list(list(diagonal.length = 0), list(diagonal.fill = NA))) {
    shown <- do.call(ucb_diagonal, setting)
    expect_true(all(vapply(shown, function(x) !is.null(x$diagonal), TRUE)))
  }
  # A blank panel has none, though the others in the layer do.
  ucb <- as.data.frame(UCBAdmissions)
  with_blank <- rbind(ucb, transform(ucb[ucb$Dept == "A", ], Dept = "G", Freq = 0))
  for (shape in c("circle", "square")) {
    shown <- panel_displays(
      ggplot2::ggplot(with_blank, ggplot2::aes(Gender, Admit, weight = Freq)) +
        geom_fourfold(shape = shape) +
        ggplot2::facet_wrap(ggplot2::vars(Dept)) + theme_fourfold()
    )
    expect_length(shown, 7)
    expect_identical(sum(vapply(shown, function(x) is.null(x$diagonal), TRUE)), 1L)
  }
})

test_that("the layer's alpha applies to the cell fills only", {
  alpha_of <- function(colour) unname(rgba(colour)[4, 1])
  plain <- ucb_diagonal()[[1]]$display
  for (setting in list(
    list(alpha = 0.3), list(alpha = 0.3, diagonal.fill = "red"),
    list(alpha = 0.3, diagonal.fill = 2L), list(alpha = 0.3, shape = "square"),
    list(alpha = 0.3, colour = "red"), list(alpha = 0.3, diagonal.fill = NA)
  )) {
    shown <- do.call(ucb_diagonal, setting)[[1]]$display
    reference <- do.call(ucb_diagonal, setting[names(setting) != "alpha"])[[1]]$display
    for (cell in 1:4) {
      sector <- grid::getGrob(shown, paste0("fourfold-sector-", cell))
      unfaded <- grid::getGrob(reference, paste0("fourfold-sector-", cell))
      # The fill is the palette color at the given alpha, the outline opaque.
      expect_identical(rgba(sector$gp$fill)[1:3, 1], rgba(unfaded$gp$fill)[1:3, 1])
      expect_equal(alpha_of(sector$gp$fill), round(0.3 * 255))
      expect_identical(sector$gp$col, unfaded$gp$col)
      expect_identical(alpha_of(sector$gp$col), 255L)
    }
    # Everything else is drawn exactly as without alpha: outlines of the
    # rings (which stay transparent inside), the diagonal line (border and
    # interior), axes, axis ticks, frame, category labels, and counts.
    others <- c(
      paste0("fourfold-conf_low_radius-", 1:4),
      paste0("fourfold-conf_high_radius-", 1:4),
      "fourfold-diagonal", "fourfold-axes", "fourfold-axis-ticks",
      "fourfold-frame", paste0("fourfold-label-", c("top", "left", "bottom", "right")),
      "fourfold-counts"
    )
    for (name in others) {
      expect_identical(
        grid::getGrob(shown, name), grid::getGrob(reference, name), info = name
      )
    }
  }
  # Spot checks of the values: opaque lines and text, transparent ring fills.
  shown <- ucb_diagonal(alpha = 0.3)[[1]]
  band <- band_of(shown$diagonal)
  expect_identical(rgba(band$gp$fill), rgba("white"))
  expect_identical(alpha_of(band$gp$fill), 255L)
  expect_identical(alpha_of(band$gp$col), 255L)
  expect_identical(alpha_of(shown$frame$gp$col), 255L)
  ring <- grid::getGrob(shown$display, "fourfold-conf_low_radius-1")
  expect_identical(alpha_of(ring$gp$fill), 0L)
  expect_identical(alpha_of(ring$gp$col), 255L)
  expect_identical(
    alpha_of(grid::getGrob(shown$display, "fourfold-counts")$colour), 255L
  )
  # Without alpha, as before.
  sector <- grid::getGrob(plain, "fourfold-sector-1")
  expect_identical(alpha_of(sector$gp$fill), 255L)
  # alpha = 0 hides the fills but not the outlines or the line; 1 is opaque.
  hidden <- ucb_diagonal(alpha = 0)[[1]]
  sector <- grid::getGrob(hidden$display, "fourfold-sector-1")
  expect_identical(alpha_of(sector$gp$fill), 0L)
  expect_identical(alpha_of(sector$gp$col), 255L)
  expect_identical(alpha_of(band_of(hidden$diagonal)$gp$fill), 255L)
  expect_identical(
    grid::getGrob(ucb_diagonal(alpha = 1)[[1]]$display, "fourfold-sector-1")$gp$fill,
    grid::getGrob(plain, "fourfold-sector-1")$gp$fill
  )
  # The statistics are not affected.
  expect_identical(
    subset(ggplot2::layer_data(ucb_layer(alpha = 0.3)), select = -alpha),
    subset(ggplot2::layer_data(ucb_layer()), select = -alpha)
  )
})

test_that("the arguments of the diagonal line are validated", {
  for (bad in list("TRUE", 1, 0L, NA, NA_character_, c(TRUE, FALSE), logical(),
                   NULL, list(TRUE))) {
    expect_error(geom_fourfold(diagonal = bad), "diagonal must be TRUE or FALSE",
                 fixed = TRUE, info = deparse(bad))
  }
  for (good in list(TRUE, FALSE)) expect_silent(geom_fourfold(diagonal = good))
  for (bad in list("notacolour", c("red", "blue"), character(), list("red"),
                   -1, NULL, "")) {
    expect_error(geom_fourfold(diagonal.fill = bad),
                 "diagonal.fill must be a single valid color", fixed = TRUE,
                 info = deparse(bad))
  }
  # Whatever col2rgb() accepts: names, hexadecimal codes, palette indices, NA.
  for (fill in list("red", "#12345678", 2, 2L, NA, NA_character_, NA_real_,
                    "transparent")) {
    expect_silent(geom_fourfold(diagonal.fill = fill))
  }
  for (bad in list(-1, NA, NA_real_, Inf, -Inf, c(0.1, 0.2), numeric(), "1",
                   TRUE)) {
    expect_error(geom_fourfold(diagonal.length = bad),
                 "diagonal.length must be NULL or a single non-negative number",
                 fixed = TRUE, info = deparse(bad))
    expect_error(geom_fourfold(diagonal.width = bad),
                 "diagonal.width must be NULL or a single non-negative number",
                 fixed = TRUE, info = deparse(bad))
  }
  for (good in list(NULL, 0, 0.15, 1L, 3)) {
    expect_silent(geom_fourfold(diagonal.length = good))
    expect_silent(geom_fourfold(diagonal.width = good))
  }
  # The arguments of the ticks they replace are gone, with no aliases.
  for (old in c("ticks", "tick.colour", "tick.color", "tick.linewidth")) {
    expect_false(old %in% names(formals(geom_fourfold)), info = old)
  }
  expect_identical(
    names(formals(geom_fourfold))[
      match("diagonal", names(formals(geom_fourfold))) + 0:3
    ],
    c("diagonal", "diagonal.length", "diagonal.fill", "diagonal.width")
  )
})

test_that("the default length of the line depends on the shape", {
  expect_identical(.fourfold_diagonal_length(NULL, "circle"), 0.15)
  expect_identical(.fourfold_diagonal_length(NULL, "square"), 0.02 * sqrt(2))
  # Without a shape it is the default shape's.
  expect_identical(.fourfold_diagonal_length(NULL), 0.15)
  # An explicit length applies as given, to either shape.
  expect_identical(.fourfold_diagonal_length(0.3, "square"), 0.3)
  expect_identical(.fourfold_diagonal_length(0, "circle"), 0)
  expect_null(.fourfold_defaults$diagonal_length)
  expect_null(formals(geom_fourfold)$diagonal.length)
  expect_null(formals(geom_fourfold)$diagonal.width)
  expect_identical(formals(geom_fourfold)$diagonal.fill, "white")
  expect_true(formals(geom_fourfold)$diagonal)
})

test_that("the arguments of the diagonal line leave the statistics alone", {
  reference <- ggplot2::layer_data(ucb_plot())
  for (setting in list(
    list(diagonal.fill = "black"), list(diagonal.width = 5),
    list(diagonal.fill = NA, diagonal.width = 0), list(diagonal.length = 1),
    list(diagonal.length = NULL), list(diagonal = FALSE)
  )) {
    plot <- ggplot2::ggplot(
      as.data.frame(UCBAdmissions),
      ggplot2::aes(x = Gender, y = Admit, weight = Freq)
    ) + do.call(geom_fourfold, setting)
    expect_identical(ggplot2::layer_data(plot), reference)
  }
  # Nor does the shape's line length.
  squares <- ggplot2::layer_data(ucb_plot() + geom_fourfold(shape = "square"))
  expect_identical(
    squares,
    ggplot2::layer_data(
      ucb_plot() + geom_fourfold(shape = "square", diagonal.length = 1)
    )
  )
})

test_that("a layer built from the geom and stat styles the line like geom_fourfold()", {
  ucb <- ggplot2::ggplot(
    as.data.frame(UCBAdmissions), ggplot2::aes(Gender, Admit, weight = Freq)
  ) +
    ggplot2::facet_wrap(ggplot2::vars(Dept)) +
    ggplot2::coord_cartesian(reverse = "y", ratio = 1) + theme_fourfold()
  from_layer <- function(...) {
    ggplot2::layer(
      geom = GeomFourfold, stat = StatFourfold, position = "identity", ...
    )
  }
  lines_of <- function(layer) {
    lapply(panel_displays(ucb + layer), function(x) x$diagonal)
  }
  # Without the parameters, it has the defaults of geom_fourfold().
  expect_identical(lines_of(from_layer()), lines_of(geom_fourfold()[[1]]))
  default <- lines_of(from_layer())
  expect_length(default, 6)
  expect_false(any(vapply(default, is.null, logical(1))))
  expect_identical(rgba(band_of(default[[1]])$gp$fill), rgba("white"))
  # With them, they apply.
  styled <- lines_of(from_layer(params = list(
    diagonal_fill = "orange", diagonal_width = 0.5, diagonal_length = 0.3
  )))
  expect_identical(rgba(band_of(styled[[1]])$gp$fill), rgba("orange"))
  expect_equal(
    band_geometry(band_of(styled[[1]]), 0.28 * mm)$across, (0.5 + 0.28) * mm
  )
  expect_identical(
    styled,
    lines_of(geom_fourfold(
      diagonal.fill = "orange", diagonal.width = 0.5, diagonal.length = 0.3
    )[[1]])
  )
  expect_false(identical(styled, default))
  # `diagonal = FALSE` omits it, as for geom_fourfold().
  none <- lines_of(from_layer(params = list(diagonal = FALSE)))
  expect_true(all(vapply(none, is.null, logical(1))))
  expect_identical(none, lines_of(geom_fourfold(diagonal = FALSE)[[1]]))
  # The length of the line depends on the shape given, as for geom_fourfold().
  for (shape in c("circle", "square")) {
    expect_identical(
      lines_of(from_layer(params = list(shape = shape))),
      lines_of(geom_fourfold(shape = shape)[[1]])
    )
  }
  expect_false(identical(
    lines_of(from_layer(params = list(shape = "square"))), default
  ))
  # The palette does not move the line's color.
  okabe <- lines_of(from_layer(params = list(palette = fourfold_palette("okabe-ito"))))
  expect_identical(rgba(band_of(okabe[[1]])$gp$fill), rgba("white"))
  # Calling draw_panel() through a layer with explicit NULLs is the default.
  expect_identical(
    lines_of(from_layer(params = list(
      diagonal_length = NULL, diagonal_width = NULL
    ))),
    default
  )
})

# Counts and the width of the diagonal line ----------------------------------------------

# The counts grob of a hand-built tree on a square null device, as in the
# circle clearance test: the labels' size is fixed by the device, not a layout.
with_counts_viewport <- function(code, size = 7) {
  grDevices::pdf(NULL, width = size, height = size)
  grid::pushViewport(grid::viewport(xscale = c(-1.3, 1.3), yscale = c(-1.3, 1.3)))
  on.exit({
    grid::popViewport()
    grDevices::dev.off()
  })
  code
}

draw_counts_tree <- function(label, shape, tick, lwd = NULL, reach = -Inf) {
  makeContent.fourfold_counts(grid::gTree(
    labels = rep(label, 4), measure_labels = label,
    reach = reach, tick_reach = tick, tick_lwd = lwd, shape = shape,
    counts = "auto", relative_size = 0.066, minimum_size = 10,
    colour = "black", family = "", name = "fourfold-counts",
    cl = "fourfold_counts"
  ))
}

# The first value in [lo, hi] at which `outside(value)` is TRUE, to within
# (hi - lo) / 2^steps, given that it is FALSE at lo and TRUE at hi and moves
# from one to the other once: a search that does not depend on any formula for
# the limit, so that the cases below do not depend on the device or fonts.
bisect_threshold <- function(outside, lo, hi, steps) {
  stopifnot(!outside(lo), outside(hi))
  for (step in seq_len(steps)) {
    middle <- (lo + hi) / 2
    if (outside(middle)) hi <- middle else lo <- middle
  }
  c(inside = lo, outside = hi)
}

test_that("auto counts account for the width of the diagonal line", {
  for (shape in c("circle", "square")) {
    with_counts_viewport({
      label <- "123456"
      # The tick endpoint at which the counts move outside.
      found <- bisect_threshold(function(tick) {
        draw_counts_tree(label, shape, tick, lwd = 0)$outside
      }, 0.3, 1.3, 14)
      threshold <- found[["outside"]]
      tick <- found[["inside"]]
      # A tick of 4 grid line widths extends 2 / 96 inch to either side; on
      # this 7 inch device, 2.6 native units wide, a corner of a flat end is
      # that over root two further along each axis.
      lwd <- 4
      extent <- lwd * (1 / 96) / 2 / 7 * 2.6 / sqrt(2)
      expect_gt(extent, 0.005)
      inside <- draw_counts_tree(label, shape, tick, lwd = 0)
      expect_false(inside$outside, info = shape)
      # The endpoint alone is inside; with the width it is past the limit.
      expect_identical(inside$tick_edge, tick)
      wide <- draw_counts_tree(label, shape, tick, lwd = lwd)
      expect_true(wide$outside, info = shape)
      expect_equal(wide$tick_edge, tick + extent, tolerance = 1e-8)
      expect_gt(wide$tick_edge, threshold)
      # Without a width, or the diagonal line, nothing changes.
      expect_false(draw_counts_tree(label, shape, tick, lwd = NULL)$outside)
      expect_false(draw_counts_tree(label, shape, tick)$outside)
      # Ticks that are not drawn have no extent, whatever the width.
      none <- draw_counts_tree(label, shape, -Inf, lwd = 50)
      expect_false(none$outside)
      expect_identical(none$tick_edge, -Inf)
      # A tick well inside the limit stays inside, however wide.
      expect_false(draw_counts_tree(label, shape, tick - 0.1, lwd = 4)$outside)
      # The extent doubles with the width.
      expect_equal(
        draw_counts_tree(label, shape, 0.5, lwd = 8)$tick_edge - 0.5, 2 * extent,
        tolerance = 1e-8
      )
    })
  }
})

test_that("the extent of the line is that of its flat end on the page", {
  grDevices::pdf(NULL, width = 7, height = 7)
  on.exit(grDevices::dev.off())
  # A viewport `width` by `height` inches whose native scales span the given
  # ranges, so that native units per inch can differ between the axes. The
  # tick runs at 45 degrees in native units, so its flat end is the segment
  # perpendicular to (1 / a, 1 / b) on the page, a and b being the native
  # units per inch, and its corners lie half a width from the endpoint: the
  # offset in native units is half * (a^2, b^2) / sqrt(a^2 + b^2) (half * a /
  # sqrt(2) when a = b); the larger of the two is used.
  edge <- function(xscale, yscale, width = 7, height = 7, lwd = 8) {
    grid::pushViewport(grid::viewport(
      width = grid::unit(width, "inches"), height = grid::unit(height, "inches"),
      xscale = xscale, yscale = yscale
    ))
    on.exit(grid::popViewport())
    draw_counts_tree("1", "square", 0.5, lwd = lwd)$tick_edge
  }
  exact <- function(xscale, yscale, width = 7, height = 7, lwd = 8) {
    a <- abs(diff(xscale)) / width
    b <- abs(diff(yscale)) / height
    0.5 + lwd / 96 / 2 * max(a, b)^2 / sqrt(a^2 + b^2)
  }
  scales <- list(
    square = list(c(-1.3, 1.3), c(-1.3, 1.3), 7, 7),
    wide = list(c(-1.3, 1.3), c(-1.3, 1.3), 7, 3.5),
    tall = list(c(-1.3, 1.3), c(-1.3, 1.3), 3.5, 7),
    four_to_one = list(c(-1.3, 1.3), c(-1.3, 1.3), 7, 1.75),
    different_ranges = list(c(-2.6, 2.6), c(-1.3, 1.3), 7, 7),
    both = list(c(-2.6, 2.6), c(-1.3, 1.3), 6, 2),
    reversed_x = list(c(1.3, -1.3), c(-1.3, 1.3), 7, 3.5),
    reversed_y = list(c(-1.3, 1.3), c(1.3, -1.3), 3.5, 7),
    reversed_both = list(c(1.3, -1.3), c(1.3, -1.3), 7, 3.5)
  )
  for (name in names(scales)) {
    case <- scales[[name]]
    expect_equal(
      do.call(edge, case), do.call(exact, case), tolerance = 1e-8, info = name
    )
    expect_equal(
      do.call(edge, c(case, lwd = 3)), do.call(exact, c(case, lwd = 3)),
      tolerance = 1e-8, info = name
    )
  }
  # For equal units it is half the width over root two, as before.
  expect_equal(
    edge(c(-1.3, 1.3), c(-1.3, 1.3)), 0.5 + 8 / 96 / 2 / 7 * 2.6 / sqrt(2),
    tolerance = 1e-8
  )
  # With units twice as long on y than on x the extent is not that of equal
  # units: the larger axis gets half * a^2 / sqrt(a^2 + b^2) with b = 2a.
  expect_equal(
    edge(c(-1.3, 1.3), c(-1.3, 1.3), 7, 3.5),
    0.5 + 8 / 96 / 2 * (2.6 / 3.5)^2 / sqrt((2.6 / 7)^2 + (2.6 / 3.5)^2),
    tolerance = 1e-8
  )
})

# A single square-sector panel at the given odds ratio (the row and column
# totals of a balanced table) on a 7 inch square device: the counts grob once
# placed.
placed_counts <- function(or, ...) {
  table <- .fourfold_table_with_or_and_margins(or, matrix(c(30, 20, 20, 30), 2))
  plot <- table_plot(table, shape = "square", conf_level = 0, ...) +
    theme_fourfold()
  grDevices::pdf(NULL, width = 7, height = 7)
  on.exit(grDevices::dev.off())
  grid::grid.newpage()
  grid::grid.draw(ggplot2::ggplotGrob(plot))
  grid::grid.force()
  grid::grid.get("fourfold-counts")
}

test_that("a drawn plot records the width of the line its counts account for", {
  tab <- matrix(c(40, 5, 8, 50), 2)
  cases <- list(
    default = list(), wide = list(diagonal.width = 3),
    none = list(diagonal = FALSE), plain = list(extended = FALSE),
    zero = list(diagonal.width = 0), hollow = list(diagonal.fill = NA)
  )
  # The whole line is the interior and a border on each side of it: the
  # layer's line width, 0.28 mm with theme_fourfold(), however it is filled.
  lwds <- c(
    default = (2.5 + 2) * 0.28, wide = 3 + 2 * 0.28, none = 0, plain = 0,
    zero = 2 * 0.28, hollow = (2.5 + 2) * 0.28
  ) * 72.27 / 25.4
  for (name in names(cases)) {
    counts <- drawn_plot(
      do.call(table_plot, c(list(tab, shape = "square"), cases[[name]])) +
        theme_fourfold(),
      counts = TRUE
    )$counts
    expect_equal(counts$tick_lwd, unname(lwds[name]), info = name)
    if (is.finite(counts$tick_reach) && counts$tick_lwd > 0) {
      expect_gt(counts$tick_edge, counts$tick_reach)
    } else {
      expect_identical(counts$tick_edge, counts$tick_reach)
    }
  }
})

test_that("the line's reach is its end's coordinate on each axis", {
  side <- sqrt(pi) / 2
  for (name in names(diagonal_tables)) {
    for (std in c("margins", "ind.max")) {
      shown <- table_diagonal(diagonal_tables[[name]], shape = "square", std = std)
      cells <- if (shown$or > 1) c(1, 4) else c(3, 2)
      # Past the outer corner by the stub on each axis, for the larger.
      expect_equal(
        counts_params(table_plot(
          matrix(diagonal_tables[[name]], 2), shape = "square", std = std
        ))$counts_tick_reach,
        max(shown$radius[cells]) * side + 0.02, info = paste(name, std)
      )
      shown <- table_diagonal(diagonal_tables[[name]], shape = "circle", std = std)
      # Circles: 0.15 past the arc along the diagonal.
      expect_equal(
        counts_params(table_plot(
          matrix(diagonal_tables[[name]], 2), shape = "circle", std = std
        ))$counts_tick_reach,
        (max(shown$radius[cells]) + 0.15) / sqrt(2), info = paste(name, std)
      )
    }
  }
  # An explicit length is along the diagonal for either shape.
  data <- ggplot2::layer_data(table_plot(matrix(c(30, 5, 8, 40), 2)))
  expect_equal(
    unname(.fourfold_counts_reach(data, "square", TRUE, 0.3)["tick"]),
    data$radius[1] * sqrt(pi) / 2 + 0.3 / sqrt(2)
  )
  expect_equal(
    unname(.fourfold_counts_reach(data, "circle", TRUE, 0.3)["tick"]),
    (data$radius[1] + 0.3) / sqrt(2)
  )
  # A line of no length ends at the sectors, and is still a reach.
  expect_equal(
    unname(.fourfold_counts_reach(data, "square", TRUE, 0)["tick"]),
    data$radius[1] * sqrt(pi) / 2
  )
  # No line, no reach: with `diagonal = FALSE` or `extended = FALSE`.
  expect_identical(
    unname(.fourfold_counts_reach(data, "square", FALSE, 0.3)["tick"]), -Inf
  )
  for (setting in list(list(diagonal = FALSE), list(extended = FALSE))) {
    expect_identical(
      counts_params(do.call(
        table_plot, c(list(matrix(c(30, 5, 8, 40), 2), shape = "square"), setting)
      ))$counts_tick_reach,
      -Inf
    )
  }
})

test_that("counts account for the whole bordered line, not its interior alone", {
  # The extent of the line's flat end beyond its end point is proportional to
  # the width of the whole line: its interior and a border on each side.
  # Hairlines give the end point itself.
  extent <- function(...) {
    counts <- drawn_plot(
      table_plot(matrix(c(40, 5, 8, 50), 2), shape = "square", ...) +
        theme_fourfold(),
      counts = TRUE
    )$counts
    counts$tick_edge - counts$tick_reach
  }
  none <- extent(linewidth = 0, diagonal.width = 0)
  expect_identical(none, 0)
  # theme_fourfold()'s 0.28 mm, in mm: 2 lines of border with no interior,
  # then 4.5 lines by default.
  borders_only <- extent(diagonal.width = 0)
  default <- extent()
  wide <- extent(diagonal.width = 2.5)
  expect_gt(borders_only, 0)
  expect_equal(default / borders_only, 4.5 / 2)
  expect_equal(wide / borders_only, (2.5 + 2 * 0.28) / (2 * 0.28))
  # A hollow line takes the same room.
  expect_equal(extent(diagonal.fill = NA), default)
  # The layer's line width counts, not only the interior's.
  expect_equal(
    extent(linewidth = 1, diagonal.width = 1) /
      extent(linewidth = 0, diagonal.width = 1),
    3
  )
})

# The odds ratio above which the counts of a square display placed by a
# hairline-wide line move outside, found by bisection on its logarithm, not
# assumed, so that the cases below do not depend on the text metrics. A
# hairline is a line with no interior and no border.
hairline <- list(linewidth = 0, diagonal.width = 0)

test_that("a wider line moves the counts of a plot outside where a hairline does not", {
  outside <- function(log_or) {
    do.call(placed_counts, c(list(exp(log_or)), hairline))$outside
  }
  found <- bisect_threshold(outside, 0.2, 2.5, 12)
  before <- exp(found[["inside"]])
  # Just before it, the hairline is inside and ends short of the limit.
  edge <- do.call(placed_counts, c(list(before), hairline))
  expect_false(edge$outside)
  expect_identical(edge$tick_lwd, 0)
  expect_lt(edge$tick_reach, edge$count_limit)
  expect_gt(edge$tick_reach, edge$count_limit - 0.02)
  # The same table with a wide interior (and borders of the layer's own width
  # outside it) is placed outside because of its width: the line's end point
  # is inside, its edge is not.
  wide <- placed_counts(before, linewidth = 0, diagonal.width = 2)
  expect_identical(wide$tick_reach, edge$tick_reach)
  expect_lt(wide$tick_reach, wide$count_limit)
  expect_gt(wide$tick_edge, wide$count_limit)
  expect_true(wide$outside)
  # And borders alone, of a wide layer line, do the same.
  bordered <- placed_counts(before, linewidth = 1, diagonal.width = 0)
  expect_gt(bordered$tick_edge, bordered$count_limit)
  expect_true(bordered$outside)
  # And a hair-thin one stays inside (the search leaves a gap of about 1e-5).
  narrow <- placed_counts(before, linewidth = 0, diagonal.width = 1e-4)
  expect_lt(narrow$tick_edge, narrow$count_limit)
  expect_false(narrow$outside)
  # The default line (interior 0.7 mm and borders of 0.28 mm with this theme)
  # is a line in between: its placement follows its edge.
  default <- placed_counts(before)
  expect_identical(default$outside, default$tick_edge > default$count_limit)
  expect_equal(default$tick_lwd, 4.5 * 0.28 * 72.27 / 25.4)
  # The statistics are the same whichever width.
  expect_identical(wide$labels, edge$labels)
})

test_that("squares keep the counts of typical standardized displays inside", {
  ucb <- ggplot2::ggplot(
    as.data.frame(UCBAdmissions), ggplot2::aes(Gender, Admit, weight = Freq)
  ) + ggplot2::facet_wrap(ggplot2::vars(Dept)) + theme_fourfold()
  placed <- function(shape, width, height, ...) {
    counts <- counts_printed(
      ucb + geom_fourfold(shape = shape, ...), width = width, height = height
    )
    expect_length(counts, 6)
    list(
      outside = vapply(counts, function(x) x$outside, logical(1)),
      # How far the line's outer edge is inside the limit for the counts.
      gap = min(vapply(counts, function(x) x$count_limit - x$tick_edge, numeric(1))),
      reach_gap = min(vapply(counts, function(x) x$count_limit - x$reach, numeric(1)))
    )
  }
  # std = "margins", the default: the stub past each square's corner leaves
  # room for the counts at ordinary sizes, by a gap that does not depend on
  # fine details (about 0.015 to 0.03 native, and so about 0.1 inch or more).
  for (size in list(c(7, 5), c(9, 6), c(12, 8))) {
    shown <- placed("square", size[1], size[2])
    expect_false(any(shown$outside), info = toString(size))
    expect_gt(shown$gap, 0.01)
    expect_gt(shown$reach_gap, 0.01)
  }
  # Circles are not affected: inside at these sizes, as they were.
  for (size in list(c(7, 5), c(9, 6), c(12, 8))) {
    expect_false(any(placed("circle", size[1], size[2])$outside), info = toString(size))
  }
  # At a small size the counts move outside, which `auto` is for; the squares
  # and the circles both, by a wide margin.
  small <- placed("square", 4, 3)
  expect_true(all(small$outside))
  expect_lt(small$gap, -0.05)
  expect_true(all(placed("circle", 4, 3)$outside))
  # A longer line reaches the counts again.
  expect_true(all(placed("square", 9, 6, diagonal.length = 0.15)$outside))
  # Without a line, or with the line omitted, what places the counts is the
  # sectors and rings alone.
  expect_identical(
    placed("square", 9, 6, diagonal = FALSE)$outside,
    placed("square", 9, 6, extended = FALSE)$outside
  )
})

test_that("circles place their counts as with the ticks they replace", {
  # The line ends where the ticks ended, so the circle's end point is the
  # tick's, as is its reach: only the width of what is drawn there differs.
  ucb <- ggplot2::layer_data(ucb_plot(ggplot2::facet_wrap(ggplot2::vars(Dept))))
  expect_length(unique(ucb$PANEL), 6)
  for (panel in 1:6) {
    rows <- ucb[ucb$PANEL == panel, ]
    expect_equal(
      unname(.fourfold_counts_reach(rows, "circle", TRUE, 0.15)["tick"]),
      max(rows$radius[if (rows$odds_ratio[1] > 1) c(1, 4) else c(3, 2)]) /
        sqrt(2) + 0.15 / sqrt(2)
    )
  }
  # The default length of a circle's line is that of the ticks, 0.15.
  expect_identical(
    unname(.fourfold_counts_reach(ucb, "circle", TRUE)["tick"]),
    unname(.fourfold_counts_reach(ucb, "circle", TRUE, 0.15)["tick"])
  )
})

# Argument and data checks ------------------------------------------------------

test_that("extended must be TRUE or FALSE", {
  for (bad in list("yes", "TRUE", 1, 0L, NA, NA_character_, c(TRUE, FALSE),
                   logical(), NULL, list(TRUE))) {
    expect_error(
      geom_fourfold(extended = bad), "extended must be TRUE or FALSE",
      info = deparse(bad)
    )
  }
  expect_silent(geom_fourfold(extended = TRUE))
  expect_silent(geom_fourfold(extended = FALSE))
  expect_false(any(grepl(
    "diagonal", panel_grob_names(ucb_layer(extended = FALSE)),
    fixed = TRUE
  )))
})

test_that("margin must be 1, 2, or both", {
  for (bad in list("1", "2", c("1", "2"), TRUE, NA, NA_real_, c(1, 1), 1.5, 0,
                   3, c(1, 2, 1), numeric(), NULL, list(1))) {
    expect_error(
      geom_fourfold(margin = bad), "incorrect margin specification",
      info = deparse(bad)
    )
  }
  for (good in list(1, 2, 1L, c(1, 2), c(2, 1), 1:2)) {
    expect_silent(geom_fourfold(margin = good))
  }
  # Only used with std = "margins".
  expect_silent(geom_fourfold(std = "ind.max", margin = "1"))
  expect_identical(
    ggplot2::layer_data(ucb_layer(margin = 1L)),
    ggplot2::layer_data(ucb_layer(margin = 1))
  )
})

test_that("weights must be numeric", {
  ucb <- as.data.frame(UCBAdmissions)
  weighted <- function(weight) {
    ucb$weight <- weight
    ggplot2::ggplot(ucb, ggplot2::aes(Gender, Admit, weight = weight)) +
      geom_fourfold()
  }
  for (bad in list(as.character(ucb$Freq), factor(ucb$Freq), ucb$Freq > 0,
                   ucb$Freq > 0 & FALSE)) {
    expect_error(
      ggplot2::layer_data(weighted(bad)),
      "fourfold weights in panel 1 must be numeric", info = class(bad)
    )
    expect_error(
      ggplot2::layer_data(weighted(bad) + ggplot2::facet_wrap(ggplot2::vars(Dept))),
      "fourfold weights in panel 1 must be numeric", info = class(bad)
    )
  }
  # Integer and double weights are the same, and a weight that is entirely
  # missing counts as missing, whatever its type.
  # (Only the flag for the count labels differs: see the count labels below.)
  expect_identical(
    subset(ggplot2::layer_data(weighted(as.integer(ucb$Freq))), select = -integer_count),
    subset(ggplot2::layer_data(weighted(ucb$Freq)), select = -integer_count)
  )
  expect_warning(
    built <- ggplot2::layer_data(weighted(NA)), "missing weight"
  )
  expect_identical(nrow(built), 0L)
  # Numeric weights that are invalid keep their message.
  expect_error(
    ggplot2::layer_data(weighted(-ucb$Freq)),
    "fourfold weights in panel 1 must be finite and non-negative"
  )
})

test_that("a missing x or y aesthetic is an error naming it", {
  ucb <- as.data.frame(UCBAdmissions)
  missing_message <- "geom_fourfold\\(\\) requires the `x` and `y` aesthetics; missing: "
  expect_error(
    ggplot2::layer_data(ggplot2::ggplot(ucb, ggplot2::aes(y = Admit, weight = Freq)) +
                          geom_fourfold()),
    paste0(missing_message, "`x`$")
  )
  expect_error(
    ggplot2::layer_data(ggplot2::ggplot(ucb, ggplot2::aes(x = Gender, weight = Freq)) +
                          geom_fourfold()),
    paste0(missing_message, "`y`$")
  )
  expect_error(
    ggplot2::layer_data(ggplot2::ggplot(ucb, ggplot2::aes(weight = Freq)) +
                          geom_fourfold()),
    paste0(missing_message, "`x` and `y`$")
  )
  expect_error(
    ggplot2::layer_data(ggplot2::ggplot(ucb) + geom_fourfold()),
    paste0(missing_message, "`x` and `y`$")
  )
  expect_error(
    ggplot2::layer_data(
      ggplot2::ggplot(ucb, ggplot2::aes(Gender, Admit, weight = Freq)) +
        geom_fourfold(inherit.aes = FALSE)
    ),
    paste0(missing_message, "`x` and `y`$")
  )
  # An aesthetic given in the layer is enough, and the direct use of the
  # stat checks too.
  expect_identical(
    ggplot2::layer_data(
      ggplot2::ggplot(ucb, ggplot2::aes(y = Admit, weight = Freq)) +
        geom_fourfold(ggplot2::aes(x = Gender))
    ),
    ggplot2::layer_data(ucb_plot())
  )
  expect_error(
    ggplot2::layer_data(
      ggplot2::ggplot(ucb, ggplot2::aes(x = Gender, weight = Freq)) +
        ggplot2::layer(
          geom = GeomFourfold, stat = StatFourfold, position = "identity",
          params = list()
        )
    ),
    paste0(missing_message, "`y`$")
  )
})

test_that("a layer without rows is drawn blank, with or without aesthetics", {
  ucb <- as.data.frame(UCBAdmissions)
  for (plot in list(
    ggplot2::ggplot(ucb[0, ], ggplot2::aes(Gender, Admit, weight = Freq)) +
      geom_fourfold(),
    ggplot2::ggplot(ucb[0, ]) + geom_fourfold(),
    ggplot2::ggplot(ucb[0, ], ggplot2::aes(y = Admit)) + geom_fourfold()
  )) {
    expect_identical(nrow(ggplot2::layer_data(plot)), 0L)
    expect_false(any(grepl("fourfold-frame", panel_grob_names(plot))))
  }
})

# Count labels --------------------------------------------------------------------

test_that("whole-number counts are labeled as vcd labels them, others rounded", {
  format_count <- .fourfold_format_count
  # Whole numbers by as.character(), as vcd::fourfold() does: scientific
  # notation for large round doubles, no rounding.
  expect_identical(
    format_count(c(0, -0, 7, 512, 1e5, 123456, 1234567, 2147483647, 1e15, 1e22)),
    c("0", "0", "7", "512", "1e+05", "123456", "1234567", "2147483647",
      "1e+15", "1e+22")
  )
  whole <- c(0, -0, 1, 512, 1e5, 99999, 1e6, 1234567, 2147483647, 1e15, 3e22)
  expect_identical(format_count(whole), as.character(whole))
  # An integer 100000L is "100000", as in as.character() (the counts of a
  # layer are doubles, so they never are integers).
  expect_identical(format_count(c(1L, 100000L)), c("1", "100000"))
  # Other weights to three significant digits (or a whole number when that is
  # larger), without trailing zeros and never in scientific notation, each on
  # its own (so a label is never padded to match another).
  expect_identical(
    format_count(c(10 / 3, 0.5, 2.50, 123456.789, 0.000333, 2 / 3 * 1e-5, 2.9999)),
    c("3.33", "0.5", "2.5", "123457", "0.000333", "0.00000667", "3")
  )
  expect_identical(format_count(c(1, 0.5)), c("1", "0.5"))
  expect_identical(format_count(numeric()), character())
  # Even denormal numbers, for which format() ignores `scientific`.
  expect_identical(
    format_count(4.94e-324),
    paste0("0.", strrep("0", 323), "494")
  )
  expect_false(any(grepl("e", format_count(c(1e-7, 123456789012.5, 12345.6)))))
})

# The count labels of the first panel: those drawn and those measured.
count_labels <- function(plot) {
  gtable <- drawn_gtable(plot)
  panels <- gtable$grobs[grepl("^panel", gtable$layout$name)]
  panels <- panels[!vapply(panels, inherits, logical(1), "zeroGrob")]
  lapply(panels, function(panel) {
    counts <- grid::getGrob(panel, "fourfold-counts", grep = TRUE)
    if (is.null(counts)) NULL else list(
      drawn = counts$labels, measured = counts$measure_labels
    )
  })
}

test_that("drawn and measured count labels agree and are formatted", {
  cases <- list(
    list(c(100000, 512, 0, 1234567), c("1e+05", "512", "0", "1234567")),
    list(c(10 / 3, 0.5, 2.50, 123456.789), c("3.33", "0.5", "2.5", "123457")),
    list(c(0.000333, 1e15, 2147483647, 7), c("0", "1e+15", "2147483647", "7")),
    list(c(0.000333, 1, 21, 7), c("0.000333", "1", "21", "7"))
  )
  for (case in cases) {
    labels <- count_labels(table_plot(matrix(case[[1]], 2)))[[1]]
    expect_identical(labels$drawn, case[[2]])
    expect_setequal(labels$measured, case[[2]])
    expect_identical(
      cells(table_plot(matrix(case[[1]], 2)))$count, case[[1]]
    )
  }
  # Every panel measures the labels of the whole layer, and blank panels none.
  ucb <- as.data.frame(UCBAdmissions)
  # No product is a tie at the rounding, whatever the platform.
  ucb$Freq[ucb$Dept == "B"] <- ucb$Freq[ucb$Dept == "B"] * 1000.123
  ucb$Dept <- as.character(ucb$Dept)
  ucb <- rbind(ucb, transform(ucb[ucb$Dept == "A", ], Dept = "G", Freq = 0))
  labels <- count_labels(
    ggplot2::ggplot(ucb, ggplot2::aes(Gender, Admit, weight = Freq)) +
      geom_fourfold() + ggplot2::facet_wrap(ggplot2::vars(Dept))
  )
  expect_length(labels, 7)
  measured <- labels[[1]]$measured
  expect_true(all(vapply(labels, function(x) identical(x$measured, measured), TRUE)))
  drawn <- lapply(labels, `[[`, "drawn")
  blank <- vapply(drawn, function(x) all(x == "0"), logical(1))
  expect_identical(sum(blank), 1L)
  expect_setequal(measured, unique(unlist(drawn[!blank])))
  expect_false("0" %in% measured)
  expect_true("353043" %in% measured)
  expect_false(any(grepl("e", unlist(drawn))))
  # No counts, no labels.
  expect_identical(
    count_labels(ucb_layer(counts = "none"))[[1]], NULL
  )
})

test_that("rounding noise next to real counts does not make long labels", {
  count_labels_of <- .fourfold_count_labels
  expect_identical(
    count_labels_of(c(0.1 + 0.2 - 0.3, 10, 20, 30)), c("0", "10", "20", "30")
  )
  expect_identical(count_labels_of(c(1e-300, 5, 7, 0)), c("0", "5", "7", "0"))
  expect_identical(count_labels_of(c(5e-324, 1e-300, 1, 1)), c("0", "0", "1", "1"))
  # A panel of small counts keeps them, and a blank panel is all zeros.
  expect_identical(
    count_labels_of(c(1e-7, 2e-7, 3e-7, 0)),
    c("0.0000001", "0.0000002", "0.0000003", "0")
  )
  expect_identical(count_labels_of(rep(0, 4)), rep("0", 4))
  expect_false(any(grepl("e", count_labels_of(c(4.94e-324, 9.88e-324, 0, 1.5e-323)))))
  # Drawn and measured labels agree, per panel, in a faceted layer: the noise
  # of one panel is not zapped by the large counts of another, nor the reverse.
  data <- data.frame(
    g = rep(c("p", "q", "r"), each = 4),
    x = factor(rep(c("a", "a", "b", "b"), 3)),
    y = factor(rep(c("u", "v", "u", "v"), 3)),
    w = c(0.1 + 0.2 - 0.3, 10, 20, 30, 1e-7, 2e-7, 3e-7, 4e-7, 5e5, 6, 7, 8)
  )
  labels <- count_labels(
    ggplot2::ggplot(data, ggplot2::aes(x, y, weight = w)) + geom_fourfold() +
      ggplot2::facet_wrap(ggplot2::vars(g))
  )
  drawn <- lapply(labels, `[[`, "drawn")
  expect_length(drawn, 3)
  expect_true(any(vapply(drawn, identical, TRUE, c("0", "10", "20", "30"))))
  expect_true(any(vapply(
    drawn, identical, TRUE, c("0.0000001", "0.0000002", "0.0000003", "0.0000004")
  )))
  expect_true(any(vapply(drawn, identical, TRUE, c("5e+05", "6", "7", "8"))))
  for (shown in labels) {
    expect_setequal(shown$measured, unique(unlist(drawn)))
  }
  # With one panel of noise only, nothing is moved outside by a long label.
  noisy <- count_labels(table_plot(c(0.1 + 0.2 - 0.3, 10, 20, 30)))[[1]]
  expect_identical(noisy$drawn, c("0", "10", "20", "30"))
  expect_identical(noisy$measured, unique(noisy$drawn))
})

test_that("only rounding noise is shown as 0; genuine weights keep their labels", {
  count_labels_of <- .fourfold_count_labels
  # Weights next to a large count are not zapped, nor rounded to a whole number
  # by the zapping.
  expect_identical(count_labels_of(c(1e7, 99999.5, 1, 2)), c("1e+07", "100000", "1", "2"))
  expect_identical(count_labels_of(c(5e6, 2.5, 3.5, 1)), c("5e+06", "2.5", "3.5", "1"))
  expect_identical(count_labels_of(c(1e8, 0.4, 3.7, 5)), c("1e+08", "0.4", "3.7", "5"))
  expect_identical(count_labels_of(c(1e7, 0.5, 1, 1)), c("1e+07", "0.5", "1", "1"))
  # Genuine weights down to about 1e-15 of the panel's largest keep their
  # labels; below that, they are lost in floating-point arithmetic anyway.
  expect_identical(count_labels_of(c(1e3, 1e-12, 1, 1)), c("1000", "0.000000000001", "1", "1"))
  expect_identical(count_labels_of(c(1e3, 1e-13, 1, 1)), c("1000", "0", "1", "1"))
  expect_identical(count_labels_of(c(1e6, 10 / 3, 1, 1)), c("1e+06", "3.33", "1", "1"))
  # Noise still becomes 0, and zero stays 0.
  expect_identical(count_labels_of(c(0.1 + 0.2 - 0.3, 10, 20, 30)), c("0", "10", "20", "30"))
  expect_identical(count_labels_of(c(1e-20, 0, 1e6, 3)), c("0", "0", "1e+06", "3"))
  expect_identical(count_labels_of(c(1e-300, 5, 7, 0)), c("0", "5", "7", "0"))
  expect_identical(count_labels_of(c(5e-324, 1e-300, 1, 1)), c("0", "0", "1", "1"))
  expect_identical(count_labels_of(c(1e7 * 1e-16, 1e7, 3, 4)), c("0", "1e+07", "3", "4"))
  # The labels do not depend on options("digits").
  for (digits in c(1, 22)) {
    old <- options(digits = digits)
    expect_identical(count_labels_of(c(5e6, 2.5, 3.5, 1)), c("5e+06", "2.5", "3.5", "1"))
    expect_identical(count_labels_of(c(0.1 + 0.2 - 0.3, 10, 20, 30)), c("0", "10", "20", "30"))
    expect_identical(count_labels_of(c(10 / 3, 0.001, 0, 1)), c("3.33", "0.001", "0", "1"))
    options(old)
  }
  # In a drawn plot, too.
  labels <- count_labels(table_plot(c(5e6, 2.5, 3.5, 1)))[[1]]
  expect_identical(labels$drawn, c("5e+06", "2.5", "3.5", "1"))
  expect_identical(labels$measured, labels$drawn)
})

test_that("the mapping error names the arguments in backticks", {
  expect_error(
    geom_fourfold(ggplot2::aes(colour = x)),
    "set `colour`, `linewidth`, and `alpha` as fixed arguments",
    fixed = TRUE
  )
})

test_that("counts of integer weights or of rows are labeled as vcd labels an integer table", {
  labels_of <- function(plot) count_labels(plot)[[1]]
  pool <- c(1e5, 512, 0, 2e6)
  # Double weights: as.character() of a whole number.
  double <- labels_of(table_plot(pool))
  expect_identical(double$drawn, c("1e+05", "512", "0", "2e+06"))
  expect_identical(double$measured, double$drawn)
  # Integer weights: as an integer table, in full.
  integer <- labels_of(table_plot(as.integer(pool)))
  expect_identical(integer$drawn, c("100000", "512", "0", "2000000"))
  expect_identical(integer$measured, integer$drawn)
  # The statistics are the same whatever the type, and are doubles.
  same <- function(a, b) {
    identical(
      subset(ggplot2::layer_data(a), select = -integer_count),
      subset(ggplot2::layer_data(b), select = -integer_count)
    )
  }
  expect_true(same(table_plot(pool), table_plot(as.integer(pool))))
  expect_type(ggplot2::layer_data(table_plot(as.integer(pool)))$count, "double")
  expect_identical(unique(ggplot2::layer_data(table_plot(as.integer(pool)))$integer_count), TRUE)
  expect_identical(unique(ggplot2::layer_data(table_plot(pool))$integer_count), FALSE)
  # A count that does not fit in an integer is labeled as a double (vcd would
  # overflow), and the sum of integer weights is not integer-typed.
  big <- labels_of(table_plot(c(2147483647L, 2147483647L, 1L, 5L)))
  expect_identical(big$drawn, c("2147483647", "2147483647", "1", "5"))
  summed <- data.frame(
    x = factor(c("a", "a", "a", "b", "b")), y = factor(c("u", "u", "v", "u", "v")),
    w = c(2147483647L, 2147483647L, 5L, 1L, 7L)
  )
  summed <- labels_of(ggplot2::ggplot(summed, ggplot2::aes(x, y, weight = w)) + geom_fourfold())
  expect_identical(summed$drawn, c("4294967294", "5", "1", "7"))
  # Unweighted rows are counted as integers.
  rows <- data.frame(
    x = factor(rep(c("a", "a", "b", "b"), c(100000, 512, 0, 20)), levels = c("a", "b")),
    y = factor(rep(c("u", "v", "u", "v"), c(100000, 512, 0, 20)), levels = c("u", "v"))
  )
  counted <- labels_of(ggplot2::ggplot(rows, ggplot2::aes(x, y)) + geom_fourfold())
  expect_identical(counted$drawn, c("100000", "512", "0", "20"))
  expect_identical(counted$measured, counted$drawn)
  # Integer weights with a double weight in another layer of the same plot: each
  # layer follows its own weights.
  two <- data.frame(
    x = factor(c("a", "a", "b", "b")), y = factor(c("u", "v", "u", "v")),
    wi = as.integer(pool), wd = pool
  )
  plot <- ggplot2::ggplot(two, ggplot2::aes(x, y)) +
    geom_fourfold(ggplot2::aes(weight = wi)) +
    geom_fourfold(ggplot2::aes(weight = wd))
  gtable <- drawn_gtable(plot)
  panel <- gtable$grobs[[which(gtable$layout$name == "panel")]]
  counts <- grid::getGrob(panel, "fourfold-counts", grep = TRUE, global = TRUE)
  expect_length(counts, 2)
  expect_setequal(vapply(counts, function(x) x$labels[1], ""), c("100000", "1e+05"))
  # Faceted: a blank panel and a panel left empty by a missing weight.
  faceted <- data.frame(
    g = rep(c("p", "q", "r"), each = 4),
    x = factor(rep(c("a", "a", "b", "b"), 3)), y = factor(rep(c("u", "v", "u", "v"), 3)),
    w = c(100000L, 512L, 3L, 4L, 0L, 0L, 0L, 0L, 200000L, NA, 5L, 6L)
  )
  expect_warning(
    labels <- count_labels(
      ggplot2::ggplot(faceted, ggplot2::aes(x, y, weight = w)) + geom_fourfold() +
        ggplot2::facet_wrap(ggplot2::vars(g))
    ),
    "missing weight"
  )
  # The panel left empty has no counts.
  labels <- Filter(Negate(is.null), labels)
  drawn <- lapply(labels, `[[`, "drawn")
  expect_length(drawn, 2)
  expect_true(any(vapply(drawn, identical, TRUE, c("100000", "512", "3", "4"))))
  expect_true(any(vapply(drawn, identical, TRUE, rep("0", 4))))
  expect_setequal(labels[[1]]$measured, c("100000", "512", "3", "4"))
  # Rounding and noise are as for doubles; integer weights only change whole
  # numbers.
  expect_identical(.fourfold_count_labels(c(1e5, 0, 7, 12), integer = TRUE), c("100000", "0", "7", "12"))
  # An integer vector stays integer unless a count is noise, so it is labeled as
  # vcd labels it even without the flag.
  expect_identical(.fourfold_count_labels(c(100000L, 2L, 3L, 4L)), c("100000", "2", "3", "4"))
  expect_identical(.fourfold_count_labels(100000L), .fourfold_format_count(100000L))
  # Whole numbers are never zapped.
  expect_identical(.fourfold_count_labels(c(1e18, 1, 2, 3)), c("1e+18", "1", "2", "3"))
  expect_identical(.fourfold_count_labels(c(1e5, 0, 7, 12), integer = FALSE), c("1e+05", "0", "7", "12"))
  expect_identical(.fourfold_count_labels(c(10 / 3, 2.5, 1, 0), integer = TRUE), c("3.33", "2.5", "1", "0"))
  # Direct use of the geom and the stat with layer(): the stat gives the flag,
  # and without it (another stat, or draw_panel() alone) counts are doubles.
  direct <- function(weight) {
    ggplot2::ggplot(two, ggplot2::aes(x, y, weight = .data[[weight]])) +
      ggplot2::layer(
        geom = GeomFourfold, stat = StatFourfold, position = "identity",
        params = list(), show.legend = FALSE
      )
  }
  expect_identical(labels_of(direct("wi"))$drawn[1], "100000")
  expect_identical(labels_of(direct("wd"))$drawn[1], "1e+05")
  built <- ggplot2::layer_data(direct("wi"))
  no_flag <- built[names(built) != "integer_count"]
  expect_identical(.fourfold_counts_params(no_flag, "circle", TRUE, 0.15)$counts_labels[1], "1e+05")
  expect_identical(.fourfold_counts_params(built, "circle", TRUE, 0.15)$counts_labels[1], "100000")
})
