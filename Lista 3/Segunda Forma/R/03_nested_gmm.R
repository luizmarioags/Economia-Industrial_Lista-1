# 03_nested_gmm.R ----------------------------------------------------------
# Nested logit por IV/2SLS e GMM operacional.
# Correção: estima alpha diretamente usando neg_price = -price.

source(file.path(ROOT, "R", "functions_gmm.R"))

df <- readRDS(file.path(OUTDATA, "prepared_data_R.rds"))
models <- load_models()

models$IV_nested <- fit_iv_2sls(
  df, "delta",
  c("cons", XVARS, NEG_PRICE, "log_share_within_nest"),
  c("cons", XVARS, ZNESTALL),
  bnames = c("b0", "bcals", "bfat", "bsugar", "alpha", "log_share_within_nest")
)

models$GMM_nested_1 <- berry_gmm_fit(
  df, "delta",
  c("cons", XVARS, NEG_PRICE, "log_share_within_nest"),
  c("cons", XVARS, ZNESTALL),
  c("b0", "bcals", "bfat", "bsugar", "alpha", "sigma"),
  step = 1
)

models$GMM_nested_2 <- berry_gmm_fit(
  df, "delta",
  c("cons", XVARS, NEG_PRICE, "log_share_within_nest"),
  c("cons", XVARS, ZNESTALL),
  c("b0", "bcals", "bfat", "bsugar", "alpha", "sigma"),
  step = 2
)

m <- models$GMM_nested_2
df_after <- df %>% mutate(
  xi_nested = delta - m$coefficients["b0"] - m$coefficients["bcals"]*cals -
    m$coefficients["bfat"]*fat - m$coefficients["bsugar"]*sugar -
    m$coefficients["alpha"]*neg_price - m$coefficients["sigma"]*log_share_within_nest
)

saveRDS(df_after, file.path(OUTDATA, "R_after_nested_gmm.rds"))
readr::write_csv(df_after, file.path(OUTDATA, "R_after_nested_gmm.csv"))
save_models(models)

alpha_hat <- as.numeric(m$coefficients["alpha"])
sigma_hat <- as.numeric(m$coefficients["sigma"])
if (!is.finite(alpha_hat) || alpha_hat <= 0) {
  warning("Alpha estimado no nested logit é não positivo: ", alpha_hat,
          ". O modelo foi estimado sem impor demanda decrescente.")
}
if (!is.finite(sigma_hat) || sigma_hat < 0 || sigma_hat >= 1) {
  warning("Sigma estimado fora do intervalo teórico [0,1): ", sigma_hat)
}

message(sprintf("Nested GMM estimado. alpha = %.5f; sigma = %.4f", alpha_hat, sigma_hat))
