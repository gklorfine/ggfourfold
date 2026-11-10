# Verification harness for `geom_fourfold(labels = c("levels", "both"))`.
# Spec: dev/labels-spec.md.  Run from the package root:
#
#   Rscript dev/verify-labels.R
#
# Parts
#   S  self-test of the comparison machinery (OLD vs OLD must pass; perturbed
#      runs must be detected)
#   A  OLD (git archive HEAD) vs NEW on the default path (never passes labels)
#   B  NEW only: labels = "both" (layer data, masked grob dump, label strings,
#      gallery PNGs, name-resolution cases, fallback, argument checking)
#   C  NEW only: patchwork, cowplot, gganimate (each guarded)
#   D  NEW vs vcd::fourfold(): which side shows which variable
#
# Output: dev/labels-verification/ (PNGs, per-run notes).  Exit status is
# non-zero if any check FAILs.  Statuses: PASS, FAIL, SKIP, INFO,
# EXPECTED-LIMITATION.  Only git read-only commands (git archive) are used.
#
# Environment variables (all optional)
#   LABELS_VERIFY_NEW      package directory used as NEW (default: repo root)
#   LABELS_VERIFY_OLD      package directory used as OLD (default: git archive HEAD)
#   LABELS_VERIFY_PARTS    letters of the parts to run (default "SABCD")
#   LABELS_VERIFY_OUT      output directory (default dev/labels-verification)
#   LABELS_VERIFY_RETRIES  tries for NEW to become available for B-D (default 5)
#   LABELS_VERIFY_WAIT     seconds between those tries (default 60)

# ---------------------------------------------------------------------------
# Helpers (pure definitions; also sourced inside the worker processes)
# ---------------------------------------------------------------------------

open_dev <- function(file, w, h) {
  if (requireNamespace("ragg", quietly = TRUE)) {
    ragg::agg_png(file, width = w, height = h, units = "in", res = 100)
  } else {
    grDevices::png(file, width = w, height = h, units = "in", res = 100,
                   type = "cairo")
  }
}

fmt_value <- function(v) {
  if (is.null(v)) return("NULL")
  if (is.function(v)) return("<function>")
  if (is.environment(v)) return("<environment>")
  if (inherits(v, "viewport")) return(fmt_vp(v))
  if (grid::is.unit(v)) {
    return(paste0("unit[", paste(as.character(v), collapse = ","), "]"))
  }
  if (inherits(v, "gpar")) {
    return(paste0("gpar", paste(deparse(unclass(v), control = c("keepNA",
      "keepInteger", "niceNames", "digits17"), width.cutoff = 500L),
      collapse = " ")))
  }
  tryCatch(
    paste(deparse(v, control = c("keepNA", "keepInteger", "niceNames",
      "digits17"), width.cutoff = 500L), collapse = " "),
    error = function(e) paste0("<", class(v)[1], ">")
  )
}

fmt_vp <- function(vp) {
  flds <- c("name", "x", "y", "width", "height", "justification", "gp",
            "clip", "xscale", "yscale", "angle")
  paste(vapply(flds, function(f) paste0(f, "=", fmt_value(vp[[f]])), ""),
        collapse = "; ")
}

# Replace auto-numbering (GRID.text.45, fourfold-panel.GROB.123, rect.13).
norm_lines <- function(x) {
  gsub("\\b([A-Za-z][A-Za-z_-]*)\\.[0-9]+\\b", "\\1.N", x, perl = TRUE)
}

walk_grob <- function(g, depth, st) {
  nm <- if (is.null(g$name)) "<NULL>" else as.character(g$name)
  ind <- strrep("  ", depth)
  saved <- st$in_label
  in_label <- saved || grepl("^fourfold-label-", nm)
  st$in_label <- in_label
  st$lines <- c(st$lines, paste0(ind, "GROB ", nm, " [",
                                 paste(class(g), collapse = "/"), "]"))
  if (!st$mask && st$orig == 0L &&
      grepl("^fourfold-label-(top|left|bottom|right)$", nm)) {
    side <- sub("^fourfold-label-", "", nm)
    if (side == "top") st$panel <- st$panel + 1L
    st$labels[[length(st$labels) + 1L]] <- list(
      panel = st$panel, side = side, label = paste(g$label, collapse = "|")
    )
  }
  flds <- sort(setdiff(names(g), c("name", "children", "childrenOrder",
                                   "grobs", "vp", "gp")))
  for (f in flds) {
    v <- unclass(g)[[f]]
    if (f == ".ORIGINAL" && grid::is.grob(v)) {
      # grid.force() keeps the unforced grob here; walk it so that labels in
      # it are masked like any other.
      st$lines <- c(st$lines, paste0(ind, "  .ORIGINAL ="))
      st$orig <- st$orig + 1L
      walk_grob(v, depth + 2L, st)
      st$orig <- st$orig - 1L
      next
    }
    txt <- if (f == "label" && st$mask && in_label) "<MASK>" else fmt_value(v)
    st$lines <- c(st$lines, paste0(ind, "  ", f, " = ", txt))
  }
  if (!is.null(g$gp)) {
    st$lines <- c(st$lines, paste0(ind, "  gp = ", fmt_value(g$gp)))
  }
  if (!is.null(g$vp)) {
    st$lines <- c(st$lines, paste0(ind, "  vp = ", fmt_value(g$vp)))
  }
  kids <- NULL
  if (is.list(g$children) && length(g$children)) {
    ord <- g$childrenOrder
    if (is.null(ord)) ord <- names(g$children)
    kids <- g$children[ord]
  } else if (is.list(g$grobs) && length(g$grobs)) {
    kids <- g$grobs
  }
  for (k in kids) if (grid::is.grob(k)) walk_grob(k, depth + 1L, st)
  st$in_label <- saved
  invisible(NULL)
}

# Draw a gtable on an off-screen device of fixed size, force it and dump it.
dump_gtable <- function(gt, w, h) {
  f <- tempfile(fileext = ".png")
  open_dev(f, w, h)
  on.exit({ grDevices::dev.off(); unlink(f) })
  grid::grid.newpage()
  fg <- grid::grid.force(gt)
  out <- list()
  for (mask in c(FALSE, TRUE)) {
    st <- new.env()
    st$lines <- character(); st$labels <- list(); st$mask <- mask
    st$in_label <- FALSE; st$panel <- 0L; st$orig <- 0L
    walk_grob(fg, 0L, st)
    out[[if (mask) "masked" else "text"]] <- norm_lines(st$lines)
    if (!mask) {
      out$labels <- if (length(st$labels)) {
        do.call(rbind, lapply(st$labels, as.data.frame, stringsAsFactors = FALSE))
      } else {
        data.frame(panel = integer(), side = character(), label = character())
      }
    }
  }
  out
}

drawn_labels <- function(p, w = 6, h = 5) {
  dump_gtable(ggplot2::ggplotGrob(p), w, h)$labels
}

render_png <- function(p, file, w, h) {
  open_dev(file, w, h)
  on.exit(grDevices::dev.off())
  print(p)
  invisible(file)
}

# expected labels for a panel: order top, left, bottom, right
expect_labels <- function(xn, xlev, yn, ylev) {
  c(top = paste0(yn, ": ", ylev[1]), left = paste0(xn, ": ", xlev[1]),
    bottom = paste0(yn, ": ", ylev[2]), right = paste0(xn, ": ", xlev[2]))
}

load_pkg <- function(pkg) {
  suppressMessages(pkgload::load_all(pkg, quiet = TRUE))
  suppressPackageStartupMessages(library(ggplot2))
}

# Shared data for the worker functions.
verify_data <- function() {
  agg <- as.data.frame(margin.table(UCBAdmissions, 1:2))
  ucb <- as.data.frame(UCBAdmissions)
  ucb2 <- rbind(transform(ucb, Year = "Y1", Freq = Freq %/% 2),
                transform(ucb, Year = "Y2", Freq = Freq - Freq %/% 2))
  ind <- ucb[rep(seq_len(nrow(ucb)), ucb$Freq), c("Admit", "Gender", "Dept")]
  rownames(ind) <- NULL
  single <- data.frame(
    Sex = factor(c("M", "M", "F", "F"), levels = c("M", "F")),
    Outcome = factor(c("Yes", "No", "Yes", "No"), levels = c("Yes", "No")),
    n = c(30, 10, 15, 25))
  zero <- single; zero$n <- c(30, 0, 15, 25)
  zero2 <- single; zero2$n <- c(30, 0, 15, 0)
  set.seed(42)
  n <- 166
  vars <- c("Female", "Employed", "Related", "Financial gain", "AI guess 1",
            "AI guess 2", "AI guess 3")
  long <- do.call(rbind, lapply(vars, function(v) data.frame(
    Variable = v,
    Predictor = factor(sample(c("No", "Yes"), n, TRUE, prob = c(.6, .4)),
                       levels = c("No", "Yes")),
    Killer = factor(sample(c("Innocent", "Killer"), n, TRUE, prob = c(.8, .2)),
                    levels = c("Innocent", "Killer")))))
  long$Variable <- factor(long$Variable, levels = vars)
  list(agg = agg, ucb = ucb, ucb2 = ucb2, ind = ind, single = single,
       zero = zero, zero2 = zero2, long = long)
}

