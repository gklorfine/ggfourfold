# Baseline/current statistics and isolated-render verification for counts changes.
# Rscript dev/counts-verification.R stats PACKAGE_ROOT OUTPUT.rds
# Rscript dev/counts-verification.R manifest OUTPUT.rds
# Rscript dev/counts-verification.R render PACKAGE_ROOT MANIFEST.rds ID OUTPUT_DIR [strip]
# Rscript dev/counts-verification.R compare BASE.rds CURRENT.rds OUTPUT.txt
# Each render invocation writes exactly one image, avoiding device-size state drift.
args <- commandArgs(trailingOnly = TRUE)
mode <- args[1]

settings <- list(
  margins_both = list(std = "margins", margin = c(1, 2)),
  margins_rows = list(std = "margins", margin = 1),
  margins_cols = list(std = "margins", margin = 2),
  ind_max = list(std = "ind.max", margin = c(1, 2)),
  all_max = list(std = "all.max", margin = c(1, 2)),
  ind_rows = list(std = "ind.max", margin = 1),
  ind_cols = list(std = "ind.max", margin = 2),
  all_rows = list(std = "all.max", margin = 1),
  all_cols = list(std = "all.max", margin = 2)
)
inferences <- list(default = list(), no_conf = list(conf_level = 0),
  nonextended = list(extended = FALSE),
  alternatives = list(conf_level = 0.8, p_adjust_method = "bonferroni", ticks = 0))

make_plot <- function(dataset, params = list(), orientation = NULL, base_size = 12) {
  ucb <- as.data.frame(UCBAdmissions)
  names(ucb)[1:2] <- c("y", "x")
  tiny <- data.frame(x = factor(c("a", "a", "b", "b"), c("a", "b")),
    y = factor(c("u", "v", "u", "v"), c("u", "v")), Freq = c(2, 5, 5, 2))
  facet <- NULL
  if (dataset == "ucb") {
    dat <- ucb
    facet <- ggplot2::facet_wrap(ggplot2::vars(Dept), ncol = 3)
  } else if (dataset %in% c("titanic", "titanic_margins")) {
    dat <- as.data.frame(Titanic)
    names(dat)[c(2, 4)] <- c("x", "y")
    facet <- ggplot2::facet_grid(Age ~ Class, margins = dataset == "titanic_margins")
  } else if (dataset == "bug") {
    dat <- tiny
  } else if (dataset == "strong") {
    dat <- tiny
    dat$Freq <- c(90, 5, 8, 95)
  } else if (dataset == "zero") {
    dat <- tiny
    dat$Freq <- c(0, 5, 10, 20)
  } else if (dataset == "blank") {
    dat <- tiny
    dat$Freq <- 0
  } else if (dataset == "mixed_blank") {
    blank <- transform(ucb[ucb$Dept == "A", ], Dept = "G", Freq = 0)
    dat <- rbind(ucb, blank)
    facet <- ggplot2::facet_wrap(ggplot2::vars(Dept), ncol = 3)
  } else if (dataset == "empty") {
    dat <- ucb[ucb$Dept != "A", ]
    facet <- ggplot2::facet_wrap(ggplot2::vars(Dept), ncol = 3, drop = FALSE)
  } else if (dataset == "missing_x") {
    dat <- ucb
    dat$x[1] <- NA
    facet <- ggplot2::facet_wrap(ggplot2::vars(Dept), ncol = 3)
  } else if (dataset == "missing_weight") {
    dat <- ucb
    dat$Freq[1] <- NA
    facet <- ggplot2::facet_wrap(ggplot2::vars(Dept), ncol = 3)
  } else stop("Unknown dataset: ", dataset)
  p <- ggplot2::ggplot(dat, ggplot2::aes(x, y, weight = Freq)) +
    do.call(geom_fourfold, params) + facet + theme_fourfold(base_size = base_size)
  if (!is.null(orientation)) p <- p + ggplot2::coord_cartesian(reverse = orientation, ratio = 1)
  p
}

