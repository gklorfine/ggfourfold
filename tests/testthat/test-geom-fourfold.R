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
