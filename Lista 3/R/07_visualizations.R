# COMENTÁRIOS DETALHADOS
# Este script gera, em R base, o mesmo conjunto de gráficos principais gerado no Python.
# Cada figura é exportada em PNG 300 dpi e PDF, agora dentro de outputs/r/figures.
# A sequência 01--10 é mantida igual à do Python para facilitar comparação entre linguagens.

# Visualizações principais em R base
save_plot <- function(name, expr, width = 8, height = 5) {
  png(file.path(FIG_PNG, paste0(name, ".png")), width = width, height = height, units = "in", res = 300)
  eval.parent(substitute(expr)); dev.off()
  pdf(file.path(FIG_PDF, paste0(name, ".pdf")), width = width, height = height)
  eval.parent(substitute(expr)); dev.off()
}


# Histograma em escala de densidade com curva kernel sobreposta.
plot_hist_density <- function(x, xlab, main, zero_line = FALSE) {
  x <- x[is.finite(x)]
  hist(x, breaks = 12, probability = TRUE,
       xlab = xlab, ylab = "Densidade", main = main)
  if (length(x) >= 3 && stats::sd(x) > 0) {
    lines(stats::density(x), lwd = 2)
  }
  if (zero_line) abline(v = 0)
  legend("topright", legend = c("Histograma", "Densidade kernel"),
         lty = c(NA, 1), pch = c(15, NA), bty = "n", cex = .8)
}

# 1. Share versus preço de transação.
save_plot("01_share_vs_transaction_price", {
  plot(df$price, df$share, pch = 19, xlab = "Preço de transação", ylab = "Market share interno",
       main = "Share e preço por segmento")
  text(df$price, df$share, labels = df$product, pos = 4, cex = 0.45)
})

# 2. Top 15 produtos por share.
ord <- order(df$share, decreasing = TRUE)[1:min(15, nrow(df))]
save_plot("02_top15_market_shares", {
  par(mar = c(5, 9, 4, 2))
  barplot(rev(df$share[ord]), names.arg = rev(df$product[ord]), horiz = TRUE, las = 1, cex.names = .65,
          xlab = "Market share", main = "Maiores produtos por market share")
}, width = 9, height = 6)

# 3. Distribuição de preços por nest/segmento.
save_plot("03_price_by_segment", {
  boxplot(price ~ segment, data = df, xlab = "Segmento", ylab = "Preço de transação",
          main = "Distribuição de preços por nest/segmento")
})

# 4. Inversão logit de Berry versus preço.
save_plot("04_delta_vs_price", {
  plot(df$price, df$delta, pch = 19, xlab = "Preço de transação", ylab = "delta = ln(s_j)-ln(s_0)",
       main = "Inversão logit de Berry e preço")
  abline(lm(delta ~ price, data = df), lwd = 2)
})

# 5. Comparação dos coeficientes de preço.
save_plot("05_price_coefficient_comparison", {
  par(mar = c(9, 4, 4, 2))
  barplot(price_rows$price_coef, names.arg = price_rows$model, las = 2, cex.names = .55,
          ylab = "Coeficiente do preço (= -alpha)", main = "Comparação das estimativas de preço")
  abline(h = 0)
}, width = 10, height = 6)

# 6. Matriz de elasticidades para subconjunto.
save_plot("06_elasticity_matrix_subset", {
  m <- E[1:min(12,n), 1:min(12,n)]
  image(t(m[nrow(m):1, ]), axes = FALSE, main = "Matriz de elasticidades-preço - subconjunto")
  axis(1, at = seq(0, 1, length.out = ncol(m)), labels = colnames(m), las = 2, cex.axis = .6)
  axis(2, at = seq(0, 1, length.out = nrow(m)), labels = rev(rownames(m)), las = 2, cex.axis = .6)
  box()
}, width = 8, height = 8)

# 7. Elasticidades próprias mais intensas.
own_plot <- own_elas[order(own_elas$own_elasticity_simple_logit), ][1:min(15, nrow(own_elas)), ]
save_plot("07_own_price_elasticities", {
  par(mar = c(5, 9, 4, 2))
  barplot(rev(own_plot$own_elasticity_simple_logit), names.arg = rev(own_plot$product), horiz = TRUE,
          las = 1, cex.names = .65, xlab = "Elasticidade própria", main = "Elasticidades próprias mais intensas")
}, width = 9, height = 6)

