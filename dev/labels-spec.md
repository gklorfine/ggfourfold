# Spec: `labels = "both"` for `geom_fourfold()`

Working spec for the feature requested in `dev/notes-for-Gavin.md` (MF's points 1 and 2).
This file is the single source of truth for the implementation, the tests and the reviews.

## Background

In a fourfold display the `x` variable's two levels are drawn on the **left and right**
sides (rotated 90 degrees) and the `y` variable's two levels on the **top and bottom**.
Today only the bare levels are drawn ("No", "Yes"), so with No/Yes levels on both
variables a reader cannot tell which variable is which. `vcd::fourfold()` labels each side
"Var: level".

## User-facing behaviour

New argument on `geom_fourfold()`:

```r
geom_fourfold(..., labels = c("levels", "both"))
```

- `"levels"` (default): output is **exactly** what it is today. Nothing about the returned
  object, the built data, the grobs or the rendering may change on this path.
- `"both"`: each of the four side labels reads `paste0(<variable name>, ": ", <level>)`,
  e.g. "Gender: Male" (left), "Gender: Female" (right), "Admit: Admitted" (top),
  "Admit: Rejected" (bottom). Separator is `": "`, as in `ggplot2::label_both`.
- `<variable name>` is the label of the expression mapped to `x` / `y`, computed with
  `rlang::as_label()` on the mapping's quosure (so `aes(x = Gender)` gives "Gender",
  `aes(x = .data$Gender)` gives "Gender", `aes(x = factor(admit))` gives "factor(admit)").
  `labs()` and scale names play **no** part.
- `<level>` is whatever is drawn today (so `scale_x_discrete(labels = )` renames still apply).
- Invalid values error through the existing `.fourfold_match_arg()` helper, in the same
  style as `shape` and `counts`.
- Counts, sectors, rings, diagonal, frame and the built layer data are unaffected by
  `labels`.

## Mechanism (decided; do not redesign)

The geom cannot see variable names at draw time, so they are handed to it as an internal
geom parameter, `label_names`: a character vector `c(x = "...", y = "...")`, or `NULL`.

The names are resolved at **two** moments (a "hybrid"):

1. **Add time** — when the result of `geom_fourfold(labels = "both")` is added to a plot.
2. **Build time** — when the plot is built (print, `ggsave()`, `ggplotGrob()`,
   `layer_data()`), when the mapping is final. This overwrites the add-time names.

Both use only ggplot2's exported S3 generics `ggplot_add()` and `ggplot_build()`.
Do **not** override `Layer$setup_layer()`, use `layer(layer_class = )`, or use `:::`.

### Pieces

- `geom_fourfold()`
  - `labels = "levels"`: returns `list(layer, coord)` exactly as today. No extra element,
    no class tag, `label_names` not needed.
  - `labels = "both"`: returns `list(layer, coord, tagger)` where `tagger` is a small
    classed object (S3 class `fourfold_labels`). The layer carries the geom params
    `labels = "both"` and `label_names = NULL`.
- One internal helper, e.g. `.fourfold_resolve_label_names(plot)`: for every layer in
  `plot@layers` whose geom inherits from `GeomFourfold` and whose `geom_params$labels` is
  `"both"`, replace that layer **with a copy** (a ggproto child of the layer instance, e.g.
  `ggplot2::ggproto(NULL, layer, geom_params = <updated>)`) whose
  `geom_params$label_names` holds the resolved names. Never mutate a layer object in place:
  layer objects have reference semantics and may be shared between plots.
  - Effective mapping of a layer: if `inherit.aes` is `TRUE`, the plot mapping overridden
    by the layer mapping (an explicit `NULL` in the layer mapping removes the inherited
    aesthetic, as in ggplot2); otherwise the layer mapping alone.
  - If either `x` or `y` has no mapping, `label_names` is `NULL`.
- `ggplot_add()` method for class `fourfold_labels`: run the helper on the plot (the layer
  has already been added, as list elements are added in order), then prepend the S3 class
  `fourfold_plot` to the plot's class if it is not already there. Return the plot.
