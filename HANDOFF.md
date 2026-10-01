# Handoff — 2026-10-01

## Update (Claude, 2026-10-01): coordinate-system change implemented, uncommitted

The coordinate task further below is superseded. The plan in
`dev/coordinate-system-plan.md` (rewritten by Claude, agreed by GK) is implemented in the
working tree, uncommitted, and recorded as done in the `issues/TASKS.md` item "The geom
draws outside ggplot2's coordinate system" (implementation, verification, reviews).

- `geom_fourfold()` returns `list(layer, coord_cartesian(reverse = "y", ratio = 1,
  default = TRUE))`, like `geom_sf()`; the display's viewport is rescaled from
  `coord$transform()`; `coord_flip()`/non-Cartesian are errors; counts are placed
  correctly under any reversal.
- Decision B (GK, after review): `theme_fourfold()` no longer sets `aspect.ratio`; the
  coordinate ratio keeps circles round. No missing-value hint warning.
- Verified: statistics identical, 260 default images identical, alignment and text
  checks pass on ggplot2 4.0.3 and 4.0.0; 2,248 test expectations; R CMD check
  --as-cran clean. Two independent Opus reviews approved; their findings are addressed.
- Next: GK to review and commit. New small follow-ups are in TASKS under "Diagnostic
  follow-ups". The count-reach bug (`conf_low_radius` ignored) is still open.
- Scratch material (harness, reviews, baseline worktree `scratchpad/base`) is in
  Claude's session scratchpad, not the repository.
- At GK's request, the GPT review and experiment files named in the superseded section
  below (`dev/coordinate-system-plan-astra-review.md`,
  `dev/coordinate-system-review-experiments.R`) were deleted, not committed; their
  findings are summarised in the History table of `dev/coordinate-system-plan.md`.

## Current task: coordinate plan and independent Astra review

The user explicitly requested this handoff to Claude. Start by reading
`dev/coordinate-system-plan.md`, then
`dev/coordinate-system-plan-astra-review.md`; the review identifies changes that
are NOT incorporated in the plan yet. This session authorized planning and review,
not implementation of the package fix. Preserve the user-facing requirements
below when proposing amendments. Ask the user about material remaining choices
instead of reverting to a mandatory coord_fourfold() or extra normal-use settings.

The user asked for an explanation of the coordinate-system issue in
issues/TASKS.md, then a repair plan with a statistician subagent, and finally a
detailed independent review using GPT-6 Astra. Their requirements are to preserve
top-first orientation matching vcd and previous defaults, keep panel aspect under
theme_fourfold() like the mosaic packages, and make ordinary added layers align
without requiring a new coord_fourfold() or extra settings for normal plots.

Created dev/coordinate-system-plan.md. Its revised architecture is a coord-aware
geom plus an addition component that installs ordinary default y reversal, with
theme aspect1 and no fixed coordinate ratio. No production implementation changes
were made. The initial default check needs revision following the review below.

A fresh independent GPT-6 Astra subagent reviewed sources and ran experiments.
Its detailed findings are saved separately in
dev/coordinate-system-plan-astra-review.md. Verdict: revise plan, then proceed;
the core architecture is sound, but explicit decisions are required before coding.
The plan itself has not yet been amended to incorporate this review.

Main required amendments:

- Missing-value categories can expand only one axis despite identical statistics,
  distorting circles and all.max comparisons with free scales. Choose a shared-scale
  policy; do not silently filter another layer's NA category. Common symmetric
  bounds require layout-aware metadata, not just static geom setup_data bounds.
- coord$default is not provenance. Explicit pristine default=TRUE is indistinguishable
  from implicit defaults. Preserve customized coords even if defaultTRUE; use an
  exact pristine predicate and owned-coordinate marker; qualify the explicit-wins
  promise for this indistinguishable exception.
- Existing .fourfold_counts_reach() omits conf_low_radius, which can be the largest
  outline (negative-association example c(2,5,5,2)). Include BOTH CI bounds in reach.
- Count clearance already differs by physical panel size. Recommend shared geometric
  reach plus per-panel physical-clearance moves, documented; avoid stale/shared
  draw-time state. Decide typography panel versus frame scaling.
- Supported update_ggplot component wrapper changes public return type from Layer;
  acknowledge this, consider direct S7 dependency, avoid unsupported Layer overrides.
