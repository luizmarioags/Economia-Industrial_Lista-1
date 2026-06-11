# 05_diagnostics_weakiv.R --------------------------------------------------
# Diagnóstico dos instrumentos/primeiro estágio.

source(file.path(ROOT, "R", "functions_gmm.R"))

df <- readRDS(file.path(OUTDATA, "prepared_data_R.rds"))

first_stage_diag <- tibble::tibble(
  endogenous_variable = character(),
  excluded_instruments = numeric(),
  partial_F_homoskedastic = numeric(),
  robust_Wald_F_manual = numeric(),
  first_stage_R2 = numeric(),
  specification = character()
)

add_diag <- function(y, excluded, spec) {
  controls <- XVARS
  r2 <- r2_ols(df, y, c("cons", controls, excluded))
  rob <- wald_test_excluded(df, y, controls, excluded, robust = TRUE)
  tibble::tibble(
    endogenous_variable = y,
    excluded_instruments = length(excluded),
    partial_F_homoskedastic = rob$F,
    robust_Wald_F_manual = rob$F,
    first_stage_R2 = r2,
    specification = spec
  )
}

first_stage_diag <- bind_rows(
  first_stage_diag,
  add_diag(NEG_PRICE, ZBOTH, "simple_logit_both"),
  add_diag(NEG_PRICE, ZNESTALL, "nested_logit"),
  add_diag("log_share_within_nest", ZNESTALL, "nested_logit")
)

readr::write_csv(first_stage_diag, file.path(OUTDATA, "first_stage_diagnostics_R.csv"))
saveRDS(first_stage_diag, file.path(OUTDATA, "first_stage_diagnostics_R.rds"))
message("Diagnósticos de primeiro estágio calculados.")
