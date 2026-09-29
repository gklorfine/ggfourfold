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