# 18. Distribuição das elasticidades próprias: histograma + densidade.
save_plot("18_own_elasticity_hist_density", {
  plot_hist_density(own_elas$own_elasticity_simple_logit,
                    xlab = "Elasticidade própria",
                    main = "Distribuição das elasticidades próprias",
                    zero_line = TRUE)
})

# 20. Boxplot das elasticidades próprias.
save_plot("20_own_elasticity_boxplot", {
  boxplot(own_elas$own_elasticity_simple_logit,
          ylab = "Elasticidade própria", main = "Boxplot das elasticidades próprias",
          names = "Logit simples")
  abline(h = 0)
})

# 8. Markups monoproduto versus multiproduto.
mk <- markup_tab[order(-markup_tab$markup_multiproduct), ][1:min(15, nrow(markup_tab)), ]
save_plot("08_markups_mono_vs_multi", {
  par(mar = c(5, 9, 4, 2))
  vals <- rbind(rev(mk$markup_monoproduct), rev(mk$markup_multiproduct))
  colnames(vals) <- rev(mk$product)
  barplot(vals, beside = TRUE, horiz = TRUE, las = 1, cex.names = .65,
          xlab = "Markup implícito", main = "Comparação de markups implícitos")
  legend("bottomright", legend = c("Monoproduto", "Multiproduto"), bty = "n", cex = .8)
}, width = 9, height = 6)

# 9. Preço observado versus markup multiproduto.
save_plot("09_price_vs_multiproduct_markup", {
  plot(markup_tab$price, markup_tab$markup_multiproduct, pch = 19,
       xlab = "Preço observado", ylab = "Markup multiproduto",
       main = "Preço observado e markup multiproduto")
})

# 19. Distribuição dos markups multiproduto: histograma + densidade.
save_plot("19_markup_multiproduct_hist_density", {
  plot_hist_density(markup_tab$markup_multiproduct,
                    xlab = "Markup multiproduto",
                    main = "Distribuição dos markups multiproduto",
                    zero_line = TRUE)
})

# 21. Boxplot dos markups multiproduto.
save_plot("21_markup_multiproduct_boxplot", {
  boxplot(markup_tab$markup_multiproduct,
          ylab = "Markup multiproduto", main = "Boxplot dos markups multiproduto",
          names = "Multiproduto")
  abline(h = 0)
})

# 10. Diagnóstico de força dos instrumentos.
save_plot("10_first_stage_robust_f", {
  barplot(fs_tab$robust_Wald_F_manual, names.arg = fs_tab$endogenous_variable, las = 2, cex.names = .75,
          ylab = "F/Wald-F robusto manual", main = "Diagnóstico de força dos instrumentos")
  abline(h = 10, lty = 2)
}, width = 7, height = 5)

# -----------------------------------------------------------------------------
# 11--17. Gráficos clássicos e diagnósticos estatísticos do logit simples.
# -----------------------------------------------------------------------------
# A curva logística clássica deve ser produzida por simulação/predição, mantendo
# características e rivais fixos. A nuvem bruta share-preço não é uma curva logit,
# pois características, firmas e nests variam simultaneamente entre produtos.

b_logit <- setNames(main_gmm$beta, main_gmm$coef_names)
price_coef_logit <- unname(b_logit["price"])
xb_no_price <- unname(b_logit["const"]) +
  unname(b_logit["cals"]) * df$cals +
  unname(b_logit["fat"]) * df$fat +
  unname(b_logit["sugar"]) * df$sugar
vhat_logit <- xb_no_price + price_coef_logit * df$price
expv_logit <- exp(vhat_logit)
pred_share_logit <- expv_logit / (1 + sum(expv_logit))

focal_i <- which.max(df$share)
focal_name <- df$product[focal_i]
C_focal <- 1 + sum(expv_logit) - expv_logit[focal_i]

