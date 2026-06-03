# -------------------------------------------------------------------
# Questões 1, 3, 4, 5, 8, 9, 10 e 11 em R
# CORREÇÕES APLICADAS:
#   - Q1 : p-valor de beta_p, beta_y e beta_b adicionados à tabela
#   - Q1 : beta_y e beta_b agora armazenados
#   - Q3 : p-valor de beta_p adicionado
#   - Q4 : p-valor individual de pi_z adicionado
#   - Q4 : verificação numérica da equivalência 2SLS == GMM no caso exato
#   - Q5 : p-valor de beta_p adicionado para GMM_Z1 e GMM_Z2
#   - Q9 : pval_p e p_F agora presentes na tabela comparativa
#   - Q9 : F_eff calculado na mão via mop_f_eff() — sem dependência do Stata
#   - Q9 : cv5/cv10/cv20 preenchidos com os valores TSLS do weakivtest/Stata para Z1-Z7
#   - Q11: IC AR aberto/vazio tratado com grade adaptativa e limites ar_low_grid/ar_high_grid
# -------------------------------------------------------------------

source("R/00_setup.R")
source("R/00_functions.R")
log_step("Estimações em R: iniciando")

dat <- readRDS(file.path(PROC, "chicken_prepared_r.rds"))

INSTRUMENTS <- list(
  Z1 = c("z"),
  Z2 = c("z", "z_sq"),
  Z3 = c("z", "z_sq", "z_cu"),
  Z4 = c("z_lag"),
  Z5 = c("z_lag", "z_lag_sq"),
  Z6 = c("z", "z_lag"),
  Z7 = c("z", "z_sq", "z_lag", "z_lag_sq")
)

# ====================================================================
# Questão 1: MQO com erro-padrão robusto HC1
# CORREÇÃO: p-valor de beta_p, beta_y e beta_b; todas as elasticidades salvas
# ====================================================================
log_step("Questão 1: estimando MQO robusto (HC1)")
log_step("Modelo: ln_q = beta0 + beta_p*ln_pch + beta_y*ln_y + beta_b*ln_pb + u")

d_ols <- dat[complete.cases(dat[, c("ln_q", "ln_pch", "ln_y", "ln_pb")]),
             c("ln_q", "ln_pch", "ln_y", "ln_pb")]
y_ols <- d_ols$ln_q
X_ols <- add_const(d_ols[, c("ln_pch", "ln_y", "ln_pb")])
ols   <- ols_hc1(y_ols, as.matrix(X_ols))
cv_t  <- qt(0.975, df = ols$df)   # valor crítico t (bilateral 5 %)

# CORREÇÃO: extrai coeficiente, SE, p-valor e IC para cada regressor
ols_rows <- lapply(c("ln_pch", "ln_y", "ln_pb"), function(v) {
  idx  <- which(colnames(X_ols) == v)
  b_v  <- ols$beta[idx]
  se_v <- ols$se[idx]
  pval <- 2 * pt(abs(b_v / se_v), df = ols$df, lower.tail = FALSE)
  log_step(sprintf("  %s: b=%.6f | SE=%.6f | p=%.6f | IC=[%.6f, %.6f]",
                   v, b_v, se_v, pval, b_v - cv_t * se_v, b_v + cv_t * se_v))
  data.frame(var = v, N = ols$n, b = b_v, se = se_v, pval = pval,
             ci_low = b_v - cv_t * se_v, ci_high = b_v + cv_t * se_v)
})
ols_tab <- do.call(rbind, ols_rows)
readr::write_csv(ols_tab, file.path(TABS, "r_question_01_ols.csv"))
log_step("Tabela salva: output/tables/r_question_01_ols.csv")

# Salva resíduos e ajustados para visualizações
dat$ols_resid  <- NA_real_
dat$ols_fitted <- NA_real_
dat[rownames(d_ols), "ols_resid"]  <- ols$resid
dat[rownames(d_ols), "ols_fitted"] <- ols$fitted
saveRDS(dat, file.path(PROC, "chicken_with_ols_residuals_r.rds"))
log_step("Resíduos e ajustados MQO salvos em data/processed/chicken_with_ols_residuals_r.rds")

# ====================================================================
# Questão 3: 2SLS com Z1 = {z}
# CORREÇÃO: p-valor de beta_p adicionado
# ====================================================================
log_step("Questão 3: estimando 2SLS com Z1 = {z}")
log_step("Equação estrutural: ln_q ~ ln_pch + ln_y + ln_pb | Endógena: ln_pch | Excluído: z")

