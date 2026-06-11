# 08_standard_tables.R -----------------------------------------------------
# Tabelas padronizadas em CSV e TEX.

source(file.path(ROOT, "R", "functions_gmm.R"))
source(file.path(ROOT, "R", "functions_io_tables.R"))

models <- load_models()
df <- readRDS(file.path(OUTDATA, "prepared_data_R.rds"))

# 01. Coeficientes estimados
all_coef <- purrr::imap_dfr(models, ~ model_tidy(.x, .y))
export_csv_tex(
  all_coef,
  file.path(TABCSV, "01_all_coefficients.csv"),
  file.path(TABTEX, "01_all_coefficients.tex"),
  "Coeficientes estimados", "tab:all-coef"
)

# 02. Comparação do parâmetro de preço
price_parameter <- purrr::imap_dfr(models, function(m, nm) {
  alpha_hat <- extract_alpha(m)
  alpha_se <- extract_alpha_se(m)
  b <- m$coefficients
  sigma <- if ("sigma" %in% names(b)) b["sigma"] else NA_real_

  tibble::tibble(
    model = nm,
    price_coef_minus_alpha = as.numeric(-alpha_hat),
    alpha = as.numeric(alpha_hat),
    alpha_se = as.numeric(alpha_se),
    gmm_objective = m$Q,
    sigma_nested = as.numeric(sigma)
  )
})

export_csv_tex(
  price_parameter,
  file.path(TABCSV, "02_price_parameter_comparison.csv"),
  file.path(TABTEX, "02_price_parameter_comparison.tex"),
  "Comparação do parâmetro de preço", "tab:price-compare"
)

if (is.null(models$GMM_both_2)) stop("GMM_both_2 não encontrado.")
alpha <- extract_alpha(models$GMM_both_2)
if (!is.finite(alpha) || alpha <= 0) {
  warning("Alpha do logit simples é não positivo: ", alpha,
          ". Tabelas serão exportadas sem imposição de sinal.")
}

# 03. Matriz de elasticidades simples em formato longo
rows <- df %>% transmute(row_id = row_number(), row_product = product, row_price = price, row_share = share)
cols <- df %>% transmute(col_id = row_number(), column_product = product, column_price = price, column_share = share)

elas_simple <- tidyr::crossing(rows, cols) %>%
  mutate(elasticity = ifelse(row_id == col_id,
                             -alpha * row_price * (1 - row_share),
                             alpha * column_price * column_share)) %>%
  select(row_product, column_product, elasticity)

export_csv_tex(
  elas_simple,
  file.path(TABCSV, "03_elasticity_matrix_simple_logit.csv"),
  file.path(TABTEX, "03_elasticity_matrix_simple_logit.tex"),
  "Matriz de elasticidades - logit simples", "tab:elas-simple"
)

# 04. Matriz simples para os 12 maiores produtos
sub <- df %>% arrange(desc(share)) %>% slice_head(n = 12)
rows_sub <- sub %>% transmute(row_id = row_number(), row_product = product, row_price = price, row_share = share)
cols_sub <- sub %>% transmute(col_id = row_number(), column_product = product, column_price = price, column_share = share)

elas_simple_sub <- tidyr::crossing(rows_sub, cols_sub) %>%
  mutate(elasticity = ifelse(row_id == col_id,
                             -alpha * row_price * (1 - row_share),
                             alpha * column_price * column_share)) %>%
  select(row_product, column_product, elasticity)

export_csv_tex(
  elas_simple_sub,
  file.path(TABCSV, "04_elasticity_matrix_simple_logit_subset.csv"),
  file.path(TABTEX, "04_elasticity_matrix_simple_logit_subset.tex"),
  "Matriz de elasticidades - logit simples - subconjunto", "tab:elas-simple-subset"
)

# 05. Elasticidades próprias simples
own_simple <- df %>%
  mutate(own_elasticity_simple_logit = -alpha*price*(1-share)) %>%
  arrange(own_elasticity_simple_logit) %>%
  select(product, firm, segment, price, share, own_elasticity_simple_logit)

export_csv_tex(
  own_simple,
  file.path(TABCSV, "05_own_elasticities_simple_logit.csv"),
  file.path(TABTEX, "05_own_elasticities_simple_logit.tex"),
  "Elasticidades próprias - logit simples", "tab:own-elas-simple"
)