- `ggplot_build()` method for class `fourfold_plot`: run the helper on the plot, then
  `NextMethod()` so ggplot2 (or another package's method) builds the modified plot.
- `GeomFourfold`
  - `labels` and `label_names` are added to `extra_params`; `labels` is added to
    `.fourfold_defaults` as `"levels"`.
  - `draw_panel()` gains `labels` and `label_names` arguments (defaults give today's
    behaviour, so direct `layer(geom = GeomFourfold, ...)` use is unchanged). With
    `labels = "both"` and usable `label_names`, it pastes the name onto each side label.
  - Fallback: with `labels = "both"` but no usable `label_names`, draw the bare levels and
    emit **one** `message()` per plot build (not one per panel) explaining that the
    variable names could not be found so only the levels are shown, and that the mapping
    should be supplied before `geom_fourfold()`. Emit it from `GeomFourfold$setup_params()`,
    which runs once per layer per build.
- Registration: roxygen `@exportS3Method ggplot2::ggplot_add` and
  `@exportS3Method ggplot2::ggplot_build`; regenerate `NAMESPACE` with
  `devtools::document()`.
- `rlang` is added to `Imports` in `DESCRIPTION` (it is already a hard dependency of
  ggplot2) and used as `rlang::as_label()`.

## Known, accepted limitation

`gganimate` puts its own class on the plot and its `ggplot_build()` method does not call
the next method. When the transition is added after the fourfold layer (the usual order),
the build-time step is skipped and only the add-time names are used. So under gganimate
only: `aes()` added after the layer gives no names (fallback + message), and `aes()`
replaced after the layer gives stale names. This is accepted and must not be "fixed" by
switching mechanism.

## Out of scope

- No version change in `DESCRIPTION`.
- No documentation notes about long names or `factor()` expressions.
- No reading of `labs()`.
- `gganimate`, `patchwork`, `cowplot` are **not** added to `Suggests`; interaction checks
  with them live in `dev/`, not in `tests/testthat/`.

## Documentation (drafts; GK reviews them at the end)

- `@param labels` for `geom_fourfold()`.
- In `@details`, after the sentence that says the `x` levels are left/right and the `y`
  levels top/bottom: a sentence saying that `theme_fourfold()` hides the axis titles, and
  that if they are turned back on ggplot2 draws the `x` title below the panel, next to the
  `y` levels (and the `y` title on the left, next to the `x` levels), so `x` and `y` must be
  swapped in `labs()`, or `labels = "both"` used instead.
- `@return`: mention the third list element for `labels = "both"`.
- One example using `labels = "both"`.
- `NEWS.md`: one bullet under a new top heading `# ggfourfold (development version)`.

## Shared-tree rules for every agent

- Several agents work in this checkout at once. Edit only the files assigned to you.
- Never run `git stash`, `git checkout`, `git reset`, `git commit`, `git add` or anything
  else that changes git state or the working tree of files you do not own.
- The released behaviour to compare against is `git show HEAD:<path>` /
  `git archive HEAD` extracted into a directory **outside** the repository.

## Amendments after review round 1

These override anything above that they contradict.

- **Fallback message count.** It is emitted once per fourfold layer per build (never once
  per panel). A plot with two fallback layers therefore gives two messages. This is
  intended; it is not deduplicated across layers.
- **Fallback message text.** In practice the fallback is reached when the layer is added
  without the rest of what `geom_fourfold()` returns (or made with `layer()` directly); a
  missing `x`/`y` mapping stops in the stat first. The text is exactly:
  `` `labels = "both"` could not find the names of the `x` and `y` variables, so only the levels are shown. Add everything that `geom_fourfold()` returns to the plot, not the layer alone. ``
  It stays a `message()`.
- **NA level labels.** A level label that is `NA` (e.g. from `scale_x_discrete(labels = )`)
  stays `NA` with `labels = "both"`, so nothing is drawn for that side, exactly as with
  `"levels"`. The name is pasted only onto non-missing level labels.
- **No needless copies.** `.fourfold_resolve_label_names()` leaves a layer alone (no new
  copy) when its `geom_params$label_names` is already identical to the freshly resolved
  names. So adding further `labels = "both"` layers, or rebuilding, does not lengthen a
  layer's chain of copies.
- **`label_names` in `...`.** `geom_fourfold(labels = "both", label_names = <anything>)`
  must not warn about duplicated parameters; the user's value is discarded (the names
  always come from the mapping).
- **Not changed (accepted):** `aes(x = stage(Gender))` gives "stage(Gender): ...", like
  other expressions; the tagger has no print method.

## Amendments after review round 2

- **Accepted limitation, same mechanism as gganimate.** A layer taken out of a tagged plot
  (`p@layers[[1]]`) and added to another, untagged plot keeps the names resolved for the
  first plot, because the build-time step only runs for tagged plots. Not handled.
- **Axis titles under ggplot2's default theme.** There the axis text (the level names on
  ordinary axes) is drawn as well, and each axis title sits next to its own axis text, so
  the reading is unambiguous. The documentation note therefore stays scoped to
  `theme_fourfold()` (which hides axis text and titles) with the titles turned back on.
