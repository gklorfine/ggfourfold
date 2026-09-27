# Default palette for fourfold displays

\`fourfold_palette()\` returns the six colours used by
\[geom_fourfold()\]. The colours encode the direction and statistical
strength of association and are drawn directly by the geom rather than
through a fill scale. Entries 1-2 are used when \`extended = FALSE\`,
entries 3-4 for an extended display without adjusted significance, and
entries 5-6 for an extended display with adjusted significance. Within
each pair, the geom assigns the two colours according to the sign of
association and cell diagonal.

## Usage

``` r
fourfold_palette()
```

## Value

A character vector containing six hexadecimal colours.

## Examples

``` r
fourfold_palette()
#> [1] "#99CCFF" "#6699CC" "#FFA0A0" "#A0A0FF" "#FF0000" "#000080"
```
