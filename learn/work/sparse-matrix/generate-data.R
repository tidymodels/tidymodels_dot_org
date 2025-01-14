library(tidyverse)
library(tidytext)

# https://snap.stanford.edu/data/web-FineFoods.html

data_raw <- read_lines("https://snap.stanford.edu/data/finefoods.txt.gz")
score <- str_subset(data_raw, "^review/score")
text <- str_subset(data_raw, "^review/text")

review_tbl <- tibble(score, text) |>
  slice(1:15000) |>
  mutate(score = if_else(score == 'review/score: 5.0', 1, 0)) |>
  mutate(text = str_remove(text, "^review/text: ")) |>
  mutate(id = row_number())

tokens <- review_tbl |>
  select(-score) |>
  unnest_tokens(tokens, text) |>
  count(id, tokens)

sparse_tokens <- cast_sparse(tokens, id, tokens, n)
sparse_tokens <- cbind(SCORE = review_tbl$score, sparse_tokens)

write_rds(sparse_tokens, "learn/work/sparse-matrix/reviews.rds", compress = "xz")
