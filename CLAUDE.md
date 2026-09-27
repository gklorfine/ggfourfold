This is an R package that extends 'ggplot2' to fourfold displays of $2 \times 2 (\times k)$ tables.

Main functions are the `geom` and `theme`, both located under `R/`.

Planning on a CRAN release; when testing the package, in addition to regular checks make sure everything conforms to https://github.com/DavisVaughan/extrachecks

Current issues are under `issues/`, important tasks are under `TASKS.md`.

`dev/` is a folder for development/rough work.

Verify all changes extensively. After a change, compare diffs, statistical, numerical, and visual output of old and new.

Test edge cases. Be creative here but not unreasonable.

The `vcd` package is a good resource for how things are supposed to be.
