test_that("fourfold_palette() returns the named palettes", {
  vcd <- c("#99CCFF", "#6699CC", "#FFA0A0", "#A0A0FF", "#FF0000", "#000080")
  okabe_ito <- c("#56B4E9", "#0072B2", "#F2CF7F", "#AAD9F3", "#D55E00", "#0072B2")
  expect_identical(fourfold_palette(), vcd)
  expect_identical(fourfold_palette("vcd"), vcd)
  expect_identical(fourfold_palette("okabe-ito"), okabe_ito)
  expect_identical(fourfold_palette("okabe"), okabe_ito)
  expect_identical(.fourfold_defaults$palette, vcd)
  expect_identical(formals(geom_fourfold)$palette, quote(fourfold_palette()))
  # The non-significant pair is the Okabe-Ito orange and sky blue mixed
  # about halfway with white.
  halfway <- (grDevices::col2rgb(c("#E69F00", "#56B4E9")) + 255) / 2
  expect_true(all(abs(grDevices::col2rgb(okabe_ito[3:4]) - halfway) <= 1))
  for (invalid in list("viridis", NA_character_, c("vcd", "okabe-ito", "x"), 1)) {
    expect_error(
      fourfold_palette(invalid),
      '`palette` must be one of "vcd" or "okabe-ito"',
      fixed = TRUE
    )
  }
})