# Funções do nested logit
nested_shares <- function(price_vec, base_df, coef) {
  sigma <- as.numeric(coef["sigma"])
  scale <- max(1 - sigma, 1e-8)
  alpha_n <- as.numeric(coef["alpha"])

  delta <- as.numeric(
    coef["b0"] +
      coef["bcals"]*base_df$cals +
      coef["bfat"]*base_df$fat +
      coef["bsugar"]*base_df$sugar +
      alpha_n*(-price_vec)
  )

  s <- numeric(nrow(base_df))
  nests <- sort(unique(base_df$idsegment))
  Dg <- numeric(length(nests))
  within <- numeric(nrow(base_df))

  for (g in seq_along(nests)) {
    idx <- which(base_df$idsegment == nests[g])
    expinner <- exp(delta[idx] / scale)
    den <- sum(expinner)
    within[idx] <- expinner / den
    Dg[g] <- den^scale
  }

  outer_den <- 1 + sum(Dg)
  gp <- Dg / outer_den

  for (g in seq_along(nests)) {
    idx <- which(base_df$idsegment == nests[g])
    s[idx] <- within[idx] * gp[g]
  }

  s
}

# 06 e 07. Nested logit: elasticidades numéricas
if (is.null(models$GMM_nested_2)) stop("GMM_nested_2 não encontrado.")
coefn <- models$GMM_nested_2$coefficients
p0 <- df$price
s0n <- nested_shares(p0, df, coefn)
n <- nrow(df)
E_nested <- matrix(NA_real_, n, n)
eps <- 1e-6

for (k in seq_len(n)) {
  p1 <- p0
  p1[k] <- p1[k] + eps
  s1 <- nested_shares(p1, df, coefn)
  E_nested[, k] <- ((s1 - s0n)/eps) * p0[k] / s0n
}

elas_nested <- tidyr::crossing(
  df %>% transmute(row_id = row_number(), row_product = product),
  df %>% transmute(col_id = row_number(), column_product = product)
) %>%
  mutate(elasticity = E_nested[cbind(row_id, col_id)]) %>%
  select(row_product, column_product, elasticity)

export_csv_tex(
  elas_nested,
  file.path(TABCSV, "06_elasticity_matrix_nested_logit.csv"),
  file.path(TABTEX, "06_elasticity_matrix_nested_logit.tex"),
  "Matriz de elasticidades - nested logit", "tab:elas-nested"
)

own_nested <- df %>%
  transmute(product, own_elasticity_nested_logit = diag(E_nested)) %>%
  arrange(own_elasticity_nested_logit)

export_csv_tex(
  own_nested,
  file.path(TABCSV, "07_own_elasticities_nested_logit.csv"),
  file.path(TABTEX, "07_own_elasticities_nested_logit.tex"),
  "Elasticidades próprias - nested logit", "tab:own-elas-nested"
)

# 08. Markups
s <- df$share
f <- df$idfirm
Delta <- matrix(0, n, n)

for (j in seq_len(n)) {
  for (k in seq_len(n)) {
    if (f[j] == f[k]) {
      Delta[j,k] <- if (j == k) alpha*s[j]*(1-s[j]) else -alpha*s[j]*s[k]
    }
  }
}

mu <- as.numeric(safe_solve(Delta) %*% s)

markups <- df %>%
  mutate(
    markup_monoproduct = 1/(alpha*(1-share)),
    mc_monoproduct = price - markup_monoproduct,
    markup_multiproduct = mu,
    mc_multiproduct = price - markup_multiproduct,
    markup_mono_over_price = markup_monoproduct/price,
    markup_multi_over_price = markup_multiproduct/price
  ) %>%
  select(product, firm, segment, price, share, markup_monoproduct, mc_monoproduct,
         markup_multiproduct, mc_multiproduct, markup_mono_over_price, markup_multi_over_price)

export_csv_tex(
  markups,
  file.path(TABCSV, "08_markups.csv"),
  file.path(TABTEX, "08_markups.tex"),
  "Markups implícitos - logit simples", "tab:markups"
)

# 09. Diagnósticos de primeiro estágio
fs_path <- file.path(OUTDATA, "first_stage_diagnostics_R.rds")
if (!file.exists(fs_path)) source(file.path(ROOT, "R", "05_diagnostics_weakiv.R"))
fs <- readRDS(fs_path)

export_csv_tex(
  fs,
  file.path(TABCSV, "09_first_stage_diagnostics.csv"),
  file.path(TABTEX, "09_first_stage_diagnostics.tex"),
  "Diagnóstico de primeiro estágio", "tab:first-stage"
)

message("Tabelas CSV/TEX exportadas.")