# Data with two spare binary variables, for the name-resolution cases.
name_data <- function() {
  dd <- as.data.frame(margin.table(UCBAdmissions, 1:2))
  dd$Smoker <- factor(c("Never", "Ever")[as.integer(dd$Gender)],
                      levels = c("Never", "Ever"))
  dd$Cancer <- factor(c("Healthy", "Cancer")[as.integer(dd$Admit)],
                      levels = c("Healthy", "Cancer"))
  dd[["Financial gain"]] <- factor(c("Low", "High")[as.integer(dd$Gender)],
                                   levels = c("Low", "High"))
  dd$Sex <- factor(dd$Gender, levels = c("Male", "Female"))     # same levels
  dd$Result <- factor(dd$Admit, levels = c("Admitted", "Rejected"))
  dd$Dept <- NULL
  dd
}

# ---------------------------------------------------------------------------
# Worker: the battery of plots (identical code in every process)
# ---------------------------------------------------------------------------

run_battery <- function(pkg, outdir, mode = c("default", "levels", "both"),
                        perturb = NULL) {
  mode <- match.arg(mode)
  load_pkg(pkg)
  dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
  extra <- switch(mode, default = list(), levels = list(labels = "levels"),
                  both = list(labels = "both"))
  cur_id <- ""
  gf <- function(...) {
    a <- c(list(...), extra)
    if (!is.null(perturb$args) && identical(cur_id, perturb$id)) {
      a <- utils::modifyList(a, perturb$args)
    }
    do.call(geom_fourfold, a)
  }
  D <- verify_data()
  W <- list(); add <- function(id, make, x, y, w = 6, h = 5) {
    W[[id]] <<- list(make = make, x = x, y = y, w = w, h = h)
  }
  A <- function(d = D$agg) ggplot(d, aes(x = Gender, y = Admit, weight = Freq))
  wrap <- function() facet_wrap(vars(Dept), ncol = 3)
  th <- function() theme_fourfold()
  gx <- "Gender"; ay <- "Admit"
  add("ucb_agg", function() A() + gf(), gx, ay)
  add("ucb_agg_theme", function() A() + gf() + th(), gx, ay)
  add("ucb_wrap", function() A(D$ucb) + gf() + wrap(), gx, ay, 9, 6)
  add("ucb_wrap_theme", function() A(D$ucb) + gf() + wrap() + th(), gx, ay, 9, 6)
  add("ucb_grid_cols", function() A(D$ucb) + gf() +
        facet_grid(cols = vars(Dept)) + th(), gx, ay, 12, 3)
  add("ucb_grid_rows", function() A(D$ucb) + gf() +
        facet_grid(Dept ~ .) + th(), gx, ay, 4, 12)
  add("ucb_grid_year", function() A(D$ucb2) + gf() +
        facet_grid(Year ~ Dept) + th(), gx, ay, 12, 5)
  add("ucb_grid_year_notheme", function() A(D$ucb2) + gf() +
        facet_grid(Year ~ Dept), gx, ay, 12, 5)
  add("single", function() ggplot(D$single, aes(Sex, Outcome, weight = n)) + gf(),
      "Sex", "Outcome")
  add("single_theme", function() ggplot(D$single, aes(Sex, Outcome, weight = n)) +
        gf() + th(), "Sex", "Outcome")
  ia <- function() ggplot(D$ind, aes(x = Gender, y = Admit))
  add("indiv", function() ia() + gf(), gx, ay)
  add("indiv_theme", function() ia() + gf() + th(), gx, ay)
  add("indiv_wrap", function() ia() + gf() + wrap() + th(), gx, ay, 9, 6)
  for (m in list(1, 2, c(1, 2))) {
    add(paste0("margins_", paste(m, collapse = "")),
        local({ m <- m; function() A(D$ucb) + gf(std = "margins", margin = m) +
                  wrap() + th() }), gx, ay, 9, 6)
  }
  add("ind_max", function() A(D$ucb) + gf(std = "ind.max") + wrap() + th(),
      gx, ay, 9, 6)
  add("all_max", function() A(D$ucb) + gf(std = "all.max") + wrap() + th(),
      gx, ay, 9, 6)
  add("ind_max_m1", function() A(D$ucb) + gf(std = "ind.max", margin = 1) +
        wrap() + th(), gx, ay, 9, 6)
  add("all_max_m2", function() A(D$ucb) + gf(std = "all.max", margin = 2) +
        wrap() + th(), gx, ay, 9, 6)
  add("square_agg", function() A() + gf(shape = "square") + th(), gx, ay)
  add("square_wrap", function() A(D$ucb) + gf(shape = "square") + wrap() +
        th(), gx, ay, 9, 6)
  for (cn in c("auto", "inside", "outside", "none")) {
    for (sh in c("circle", "square")) {
      add(paste0("counts_", cn, "_", sh), local({ cn <- cn; sh <- sh;
        function() A(D$ucb) + gf(counts = cn, shape = sh) + wrap() + th() }),
        gx, ay, 9, 6)
    }
  }
  add("extended_false", function() A(D$ucb) + gf(extended = FALSE) + wrap() +
        th(), gx, ay, 9, 6)
  add("diagonal_false", function() A(D$ucb) + gf(diagonal = FALSE) + wrap() +
        th(), gx, ay, 9, 6)
  add("conf0", function() A(D$ucb) + gf(conf_level = 0) + wrap() + th(),
      gx, ay, 9, 6)
  add("zero_cell", function() ggplot(D$zero, aes(Sex, Outcome, weight = n)) +
        gf() + th(), "Sex", "Outcome")
  add("zero_cell_square", function() ggplot(D$zero, aes(Sex, Outcome, weight = n)) +
        gf(shape = "square") + th(), "Sex", "Outcome")
  add("zero_two_cells", function() ggplot(D$zero2, aes(Sex, Outcome, weight = n)) +
        gf() + th(), "Sex", "Outcome")
  add("palette_okabe", function() A(D$ucb) +
        gf(palette = fourfold_palette("okabe-ito")) + wrap() + th(), gx, ay, 9, 6)
  add("palette_custom", function() A(D$ucb) + gf(palette = c("#111111",
        "#222222", "#33AA33", "#AA33AA", "#FFCC00", "#00CCFF")) + wrap() + th(),
      gx, ay, 9, 6)
  add("fixed_colour", function() A(D$ucb) + gf(colour = "navy", linewidth = 1) +
        wrap() + th(), gx, ay, 9, 6)
  add("fixed_colour_notheme", function() A() + gf(colour = "darkgreen",
        linewidth = 0.3), gx, ay)
  add("scale_labels", function() A(D$ucb) + gf() + wrap() + th() +
        scale_x_discrete(labels = c(Male = "Men", Female = "Women")) +
        scale_y_discrete(labels = toupper), gx, ay, 9, 6)
  add("scale_labels_notheme", function() A() + gf() +
        scale_x_discrete(labels = c(Male = "Men", Female = "Women")), gx, ay)
  lg <- function() ggplot(D$long, aes(Predictor, Killer)) + gf() +
    facet_wrap(vars(Variable), nrow = 2)
  add("realuse_circle", function() lg() + th(), "Predictor", "Killer", 11, 6)
  add("realuse_square", function() ggplot(D$long, aes(Predictor, Killer)) +
        gf(shape = "square") + facet_wrap(vars(Variable), nrow = 2) + th(),
      "Predictor", "Killer", 11, 6)
  add("realuse_outside", function() ggplot(D$long, aes(Predictor, Killer)) +
        gf(counts = "outside") + facet_wrap(vars(Variable), nrow = 2) + th(),
      "Predictor", "Killer", 11, 6)
  add("realuse_notheme", function() lg(), "Predictor", "Killer", 11, 6)

  records <- list()
  for (id in names(W)) {
    it <- W[[id]]
    cur_id <- id
    msgs <- character()
    rec <- tryCatch(
      withCallingHandlers({
        p <- it$make()
        ld <- ggplot2::layer_data(p, 1L)
        gt <- ggplot2::ggplotGrob(p)
        dd <- dump_gtable(gt, it$w, it$h)
        pf <- file.path(outdir, paste0(mode, "-", id, ".png"))
        render_png(p, pf, it$w, it$h)
        list(ok = TRUE, layer_data = ld, dump = dd$text,
             masked = dd$masked, labels = dd$labels, png = pf,
             cls = class(p), x = it$x, y = it$y)
      }, message = function(m) {
        msgs <<- c(msgs, paste0("message: ", conditionMessage(m)))
        invokeRestart("muffleMessage")
      }, warning = function(w) {
        msgs <<- c(msgs, paste0("warning: ", conditionMessage(w)))
        invokeRestart("muffleWarning")
      }),
      error = function(e) list(ok = FALSE, error = conditionMessage(e))
    )
    rec$msgs <- msgs
    if (!is.null(perturb$class) && identical(id, perturb$id_class) &&
        isTRUE(rec$ok)) {
      rec$cls <- c(perturb$class, rec$cls)
    }
    records[[id]] <- rec
  }
  gfl <- do.call(geom_fourfold, extra)
  third <- if (length(gfl) >= 3L) class(gfl[[3L]]) else NA_character_
  list(records = records, len = length(gfl), gf_class = class(gfl), third_class = third,
       layer_class = class(gfl[[1]]), has_labels = "labels" %in%
         names(formals(geom_fourfold)))
}

