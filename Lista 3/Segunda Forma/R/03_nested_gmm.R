# 03_nested_gmm.R ----------------------------------------------------------
# Nested logit por IV/2SLS e GMM operacional.

source(file.path(ROOT, "R", "functions_gmm.R"))

df <- readRDS(file.path(OUTDATA, "prepared_data_R.rds"))
models <- load_models()

models$IV_nested <- fit_iv_2sls(
  df, "delta",
  c("cons", XVARS, "price", "log_share_within_nest"),
  c("cons", XVARS, ZNESTALL),
  bnames = c("b0", XVARS, "price", "log_share_within_nest")
)
models$GMM_nested_1 <- berry_gmm_fit(
  df, "delta",
  c("cons", XVARS, "price", "log_share_within_nest"),
  c("cons", XVARS, ZNESTALL),
  c("b0", "bcals", "bfat", "bsugar", "bp", "sigma"),
  step = 1
)
models$GMM_nested_2 <- berry_gmm_fit(
  df, "delta",
  c("cons", XVARS, "price", "log_share_within_nest"),
  c("cons", XVARS, ZNESTALL),
  c("b0", "bcals", "bfat", "bsugar", "bp", "sigma"),
  step = 2
)

m <- models$GMM_nested_2
df_after <- df %>% mutate(
  xi_nested = delta - m$coefficients["b0"] - m$coefficients["bcals"]*cals -
    m$coefficients["bfat"]*fat - m$coefficients["bsugar"]*sugar -
    m$coefficients["bp"]*price - m$coefficients["sigma"]*log_share_within_nest
)
saveRDS(df_after, file.path(OUTDATA, "R_after_nested_gmm.rds"))
readr::write_csv(df_after, file.path(OUTDATA, "R_after_nested_gmm.csv"))
save_models(models)
message(sprintf("Nested GMM estimado. Sigma = %.4f", m$coefficients["sigma"]))
