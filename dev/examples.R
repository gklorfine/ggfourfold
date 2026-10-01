# Examples for geom_fourfold().
#
# Run the complete file from the package root with:
#   Rscript dev/examples.R
#
# In RStudio, source the file once, then run individual example sections to
# display their named plot objects in the Plots pane.

# The directory of this script when it is run with source() or Rscript,
# otherwise the working directory. load_all() finds the package root from
# there. source() is checked first: when this file is sourced from another
# script run with Rscript, --file names that other script.
.fourfold_examples_dir <- function() {
  source_files <- vapply(
    sys.frames(),
    function(frame) {
      if (is.null(frame$ofile)) NA_character_ else frame$ofile
    },
    character(1)
  )
  source_files <- source_files[!is.na(source_files)]
  if (length(source_files)) {
    file <- tail(source_files, 1)
    # With source(chdir = TRUE), a relative path no longer resolves from the
    # new working directory, which is the script's own.
    if (!file.exists(file)) file <- basename(file)
    return(dirname(normalizePath(file)))
  }

  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg)) {
    return(dirname(normalizePath(sub("^--file=", "", file_arg[1]))))
  }

  getwd()
}

pkgload::load_all(.fourfold_examples_dir(), quiet = TRUE)
library(ggplot2)

# Interactively, display the plot. Otherwise draw it on a null device, so
# that running the file with Rscript checks every example, including the
# count placement done at drawing time.
.show_fourfold_example <- function(x) {
  if (interactive()) {
    print(x)
  } else if (inherits(x, "ggplot")) {
    grDevices::pdf(NULL)
    on.exit(grDevices::dev.off())
    print(x)
  }
  invisible(x)
}


# 1. A single 2-by-2 table -------------------------------------------------

trial <- data.frame(
  Treatment = factor(
    rep(c("Control", "Treated"), each = 2),
    levels = c("Control", "Treated")
  ),
  Outcome = factor(
    rep(c("Improved", "Not improved"), 2),
    levels = c("Improved", "Not improved")
  ),
  Freq = c(20, 30, 35, 15)
)

single_table <- ggplot(
  trial,
  aes(x = Treatment, y = Outcome, weight = Freq)
) +
  geom_fourfold() +
  labs(title = "Treatment outcome") +
  theme_fourfold()

.show_fourfold_example(single_table)


# 2. One faceting variable, wrapped ---------------------------------------
# This is the compact 2-by-3 counterpart of vcd::fourfold(UCBAdmissions).

ucb <- as.data.frame(UCBAdmissions)

ucb_wrap <- ggplot(
  ucb,
  aes(x = Gender, y = Admit, weight = Freq)
) +
  geom_fourfold() +
  facet_wrap(vars(Dept), ncol = 3, labeller = label_both) +
  labs(title = "Berkeley admissions") +
  theme_fourfold()

.show_fourfold_example(ucb_wrap)


# 3. One faceting variable with facet_grid() ------------------------------
# facet_grid() is useful when the strata should stay in one fixed row or
# column. A three-department subset fits a typical RStudio plot pane well.

ucb_grid <- ggplot(
  subset(ucb, Dept %in% c("A", "B", "C")),
  aes(x = Gender, y = Admit, weight = Freq)
) +
  geom_fourfold() +
  facet_grid(cols = vars(Dept), labeller = label_both) +
  labs(title = "Berkeley admissions: departments A-C") +
  theme_fourfold()

.show_fourfold_example(ucb_grid)


# 4. Two faceting variables with facet_grid() -----------------------------

titanic <- droplevels(subset(
  as.data.frame(Titanic),
  Class %in% c("1st", "2nd", "3rd")
))