# ---------------------------------------------------------------------------
# Worker: gallery of levels vs both
# ---------------------------------------------------------------------------

run_gallery <- function(pkg, outdir) {
  load_pkg(pkg)
  dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
  mk_data <- function(xn, yn, xlev, ylev, facets) {
    one <- function(v) {
      d <- data.frame(
        x = factor(rep(xlev, each = 2), levels = xlev),
        y = factor(rep(ylev, 2), levels = ylev),
        n = c(40, 12, 15, 30) + c(2, 1, -1, 3) * (v - 1))
      names(d)[1:2] <- c(xn, yn)
      d$Panel <- paste("Variable", v)
      d
    }
    do.call(rbind, lapply(seq_len(facets), one))
  }
  mk_plot <- function(d, xn, yn, labels, shape, counts, facets, theme = TRUE) {
    p <- ggplot(d, aes(x = !!rlang::sym(xn), y = !!rlang::sym(yn), weight = n)) +
      geom_fourfold(shape = shape, counts = counts, labels = labels)
    if (facets > 1) p <- p + facet_wrap(vars(Panel), nrow = 2)
    if (theme) p <- p + theme_fourfold()
    p
  }
  names3 <- list(
    short = list(xn = "Sex", yn = "Result", xlev = c("Male", "Female"),
                 ylev = c("Yes", "No")),
    medium = list(xn = "Financial gain", yn = "Killer", xlev = c("No", "Yes"),
                  ylev = c("Innocent", "Killer")),
    long = list(xn = "Socioeconomic status", yn = "Hospital readmission",
                xlev = c("Low", "High"), ylev = c("Yes", "No")))
  cases <- list()
  addc <- function(len, shape, counts, facets, theme = TRUE) {
    id <- paste0(if (facets > 1) "facets7" else "single", "-", len, "-", shape,
                 "-counts-", counts, if (!theme) "-default-theme" else "")
    cases[[id]] <<- list(len = len, shape = shape, counts = counts,
                         facets = facets, theme = theme)
  }
  for (l in names(names3)) addc(l, "circle", "auto", 1)
  for (l in names(names3)) addc(l, "square", "auto", 1)
  addc("medium", "circle", "outside", 1); addc("long", "circle", "outside", 1)
  addc("long", "square", "outside", 1)
  addc("medium", "circle", "auto", 7); addc("long", "circle", "auto", 7)
  addc("long", "square", "auto", 7)
  addc("long", "circle", "outside", 7); addc("long", "square", "outside", 7)
  addc("long", "circle", "auto", 1, theme = FALSE)
  addc("medium", "circle", "auto", 7, theme = FALSE)

  title_row <- function(txt) {
    grid::grid.text(txt, gp = grid::gpar(fontface = "bold", fontsize = 11))
  }
  out <- list()
  for (id in names(cases)) {
    cs <- cases[[id]]; nm <- names3[[cs$len]]
    d <- mk_data(nm$xn, nm$yn, nm$xlev, nm$ylev, cs$facets)
    pl <- mk_plot(d, nm$xn, nm$yn, "levels", cs$shape, cs$counts, cs$facets, cs$theme)
    pb <- mk_plot(d, nm$xn, nm$yn, "both", cs$shape, cs$counts, cs$facets, cs$theme)
    stack <- cs$facets > 1
    w <- if (stack) 9 else 11; h <- if (stack) 12.5 else 5.5
    file <- file.path(outdir, paste0("gallery-", id, ".png"))
    msgs <- character()
    withCallingHandlers({
      open_dev(file, w, h)
      grid::grid.newpage()
      grid::pushViewport(grid::viewport(layout = grid::grid.layout(
        if (stack) 2 else 1, if (stack) 1 else 2)))
      for (i in 1:2) {
        grid::pushViewport(grid::viewport(
          layout.pos.row = if (stack) i else 1,
          layout.pos.col = if (stack) 1 else i,
          layout = grid::grid.layout(2, 1, heights = grid::unit(
            c(1.3, 1), c("lines", "null")))))
        grid::pushViewport(grid::viewport(layout.pos.row = 1))
        title_row(if (i == 1) 'labels = "levels"' else 'labels = "both"')
        grid::popViewport()
        grid::pushViewport(grid::viewport(layout.pos.row = 2))
        grid::grid.draw(ggplot2::ggplotGrob(list(pl, pb)[[i]]))
        grid::popViewport(2)
      }
      grDevices::dev.off()
    }, message = function(m) {
      msgs <<- c(msgs, conditionMessage(m)); invokeRestart("muffleMessage")
    })
    lab <- drawn_labels(pb, w = 9, h = 6)
    labl <- drawn_labels(pl, w = 9, h = 6)
    exp1 <- expect_labels(nm$xn, nm$xlev, nm$yn, nm$ylev)
    got <- vapply(split(lab, lab$panel), function(z)
      all(z$label[match(names(exp1), z$side)] == exp1), NA)
    out[[id]] <- list(file = file, labels_ok = all(got), n_panels = length(got),
                      msgs = msgs, expected = exp1,
                      levels_labels = labl$label[labl$panel == 1])
  }
  out
}

# ---------------------------------------------------------------------------
# Worker: name-resolution cases
# ---------------------------------------------------------------------------

