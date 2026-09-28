# fourfold ideas

* **Does it have to be circles**: The quarter circles have nice properties, but I recall
an early version of this for 2x2 tables by Feinberg that used square shapes, for more
or less the same thing. Might be interesting...

* **Marginal plots**: For the 2 x 2 x R x C case (cf `woolf_test()`) showing the fourfold plot
for the marginal 2 x 2 R & 2 x 2 C tables would show the effect of pooling over R or C or both,
assuming the odds ratios are equal.

Example to try:

```
data(Detergent, package = "vcdExtra")
dimnames(Detergent) |> names()
Detergent <- aperm(Detergent, c(3, 2, 1, 4))
woolf_test(Detergent, decompose = TRUE)

# Woolf-test on Homogeneity of Odds Ratios (no 4-way association) 
#
# Data:          Detergent 
# OR variables:  Preference, M_User 
# Strata:        Temperature, Water_softness 
# 
# Overall homogeneity test:
#   X-squared = 8.0132, df = 5, p-value = 0.1555
# 
# Decomposition:
#   Rows (Temperature):    X-squared = 2.7742, df = 1, p-value = 0.09579
#   Cols (Water_softness): X-squared = 5.3351, df = 2, p-value = 0.06942
#   Residual:              X-squared = -0.0961, df = 2, p-value = 1
```


I'm also thinking of some way to visualize **departures from homoogeneity** in this context,
but maybe something will come up.
