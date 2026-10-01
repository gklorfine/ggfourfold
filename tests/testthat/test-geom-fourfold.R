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
    expect_false(any(grepl("sector|conf|direction", drawn)))
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
    geom_fourfold(ggplot2::aes(x, y, weight = w)), "LayerInstance"
  )
  expect_s3_class(geom_fourfold(ggplot2::aes(colour = NULL)), "LayerInstance")
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
  expect_identical(frame$gp$col, scales::alpha("red", 0.5))
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
      sprintf("^Removed 1 row containing missing fourfold values in panel %d\\.$",
              panel)
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
    "Removed 4 rows containing missing fourfold values in panel 3, leaving it empty."
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