- Free scales with fixed panel space work; free panel space conflicts with square
  theme aspect. Qualify support and test both facet types.
- Distinguish circularity, within-panel area ratios, and cross-panel area multipliers.
  Prefer actionable anisotropy warning, retaining theme ownership.
- Numeric geometry bounds can prevent continuous.limits/expand from contracting the
  display; coordinate limits govern zoom. Clarify clipping and supported coordinates.

Experiment script: /tmp/astra-fourfold-review.R (54 lines). All version experiments
used installed ggplot2 4.0.3; executing the minimum supported 4.0.0 remains a gate.
The core experiment will also be preserved at
`dev/coordinate-system-review-experiments.R` for the handoff. The full review
records additional physical experiments not all reproduced by that core script.
Current untracked files are the plan, review, and preserved experiment script.
This HANDOFF update is required by CLAUDE.md; at handoff the five-hour account
window was 93% used (7% remaining).
Do not imply the package fix or full validation has been implemented.

Suggested continuation:

1. Amend the plan for all eight Astra findings. Prioritize missing-category scale
   policy, coordinate precedence/provenance exception, public component return
   type, and precise count-placement guarantees.
2. Preserve ordinary `geom_fourfold() + theme_fourfold()` syntax and top-first
   orientation. Keep aspect in the theme; coordinate reversal affects all layers.
3. Once implementation is authorized, use supported addition hooks, transform ALL
   drawing through the plot coordinate, and fix both-confidence-bound reach.
4. Verify exact statistical invariance, actual point/text alignment, physical
   shape/area comparisons, addition order/reuse, missing categories, facet space,
   device resizing, coordinate clipping/zoom, and oldest supported ggplot2.
   Run package tests, independent vcd verification, visual comparisons, package
   checks, and repository-required extrachecks.

Useful quantitative evidence (details and reproducible cases in the review):

- NA x retained by the scale expands x from 0.2–2.8 to 0.2–3.6 while y stays
  0.2–2.8 and statistics remain identical. Free-scale identical tables then had
  physical area multipliers 1.441209 versus 1.884658 (ratio 0.7647059).
- Table c(2,5,5,2), square shape, ticks0: current reach 0.7489985 versus true
  both-CI reach 0.8353744; nominal count limit is 0.8.
- Same reach0.74 and label5: counts move outside a 1-inch panel but stay inside a
  4-inch panel because of minimum physical font size.
- Free panel space plus theme aspect1 errors even without a coordinate ratio.

## Previous completed task: missing-value follow-up

Finished the missing-value fix follow-up from the pasted Claude chat. Everything
remains uncommitted on main; no package implementation changes were needed beyond
Claude's existing patch. Preserved the pre-existing CLAUDE.md and .Rbuildignore edits.

Added regressions for invalid non-missing weights on missing-category rows, NA
palette collisions on either axis, mixed missing-category/missing-weight panels,
and all.max with Freq[2] missing (largest known cell remains in the empty panel).
Warning assertions now enforce singular/plural grammar. Updated issues/TASKS.md
with prior reviewer results, known limitations, margin behavior, current results,
and the two pre-existing diagnostic follow-ups.

Validation: 1376 assertions, no failures/warnings/skips; dev verification passes;
8 complete-data results identical to HEAD; 4 renders pixel-identical; 18 exact
missing-value equivalence checks. User-requested independent subagent found no
actionable findings after 24 additional equivalence cases and independently
checking Titanic pooled margin counts and drawing.

Network-enabled R CMD check --as-cran: 0 errors, 0 warnings, 1 NOTE (new submission
and pre-existing SAS vignette reference URL lookup failure). Log is at
/private/tmp/ggfourfold-codex-check/ggfourfold.Rcheck/00check.log.
Use env -u DISPLAY on this Mac: XQuartz/tcltk hangs at S3 registration, as already
recorded in issues/TASKS.md:55. The successful run used DISPLAY=.

Claude's clean temporary HEAD worktree was removed after comparisons and review.
Original reviewer scripts/images remain in the Claude scratchpad; new rendering
and verification artifacts are in /private/tmp/ggfourfold-codex-check and
/private/tmp/ggfourfold-codex-verify. No commit or release performed.
