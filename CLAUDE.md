# NA

This is an R package that extends ‘ggplot2’ to fourfold displays of \\2
\times 2 (\times k)\\ tables.

Main functions are the `geom` and `theme`, both located under `R/`.

Planning on a CRAN release; when testing the package, in addition to
regular checks make sure everything conforms to
<https://github.com/DavisVaughan/extrachecks>

Current issues are under `issues/`, important tasks are under
`TASKS.md`.

`dev/` is a folder for development/rough work.

Verify all changes extensively. After a change, compare diffs,
statistical, numerical, and visual output of old and new.

Test edge cases. Be creative here but not unreasonable.

The `vcd` package is a good resource for how things are supposed to be.

`HANDOFF.md` is for GPT to communicate with Claude or vice-versa. It is
mainly used so that a developer can pick up work on a different model
after he/she exhausts usage on one of the two models.

When usage information is available, check remaining account quota at
task start and between major phases. If any applicable quota window has
10% or less remaining, update `HANDOFF.md` before starting more work. If
usage information is unavailable, state that; do not guess.

Do not worry about writing to `HANDOFF.md` if there’s a good amount of
usage remaining (i.e., \> 25% remaining).

There should be sections in `HANDOFF.md` per-developer. For example, one
for GK and one for MF.
