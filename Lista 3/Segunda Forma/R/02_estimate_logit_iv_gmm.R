# 02_estimate_logit_iv_gmm.R ----------------------------------------------
# MQO, 2SLS e GMM estrutural do logit simples.
# Correção: estima alpha diretamente usando neg_price = -price.

source(file.path(ROOT, "R", "functions_gmm.R"))

df <- readRDS(file.path(OUTDATA, "prepared_data_R.rds"))
models <- load_models()

models$OLS <- fit_ols(
  df, "delta",
  c("cons", XVARS, NEG_PRICE),
  bnames = c("b0", "bcals", "bfat", "bsugar", "alpha")
)

models$IV_own <- fit_iv_2sls(
  df, "delta",
  c("cons", XVARS, NEG_PRICE),
  c("cons", XVARS, ZOWN),
  bnames = c("b0", "bcals", "bfat", "bsugar", "alpha")
)

models$IV_rival <- fit_iv_2sls(
  df, "delta",
  c("cons", XVARS, NEG_PRICE),
  c("cons", XVARS, ZRIVAL),
  bnames = c("b0", "bcals", "bfat", "bsugar", "alpha")
)

models$IV_both <- fit_iv_2sls(
  df, "delta",
  c("cons", XVARS, NEG_PRICE),
  c("cons", XVARS, ZBOTH),
  bnames = c("b0", "bcals", "bfat", "bsugar", "alpha")
)

models$GMM_own_1 <- berry_gmm_fit(
  df, "delta",
  c("cons", XVARS, NEG_PRICE),
  c("cons", XVARS, ZOWN),
  c("b0", "bcals", "bfat", "bsugar", "alpha"),
  step = 1
)

models$GMM_own_2 <- berry_gmm_fit(
  df, "delta",
  c("cons", XVARS, NEG_PRICE),
  c("cons", XVARS, ZOWN),
  c("b0", "bcals", "bfat", "bsugar", "alpha"),
  step = 2
)

models$GMM_rival_1 <- berry_gmm_fit(
  df, "delta",
  c("cons", XVARS, NEG_PRICE),
  c("cons", XVARS, ZRIVAL),
  c("b0", "bcals", "bfat", "bsugar", "alpha"),
  step = 1
)

models$GMM_rival_2 <- berry_gmm_fit(
  df, "delta",
  c("cons", XVARS, NEG_PRICE),
  c("cons", XVARS, ZRIVAL),
  c("b0", "bcals", "bfat", "bsugar", "alpha"),
  step = 2
)

models$GMM_both_1 <- berry_gmm_fit(
  df, "delta",
  c("cons", XVARS, NEG_PRICE),
  c("cons", XVARS, ZBOTH),
  c("b0", "bcals", "bfat", "bsugar", "alpha"),
  step = 1
)

models$GMM_both_2 <- berry_gmm_fit(
  df, "delta",
  c("cons", XVARS, NEG_PRICE),
  c("cons", XVARS, ZBOTH),
  c("b0", "bcals", "bfat", "bsugar", "alpha"),
  step = 2
)

m <- models$GMM_both_2
df_after <- df %>% mutate(
  xi_gmm_both = delta - m$coefficients["b0"] - m$coefficients["bcals"]*cals -
    m$coefficients["bfat"]*fat - m$coefficients["bsugar"]*sugar -
    m$coefficients["alpha"]*neg_price
)

saveRDS(df_after, file.path(OUTDATA, "R_after_simple_gmm.rds"))
readr::write_csv(df_after, file.path(OUTDATA, "R_after_simple_gmm.csv"))
save_models(models)

alpha_hat <- as.numeric(m$coefficients["alpha"])
if (!is.finite(alpha_hat) || alpha_hat <= 0) {
  warning("Alpha estimado no logit simples é não positivo: ", alpha_hat,
          ". O modelo foi estimado sem impor demanda decrescente.")
}

message(sprintf("Modelos de logit simples estimados e salvos. alpha = %.5f", alpha_hat))