run_names <- function(pkg) {
  load_pkg(pkg)
  dd <- name_data()
  gl <- function(...) geom_fourfold(labels = "both", ...)
  E <- function(xn, yn, xlev, ylev) expect_labels(xn, xlev, yn, ylev)
  GA <- E("Gender", "Admit", c("Male", "Female"), c("Admitted", "Rejected"))
  SC <- E("Smoker", "Cancer", c("Never", "Ever"), c("Healthy", "Cancer"))
  AG <- E("Admit", "Gender", c("Admitted", "Rejected"), c("Male", "Female"))
  FG <- E("Financial gain", "Admit", c("Low", "High"), c("Admitted", "Rejected"))
  cases <- list()
  add <- function(id, make, expect) cases[[id]] <<- list(make = make, expect = expect)
  add("mapping in ggplot()", function() ggplot(dd, aes(Gender, Admit, weight = Freq)) + gl(), GA)
  add("mapping in the geom", function() ggplot(dd) + gl(aes(Gender, Admit, weight = Freq)), GA)
  add("mapping split plot/geom", function() ggplot(dd, aes(x = Gender)) +
        gl(aes(y = Admit, weight = Freq)), GA)
  add("inherit.aes = FALSE", function() ggplot(dd, aes(x = Smoker, y = Cancer)) +
        gl(aes(Gender, Admit, weight = Freq), inherit.aes = FALSE), GA)
  add("inherit.aes = TRUE, layer overrides x", function() ggplot(dd, aes(Smoker, Admit, weight = Freq)) +
        gl(aes(x = Gender)), GA)
  add(".data pronoun", function() ggplot(dd, aes(.data$Gender, .data[["Admit"]], weight = Freq)) + gl(), GA)
  add("non-syntactic (backticks)", function() ggplot(dd, aes(`Financial gain`, Admit, weight = Freq)) + gl(), FG)
  add("non-syntactic (.data[[ ]])", function() ggplot(dd, aes(.data[["Financial gain"]], Admit, weight = Freq)) + gl(), FG)
  add("expression factor(admit)", function() {
    d2 <- dd; d2$admit <- d2$Admit
    ggplot(d2, aes(Gender, factor(admit), weight = Freq)) + gl() },
    E("Gender", "factor(admit)", c("Male", "Female"), c("Admitted", "Rejected")))
  add("labs() and scale names are ignored", function() ggplot(dd, aes(Gender, Admit, weight = Freq)) + gl() +
        labs(x = "XXX", y = "YYY") + scale_x_discrete(name = "ZZZ"), GA)
  add("scale_x_discrete(labels=) renames levels", function() ggplot(dd, aes(Gender, Admit, weight = Freq)) + gl() +
        scale_x_discrete(labels = c(Male = "Men", Female = "Women")),
      E("Gender", "Admit", c("Men", "Women"), c("Admitted", "Rejected")))
  add("aes() added after the layer", function() ggplot(dd) + gl() + aes(Gender, Admit, weight = Freq), GA)
  add("aes() replaced after the layer (x, y swapped)", function() ggplot(dd, aes(Gender, Admit, weight = Freq)) + gl() +
        aes(x = Admit, y = Gender), AG)
  add("aes() replaced after the layer (other variables)", function() ggplot(dd, aes(Gender, Admit, weight = Freq)) + gl() +
        aes(x = Smoker, y = Cancer), SC)
  add("aes() replaced after the layer, with a theme in between", function() ggplot(dd, aes(Gender, Admit, weight = Freq)) +
        gl() + theme_fourfold() + aes(x = Smoker, y = Cancer) + labs(title = "t"), SC)
  add("facetted", function() ggplot(dd, aes(Gender, Admit, weight = Freq)) + gl() +
        facet_wrap(vars(Smoker)), GA)
  add("two fourfold layers, different mappings (panel 1 = layer 1, panel 2 = layer 2)",
      function() ggplot(dd, aes(Gender, Admit, weight = Freq)) + gl() +
        gl(aes(x = Sex, y = Result)),
      list(GA, E("Sex", "Result", c("Male", "Female"), c("Admitted", "Rejected"))))
  res <- list()
  for (id in names(cases)) {
    cs <- cases[[id]]; msgs <- character()
    r <- tryCatch(withCallingHandlers({
      p <- cs$make()
      lab <- drawn_labels(p)
      list(ok = TRUE, labels = lab)
    }, message = function(m) { msgs <<- c(msgs, conditionMessage(m)); invokeRestart("muffleMessage") }),
    error = function(e) list(ok = FALSE, error = conditionMessage(e)))
    r$msgs <- msgs; r$expect <- cs$expect
    res[[id]] <- r
  }
  # ---- reuse cases ----
  reuse <- list()
  chk <- function(id, p, expect) {
    r <- tryCatch(list(ok = TRUE, labels = drawn_labels(p)),
                  error = function(e) list(ok = FALSE, error = conditionMessage(e)))
    r$expect <- expect; reuse[[id]] <<- r
  }
  p0 <- ggplot(dd, aes(Gender, Admit, weight = Freq)) + gl()
  p1 <- p0 + aes(x = Smoker, y = Cancer)
  p2 <- p0 + aes(x = Admit, y = Gender)
  chk("reuse: derived plot p1 (built first)", p1, SC)
  chk("reuse: original plot p0 (built after p1)", p0, GA)
  chk("reuse: derived plot p2", p2, AG)
  chk("reuse: original plot p0 (built again)", p0, GA)
  chk("reuse: p1 again", p1, SC)
  lyr <- gl()
  pA <- ggplot(dd, aes(Gender, Admit, weight = Freq)) + lyr
  pB <- ggplot(dd, aes(Smoker, Cancer, weight = Freq)) + lyr
  chk("one layer in two plots: plot A", pA, GA)
  chk("one layer in two plots: plot B", pB, SC)
  chk("one layer in two plots: plot A again", pA, GA)
  lyr_ln <- tryCatch(lyr[[1]]$geom_params$label_names, error = function(e) "<error>")
  lyr_aes_ok <- is.null(lyr_ln)
  # ---- fallback: layer never tagged, so no names ----
  fb <- tryCatch({
    l <- geom_fourfold(labels = "both")[[1]]
    p <- ggplot(dd, aes(Gender, Admit, weight = Freq)) + facet_wrap(vars(Smoker))
    p$layers <- list(l)
    msgs <- character()
    lab <- withCallingHandlers(drawn_labels(p), message = function(m) {
      msgs <<- c(msgs, conditionMessage(m)); invokeRestart("muffleMessage") })
    list(ok = TRUE, labels = lab, msgs = msgs)
  }, error = function(e) list(ok = FALSE, error = conditionMessage(e)))
  # ---- argument handling ----
  argchk <- list(
    invalid = tryCatch({ geom_fourfold(labels = "nope"); "no error" },
                       error = function(e) conditionMessage(e)),
    default_vector_len = length(geom_fourfold()),
    levels_len = length(geom_fourfold(labels = "levels")),
    both_len = length(geom_fourfold(labels = "both")),
    both_class3 = tryCatch(class(geom_fourfold(labels = "both")[[3]]), error = function(e) "<error>"),
    levels_classes = vapply(geom_fourfold(labels = "levels"), function(z) class(z)[1], ""),
    explicit_default_equal = identical(
      vapply(geom_fourfold(), function(z) class(z)[1], ""),
      vapply(geom_fourfold(labels = c("levels", "both")), function(z) class(z)[1], "")),
    vector_default_builds = tryCatch({
      layer_data(ggplot(dd, aes(Gender, Admit, weight = Freq)) +
                   geom_fourfold(labels = c("levels", "both")), 1L); TRUE },
      error = function(e) conditionMessage(e)),
    plain_plot_class_after_levels = class(ggplot(dd, aes(Gender, Admit, weight = Freq)) +
                                           geom_fourfold(labels = "levels"))[1],
    plain_plot_class_after_both = class(ggplot(dd, aes(Gender, Admit, weight = Freq)) +
                                          geom_fourfold(labels = "both"))[1])
  list(cases = res, reuse = reuse, layer_unmutated = lyr_aes_ok, fallback = fb,
       argchk = argchk)
}

# ---------------------------------------------------------------------------
# Worker: other packages
# ---------------------------------------------------------------------------

# Wrap GeomFourfold$draw_panel so that the four side labels of every drawn
# panel are recorded.  (`GeomFourfold$draw_panel` returns a bound method with
# formals `...`, so the raw function is taken from the ggproto environment and
# put back there afterwards.)  Returns list(log = <env>, restore = <function>).
install_logger <- function() {
  LOG <- new.env(); LOG$calls <- list()
  orig <- get("draw_panel", envir = GeomFourfold, inherits = FALSE)
  wrapper <- function() NULL
  formals(wrapper) <- formals(orig)
  body(wrapper) <- quote({
    cl <- match.call(); cl[[1]] <- orig
    res <- eval(cl, parent.frame())
    labs <- vapply(c("top", "left", "bottom", "right"), function(s)
      paste(res$children[[paste0("fourfold-label-", s)]]$label, collapse = "|"), "")
    LOG$calls[[length(LOG$calls) + 1L]] <- labs
    res
  })
  environment(wrapper) <- list2env(list(orig = orig, LOG = LOG), parent = environment(orig))
  assign("draw_panel", wrapper, envir = GeomFourfold)
  list(log = LOG, restore = function() assign("draw_panel", orig, envir = GeomFourfold))
}

# Run fun() with the logger installed; returns the recorded calls (one named
# vector top/left/bottom/right per draw_panel() call).
logged_calls <- function(fun) {
  lg <- install_logger()
  on.exit(lg$restore())
  fun()
  lg$log$calls
}

