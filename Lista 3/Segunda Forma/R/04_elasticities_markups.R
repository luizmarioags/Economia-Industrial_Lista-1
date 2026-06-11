# 04_elasticities_markups.R ------------------------------------------------
# Elasticidades próprias do logit simples e markups implícitos.
# Não impõe demanda decrescente: usa alpha estimado diretamente.

source(file.path(ROOT, "R", "functions_gmm.R"))

df <- readRDS(file.path(OUTDATA, "R_after_simple_gmm.rds"))
models <- load_models()
if (is.null(models$GMM_both_2)) stop("GMM_both_2 não encontrado. Rode 02_estimate_logit_iv_gmm.R antes.")

alpha <- extract_alpha(models$GMM_both_2)
if (!is.finite(alpha) || alpha <= 0) {
  warning("Alpha estimado é não positivo ou não finito: ", alpha,
          ". Elasticidades/markups serão calculados sem imposição de sinal, mas podem não ser economicamente plausíveis.")
}

df <- df %>% mutate(
  own_elasticity_simple_logit = -alpha * price * (1 - share),
  markup_monoproduct = 1/(alpha * (1 - share)),
  mc_monoproduct = price - markup_monoproduct
)

s <- df$share
firm_id <- df$idfirm
n <- length(s)
Delta <- matrix(0, n, n)

for (j in seq_len(n)) {
  for (k in seq_len(n)) {
    if (firm_id[j] == firm_id[k]) {
      Delta[j, k] <- if (j == k) alpha*s[j]*(1-s[j]) else -alpha*s[j]*s[k]
    }
  }
}

markup_multi <- as.numeric(safe_solve(Delta) %*% s)

df <- df %>% mutate(
  markup_multiproduct = markup_multi,
  mc_multiproduct = price - markup_multiproduct,
  markup_multi_over_price = markup_multiproduct/price,
  markup_mono_over_price = markup_monoproduct/price
)

saveRDS(df, file.path(OUTDATA, "R_elasticities_markups_work.rds"))
readr::write_csv(df, file.path(OUTDATA, "R_elasticities_markups_work.csv"))
message(sprintf("Elasticidades e markups calculados. alpha = %.5f", alpha))
