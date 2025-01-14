---
title: "Model tuning using a sparse matrix"
categories:
 - tuning
 - classification
 - sparse data
type: learn-subsection
weight: 1
description: | 
  Fitting a model using tidymodels with a sparse matrix as the data.
toc: true
toc-depth: 2
include-after-body: ../../../resources.html
---









## Introduction

To use code in this article,  you will need to install the following packages: sparsevctrs and tidymodels.

This article demonstrates how we can use a sparse matrix in tidymodels.

## Example data

The data we will be using in this article is a larger sample of the [small_fine_foods](https://modeldata.tidymodels.org/reference/small_fine_foods.html) data set from the [modeldata](https://modeldata.tidymodels.org) package. The [raw data](https://snap.stanford.edu/data/web-FineFoods.html) was sliced down to 100,000 rows, tokenized, and saved as a sparse matrix. Data has been saved as [reviews.rds](reviews.rds) and the code to generate this data set is found at [generate-data.R](generate-data.R). This file takes up around 1MB compressed, and around 12MB once loaded into R. This data set is encoded as a sparse matrix from the Matrix package; if we were to turn it into a dense matrix, it would take up 3GB.




::: {.cell layout-align="center"}

```{.r .cell-code}
reviews <- readr::read_rds("reviews.rds")
reviews |> head()
#> 6 x 24818 sparse Matrix of class "dgCMatrix"
#>   [[ suppressing 34 column names 'SCORE', 'a', 'all' ... ]]
#>                                                                             
#> 1 1 2 1 3 1 1 2 1 1 1 1 1 1 1 2 1 1 1 1 1 1 1 1 1 1 2 1 2 1 1 1 1 1 1 ......
#> 2 . . . . . . . . . . . . . . . . . . . . . . . . . . . 2 . . . . . . ......
#> 3 . 4 . 6 . . . . . . . . . . . 1 5 3 . . . . . . . 2 . . . . . . . . ......
#> 4 . . . 1 . . . . . . . . 1 1 1 4 1 1 . . . . . . . . . . . . . . . . ......
#> 5 1 4 . . . . . . . . . . . . . . 1 . . . . . . . . 1 . . . . . . . . ......
#> 6 . 3 1 2 . . . . . . . . . . . 2 1 1 . . . . . . 4 1 . . . . . . . . ......
#> 
#>  .....suppressing 24784 columns in show(); maybe adjust options(max.print=, width=)
#>  ..............................
```
:::




## Modeling

We start by loading tidymodels and the sparsevctrs package. The sparsevctrs package includes some helper functions that will allow us to more easily work with sparse matrices in tidymodels.




::: {.cell layout-align="center"}

```{.r .cell-code}
library(tidymodels)
library(sparsevctrs)
```
:::




While sparse matrices now work in parsnip, recipes, and workflows directly, we can use rsample's sampling functions as well if we turn it into a tibble. The usual `as_tibble()` would turn the object to a dense representation, greatly expanding the object size. However, sparsevctrs' `coerce_to_sparse_tibble()` will create a tibble with sparse columns, which we call a **sparse tibble**.




::: {.cell layout-align="center"}

```{.r .cell-code}
reviews_tbl <- coerce_to_sparse_tibble(reviews)
reviews_tbl
#> # A tibble: 15,000 × 24,818
#>    SCORE     a   all   and appreciates    be better bought canned   dog finicky
#>    <dbl> <dbl> <dbl> <dbl>       <dbl> <dbl>  <dbl>  <dbl>  <dbl> <dbl>   <dbl>
#>  1     1     2     1     3           1     1      2      1      1     1       1
#>  2     0     0     0     0           0     0      0      0      0     0       0
#>  3     0     4     0     6           0     0      0      0      0     0       0
#>  4     0     0     0     1           0     0      0      0      0     0       0
#>  5     1     4     0     0           0     0      0      0      0     0       0
#>  6     0     3     1     2           0     0      0      0      0     0       0
#>  7     1     1     0     3           0     0      0      0      0     0       0
#>  8     1     0     0     1           0     0      0      0      0     0       0
#>  9     1     0     0     1           0     0      0      0      0     0       0
#> 10     1     1     0     0           0     0      0      0      0     2       0
#> # ℹ 14,990 more rows
#> # ℹ 24,807 more variables: food <dbl>, found <dbl>, good <dbl>, have <dbl>,
#> #   i <dbl>, is <dbl>, it <dbl>, labrador <dbl>, like <dbl>, looks <dbl>,
#> #   meat <dbl>, more <dbl>, most <dbl>, my <dbl>, of <dbl>, processed <dbl>,
#> #   product <dbl>, products <dbl>, quality <dbl>, several <dbl>, she <dbl>,
#> #   smells <dbl>, stew <dbl>, than <dbl>, the <dbl>, them <dbl>, this <dbl>,
#> #   to <dbl>, vitality <dbl>, actually <dbl>, an <dbl>, arrived <dbl>, …
```
:::




Despite this tibble containing 15,000 rows and a little under 25,000 columns, it only takes up marginally more space than the sparse matrix.




::: {.cell layout-align="center"}

```{.r .cell-code}
lobstr::obj_size(reviews)
#> 12.75 MB
lobstr::obj_size(reviews_tbl)
#> 18.27 MB
```
:::




The outcome `SCORE` is currently encoded as a double, but we want it to be a factor for it to work well with tidymodels.




::: {.cell layout-align="center"}

```{.r .cell-code}
reviews_tbl <- reviews_tbl |>
  mutate(SCORE = factor(SCORE, levels = c(1, 0), labels = c("great", "other")))
```
:::




Since `reviews_tbl` is now a tibble, we can use `initial_split()` as we usually do.




::: {.cell layout-align="center"}

```{.r .cell-code}
set.seed(1234)

review_split <- initial_split(reviews_tbl)
review_train <- training(review_split)
review_test <- testing(review_split)

review_folds <- vfold_cv(review_train)
```
:::




Next, we will specify our workflow. Since we are showcasing how sparse data works in tidymodels, we will stick to a simple lasso regression model. These models tend to work well with sparse predictors. `penalty` has been set to be tuned.




::: {.cell layout-align="center"}

```{.r .cell-code}
rec_spec <- recipe(SCORE ~ ., data = review_train)

lm_spec <- logistic_reg(penalty = tune()) |>
  set_engine("glmnet")

wf_spec <- workflow(rec_spec, lm_spec)
```
:::




With everything in order, we can now evaluate several different values of `penalty` with `tune_grid()`.




::: {.cell layout-align="center"}

```{.r .cell-code}
tune_res <- tune_grid(wf_spec, review_folds)
```
:::




Despite the size of the data, this code runs quite quickly due to the sparse encoding of the data. Once the tuning process is done, then we can look at the performance for different values of regularization.




::: {.cell layout-align="center"}

```{.r .cell-code}
autoplot(tune_res)
```

::: {.cell-output-display}
![](figs/autoplot-1.svg){fig-align='center' width=672}
:::
:::




We can now finalize the workflow and fit the final model on the training data set.




::: {.cell layout-align="center"}

```{.r .cell-code}
wf_final <- finalize_workflow(
 wf_spec, 
  select_best(tune_res, metric = "roc_auc")
 )

wf_fit <- fit(wf_final, review_train)
```
:::




With this fitted model, we can now predict with a sparse tibble.




::: {.cell layout-align="center"}

```{.r .cell-code}
predict(wf_fit, review_test)
#> # A tibble: 3,750 × 1
#>    .pred_class
#>    <fct>      
#>  1 other      
#>  2 great      
#>  3 great      
#>  4 great      
#>  5 great      
#>  6 great      
#>  7 great      
#>  8 great      
#>  9 great      
#> 10 great      
#> # ℹ 3,740 more rows
```
:::




## Session information {#session-info}




::: {.cell layout-align="center"}

```
#> ─ Session info ─────────────────────────────────────────────────────
#>  setting  value
#>  version  R version 4.4.0 (2024-04-24)
#>  os       macOS 15.0
#>  system   aarch64, darwin20
#>  ui       X11
#>  language (EN)
#>  collate  en_US.UTF-8
#>  ctype    en_US.UTF-8
#>  tz       America/Los_Angeles
#>  date     2024-10-14
#>  pandoc   2.17.1.1 @ /opt/homebrew/bin/ (via rmarkdown)
#> 
#> ─ Packages ─────────────────────────────────────────────────────────
#>  package     * version    date (UTC) lib source
#>  broom       * 1.0.6      2024-05-17 [1] CRAN (R 4.4.0)
#>  dials       * 1.3.0.9000 2024-09-23 [1] local
#>  dplyr       * 1.1.4      2023-11-17 [1] CRAN (R 4.4.0)
#>  ggplot2     * 3.5.1      2024-04-23 [1] CRAN (R 4.4.0)
#>  infer       * 1.0.7      2024-03-25 [1] CRAN (R 4.4.0)
#>  parsnip     * 1.2.1.9002 2024-10-02 [1] local
#>  purrr       * 1.0.2      2023-08-10 [1] CRAN (R 4.4.0)
#>  recipes     * 1.1.0.9000 2024-10-04 [1] local
#>  rlang         1.1.4      2024-06-04 [1] CRAN (R 4.4.0)
#>  rsample     * 1.2.1.9000 2024-09-18 [1] Github (tidymodels/rsample@77fc1fe)
#>  sparsevctrs * 0.1.0.9002 2024-09-30 [1] Github (r-lib/sparsevctrs@b29b723)
#>  tibble      * 3.2.1      2023-03-20 [1] CRAN (R 4.4.0)
#>  tidymodels  * 1.2.0      2024-03-25 [1] CRAN (R 4.4.0)
#>  tune        * 1.2.1      2024-04-18 [1] CRAN (R 4.4.0)
#>  workflows   * 1.1.4.9000 2024-09-24 [1] local
#>  yardstick   * 1.3.1      2024-03-21 [1] CRAN (R 4.4.0)
#> 
#>  [1] /Library/Frameworks/R.framework/Versions/4.4-arm64/Resources/library
#> 
#> ────────────────────────────────────────────────────────────────────
```
:::