# 11. Curva clássica em S: share previsto contra a utilidade relativa V_j - ln(C_j).
# Nessa escala, s_j = 1/(1 + exp(-(V_j - ln C_j))).
save_plot("11_classic_logit_curve_share_vs_utility", {
  rel_grid <- seq(-6, 6, length.out = 250)
  s_grid <- 1 / (1 + exp(-rel_grid))
  rel_observed_index <- vhat_logit[focal_i] - log(C_focal)
  plot(rel_grid, s_grid, type = "l", lwd = 2,
       xlab = "Utilidade relativa V_j - ln(C_j)", ylab = "Share previsto",
       main = paste("Curva clássica do logit -", focal_name))
  points(rel_observed_index, pred_share_logit[focal_i], pch = 19, cex = 1.2)
  abline(v = rel_observed_index, lty = 2)
})

# 12. Share previsto contra preço simulado do produto focal.
p0_focal <- df$price[focal_i]
save_plot("12_focal_product_share_vs_price", {
  p_grid <- seq(max(0.01, 0.5 * p0_focal), 1.5 * p0_focal, length.out = 250)
  v_price <- xb_no_price[focal_i] + price_coef_logit * p_grid
  s_price <- exp(v_price) / (C_focal + exp(v_price))
  plot(p_grid, s_price, type = "l", lwd = 2,
       xlab = "Preço simulado do produto focal", ylab = "Share previsto",
       main = paste("Resposta do share ao preço -", focal_name))
  points(p0_focal, df$share[focal_i], pch = 19, cex = 1.2)
  abline(v = p0_focal, lty = 2)
})

# 13. Efeito marginal do preço ao longo da curva simulada.
save_plot("13_focal_product_marginal_effect_vs_price", {
  p_grid <- seq(max(0.01, 0.5 * p0_focal), 1.5 * p0_focal, length.out = 250)
  v_price <- xb_no_price[focal_i] + price_coef_logit * p_grid
  s_price <- exp(v_price) / (C_focal + exp(v_price))
  marginal_effect <- price_coef_logit * s_price * (1 - s_price)
  plot(p_grid, marginal_effect, type = "l", lwd = 2,
       xlab = "Preço simulado do produto focal", ylab = "Efeito marginal ds_j/dp_j",
       main = paste("Efeito marginal do preço -", focal_name))
  abline(h = 0)
  abline(v = p0_focal, lty = 2)
})

# 14. Share observado versus share previsto pelo logit simples.
save_plot("14_observed_vs_predicted_shares_simple_logit", {
  plot(pred_share_logit, df$share, pch = 19,
       xlab = "Share previsto pelo logit simples", ylab = "Share observado",
       main = "Share observado versus previsto")
  lo <- min(pred_share_logit, df$share); hi <- max(pred_share_logit, df$share)
  abline(0, 1)
  invisible(c(lo, hi))
}, width = 7, height = 5)

# 15. Histograma dos resíduos estruturais.
save_plot("15_structural_residual_histogram", {
  hist(main_gmm$resid, breaks = 12,
       xlab = "Resíduo estrutural estimado", main = "Distribuição dos resíduos estruturais")
  abline(v = 0)
})

# 16. QQ plot dos resíduos estruturais.
save_plot("16_structural_residual_qqplot", {
  qqnorm(main_gmm$resid, pch = 19, main = "QQ plot dos resíduos estruturais")
  qqline(main_gmm$resid)
}, width = 7, height = 5)

# 17. Curvas de resposta ao preço dos cinco maiores produtos.
top5_idx <- order(-df$share)[1:min(5, nrow(df))]
save_plot("17_price_response_curves_top5_products", {
  first <- TRUE
  for (idx in top5_idx) {
    p_i <- df$price[idx]
    p_grid <- seq(max(0.01, 0.5 * p_i), 1.5 * p_i, length.out = 200)
    C_i <- 1 + sum(expv_logit) - expv_logit[idx]
    v_i <- xb_no_price[idx] + price_coef_logit * p_grid
    s_i <- exp(v_i) / (C_i + exp(v_i))
    if (first) {
      plot(p_grid, s_i, type = "l", lwd = 2,
           xlab = "Preço simulado", ylab = "Share previsto",
           main = "Curvas de resposta ao preço - top 5 produtos",
           ylim = range(0, s_i))
      first <- FALSE
    } else {
      lines(p_grid, s_i, lwd = 2)
    }
  }
  legend("topright", legend = df$product[top5_idx], bty = "n", cex = .7)
})
