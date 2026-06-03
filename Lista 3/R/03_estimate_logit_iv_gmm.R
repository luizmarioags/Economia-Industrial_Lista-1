# COMENTÁRIOS DETALHADOS
# Este script monta y, X e Z para o logit simples, estima MQO, 2SLS e GMM para os três conjuntos de instrumentos.
# A especificação principal para comparação usa o coeficiente de price, cujo sinal é o negativo de alpha.
# As tabelas finais consolidam todos os coeficientes e a comparação do parâmetro de preço.

# MQO, 2SLS e GMM estrutural - logit simples
y <- df$delta
X_logit <- add_const(df[, c(CHAR_VARS, "price")])
names_logit <- c("const", CHAR_VARS, "price")
ZOWN <- paste0("own_", CHAR_VARS)
ZRIVAL <- paste0("rival_", CHAR_VARS)
ZBOTH <- c(ZOWN, ZRIVAL)
Z_own <- add_const(df[, c(CHAR_VARS, ZOWN)])
Z_rival <- add_const(df[, c(CHAR_VARS, ZRIVAL)])
Z_both <- add_const(df[, c(CHAR_VARS, ZBOTH)])

res <- list()
res$OLS <- ols_manual(y, X_logit, names_logit, "Q1_MQO_logit_simples")
res$IV_own <- twosls_manual(y, X_logit, Z_own, names_logit, "Q2_2SLS_own_firm")
res$IV_rival <- twosls_manual(y, X_logit, Z_rival, names_logit, "Q2_2SLS_rival_firms")
res$IV_both <- twosls_manual(y, X_logit, Z_both, names_logit, "Q2_2SLS_both")
for (nm in c("own", "rival", "both")) {
  Z <- switch(nm, own = Z_own, rival = Z_rival, both = Z_both)
  g <- gmm_2step(y, X_logit, Z, names_logit, paste0("Q3_GMM_", nm, "_2step"))
  res[[paste0("GMM_", nm, "_1")]] <- g$step1
  res[[paste0("GMM_", nm, "_2")]] <- g$step2
}
coef_tab_simple <- do.call(rbind, lapply(res, function(x) x$table))
price_rows_simple <- do.call(rbind, lapply(res, function(x) {
  ix <- match("price", x$coef_names)
  data.frame(model = x$name, price_coef = x$beta[ix], alpha = -x$beta[ix], std_error_price = x$se[ix],
             gmm_objective = ifelse(is.null(x$objective), NA, x$objective), sigma_nested = NA_real_)
}))
