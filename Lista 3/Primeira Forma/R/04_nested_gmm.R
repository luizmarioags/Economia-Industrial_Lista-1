# COMENTÁRIOS DETALHADOS
# Este script estima o nested logit por 2SLS de referência e por GMM manual de duas etapas.
# ZNEST inclui instrumentos para a variável endógena ln(s_j|g), além dos instrumentos BLP tradicionais.
# sigma_hat é extraído para avaliar se a estimativa satisfaz o intervalo teórico 0 <= sigma < 1.

# Nested logit por GMM manual
ZNEST <- c("n_same_nest_other", "n_rival_nest", paste0("nest_own_", CHAR_VARS), paste0("nest_rival_", CHAR_VARS))
ZNESTALL <- c(ZBOTH, ZNEST)
X_nested <- add_const(df[, c(CHAR_VARS, "price", "log_share_within_nest")])
names_nested <- c("const", CHAR_VARS, "price", "log_share_within_nest")
Z_nested <- add_const(df[, c(CHAR_VARS, ZNESTALL)])

nested_iv <- twosls_manual(y, X_nested, Z_nested, names_nested, "Q4_2SLS_nested_reference")
nested_g <- gmm_2step(y, X_nested, Z_nested, names_nested, "Q4_nested_GMM_2step")
nested_res <- list(nested_iv = nested_iv, nested_gmm_step1 = nested_g$step1, nested_gmm_step2 = nested_g$step2)
nested_tab <- do.call(rbind, lapply(nested_res, function(x) x$table))
coef_tab <- rbind(coef_tab_simple, nested_tab)
save_table(coef_tab, "01_all_coefficients", "Coeficientes estimados", "tab:all-coef")

price_rows_nested <- do.call(rbind, lapply(nested_res, function(x) {
  ix <- match("price", x$coef_names)
  sigix <- match("log_share_within_nest", x$coef_names)
  data.frame(model = x$name, price_coef = x$beta[ix], alpha = -x$beta[ix], std_error_price = x$se[ix],
             gmm_objective = ifelse(is.null(x$objective), NA, x$objective),
             sigma_nested = ifelse(is.na(sigix), NA_real_, x$beta[sigix]))
}))
price_rows <- rbind(price_rows_simple, price_rows_nested)
save_table(price_rows, "02_price_parameter_comparison", "Comparação do parâmetro de preço", "tab:price-compare")

sigma_hat <- nested_g$step2$beta[match("log_share_within_nest", nested_g$step2$coef_names)]
cat("Sigma nested estimado em R:", sigma_hat, "\n")