d_iv <- dat[complete.cases(dat[, c("ln_q", "ln_pch", "ln_y", "ln_pb", "z")]),
            c("ln_q", "ln_pch", "ln_y", "ln_pb", "z")]
y_iv  <- d_iv$ln_q
X_iv  <- add_const(d_iv[, c("ln_pch", "ln_y", "ln_pb")])
Z_iv  <- add_const(d_iv[, c("ln_y", "ln_pb", "z")])
iv_z1 <- iv_2sls(y_iv, as.matrix(X_iv), as.matrix(Z_iv))

idx_p    <- which(colnames(X_iv) == "ln_pch")
b_p      <- iv_z1$beta[idx_p]
se_p     <- iv_z1$se[idx_p]
# CORREÇÃO: p-valor assintótico normal (aproximação padrão do 2SLS)
pval_p   <- 2 * pnorm(abs(b_p / se_p), lower.tail = FALSE)
cv_n     <- qnorm(0.975)

log_step(sprintf("  2SLS Z1: beta_p=%.6f | SE=%.6f | p=%.6f | IC=[%.6f, %.6f]",
                 b_p, se_p, pval_p, b_p - cv_n * se_p, b_p + cv_n * se_p))

iv_z1_out <- data.frame(
  method = "2SLS_Z1", N = iv_z1$n,
  beta_p = b_p, se_p = se_p, pval_p = pval_p,
  ci_low = b_p - cv_n * se_p, ci_high = b_p + cv_n * se_p
)
readr::write_csv(iv_z1_out, file.path(TABS, "r_question_03_iv_z1.csv"))
log_step("Tabela salva: output/tables/r_question_03_iv_z1.csv")

# ====================================================================
# Questão 4: Primeiro estágio para Z1
# CORREÇÃO: p-valor individual de pi_z adicionado
#           + verificação numérica 2SLS == GMM no caso exato
# ====================================================================
log_step("Questão 4: estimando primeiro estágio de Z1")
log_step("Modelo: ln_pch = pi0 + pi_z*z + pi_y*ln_y + pi_b*ln_pb + v")

X_fs   <- add_const(d_iv[, c("z", "ln_y", "ln_pb")])
fs_fit <- ols_hc1(d_iv$ln_pch, as.matrix(X_fs))
idx_z  <- which(colnames(X_fs) == "z")

pi_z  <- fs_fit$beta[idx_z]
se_z  <- fs_fit$se[idx_z]
# CORREÇÃO: p-valor individual de pi_z
p_z   <- 2 * pt(abs(pi_z / se_z), df = fs_fit$df, lower.tail = FALSE)

R_z   <- matrix(0, nrow = 1, ncol = ncol(X_fs)); R_z[1, idx_z] <- 1
wt_z  <- wald_test(fs_fit$beta, fs_fit$vcov, R_z, df_denom = fs_fit$df)
pr2   <- partial_r2(d_iv$ln_pch, add_const(d_iv[, c("ln_y", "ln_pb")]), d_iv[, "z", drop = FALSE])

log_step(sprintf("  pi_z=%.6f | SE=%.6f | p(t)=%.6f | F usual=%.4f | p(F)=%.6f | R2 parcial=%.6f",
                 pi_z, se_z, p_z, wt_z$F, wt_z$p, pr2))

# CORREÇÃO: verificação numérica equivalência 2SLS == GMM
gmm_z1_check <- iv_gmm_2step(y_iv, as.matrix(X_iv), as.matrix(Z_iv))
diff_check   <- abs(iv_z1$beta[idx_p] - gmm_z1_check$beta[idx_p])
log_step(sprintf("  Verificação Q4 — equivalência exata: |2SLS - GMM| = %.2e (deve ser ~0)", diff_check))

fs_out <- data.frame(
  model = "Z1_first_stage", N = fs_fit$n,
  pi_z = pi_z, se_z = se_z, p_z = p_z,
  partial_R2 = pr2, F_usual = wt_z$F, p_F = wt_z$p
)
readr::write_csv(fs_out, file.path(TABS, "r_question_04_first_stage.csv"))
log_step("Tabela salva: output/tables/r_question_04_first_stage.csv")

# ====================================================================
# Questão 5: GMM em dois passos para Z1 e Z2
# CORREÇÃO: p-valor de beta_p adicionado
# ====================================================================
log_step("Questão 5: estimando GMM em dois passos para Z1 e Z2")