if (mode == "manifest") {
  cases <- list()
  add <- function(id, dataset, params = list(), width = 1000, height = 700,
                  orientation = NULL, group = "auto", base_size = 12) {
    cases[[id]] <<- list(id = id, dataset = dataset, params = params,
      width = width, height = height, orientation = orientation, group = group,
      base_size = base_size)
  }
  for (dataset in c("ucb", "titanic", "titanic_margins"))
    for (shape in c("circle", "square"))
      for (setting in names(settings)[1:5])
        add(paste(dataset, shape, setting, sep = "-"), dataset,
          c(settings[[setting]], list(shape = shape)))
  for (dataset in c("bug", "strong", "zero", "blank", "mixed_blank", "empty", "missing_x", "missing_weight"))
    for (shape in c("circle", "square"))
      add(paste(dataset, shape, sep = "-"), dataset, list(shape = shape, ticks = 0))
  for (shape in c("circle", "square")) {
    add(paste0("ucb-", shape, "-no_conf"), "ucb", list(shape = shape, conf_level = 0))
    add(paste0("ucb-", shape, "-nonextended"), "ucb", list(shape = shape, extended = FALSE))
    add(paste0("ucb-", shape, "-small"), "ucb", list(shape = shape, ticks = 0), 500, 350)
    for (counts in c("inside", "outside", "none"))
      for (orientation in c("none", "x", "y", "xy"))
        add(paste(shape, counts, orientation, sep = "-"), "bug",
          list(shape = shape, ticks = 0, counts = counts), 600, 600,
          orientation, "explicit")
  }
  saveRDS(cases, args[2])
  cat(length(cases), "cases:", sum(vapply(cases, function(x) x$group == "auto", logical(1))), "auto;",
    sum(vapply(cases, function(x) x$group == "explicit", logical(1))), "explicit\n")
  quit(save = "no")
}

if (mode == "compare") {
  baseline <- readRDS(args[2]); current <- readRDS(args[3])
  # Layer-wide count values that earlier versions kept as layer-data columns
  # (b8b9149: counts_reach); they are now parameters from setup_params().
  metadata <- c("counts_reach", "counts_tick_reach", "counts_labels")
  failures <- character()
  for (id in names(baseline)) {
    b <- baseline[[id]]; n <- current[[id]]
    b$data <- b$data[setdiff(names(b$data), metadata)]
    n$data <- n$data[setdiff(names(n$data), metadata)]
    # Baselines made before the removed-rows warning was reworded use the old text.
    b$warnings <- sub(
      "^(Removed [0-9]+ rows?) containing missing fourfold values in panel ",
      "\\1 containing missing values or values outside the scale range in fourfold panel ",
      b$warnings
    )
    if (!identical(b, n)) failures <- c(failures, id)
  }
  report <- c(paste(length(baseline), "statistical cases compared; all columns except", paste(metadata, collapse = ", ")),
    paste("Failures:", length(failures)), failures)
  writeLines(report, args[4]); cat(paste(report, collapse = "\n"), "\n")
  if (length(failures)) stop("Statistical mismatch")
  quit(save = "no")
}