run_packages <- function(pkg, which, outdir) {
  load_pkg(pkg)
  dd <- name_data()
  gl <- function(...) geom_fourfold(labels = "both", ...)
  E <- function(xn, yn, xlev, ylev) expect_labels(xn, xlev, yn, ylev)
  GA <- E("Gender", "Admit", c("Male", "Female"), c("Admitted", "Rejected"))
  SC <- E("Smoker", "Cancer", c("Never", "Ever"), c("Healthy", "Cancer"))
  AG <- E("Admit", "Gender", c("Admitted", "Rejected"), c("Male", "Female"))
  pA <- ggplot(dd, aes(Gender, Admit, weight = Freq)) + gl() + theme_fourfold()
  pB <- ggplot(dd, aes(Smoker, Cancer, weight = Freq)) + gl() + theme_fourfold()
  pS <- pA + aes(x = Admit, y = Gender)           # swapped after the layer
  pL <- ggplot(dd) + gl() + theme_fourfold() + aes(Smoker, Cancer, weight = Freq)
  res <- list()
  getlab <- function(grob_fun) {
    f <- tempfile(fileext = ".png"); open_dev(f, 10, 6)
    on.exit({ grDevices::dev.off(); unlink(f) })
    grid::grid.newpage()
    g <- grid::grid.force(grob_fun())
    st <- new.env(); st$lines <- character(); st$labels <- list(); st$mask <- FALSE
    st$in_label <- FALSE; st$panel <- 0L; st$orig <- 0L
    walk_grob(g, 0L, st)
    vapply(st$labels, function(z) z$label, "")
  }
  rec <- function(id, expr_grob, expect, via_log = FALSE) {
    msgs <- character()
    r <- tryCatch(withCallingHandlers({
      if (via_log) {
        # every panel may be drawn more than once (get_dim() builds the plot);
        # compare the set of distinct four-label tuples.
        calls <- logged_calls(expr_grob)
        got <- sort(unique(vapply(calls, function(z) paste(z, collapse = " | "), "")))
        list(ok = TRUE, got = got)
      } else {
        got <- getlab(expr_grob); list(ok = TRUE, got = got)
      }
    }, message = function(m) { msgs <<- c(msgs, conditionMessage(m)); invokeRestart("muffleMessage") }),
    error = function(e) list(ok = FALSE, error = conditionMessage(e)))
    r$expect <- if (via_log) sort(vapply(expect, function(z) paste(z, collapse = " | "), "")) else
      unlist(lapply(expect, unname))
    r$msgs <- msgs
    res[[id]] <<- r
  }
  if (which == "patchwork") {
    pw <- asNamespace("patchwork")
    G <- function(x) function() patchwork::patchworkGrob(x)
    rec("patchwork: A | B", G(pA | pB), list(GA, SC))
    rec("patchwork: A / B", G(pA / pB), list(GA, SC))
    rec("patchwork: (A | B) & theme", G((pA | pB) & theme(plot.margin = margin(5, 5, 5, 5))), list(GA, SC))
    rec("patchwork: wrap_plots(A, B, S, L, ncol = 2)", G(patchwork::wrap_plots(pA, pB, pS, pL, ncol = 2)), list(GA, SC, AG, SC))
    rec("patchwork: swapped-after-layer sub-plot (A | S)", G(pA | pS), list(GA, AG))
    rec("patchwork: aes-added-after-layer sub-plot (L | A)", G(pL | pA), list(SC, GA))
    rec("patchwork: A | (B / S)", G(pA | (pB / pS)), list(GA, SC, AG))
    rec("patchwork: plot_layout(guides = 'collect')", G((pA | pB) + patchwork::plot_layout(guides = "collect")), list(GA, SC))
    rec("patchwork: plot_annotation", G((pA | pS) + patchwork::plot_annotation(title = "x")), list(GA, AG))
    # grid.force() fails on set_dim() patchworks even for plain geom_point plots
    # (invalid 'layout.pos.row'), so the labels are read from draw_panel() calls.
    rec("patchwork: set_dim/get_dim (labels read via draw_panel log)", function() {
      dA <- patchwork::get_dim(pA); dS <- patchwork::get_dim(pS)
      patchwork::patchworkGrob(patchwork::set_dim(pA, dA) | patchwork::set_dim(pS, dS)) },
      list(GA, AG), via_log = TRUE)
    rec("patchwork: wrap_plots of facetted plot", G(patchwork::wrap_plots(
      ggplot(dd, aes(Gender, Admit, weight = Freq)) + gl() + facet_wrap(vars(Smoker)), pB, widths = c(2, 1))),
      list(GA, GA, SC))
  } else if (which == "cowplot") {
    rec("cowplot: plot_grid(A, B)", function() ggplot2::ggplotGrob(cowplot::plot_grid(pA, pB, nrow = 1)), list(GA, SC))
    rec("cowplot: plot_grid(A, S, L, labels = AUTO, align = hv)", function()
      ggplot2::ggplotGrob(cowplot::plot_grid(pA, pS, pL, nrow = 1, labels = "AUTO", align = "hv")),
      list(GA, AG, SC))
    rec("cowplot: plot_grid(A / B column)", function()
      ggplot2::ggplotGrob(cowplot::plot_grid(pA, pB, ncol = 1, rel_heights = c(2, 1))), list(GA, SC))
    rec("cowplot: as_grob(S)", function() cowplot::as_grob(pS), list(AG))
  } else if (which == "gganimate") {
    sub <- as.data.frame(UCBAdmissions)
    sub <- sub[sub$Dept %in% c("A", "B"), ]; sub$Dept <- droplevels(sub$Dept)
    sub$Smoker <- factor(c("Never", "Ever")[as.integer(sub$Gender)], levels = c("Never", "Ever"))
    sub$Cancer <- factor(c("Healthy", "Cancer")[as.integer(sub$Admit)], levels = c("Healthy", "Cancer"))
    ts <- function() gganimate::transition_states(Dept, transition_length = 1, state_length = 1)
    # Record label strings from every draw_panel() call.
    lg <- install_logger(); LOG <- lg$log
    run_anim <- function(id, p, expect, kind) {
      LOG$calls <- list(); msgs <- character()
      dir <- file.path(outdir, paste0("gganimate-", gsub("[^a-z0-9]+", "-", tolower(id))))
      unlink(dir, recursive = TRUE); dir.create(dir, recursive = TRUE)
      r <- tryCatch(withCallingHandlers({
        gganimate::animate(p, nframes = 2, fps = 2, width = 500, height = 400,
                           device = "png", renderer = gganimate::file_renderer(dir, prefix = "frame", overwrite = TRUE))
        list(ok = TRUE)
      }, message = function(m) { msgs <<- c(msgs, conditionMessage(m)); invokeRestart("muffleMessage") },
      warning = function(w) { msgs <<- c(msgs, paste("warning:", conditionMessage(w))); invokeRestart("muffleWarning") }),
      error = function(e) list(ok = FALSE, error = conditionMessage(e)))
      r$frames <- length(list.files(dir, pattern = "\\.png$"))
      r$dir <- dir
      r$labels <- unique(unlist(lapply(LOG$calls, function(z) z)))
      r$calls <- length(LOG$calls)
      r$expect <- unname(expect); r$msgs <- msgs; r$kind <- kind
      # State of the plot object, independent of whether gganimate can render.
      cls <- class(p)
      fn <- get0(".fourfold_resolve_label_names", asNamespace("ggfourfold"), inherits = FALSE)
      first <- function(z) tryCatch(z$layers[[1]]$geom_params$label_names, error = function(e) "<error>")
      r$info <- list(class_head = head(cls, 3), fourfold_idx = match("fourfold_plot", cls),
                     gganim_idx = match("gganim", cls), add_time = first(p),
                     resolved = if (is.null(fn)) "<no helper>" else tryCatch(first(fn(p)), error = function(e) "<error>"))
      res[[id]] <<- r
    }
    base <- function() ggplot(sub, aes(Gender, Admit, weight = Freq))
    run_anim("A: aes before layer, transition after layer",
             base() + gl() + ts(), GA, "ordinary")
    run_anim("B: aes before layer, transition before layer",
             base() + ts() + gl(), GA, "ordinary")
    run_anim("C: aes added after layer, transition after layer",
             ggplot(sub) + gl() + aes(Gender, Admit, weight = Freq) + ts(), GA, "added_after_transition_last")
    run_anim("D: aes added after layer, transition before layer",
             ggplot(sub) + ts() + gl() + aes(Gender, Admit, weight = Freq), GA, "added_after_transition_first")
    run_anim("E: aes replaced after layer, transition after layer",
             base() + gl() + aes(x = Smoker, y = Cancer) + ts(), SC, "replaced_after_transition_last")
    run_anim("F: aes replaced after layer, transition before layer",
             base() + ts() + gl() + aes(x = Smoker, y = Cancer), SC, "replaced_after_transition_first")
    run_anim("G: aes replaced after the transition and the layer",
             base() + gl() + ts() + aes(x = Smoker, y = Cancer), SC, "replaced_after_all")
    run_anim("H: labels = levels control, transition after layer",
             base() + geom_fourfold(labels = "levels") + ts(), NULL, "control")
    lg$restore()
  }
  res
}

# ---------------------------------------------------------------------------
# Worker: vcd comparison
# ---------------------------------------------------------------------------

run_vcd <- function(pkg, outdir) {
  load_pkg(pkg)
  suppressPackageStartupMessages(library(vcd))
  w <- 9; h <- 6
  f1 <- file.path(outdir, "vcd-fourfold-UCBAdmissions.png")
  open_dev(f1, w, h)
  grid::grid.newpage()
  vcd::fourfold(UCBAdmissions, mfcol = c(2, 3))
  nm <- grid::grid.ls(print = FALSE)$name
  vtxt <- list()
  for (n in nm) {
    g <- grid::grid.get(n)
    if (inherits(g, "text") && grepl("^(Admit|Gender): ", g$label)) {
      vtxt[[length(vtxt) + 1L]] <- data.frame(label = g$label,
        x = as.numeric(g$x), y = as.numeric(g$y), rot = g$rot)
    }
  }
  grDevices::dev.off()
  vt <- do.call(rbind, vtxt)
  vt$side <- ifelse(vt$rot == 90, ifelse(vt$x < 0, "left", "right"),
                    ifelse(vt$y > 0, "top", "bottom"))
  vsrc <- paste(deparse(vcd::fourfold), collapse = "\n")
  # first stratum of vcd (Dept A) is the first four labels
  vcd_first <- vt[1:4, ]
  # ggfourfold equivalent
  ucb <- as.data.frame(UCBAdmissions)
  p <- ggplot(ucb, aes(x = Gender, y = Admit, weight = Freq)) +
    geom_fourfold(labels = "both") + facet_wrap(vars(Dept), ncol = 3) +
    theme_fourfold()
  f2 <- file.path(outdir, "ggfourfold-UCBAdmissions-labels-both.png")
  render_png(p, f2, w, h)
  lab <- drawn_labels(p, w, h)
  list(vcd_labels = vt, vcd_first = vcd_first, gg_labels = lab, files = c(f1, f2),
       vcd_src_label_lines = grep("grid.text\\(paste\\(names", strsplit(vsrc, "\n")[[1]], value = TRUE),
       vcd_src_args = names(formals(vcd::fourfold)))
}

# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------

sub_run <- function(script, fun, ...) {
  callr::r(function(script, fun, args) {
    Sys.setenv(LABELS_VERIFY_WORKER = "1")
    source(script, local = FALSE)
    do.call(get(fun), args)
  }, args = list(script = script, fun = fun, args = list(...)),
  show = FALSE, spinner = FALSE)
}

png_diff <- function(f1, f2) {
  a <- png::readPNG(f1); b <- png::readPNG(f2)
  if (!identical(dim(a), dim(b))) {
    return(list(n = NA_integer_, detail = paste0("dimensions differ: ",
      paste(dim(a), collapse = "x"), " vs ", paste(dim(b), collapse = "x"))))
  }
  neq <- a != b
  if (length(dim(a)) == 3L) neq <- apply(neq, c(1, 2), any)
  list(n = sum(neq), detail = "", mask = neq)
}