gmm_rows <- lapply(c("Z1", "Z2"), function(model) {
  inst  <- INSTRUMENTS[[model]]
  vars  <- c("ln_q", "ln_pch", "ln_y", "ln_pb", inst)
  d     <- dat[complete.cases(dat[, vars]), vars]
  y     <- d$ln_q
  X     <- add_const(d[, c("ln_pch", "ln_y", "ln_pb")])
  Z     <- add_const(d[, c("ln_y", "ln_pb", inst)])
  fit   <- iv_gmm_2step(y, as.matrix(X), as.matrix(Z))
  idx   <- which(colnames(X) == "ln_pch")
  b_v   <- fit$beta[idx]
  se_v  <- fit$se[idx]
  # CORREÇÃO: p-valor assintótico normal
  pval  <- 2 * pnorm(abs(b_v / se_v), lower.tail = FALSE)

  log_step(sprintf("  GMM_%s: beta_p=%.6f | SE=%.6f | p=%.6f | J=%.4f | p(J)=%.6f | gl=%d",
                   model, b_v, se_v, pval,
                   ifelse(is.na(fit$hansen_J), NA, fit$hansen_J),
                   ifelse(is.na(fit$hansen_p), NA, fit$hansen_p),
                   fit$hansen_df))

  data.frame(model = paste0("GMM_", model), N = fit$n,
             beta_p = b_v, se_p = se_v, pval_p = pval,
             ci_low = b_v - qnorm(0.975) * se_v,
             ci_high = b_v + qnorm(0.975) * se_v,
             hansen_J = fit$hansen_J, hansen_p = fit$hansen_p, hansen_df = fit$hansen_df)
})
gmm_tab <- do.call(rbind, gmm_rows)
readr::write_csv(gmm_tab, file.path(TABS, "r_question_05_gmm.csv"))
log_step("Tabela salva: output/tables/r_question_05_gmm.csv")

# ====================================================================
# Questões 8, 9 e 10: Z1-Z7, 2SLS, MOP na mão e Hansen J
# CORREÇÕES:
#   - pval_p adicionado
#   - p_F (p-valor do F usual) transferido diretamente à tabela comparativa
#   - F_eff calculado via mop_f_eff() — 100 % em R, sem Stata
#   - cv5/cv10/cv20 preenchidos com os valores críticos TSLS do weakivtest/Stata para esta aplicação
# ====================================================================
log_step("Questões 8, 9 e 10: tabela comparativa Z1-Z7 com MOP na mão")

fs_all   <- list()
comp_all <- list()