pkgload::load_all(args[2], quiet = TRUE)
if (mode == "stats") {
  result <- list()
  datasets <- c("ucb", "titanic", "titanic_margins", "bug", "zero", "blank", "mixed_blank", "empty", "missing_x", "missing_weight")
  for (dataset in datasets) for (shape in c("circle", "square"))
    for (setting in names(settings)) for (inference in names(inferences)) {
      id <- paste(dataset, shape, setting, inference, sep = "-")
      warnings <- character()
      params <- c(settings[[setting]], inferences[[inference]], list(shape = shape))
      data <- withCallingHandlers(ggplot2::ggplot_build(make_plot(dataset, params))$data[[1]],
        warning = function(w) { warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning") })
      # Square side is sqrt(pi)/2, hence its sector area equals a quarter circle.
      circle_area <- pi * data$radius^2 / 4
      square_area <- (.fourfold_square_side * data$radius)^2
      stopifnot(isTRUE(all.equal(circle_area, square_area, tolerance = 1e-15)))
      result[[id]] <- list(data = data, warnings = warnings, area = circle_area)
    }
  # Every counts choice must leave the whole layer data unchanged.
  if ("counts" %in% names(formals(geom_fourfold))) {
    for (dataset in datasets) for (shape in c("circle", "square")) {
      built <- lapply(c("auto", "inside", "outside", "none"), function(counts)
        suppressWarnings(ggplot2::ggplot_build(make_plot(dataset, list(shape = shape, counts = counts)))$data[[1]]))
      stopifnot(all(vapply(built[-1], identical, logical(1), built[[1]])))
    }
  }
  saveRDS(result, args[3]); cat(length(result), "statistical cases and numeric area checks passed\n")
} else if (mode == "render") {
  cases <- readRDS(args[3]); case <- cases[[args[4]]]
  out <- args[5]; strip <- length(args) > 5 && args[6] == "strip"
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  if (!"counts" %in% names(formals(geom_fourfold))) case$params$counts <- NULL
  p <- make_plot(case$dataset, case$params, case$orientation, case$base_size)
  remove_counts <- function(g) {
    if (inherits(g, "fourfold_counts")) return(grid::nullGrob(name = g$name))
    if (!is.null(g$children)) g$children <- do.call(grid::gList, lapply(g$children, remove_counts))
    if (!is.null(g$grobs)) g$grobs <- lapply(g$grobs, remove_counts)
    g
  }
  grDevices::png(file.path(out, paste0(case$id, if (strip) "-stripped" else "", ".png")),
    width = case$width, height = case$height, res = 144, bg = "white")
  # Record the real (unenlarged) count-box boundary alongside the automatic
  # clearance boundary, without changing any drawing behavior.
  original_counts <- getS3method("makeContent", "fourfold_counts", envir = asNamespace("grid"))
  measure_counts <- function(x) {
    drawn <- original_counts(x)
    labels <- if (length(x$measure_labels)) x$measure_labels else x$labels
    gp <- drawn$children[[1]]$gp
    inner <- vapply(labels, function(label) {
      text <- grid::textGrob(label, gp = gp)
      pmax(0, 0.88 - c(
        abs(grid::convertWidth(grid::grobWidth(text), "native", valueOnly = TRUE)),
        abs(grid::convertHeight(grid::grobHeight(text), "native", valueOnly = TRUE))))
    }, numeric(2))
    drawn$actual_outline_limit <- if (case$params$shape == "circle")
      min(sqrt(colSums(inner^2))) else min(inner[2, ])
    drawn$actual_tick_limit <- if (case$params$shape == "circle")
      min(apply(inner, 2, max)) else min(inner[2, ])
    drawn
  }
  registerS3method("makeContent", "fourfold_counts", measure_counts, envir = asNamespace("grid"))
  g <- suppressWarnings(ggplot2::ggplotGrob(p))
  if (strip) g <- remove_counts(g)
  grid::grid.newpage(); grid::grid.draw(g); grid::grid.force()
  counts <- if (strip) NULL else grid::grid.get("fourfold-counts", global = TRUE)
  if (inherits(counts, "gTree")) counts <- list(counts)
  summary <- lapply(counts, function(x) list(outside = x$outside,
    reach = x$reach, tick_reach = x$tick_reach, limit = x$count_limit,
    actual_outline_limit = x$actual_outline_limit, actual_tick_limit = x$actual_tick_limit,
    labels = x$labels,
    children = lapply(x$children, function(t) list(label = t$label,
      x = as.numeric(t$x), y = as.numeric(t$y), hjust = t$hjust, vjust = t$vjust))))
  invisible(grDevices::dev.off())
  saveRDS(summary, file.path(out, paste0(case$id, if (strip) "-stripped" else "", ".rds")))
} else stop("Unknown mode")
