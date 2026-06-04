# COMENTÁRIOS DETALHADOS
# Este script usa alpha estimado no GMM principal para calcular elasticidades próprias/cruzadas e markups.
# Todas as tabelas econômicas são salvas em CSV e TEX com nomes padronizados iguais aos de Python e Stata.
# Matrizes de elasticidade são salvas em formato longo para preservar a comparabilidade entre linguagens.

# Elasticidades e markups
main_gmm <- res$GMM_both_2
alpha_hat <- -main_gmm$beta[match("price", main_gmm$coef_names)]
cat("Alpha usado em R:", alpha_hat, "\n")

n <- nrow(df)
E <- matrix(NA_real_, n, n, dimnames = list(df$product, df$product))
for (j in 1:n) for (k in 1:n) {
  if (j == k) E[j, k] <- -alpha_hat * df$price[j] * (1 - df$share[j]) else E[j, k] <- alpha_hat * df$price[k] * df$share[k]
}
save_table(matrix_to_long(E), "03_elasticity_matrix_simple_logit", "Matriz de elasticidades - logit simples", "tab:elas-simple")

top_products <- df$product[order(-df$share)][1:min(12, n)]
E_subset <- E[top_products, top_products, drop = FALSE]
save_table(matrix_to_long(E_subset), "04_elasticity_matrix_simple_logit_subset", "Matriz de elasticidades - logit simples - subconjunto", "tab:elas-simple-subset")

own_elas <- data.frame(product = df$product, firm = df$firm, segment = df$segment, price = df$price, share = df$share,
                       own_elasticity_simple_logit = diag(E))
own_elas <- own_elas[order(-own_elas$share), ]
save_table(own_elas, "05_own_elasticities_simple_logit", "Elasticidades próprias - logit simples", "tab:own-elas-simple")

En <- nested_logit_numeric_elasticities(df, nested_g$step2)
if (is.null(En)) {
  nested_long <- data.frame(row_product = character(), column_product = character(), elasticity = numeric())
  nested_own <- data.frame(product = character(), own_elasticity_nested_logit = numeric())
} else {
  nested_long <- matrix_to_long(En)
  nested_own <- data.frame(product = df$product, own_elasticity_nested_logit = diag(En))
  nested_own <- nested_own[order(nested_own$own_elasticity_nested_logit), ]
}
save_table(nested_long, "06_elasticity_matrix_nested_logit", "Matriz de elasticidades - nested logit", "tab:elas-nested")
save_table(nested_own, "07_own_elasticities_nested_logit", "Elasticidades próprias - nested logit", "tab:own-elas-nested")

mono <- 1 / (alpha_hat * (1 - df$share))
Delta <- matrix(0, n, n)
for (j in 1:n) for (k in 1:n) if (df$firm[j] == df$firm[k]) {
  if (j == k) Delta[j, k] <- alpha_hat * df$share[j] * (1 - df$share[j]) else Delta[j, k] <- -alpha_hat * df$share[j] * df$share[k]
}
multi <- as.numeric(pinv(Delta) %*% df$share)
markup_tab <- data.frame(product = df$product, firm = df$firm, segment = df$segment, price = df$price, share = df$share,
                         markup_monoproduct = mono, mc_monoproduct = df$price - mono,
                         markup_multiproduct = multi, mc_multiproduct = df$price - multi,
                         markup_mono_over_price = mono/df$price, markup_multi_over_price = multi/df$price)
save_table(markup_tab, "08_markups", "Markups implícitos - logit simples", "tab:markups")