dump_diff <- function(a, b, max = 6L) {
  if (identical(a, b)) return("")
  n <- min(length(a), length(b))
  idx <- which(a[seq_len(n)] != b[seq_len(n)])
  out <- sprintf("lengths %d vs %d; %d differing lines", length(a), length(b), length(idx))
  for (i in head(idx, max)) out <- c(out, sprintf("  line %d:\n    A: %s\n    B: %s", i, a[i], b[i]))
  if (!length(idx) && length(a) != length(b)) {
    extra <- if (length(a) > n) a[(n + 1):length(a)] else b[(n + 1):length(b)]
    out <- c(out, paste0("  extra: ", head(extra, 3)))
  }
  paste(out, collapse = "\n")
}

# Compare two battery results; returns data.frame(id, channel, ok, detail).
compare_runs <- function(a, b, ids = names(a$records), diff_dir = NULL) {
  rows <- list()
  put <- function(id, ch, ok, detail = "") {
    rows[[length(rows) + 1L]] <<- data.frame(id = id, channel = ch, ok = ok,
      detail = detail, stringsAsFactors = FALSE)
  }
  for (id in ids) {
    ra <- a$records[[id]]; rb <- b$records[[id]]
    if (is.null(ra) || is.null(rb)) { put(id, "present", FALSE, "missing in one run"); next }
    if (!isTRUE(ra$ok) || !isTRUE(rb$ok)) {
      same <- identical(ra$ok, rb$ok) && identical(ra$error, rb$error)
      put(id, "error", same, if (same) paste("both error identically:", ra$error) else
        paste0("A: ", if (isTRUE(ra$ok)) "ok" else ra$error, " | B: ", if (isTRUE(rb$ok)) "ok" else rb$error))
      next
    }
    ident <- identical(ra$layer_data, rb$layer_data)
    det <- ""
    if (!ident) det <- paste(c(all.equal(ra$layer_data, rb$layer_data, tolerance = 0),
      paste("names A:", paste(names(ra$layer_data), collapse = ","), "| B:",
            paste(names(rb$layer_data), collapse = ","))), collapse = "\n")
    put(id, "layer_data", ident, det)
    put(id, "grob_dump", identical(ra$dump, rb$dump), dump_diff(ra$dump, rb$dump))
    pd <- png_diff(ra$png, rb$png)
    ok <- !is.na(pd$n) && pd$n == 0
    put(id, "pixels", ok, if (ok) "" else paste0(if (is.na(pd$n)) pd$detail else paste(pd$n, "pixels differ")))
    if (!ok && !is.null(diff_dir) && !is.na(pd$n)) {
      dir.create(diff_dir, showWarnings = FALSE, recursive = TRUE)
      img <- array(1, dim = c(dim(pd$mask), 3)); img[, , 2:3][pd$mask] <- 0
      png::writePNG(img, file.path(diff_dir, paste0("diff-", id, ".png")))
    }
    put(id, "class/length", identical(ra$cls, rb$cls) &&
          identical(a$len, b$len) && identical(a$layer_class, b$layer_class),
        paste0("class A: ", paste(ra$cls, collapse = "/"), " | B: ", paste(rb$cls, collapse = "/"),
               "; length A: ", a$len, " B: ", b$len))
    put(id, "messages", identical(ra$msgs, rb$msgs),
        paste0("A: ", paste(ra$msgs, collapse = " ; "), " | B: ", paste(rb$msgs, collapse = " ; ")))
  }
  do.call(rbind, rows)
}

