---
title: "How Sparse Data are Used in tidymodels"
categories:
 - sparse data
type: learn-subsection
weight: 1
description: | 
  Design decisions around the use of sparse data in tidymodels.
toc: true
toc-depth: 2
include-after-body: ../../../resources.html
---









## What is sparse data?

We use the term **sparse data** to denote a data set that contains a lot of 0s. Such data is commonly seen as a result of dealing with categorical variables, text tokenization, or graph data sets. The word sparse describes how the information is packed. Namely, it represents the presence of a lot of zeroes. For some tasks, we can easily get above 99% percent of 0s in the predictors. 

The reason we use sparse data as a construct is that it is a lot more memory efficient to store the positions and values of the non-zero entries than to encode all the values. One could think of this as a compression, but one that is done such that data tasks are still fast. The following vector requires 25 values to store it normally (dense representation). This representation will be referred to as a **dense vector**.

```r
c(100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0)
```
The sparse representation of this vector only requires 5 values. 1 value for the length (25), 2 values for the locations of the non-zero values (1, 22), and 2 values for the non-zero values (100, 1). This idea can also be extended to matrices as is done in the Matrix package.

The Matrix package implements sparse vectors and sparse matrices as S4 objects. These objects are the go-to objects in the R ecosystem for dealing with sparse data.

The [tibble](https://tibble.tidyverse.org/) is used as the main carrier of data inside tidymodels. While matrices or data frames are accepted as input in different places, they are converted to tibbles early to take advantage of the benefits and checks they provide. This is where the [sparsevctrs](https://github.com/r-lib/sparsevctrs) package comes in. The sparse vectors and matrices from the Matrix package don't work with data frames or tibbles and are thus not able to be used well within tidymodels. The sparsevctrs package allows for the creation of [ALTREP](https://svn.r-project.org/R/branches/ALTREP/ALTREP.html) vectors that act like normal numeric vectors but are encoded sparsely. If an operation on the vector can't be done sparsely, it will fall back and **materialize**. Materialization means that it will generate and cache a dense version of the vector that is then used. 

These sparse vectors can be put into tibbles and are what allow tidymodels to handle sparse data. We will henceforth refer to a tibble that contains sparse columns as a **sparse tibble**. Sparse matrices require all the elements to be of the same type. All logical, all integer, or all doubles. This limitation does not apply to sparse tibbles as you can store both sparse vectors and dense vectors, but also mix and match numeric, factors, datetimes, and more.

The sparsity mostly matters for the predictors. The outcomes, case weights, and predictions are done densely.

Below is outlined how sparse data (matrix & tibble) works with the various tidymodels packages.

## rsample

The resampling functions from the rsample package work with sparse tibbles out of the box. However, they won't work with sparse matrices. Instead, use the `coerce_to_sparse_tibble()` function from the sparsevctrs package to turn the sparse matrix into a sparse tibble and proceed with that object.

```r
library(sparsevctrs)
data_tbl <- coerce_to_sparse_tibble(data_mat)
```

## recipes

The recipes package receives data in `recipe()`, `prep()`, and `bake()`. These functions all handle sparse data in the same manner.

Sparse tibbles should work as normal. Sparse matrices are accepted and then turned into sparse tibbles right away, and flow through the internals as sparse tibbles.

The `composition` argument of `bake()` understands sparse tibbles. When `composition = "dgCMatrix"` the resulting sparse matrix will be created from the sparse tibble with minimal overhead.

Recipe steps themselves don't know how to handle sparse vectors yet. In most cases, this means that sparse vectors will be materialized. This is a known issue and is planned to be fixed.

## parsnip

The parsnip package receives data in `fit()`, `fit_xy()`, and `predict()`.

Sparse data does not yet work with the formula interface for `fit()`. This is a known issue and is expected to be fixed long term.

For `fit_xy()`, both sparse tibbles and sparse matrices are supported. Sparse matrices are turned into sparse tibbles early on. When fitting a model in parsnip, the package checks whether the engine supports sparse matrices using the `allow_sparse_x` specification. A warning is thrown if sparse data is passed to an engine that doesn't support it, informing the user of that fact and that the data will be converted to a dense representation.

`predict()` works with sparse tibbles and sparse matrices, where sparse matrices are turned into sparse tibbles right away, and into the appropriate format before it is passed to the model engine.

## workflows

The workflows package receives data in `fit()` and `predict()`.

Sparse data does not yet work with the formula interface for `fit()`. This is a known issue and is expected to be fixed long term.

Both `fit()` and `predict()` work with sparse matrices and sparse tibbles when using recipes or variables as preprocessors, turning sparse matrics into sparse tibbles at the earliest convenience. Most of the checking and functionality is delegated to recipes and parsnip.

## All other packages

All other packages should work out of the box with sparse tibbles.