titanic_grid <- ggplot(
  titanic,
  aes(x = Sex, y = Survived, weight = Freq)
) +
  # Suppressing confidence rings keeps this layout example focused on the
  # two-variable facet design. (Every 1st- and 2nd-class child survived, so
  # those panels have an empty row; see "Zero counts" in ?geom_fourfold.)
  geom_fourfold(conf_level = 0) +
  facet_grid(
    rows = vars(Age),
    cols = vars(Class),
    labeller = label_both
  ) +
  labs(title = "Titanic survival by age and passenger class") +
  theme_fourfold(base_size = 11)

.show_fourfold_example(titanic_grid)


# 5. Raw observations (weight defaults to 1) ------------------------------

cars <- transform(
  mtcars,
  Transmission = factor(
    am, levels = c(0, 1), labels = c("Automatic", "Manual")
  ),
  Engine = factor(
    vs, levels = c(0, 1), labels = c("V-shaped", "Straight")
  )
)

raw_observations <- ggplot(
  cars,
  aes(x = Transmission, y = Engine)
) +
  geom_fourfold() +
  labs(title = "Transmission and engine shape") +
  theme_fourfold()

.show_fourfold_example(raw_observations)


# 6. Statistical and visual controls --------------------------------------
# Palette entries retain their semantic fourfold roles; they are not a fill
# scale. Text size and family belong in theme_fourfold().

soft_palette <- c(
  "#B8D8F0", "#79A8CE",
  "#F5B7B1", "#B8B5E8",
  "#D1495B", "#4056A1"
)

customized <- ggplot(
  ucb,
  aes(x = Gender, y = Admit, weight = Freq)
) +
  geom_fourfold(
    std = "ind.max",
    conf_level = 0.90,
    p_adjust_method = "bonferroni",
    palette = soft_palette,
    colour = "grey15",
    linewidth = 0.35
  ) +
  facet_wrap(vars(Dept), ncol = 3, labeller = label_both) +
  labs(
    title = "Berkeley admissions",
    subtitle = "Individual-maximum standardization; 90% confidence rings",
    caption = "P-values adjusted across panels using Bonferroni"
  ) +
  theme_fourfold(base_size = 14, base_family = "sans")

.show_fourfold_example(customized)


# Other useful statistical variants:
#
#   geom_fourfold(std = "margins", margin = 1)
#   geom_fourfold(std = "margins", margin = 2)
#   geom_fourfold(std = "all.max")
#   geom_fourfold(conf_level = 0)       # omit confidence rings
#   geom_fourfold(extended = FALSE)     # omit significance emphasis/ticks


# 7. Inspect the computed statistics --------------------------------------
# There are four rows per panel, so retain one row per PANEL for a concise
# odds-ratio and inference summary.

ucb_computed <- ggplot_build(ucb_wrap)$data[[1]]
ucb_inference <- ucb_computed[
  !duplicated(ucb_computed$PANEL),
  c(
    "PANEL", "odds_ratio", "standard_error",
    "conf_low", "conf_high", "p_value", "p_adjusted", "significant"
  )
]
ucb_inference$Dept <- levels(ucb$Dept)[as.integer(ucb_inference$PANEL)]
ucb_inference <- ucb_inference[
  c("Dept", setdiff(names(ucb_inference), c("Dept", "PANEL")))
]

.show_fourfold_example(ucb_inference)


# 8. Export ---------------------------------------------------------------
# Uncomment the formats you need. Width and height are in inches; vector
# output preserves the same layout without depending on a raster resolution.

if (FALSE) {
  dir.create("dev/output", showWarnings = FALSE, recursive = TRUE)

  ggsave(
    "dev/output/ucb-fourfold.png",
    ucb_wrap,
    width = 10,
    height = 7,
    units = "in",
    dpi = 300,
    bg = "white"
  )
  ggsave(
    "dev/output/ucb-fourfold.pdf",
    ucb_wrap,
    width = 10,
    height = 7,
    units = "in",
    bg = "white"
  )
  ggsave(
    "dev/output/ucb-fourfold.svg",
    ucb_wrap,
    width = 10,
    height = 7,
    units = "in",
    bg = "white"
  )
}
