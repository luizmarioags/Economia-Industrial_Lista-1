# COMENTÁRIOS DETALHADOS
# Este script gera, em R base, o mesmo conjunto de visualizações extras do Python.
# As figuras extras avaliam concentração, composição dos nests, características, correlação de instrumentos,
# resíduos estruturais e ajuste do primeiro estágio.

# extra_01: concentração de market share por firma.
firm_share <- aggregate(share ~ firm, df, sum)
firm_share <- firm_share[order(firm_share$share), ]
save_plot("extra_01_firm_share_concentration", {
  par(mar = c(5, 8, 4, 2))
  barplot(firm_share$share, names.arg = firm_share$firm, horiz = TRUE, las = 1, cex.names = .75,
          xlab = "Share agregado", main = "Concentração de market share por firma")
})

# extra_02: tamanho dos nests/segmentos.
seg_share <- aggregate(share ~ segment, df, sum)
save_plot("extra_02_nest_sizes", {
  barplot(seg_share$share, names.arg = seg_share$segment, ylab = "Share agregado", main = "Tamanho dos nests")
})

# extra_03: características médias por segmento.
for (x in CHAR_VARS) {
  local_name <- paste0("extra_03_mean_", x, "_by_segment")
  tmp <- aggregate(df[[x]], list(segment = df$segment), mean)
  names(tmp)[2] <- x
  save_plot(local_name, {
    barplot(tmp[[x]], names.arg = tmp$segment, ylab = x, main = paste("Média de", x, "por segmento"))
  })
}

# extra_04: matriz de correlação dos instrumentos excluídos.
inst <- c(ZNESTALL)
C <- cor(df[, inst])
save_plot("extra_04_instrument_correlation_matrix", {
  image(t(C[nrow(C):1, ]), axes = FALSE, main = "Correlação entre instrumentos excluídos")
  axis(1, at = seq(0, 1, length.out = length(inst)), labels = inst, las = 2, cex.axis = .55)
  axis(2, at = seq(0, 1, length.out = length(inst)), labels = rev(inst), las = 2, cex.axis = .55)
  box()
}, width = 9, height = 9)

# extra_05: resíduos estruturais versus preço.
save_plot("extra_05_structural_residuals_vs_price", {
  plot(df$price, main_gmm$resid, pch = 19, xlab = "Preço de transação", ylab = "Resíduo estrutural estimado",
       main = "Resíduos estruturais e preço")
  abline(h = 0)
  abline(lm(main_gmm$resid ~ df$price), lwd = 2)
})

# extra_06: resíduos estruturais por firma.
save_plot("extra_06_structural_residuals_by_firm", {
  boxplot(main_gmm$resid ~ df$firm, las = 2, cex.axis = .65,
          ylab = "Resíduo estrutural", main = "Resíduos estruturais por firma")
}, width = 8, height = 5)

# extra_07: preço observado versus preço ajustado no primeiro estágio.
first_stage_X <- add_const(df[, c(CHAR_VARS, ZBOTH)])
first_stage_fit <- ols_manual(df$price, first_stage_X, c("const", CHAR_VARS, ZBOTH), "first_stage_price")$fitted
save_plot("extra_07_first_stage_price_fit", {
  plot(df$price, first_stage_fit, pch = 19, xlab = "Preço observado", ylab = "Preço ajustado no primeiro estágio",
       main = "Primeiro estágio: preço observado vs ajustado")
  lo <- min(df$price, first_stage_fit); hi <- max(df$price, first_stage_fit)
  abline(0, 1)
  xlim <- c(lo, hi)
})