for (model in names(INSTRUMENTS)) {
  inst <- INSTRUMENTS[[model]]
  vars <- c("ln_q", "ln_pch", "ln_y", "ln_pb", inst)
  d    <- dat[complete.cases(dat[, vars]), vars]

  log_step(sprintf("  Processando %s (instrumentos: %s)", model, paste(inst, collapse = ", ")))

  # --- Primeiro estágio ---
  Xfs     <- add_const(d[, c(inst, "ln_y", "ln_pb")])
  fsfit   <- ols_hc1(d$ln_pch, as.matrix(Xfs))
  inst_pos <- match(inst, colnames(Xfs))
  R_inst  <- matrix(0, nrow = length(inst), ncol = ncol(Xfs))
  for (j in seq_along(inst)) R_inst[j, inst_pos[j]] <- 1
  wtf   <- wald_test(fsfit$beta, fsfit$vcov, R_inst, df_denom = fsfit$df)
  pr2   <- partial_r2(d$ln_pch,
                      add_const(d[, c("ln_y", "ln_pb")]),
                      d[, inst, drop = FALSE])

  fs_all[[model]] <- data.frame(
    model = model, N = fsfit$n, k_inst = length(inst),
    partial_R2 = pr2, F_usual = wtf$F, p_F = wtf$p
  )

  # --- 2SLS estrutural ---
  y     <- d$ln_q
  X     <- add_const(d[, c("ln_pch", "ln_y", "ln_pb")])
  Z     <- add_const(d[, c("ln_y", "ln_pb", inst)])
  ivfit <- iv_2sls(y, as.matrix(X), as.matrix(Z))
  idx   <- which(colnames(X) == "ln_pch")
  b_v   <- ivfit$beta[idx]
  se_v  <- ivfit$se[idx]
  # CORREÇÃO: p-valor de beta_p
  pval_p <- 2 * pnorm(abs(b_v / se_v), lower.tail = FALSE)

  # --- GMM para Hansen J ---
  gmmfit <- iv_gmm_2step(y, as.matrix(X), as.matrix(Z))

  # --- F efetivo MOP na mão ---
  f_eff <- mop_f_eff(
    y_endog = d$ln_pch,
    Z_excl  = d[, inst, drop = FALSE],
    X_incl  = add_const(d[, c("ln_y", "ln_pb"), drop = FALSE])
  )

  log_step(sprintf("    beta_p=%.6f | SE=%.6f | p=%.6f | F_usual=%.4f | p_F=%.6f | F_eff(MOP)=%.4f | J=%.4f | p(J)=%.6f",
                   b_v, se_v, pval_p, wtf$F, wtf$p,
                   ifelse(is.na(f_eff), NA, f_eff),
                   ifelse(is.na(gmmfit$hansen_J), NA, gmmfit$hansen_J),
                   ifelse(is.na(gmmfit$hansen_p), NA, gmmfit$hansen_p)))

  # Valores críticos TSLS do weakivtest/Stata para os modelos desta lista.
  # Em R, F_eff é calculado na mão; os críticos são uma tabela de referência.
  cv_mop <- mop_cv_tsls_lista1(model)

  comp_all[[model]] <- data.frame(
    model  = model, N = ivfit$n, k_inst = length(inst),
    beta_p = b_v, se_p = se_v, pval_p = pval_p,
    ci_low = b_v - qnorm(0.975) * se_v,
    ci_high = b_v + qnorm(0.975) * se_v,
    F_usual = wtf$F,
    p_F     = wtf$p,       # CORREÇÃO: p_F agora na tabela comparativa
    F_eff   = f_eff,       # MOP calculado na mão
    cv5     = cv_mop$cv5,
    cv10    = cv_mop$cv10,
    cv20    = cv_mop$cv20,
    hansen_J = gmmfit$hansen_J,
    hansen_p = gmmfit$hansen_p
  )
}

readr::write_csv(do.call(rbind, fs_all),   file.path(TABS, "r_question_08_first_stage_all.csv"))
readr::write_csv(do.call(rbind, comp_all), file.path(TABS, "r_question_09_comparative.csv"))
log_step("Tabelas salvas: r_question_08_first_stage_all.csv e r_question_09_comparative.csv")

# ====================================================================
# Questão 11: intervalos Anderson-Rubin por grade
# CORREÇÃO: grade AR adaptativa; beta0_minp, p_min, open_left/open_right e n_expand salvos
# ====================================================================
log_step("Questão 11: calculando intervalos Anderson-Rubin para Z1, Z2 e Z7 com grade adaptativa")

fmt_num <- function(x, digits = 4) {
  ifelse(is.na(x), "NA", formatC(x, format = "f", digits = digits))
}
fmt_ar <- function(ar) {
  left  <- ifelse(isTRUE(ar$open_left), "-infinito", fmt_num(ar$ar_low, 4))
  right <- ifelse(isTRUE(ar$open_right), "+infinito", fmt_num(ar$ar_high, 4))
  paste0("[", left, ", ", right, "]")
}

ar_rows <- lapply(c("Z1", "Z2", "Z7"), function(model) {
  inst <- INSTRUMENTS[[model]]
  log_step(sprintf("  AR %s (instrumentos: %s)", model, paste(inst, collapse = ", ")))
  ar   <- ar_interval(dat, inst_vars = inst,
                      beta_grid = seq(-5, 2, by = 0.005),
                      expand_grid = TRUE,
                      expand_by = 2,
                      max_expand = 20,
                      max_abs_beta = 100,
                      min_tail_hits = 3)
  log_step(sprintf("    IC AR = %s | beta0 menos rejeitado=%.4f | p_max=%.6f | p_min=%.6f | grade_final=[%.4f, %.4f] | expansoes=%d | aberto_esq=%s | aberto_dir=%s | vazio=%s",
                   fmt_ar(ar), ar$beta0_minp, ar$p_max, ar$p_min,
                   ar$grid_min, ar$grid_max, ar$n_expand,
                   ar$open_left, ar$open_right, ar$empty_interval))
  cbind(model = model, k_inst = length(inst), ar)
})
ar_tab <- do.call(rbind, ar_rows)
readr::write_csv(ar_tab, file.path(TABS, "r_question_11_ar_intervals.csv"))
log_step("Tabela salva: output/tables/r_question_11_ar_intervals.csv")

log_step("Estimações em R: concluídas")
