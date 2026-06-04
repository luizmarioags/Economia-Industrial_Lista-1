# 02_estimate_logit_iv_gmm.R ----------------------------------------------
# MQO, 2SLS e GMM estrutural do logit simples.

source(file.path(ROOT, "R", "functions_gmm.R"))

df <- readRDS(file.path(OUTDATA, "prepared_data_R.rds"))
models <- load_models()

models$OLS <- fit_ols(df, "delta", c("cons", "price", XVARS), bnames = c("b0", "price", XVARS))
models$IV_own <- fit_iv_2sls(df, "delta", c("cons", XVARS, "price"), c("cons", XVARS, ZOWN), bnames = c("b0", XVARS, "price"))
models$IV_rival <- fit_iv_2sls(df, "delta", c("cons", XVARS, "price"), c("cons", XVARS, ZRIVAL), bnames = c("b0", XVARS, "price"))
models$IV_both <- fit_iv_2sls(df, "delta", c("cons", XVARS, "price"), c("cons", XVARS, ZBOTH), bnames = c("b0", XVARS, "price"))

models$GMM_own_1 <- berry_gmm_fit(df, "delta", c("cons", XVARS, "price"), c("cons", XVARS, ZOWN), c("b0", "bcals", "bfat", "bsugar", "bp"), step = 1)
models$GMM_own_2 <- berry_gmm_fit(df, "delta", c("cons", XVARS, "price"), c("cons", XVARS, ZOWN), c("b0", "bcals", "bfat", "bsugar", "bp"), step = 2)
models$GMM_rival_1 <- berry_gmm_fit(df, "delta", c("cons", XVARS, "price"), c("cons", XVARS, ZRIVAL), c("b0", "bcals", "bfat", "bsugar", "bp"), step = 1)
models$GMM_rival_2 <- berry_gmm_fit(df, "delta", c("cons", XVARS, "price"), c("cons", XVARS, ZRIVAL), c("b0", "bcals", "bfat", "bsugar", "bp"), step = 2)
models$GMM_both_1 <- berry_gmm_fit(df, "delta", c("cons", XVARS, "price"), c("cons", XVARS, ZBOTH), c("b0", "bcals", "bfat", "bsugar", "bp"), step = 1)
models$GMM_both_2 <- berry_gmm_fit(df, "delta", c("cons", XVARS, "price"), c("cons", XVARS, ZBOTH), c("b0", "bcals", "bfat", "bsugar", "bp"), step = 2)

m <- models$GMM_both_2
df_after <- df %>% mutate(
  xi_gmm_both = delta - m$coefficients["b0"] - m$coefficients["bcals"]*cals -
    m$coefficients["bfat"]*fat - m$coefficients["bsugar"]*sugar - m$coefficients["bp"]*price
)
saveRDS(df_after, file.path(OUTDATA, "R_after_simple_gmm.rds"))
readr::write_csv(df_after, file.path(OUTDATA, "R_after_simple_gmm.csv"))
save_models(models)
message("Modelos de logit simples estimados e salvos.")