main <- function() {
  RES <- data.frame(status = character(), part = character(), name = character(),
                    stringsAsFactors = FALSE)
  record <- function(status, part, name, detail = "") {
    RES[nrow(RES) + 1L, ] <<- list(status, part, name)
    cat(sprintf("[%s] %s  %s\n", status, part, name))
    if (nzchar(detail)) cat(paste0("      ", strsplit(detail, "\n")[[1]], collapse = "\n"), "\n", sep = "")
  }
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  script <- normalizePath(if (length(file_arg)) sub("^--file=", "", file_arg[1]) else "dev/verify-labels.R")
  root <- dirname(dirname(script))
  new_path <- normalizePath(Sys.getenv("LABELS_VERIFY_NEW", root))
  parts <- strsplit(Sys.getenv("LABELS_VERIFY_PARTS", "SABCD"), "")[[1]]
  out_dir <- Sys.getenv("LABELS_VERIFY_OUT", file.path(root, "dev", "labels-verification"))
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  out_dir <- normalizePath(out_dir)
  tmp <- tempfile("labels-verify-"); dir.create(tmp)
  retries <- as.integer(Sys.getenv("LABELS_VERIFY_RETRIES", "5"))
  wait <- as.numeric(Sys.getenv("LABELS_VERIFY_WAIT", "60"))
  need <- c("callr", "pkgload", "png", "ggplot2", "grid")
  miss <- need[!vapply(need, requireNamespace, NA, quietly = TRUE)]
  if (length(miss)) stop("missing packages: ", paste(miss, collapse = ", "))
  cat("NEW =", new_path, "\nOutput =", out_dir, "\nScratch =", tmp, "\n")
  cat("ragg available:", requireNamespace("ragg", quietly = TRUE), "\n\n")

  # OLD
  old_path <- Sys.getenv("LABELS_VERIFY_OLD", "")
  if (!nzchar(old_path)) {
    old_path <- file.path(tmp, "old"); dir.create(old_path)
    rc <- system2("sh", c("-c", shQuote(sprintf("git -C %s archive HEAD | tar -x -C %s",
                                                 shQuote(root), shQuote(old_path)))))
    if (rc != 0 || !file.exists(file.path(old_path, "DESCRIPTION"))) stop("git archive failed")
  }
  old_head <- tryCatch(system2("git", c("-C", shQuote(root), "rev-parse", "--short", "HEAD"),
                               stdout = TRUE), error = function(e) "?")
  cat("OLD =", old_path, "(git HEAD", old_head, ")\n\n")

  report_compare <- function(cmp, part, prefix = "") {
    for (id in unique(cmp$id)) {
      z <- cmp[cmp$id == id, ]
      bad <- z[!z$ok, ]
      if (!nrow(bad)) {
        record("PASS", part, sprintf("%s%s  [%s]", prefix, id, paste(z$channel, collapse = ", ")))
      } else {
        for (k in seq_len(nrow(bad))) {
          record("FAIL", part, sprintf("%s%s  %s", prefix, id, bad$channel[k]), bad$detail[k])
        }
      }
    }
  }

  # ---------------- S: self-test ----------------
  if ("S" %in% parts) {
    cat("== S: self-test of the comparison machinery (OLD vs OLD) ==\n")
    s1 <- sub_run(script, "run_battery", old_path, file.path(tmp, "s1"), "default")
    s2 <- sub_run(script, "run_battery", old_path, file.path(tmp, "s2"), "default")
    c0 <- compare_runs(s1, s2)
    nbad <- sum(!c0$ok)
    record(if (nbad == 0) "PASS" else "FAIL", "S",
           sprintf("OLD vs OLD: %d plots x channels, %d mismatches (must be 0)", nrow(c0), nbad),
           if (nbad) paste(utils::capture.output(print(c0[!c0$ok, ])), collapse = "\n") else "")
    n_err <- sum(vapply(s1$records, function(r) !isTRUE(r$ok), NA))
    record(if (n_err == 0) "PASS" else "INFO", "S", sprintf("%d of %d battery plots errored in OLD", n_err, length(s1$records)),
           if (n_err) paste(vapply(names(s1$records)[!vapply(s1$records, function(r) isTRUE(r$ok), NA)],
                        function(i) paste0(i, ": ", s1$records[[i]]$error), ""), collapse = "\n") else "")
    s3 <- sub_run(script, "run_battery", old_path, file.path(tmp, "s3"), "default",
                  perturb = list(id = "ucb_wrap_theme", args = list(conf_level = 0.5),
                                 id_class = "single", class = "perturbed"))
    c3 <- compare_runs(s1, s3)
    det <- function(id, ch) { z <- c3[c3$id == id & c3$channel == ch, ]; nrow(z) == 1 && !z$ok }
    for (ch in c("layer_data", "grob_dump", "pixels")) {
      record(if (det("ucb_wrap_theme", ch)) "PASS" else "FAIL", "S",
             sprintf("perturbation (conf_level 0.95 -> 0.5 in one plot) is detected by channel %s", ch))
    }
    record(if (det("single", "class/length")) "PASS" else "FAIL", "S",
           "perturbation (extra class on one plot object) is detected by channel class/length")
    others <- c3[!(c3$id %in% c("ucb_wrap_theme", "single")), ]
    record(if (all(others$ok)) "PASS" else "FAIL", "S",
           "perturbation leaves all other plots unreported (no false alarms)")
    # unit-level perturbations of the comparers
    a <- png::readPNG(s1$records$single$png); b <- a; b[10, 10, 1] <- if (b[10, 10, 1] > 0.5) 0 else 1
    tf <- tempfile(fileext = ".png"); png::writePNG(b, tf)
    d1 <- png_diff(s1$records$single$png, tf)$n
    record(if (identical(d1, 1L)) "PASS" else "FAIL", "S", sprintf("one flipped pixel is counted by the pixel comparer (got %s)", d1))
    dmp <- s1$records$single$dump
    i <- grep("[0-9]\\.[0-9]", dmp)[1]; dm2 <- dmp; dm2[i] <- sub("([0-9])\\.([0-9]+)", "\\1.\\2000000001", dm2[i])
    record(if (!identical(dmp, dm2) && nzchar(dump_diff(dmp, dm2))) "PASS" else "FAIL", "S",
           "a 1e-10 change to one coordinate in the grob dump is detected")
    lbl <- s1$records$single$dump; lbl2 <- sub("Male|\"M\"", "\"X\"", lbl)
    record(if (!identical(lbl, lbl2)) "PASS" else "INFO", "S",
           "dump contains the label strings (so label changes would be seen by the default dump comparison)")
    cat("\n")
  }

  # ---------------- A ----------------
  new_ready <- function() {
    tryCatch(sub_run(script, "run_battery_probe", new_path), error = function(e) conditionMessage(e))
  }
  if ("A" %in% parts) {
    cat("== A: OLD vs NEW, default path (no labels argument) ==\n")
    oldr <- sub_run(script, "run_battery", old_path, file.path(tmp, "oldA"), "default")
    newr <- NULL
    for (try in seq_len(retries)) {
      newr <- tryCatch(sub_run(script, "run_battery", new_path, file.path(tmp, "newA"), "default"),
                       error = function(e) { cat("NEW failed to run (try ", try, "): ",
                                                 substr(conditionMessage(e), 1, 300), "\n", sep = ""); NULL })
      if (!is.null(newr)) break
      if (try < retries) Sys.sleep(wait)
    }
    if (is.null(newr)) {
      record("FAIL", "A", "NEW could not be loaded/run (possibly half-written); part A not compared")
    } else {
      cmp <- compare_runs(oldr, newr, diff_dir = file.path(out_dir, "failures"))
      report_compare(cmp, "A")
      record(if (identical(oldr$len, newr$len) && oldr$len == 2L) "PASS" else "FAIL", "A",
             sprintf("length(geom_fourfold()): OLD %d, NEW %d (must both be 2)", oldr$len, newr$len))
      record(if (identical(oldr$gf_class, newr$gf_class)) "PASS" else "FAIL", "A",
             sprintf("class(geom_fourfold()): OLD %s, NEW %s", paste(oldr$gf_class, collapse = "/"),
                     paste(newr$gf_class, collapse = "/")))
      cat(sprintf("   (A: %d plots x %d channels compared)\n", length(unique(cmp$id)), length(unique(cmp$channel))))
    }
    cat("\n")
  }

  # ---------------- availability for B-D ----------------
  later <- intersect(c("B", "C", "D"), parts)
  new_has_labels <- FALSE
  if (length(later)) {
    for (try in seq_len(retries)) {
      probe <- tryCatch(sub_run(script, "labels_probe", new_path), error = function(e) conditionMessage(e))
      if (isTRUE(probe)) { new_has_labels <- TRUE; break }
      cat(sprintf("NEW has no usable labels argument yet (try %d/%d): %s\n", try, retries,
                  substr(as.character(probe)[1], 1, 200)))
      if (try < retries) Sys.sleep(wait)
    }
    if (!new_has_labels) {
      record("SKIP", paste(later, collapse = ""), "NEW does not accept geom_fourfold(labels = ) yet; B-D not run")
    }
    cat("\n")
  }

  # ---------------- B ----------------
  if ("B" %in% parts && new_has_labels) {
    cat("== B: NEW, labels = \"both\" ==\n")
    lev <- sub_run(script, "run_battery", new_path, file.path(tmp, "newLevels"), "levels")
    def <- sub_run(script, "run_battery", new_path, file.path(tmp, "newDefault"), "default")
    both <- sub_run(script, "run_battery", new_path, file.path(tmp, "newBoth"), "both")
    cmp0 <- compare_runs(def, lev, diff_dir = file.path(out_dir, "failures"))
    report_compare(cmp0, "B0", "labels = \"levels\" == default: ")
    record(if (lev$len == 2L) "PASS" else "FAIL", "B0", sprintf("length(geom_fourfold(labels = 'levels')) = %d (must be 2)", lev$len))
    record(if (both$len == 3L && "fourfold_labels" %in% both$third_class) "PASS" else
      if (both$len == 3L) "INFO" else "FAIL", "B1",
      sprintf("length(geom_fourfold(labels = 'both')) = %d (spec: 3, tagger class fourfold_labels)", both$len))
    for (id in names(lev$records)) {
      rl <- lev$records[[id]]; rb <- both$records[[id]]
      nm <- paste0("both vs levels: ", id)
      if (!isTRUE(rl$ok)) { record(if (isTRUE(rb$ok)) "FAIL" else "INFO", "B1", nm,
                                   paste("levels errored:", rl$error)); next }
      if (!isTRUE(rb$ok)) { record("FAIL", "B1", nm, paste("labels = 'both' errored:", rb$error)); next }
      fails <- character()
      if (!identical(rl$layer_data, rb$layer_data)) fails <- c(fails, "layer data differ")
      if (!identical(rl$masked, rb$masked)) fails <- c(fails, paste("masked grob dump differs:", dump_diff(rl$masked, rb$masked)))
      if (identical(rl$dump, rb$dump)) fails <- c(fails, "unmasked dump identical: labels = 'both' changed nothing")
      lab_l <- rl$labels; lab_b <- rb$labels
      if (!identical(lab_l$side, lab_b$side) || !identical(lab_l$panel, lab_b$panel)) {
        fails <- c(fails, "label grobs (panel/side) differ")
      } else {
        exp_lab <- paste0(ifelse(lab_l$side %in% c("top", "bottom"), rb$y, rb$x), ": ", lab_l$label)
        bad <- which(exp_lab != lab_b$label)
        if (length(bad)) fails <- c(fails, sprintf("%d labels wrong; first: got '%s' expected '%s' (panel %d, %s)",
          length(bad), lab_b$label[bad[1]], exp_lab[bad[1]], lab_b$panel[bad[1]], lab_b$side[bad[1]]))
        if (nrow(lab_b) != 4L * max(lab_b$panel)) fails <- c(fails, "not four labels per panel")
      }
      if (!identical(rl$msgs, rb$msgs)) fails <- c(fails, paste("messages differ:", paste(rb$msgs, collapse = " ; ")))
      if (!identical(rl$cls, rb$cls) && !identical(rb$cls[1], "fourfold_plot")) {
        fails <- c(fails, "plot class differs unexpectedly")
      }
      pd <- png_diff(rl$png, rb$png)
      if (!is.na(pd$n) && pd$n == 0) fails <- c(fails, "PNG identical: labels = 'both' not visible")
      record(if (length(fails)) "FAIL" else "PASS", "B1",
             sprintf("%s  (%d px differ; labels ok)", nm, if (is.na(pd$n)) NA else pd$n),
             paste(fails, collapse = "\n"))
    }

    cat("\n-- B2: name resolution --\n")
    nr <- sub_run(script, "run_names", new_path)
    chk_cases <- function(lst, part) {
      for (id in names(lst)) {
        r <- lst[[id]]
        if (!isTRUE(r$ok)) { record("FAIL", part, id, paste("error:", r$error)); next }
        lab <- r$labels
        if (is.null(r$expect)) {
          record("INFO", part, id, paste("labels drawn:", paste(unique(lab$label), collapse = " | ")))
          next
        }
        got_panels <- split(lab, lab$panel)
        ok <- if (is.list(r$expect)) {
          length(got_panels) == length(r$expect) && all(vapply(seq_along(got_panels), function(i)
            identical(got_panels[[i]]$label[match(names(r$expect[[i]]), got_panels[[i]]$side)], unname(r$expect[[i]])), NA))
        } else all(vapply(got_panels, function(z) identical(z$label[match(names(r$expect), z$side)], unname(r$expect)), NA))
        msg <- if (length(r$msgs)) paste("messages:", paste(r$msgs, collapse = " ; ")) else ""
        record(if (ok && !length(r$msgs)) "PASS" else "FAIL", part, id,
               if (!(ok && !length(r$msgs))) paste0("expected ", paste(unlist(r$expect), collapse = " | "), "\ngot      ",
                 paste(vapply(got_panels, function(z) paste(z$label, collapse = " | "), ""), collapse = "\n         "), "\n", msg) else "")
      }
    }
    chk_cases(nr$cases, "B2")
    chk_cases(nr$reuse, "B2")
    record(if (isTRUE(nr$layer_unmutated)) "PASS" else "FAIL", "B2",
           "shared layer object is not mutated by adding it to plots (geom_params$label_names stays NULL)")
    fb <- nr$fallback
    if (!isTRUE(fb$ok)) record("FAIL", "B2", "fallback (layer without names): errored", fb$error) else {
      fall_ok <- all(fb$labels$label %in% c("Admitted", "Rejected", "Male", "Female")) && length(fb$msgs) == 1L &&
        max(fb$labels$panel) == 2L
      record(if (fall_ok) "PASS" else "FAIL", "B2",
             "fallback: untagged layer draws bare levels and emits exactly one message for 2 panels",
             sprintf("messages (%d): %s\nlabels: %s", length(fb$msgs), paste(fb$msgs, collapse = " ; "),
                     paste(unique(fb$labels$label), collapse = " | ")))
    }
    ac <- nr$argchk
    record(if (grepl("labels", ac$invalid)) "PASS" else "FAIL", "B2", "invalid labels value errors", paste("error text:", ac$invalid))
    record(if (isTRUE(ac$explicit_default_equal) && ac$default_vector_len == 2L && identical(ac$vector_default_builds, TRUE)) "PASS" else "FAIL", "B2",
           "labels = c('levels','both') behaves as 'levels'")
    record(if (identical(ac$plain_plot_class_after_levels, ac$plain_plot_class_after_both) ||
               TRUE) "INFO" else "INFO", "B2",
           sprintf("class(plot)[1]: levels -> %s, both -> %s", ac$plain_plot_class_after_levels, ac$plain_plot_class_after_both))

    cat("\n-- B3: gallery (PNG pairs in dev/labels-verification/) --\n")
    gal <- sub_run(script, "run_gallery", new_path, out_dir)
    for (id in names(gal)) {
      g <- gal[[id]]
      record(if (g$labels_ok && !length(g$msgs)) "PASS" else "FAIL", "B3",
             sprintf("gallery-%s.png (labels in %d panel(s) as expected)", id, g$n_panels),
             if (length(g$msgs)) paste(g$msgs, collapse = "\n") else "")
    }
    cat("   (Visual review of the gallery is manual: open the PNG files.)\n")
    cat("\n")
  }

  # ---------------- C ----------------
  if ("C" %in% parts && new_has_labels) {
    cat("== C: NEW with other packages ==\n")
    ctrl_ok <- list(FALSE)
    for (pk in c("patchwork", "cowplot", "gganimate")) {
      if (!requireNamespace(pk, quietly = TRUE)) { record("SKIP", "C", paste(pk, "not installed")); next }
      r <- tryCatch(sub_run(script, "run_packages", new_path, pk, out_dir),
                    error = function(e) conditionMessage(e))
      if (is.character(r)) { record("FAIL", "C", paste(pk, "worker failed"), r); next }
      ids <- names(r)
      if (pk == "gganimate") ids <- c(grep("^H:", ids, value = TRUE), grep("^H:", ids, value = TRUE, invert = TRUE))
      for (id in ids) {
        x <- r[[id]]
        if (pk != "gganimate") {
          if (!isTRUE(x$ok)) { record("FAIL", "C", id, paste("error:", x$error)); next }
          ok <- identical(sort(x$got), sort(x$expect)) && !length(x$msgs)
          record(if (ok) "PASS" else "FAIL", "C", id, if (ok) "" else
            paste0("expected (sorted): ", paste(sort(x$expect), collapse = " | "), "\ngot (sorted):      ",
                   paste(sort(x$got), collapse = " | "), "\nmessages: ", paste(x$msgs, collapse = " ; ")))
        } else {
          inf <- x$info
          nm <- function(z) if (is.null(z)) "NULL" else if (is.character(z)) paste(names(z), z, sep = "=", collapse = ", ") else "?"
          want <- c(x = sub(": .*", "", x$expect[2]), y = sub(": .*", "", x$expect[1]))  # left label -> x name, top -> y name
          stale <- c(x = "Gender", y = "Admit")
          fourfold_first <- !is.na(inf$fourfold_idx) && (is.na(inf$gganim_idx) || inf$fourfold_idx < inf$gganim_idx)
          eff <- if (fourfold_first) inf$resolved else inf$add_time
          det <- paste0("class head: ", paste(inf$class_head, collapse = "/"), "\nadd-time names: ", nm(inf$add_time),
                        "\nbuild-time resolution (helper, inferred; gganimate's build is not what runs here): ", nm(inf$resolved),
                        "\nnames that would be used: ", nm(eff), "  (", if (fourfold_first) "fourfold_plot method runs first" else
                          "gganimate's ggplot_build() method wins; build-time step skipped", ")")
          if (x$kind == "control") {
            ctrl_ok[[1]] <- isTRUE(x$ok) && x$frames == 2L
            record(if (is.null(inf$add_time) && !fourfold_first) "PASS" else "FAIL", "C", paste("gganimate", id, "- plot state"), det)
            record(if (ctrl_ok[[1]]) "PASS" else "INFO", "C", paste("gganimate", id, "- animate() to 2 PNG frames"),
                   paste0(if (ctrl_ok[[1]]) "" else paste0("animate() fails even with labels = 'levels': ", x$error, "\n"), "frames: ", x$frames))
            next
          }
          wanted <- identical(eff, want)
          kind <- x$kind
          st <- if (kind %in% c("ordinary", "added_after_transition_first", "replaced_after_transition_first")) {
            if (wanted) "PASS" else "FAIL"
          } else if (kind == "added_after_transition_last") {
            if (wanted) "PASS" else if (is.null(eff)) "EXPECTED-LIMITATION" else "FAIL"
          } else {  # replaced_after_transition_last, replaced_after_all
            if (wanted) "PASS" else if (identical(eff, stale)) "EXPECTED-LIMITATION" else "FAIL"
          }
          note <- switch(st, `EXPECTED-LIMITATION` = if (is.null(eff)) "no names: bare levels + one message, as the spec's limitation describes\n" else
            "stale add-time names, as the spec's limitation describes\n", "")
          record(st, "C", paste("gganimate", id, "- names"), paste0(note, det))
          if (isTRUE(ctrl_ok[[1]])) {
            rendered <- isTRUE(x$ok) && x$frames == 2L
            record(if (rendered) "PASS" else "FAIL", "C", paste("gganimate", id, "- animate() to 2 PNG frames"),
                   paste0("frames: ", x$frames, "; labels drawn: ", paste(unique(x$labels), collapse = " | "),
                          "\nmessages: ", paste(x$msgs, collapse = " ; "), if (!rendered) paste("\nerror:", x$error) else ""))
          }
        }
      }
    }
    cat("\n")
  }

  # ---------------- D ----------------
  if ("D" %in% parts && new_has_labels) {
    cat("== D: vcd comparison ==\n")
    if (!requireNamespace("vcd", quietly = TRUE)) record("SKIP", "D", "vcd not installed") else {
      v <- tryCatch(sub_run(script, "run_vcd", new_path, out_dir), error = function(e) conditionMessage(e))
      if (is.character(v)) record("FAIL", "D", "vcd worker failed", v) else {
        cat("   vcd source lines placing labels:\n"); cat(paste0("     ", trimws(v$vcd_src_label_lines)), sep = "\n")
        cat("   vcd labels of the first stratum (read from vcd's drawn grobs):\n")
        print(v$vcd_first, row.names = FALSE)
        gg1 <- v$gg_labels[v$gg_labels$panel == 1, ]
        vc <- setNames(v$vcd_first$label, v$vcd_first$side)
        gg <- setNames(gg1$label, gg1$side)
        same <- identical(vc[sort(names(vc))], gg[sort(names(gg))])
        record(if (same) "PASS" else "FAIL", "D",
               "first stratum: label on each side equals vcd's (top/left/bottom/right)",
               paste0("vcd: ", paste(names(vc), vc, sep = "=", collapse = " | "), "\nggfourfold: ",
                      paste(names(gg), gg, sep = "=", collapse = " | ")))
        all_same <- all(vapply(split(v$gg_labels, v$gg_labels$panel), function(z) {
          identical(setNames(z$label, z$side)[sort(z$side)], gg[sort(names(gg))])
        }, NA))
        record(if (all_same) "PASS" else "FAIL", "D", "all six ggfourfold panels carry the same four label strings (Admit/Gender fixed)")
        cat("   images:", paste(v$files, collapse = ", "), "\n")
      }
    }
    cat("\n")
  }

  # ---------------- summary ----------------
  cat("== SUMMARY ==\n")
  tab <- table(RES$status)
  print(tab)
  cat("\nBy part:\n"); print(table(RES$part, RES$status))
  nfail <- sum(RES$status == "FAIL")
  cat(sprintf("\n%s (%d FAIL)\n", if (nfail) "OVERALL: FAIL" else "OVERALL: PASS", nfail))
  utils::write.csv(RES, file.path(out_dir, "last-run-results.csv"), row.names = FALSE)
  quit(status = if (nfail) 1L else 0L)
}

`%||%` <- function(a, b) if (is.null(a)) b else a
run_battery_probe <- function(pkg) { load_pkg(pkg); TRUE }
labels_probe <- function(pkg) {
  load_pkg(pkg)
  "labels" %in% names(formals(geom_fourfold)) &&
    length(geom_fourfold(labels = "both")) >= 1L
}

if (identical(Sys.getenv("LABELS_VERIFY_WORKER"), "")) main()
