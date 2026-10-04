#' Palettes for fourfold displays
#'
#' `fourfold_palette()` returns six colours for the `palette` argument of
#' [geom_fourfold()]. The colours encode the direction and statistical
#' strength of association and are drawn directly by the geom rather than
#' through a fill scale.
#' Entries 1-2 are used when `extended = FALSE` (or `conf_level = 0`),
#' entries 3-4 for an extended display without adjusted significance, and
#' entries 5-6 for an extended display with adjusted significance. Within
#' each pair, the first colour fills the diagonal with fewer cases than
#' expected under independence and the second fills the diagonal with more.
#'
#' `"vcd"`, the default, gives the colours of `vcd::fourfold()` (Meyer et
#' al., 2026): light and darker blue, then light red and light blue, then red
#' and navy.
#'
#' `"okabe-ito"` uses the colours of Okabe and Ito (2008), chosen to remain
#' distinguishable for readers with common forms of colour-vision deficiency:
#' sky blue and blue, then orange and sky blue lightened about halfway to
#' white, then vermillion and blue.
#'
#' @param palette Name of the palette: `"vcd"` (the default) or
#'   `"okabe-ito"`.
#'
#' @return A character vector containing six hexadecimal colours.
#'
#' @references
#' Meyer, D., Zeileis, A., Hornik, K., & Friendly, M. (2026). *vcd:
#' Visualizing Categorical Data* (R package).
#' \doi{10.32614/CRAN.package.vcd}
#'
#' Okabe, M., & Ito, K. (2008). *Color Universal Design (CUD): How to make
#' figures and presentations that are friendly to colorblind people*.
#' <https://jfly.uni-koeln.de/color/>
#'
#' @seealso [geom_fourfold()] and [grDevices::palette.colors()]
#'
#' @examples
#' fourfold_palette()
#' fourfold_palette("okabe-ito")
#'
#' ucb <- as.data.frame(UCBAdmissions)
#'
#' ggplot2::ggplot(
#'   ucb,
#'   ggplot2::aes(x = Gender, y = Admit, weight = Freq)
#' ) +
#'   geom_fourfold(palette = fourfold_palette("okabe-ito")) +
#'   ggplot2::facet_wrap(ggplot2::vars(Dept), ncol = 3) +
#'   theme_fourfold()
#'
#' @export
fourfold_palette <- function(palette = c("vcd", "okabe-ito")) {
  palette <- .fourfold_match_arg(palette, c("vcd", "okabe-ito"), "palette")
  switch(palette,
    vcd = c(
      "#99CCFF", "#6699CC",
      "#FFA0A0", "#A0A0FF",
      "#FF0000", "#000080"
    ),
    "okabe-ito" = c(
      "#56B4E9", "#0072B2",
      "#F2CF7F", "#AAD9F3",
      "#D55E00", "#0072B2"
    )
  )
}
