# 06_visualizations.R ------------------------------------------------------
# Gráficos principais em PDF e PNG.

source(file.path(ROOT, "R", "functions_gmm.R"))
models <- load_models()
df <- readRDS(file.path(OUTDATA, "prepared_data_R.rds"))
work <- if (file.exists(file.path(OUTDATA, "R_elasticities_markups_work.rds"))) readRDS(file.path(OUTDATA, "R_elasticities_markups_work.rds")) else df

if (requireNamespace("ggrepel", quietly = TRUE)) {
  p <- ggplot(df, aes(price, share, label = product)) + geom_point() + ggrepel::geom_text_repel(size = 2, max.overlaps = 20) + labs(title = "Share e preço por segmento", x = "Preço de transação", y = "Market share (s_j)") + theme_blp()
} else {
  p <- ggplot(df, aes(price, share)) + geom_point() + labs(title = "Share e preço por segmento", x = "Preço de transação", y = "Market share (s_j)") + theme_blp()
}
save_plot_both(p, "01_share_vs_transaction_price")

p <- df %>% arrange(desc(share)) %>% slice_head(n = 15) %>% mutate(product = reorder(product, share)) %>% ggplot(aes(product, share)) + geom_col() + coord_flip() + labs(title = "Maiores produtos por market share", x = NULL, y = "Market share") + theme_blp()
save_plot_both(p, "02_top15_market_shares")

p <- ggplot(df, aes(segment, price)) + geom_boxplot() + labs(title = "Distribuição de preços por nest/segmento", x = "Segmento", y = "Preço de transação") + theme_blp()
save_plot_both(p, "03_price_by_segment")

p <- ggplot(df, aes(price, delta)) + geom_point() + geom_smooth(method = "lm", se = FALSE) + labs(title = "Inversão logit de Berry e preço", x = "Preço de transação", y = "delta_j = ln(s_j) - ln(s_0)") + theme_blp()
save_plot_both(p, "04_delta_vs_price")

price_comp <- purrr::imap_dfr(models, function(m, nm) {
  b <- m$coefficients
  coef_price <- if ("bp" %in% names(b)) b["bp"] else if ("price" %in% names(b)) b["price"] else NA_real_
  tibble(model = nm, price_coef = as.numeric(coef_price))
}) %>% filter(is.finite(price_coef))
readr::write_csv(price_comp, file.path(OUTDATA, "price_parameter_comparison_R_graph.csv"))
p <- ggplot(price_comp, aes(reorder(model, price_coef), price_coef)) + geom_col() + coord_flip() + geom_hline(yintercept = 0, linetype = "dashed") + labs(title = "Comparação das estimativas de preço", x = NULL, y = "Coeficiente do preço (= -alpha)") + theme_blp()
save_plot_both(p, "05_price_coefficient_comparison")

if (file.exists(file.path(TABCSV, "04_elasticity_matrix_simple_logit_subset.csv"))) {
  E <- readr::read_csv(file.path(TABCSV, "04_elasticity_matrix_simple_logit_subset.csv"), show_col_types = FALSE)
  p <- ggplot(E, aes(column_product, row_product, fill = elasticity)) + geom_tile() + labs(title = "Matriz de elasticidades - logit simples", x = "Preço do produto k", y = "Share do produto j") + theme_blp() + theme(axis.text.x = element_text(angle = 45, hjust = 1))
  save_plot_both(p, "06_elasticity_matrix_subset", width = 10, height = 8)
}

if ("own_elasticity_simple_logit" %in% names(work)) {
  p <- work %>% arrange(own_elasticity_simple_logit) %>% mutate(product = reorder(product, own_elasticity_simple_logit)) %>% ggplot(aes(product, own_elasticity_simple_logit)) + geom_col() + coord_flip() + labs(title = "Elasticidades-preço próprias", x = NULL, y = "epsilon_jj") + theme_blp()
  save_plot_both(p, "07_own_price_elasticities")
  p <- ggplot(work, aes(own_elasticity_simple_logit)) + geom_histogram(aes(y = after_stat(density)), bins = 20) + geom_density() + labs(title = "Distribuição das elasticidades próprias", x = "epsilon_jj", y = "Densidade") + theme_blp()
  save_plot_both(p, "18_own_elasticity_hist_density")
  p <- ggplot(work, aes(y = own_elasticity_simple_logit)) + geom_boxplot() + labs(title = "Boxplot das elasticidades próprias", x = NULL, y = "epsilon_jj") + theme_blp()
  save_plot_both(p, "20_own_elasticity_boxplot")
}

if (all(c("markup_monoproduct", "markup_multiproduct") %in% names(work))) {
  long <- work %>% select(product, markup_monoproduct, markup_multiproduct) %>% tidyr::pivot_longer(-product, names_to = "tipo", values_to = "markup")
  p <- ggplot(long, aes(reorder(product, markup), markup, fill = tipo)) + geom_col(position = "dodge") + coord_flip() + labs(title = "Markups monoproduto e multiproduto", x = NULL, y = "Markup") + theme_blp()
  save_plot_both(p, "08_markups_mono_vs_multi", width = 10, height = 8)
  p <- ggplot(work, aes(price, markup_multiproduct)) + geom_point() + geom_smooth(method = "lm", se = FALSE) + labs(title = "Preço e markup multiproduto", x = "Preço", y = "Markup multiproduto") + theme_blp()
  save_plot_both(p, "09_price_vs_multiproduct_markup")
  p <- ggplot(work, aes(markup_multiproduct)) + geom_histogram(aes(y = after_stat(density)), bins = 20) + geom_density() + labs(title = "Distribuição dos markups multiproduto", x = "Markup multiproduto", y = "Densidade") + theme_blp()
  save_plot_both(p, "19_markup_multiproduct_hist_density")
  p <- ggplot(work, aes(y = markup_multiproduct)) + geom_boxplot() + labs(title = "Boxplot do markup multiproduto", x = NULL, y = "Markup multiproduto") + theme_blp()
  save_plot_both(p, "21_markup_multiproduct_boxplot")
}

fs_path <- file.path(OUTDATA, "first_stage_diagnostics_R.rds")
if (file.exists(fs_path)) {
  fs <- readRDS(fs_path)
  readr::write_csv(fs, file.path(OUTDATA, "first_stage_diagnostics_for_graph_R.csv"))
  p <- ggplot(fs, aes(paste(endogenous_variable, specification, sep = "\n"), robust_Wald_F_manual)) + geom_col() + coord_flip() + labs(title = "F/Wald-F robusto do primeiro estágio", x = NULL, y = "F robusto") + theme_blp()
  save_plot_both(p, "10_first_stage_robust_f")
}

# Gráfico clássico do logit: share como função da utilidade média.
v <- seq(-8, 8, length.out = 300)
curve_df <- tibble(V = v, share = exp(v)/(1 + exp(v)))
p <- ggplot(curve_df, aes(V, share)) + geom_line(linewidth = 1) + labs(title = "Curva clássica do logit", x = "V_j - ln(C_j)", y = "s_j previsto") + theme_blp()
save_plot_both(p, "11_classic_logit_curve_share_vs_utility")

if (!is.null(models$GMM_both_2)) {
  m <- models$GMM_both_2$coefficients
  focal <- df %>% arrange(desc(share)) %>% slice(1)
  grid <- tibble(price = seq(min(df$price), max(df$price), length.out = 200)) %>%
    mutate(delta = as.numeric(m["b0"] + m["bcals"]*focal$cals + m["bfat"]*focal$fat + m["bsugar"]*focal$sugar + m["bp"]*price),
           share = exp(delta)/(1 + exp(delta)),
           dsdprice = as.numeric(m["bp"])*share*(1-share))
  p <- ggplot(grid, aes(price, share)) + geom_line() + labs(title = paste("Resposta do share ao preço:", focal$product), x = "p_j simulado", y = "s_j previsto") + theme_blp()
  save_plot_both(p, "12_focal_product_share_vs_price")
  p <- ggplot(grid, aes(price, dsdprice)) + geom_line() + labs(title = paste("Efeito marginal do preço:", focal$product), x = "p_j simulado", y = "ds_j/dp_j") + theme_blp()
  save_plot_both(p, "13_focal_product_marginal_effect_vs_price")
  pred <- df %>% mutate(delta_hat = as.numeric(m["b0"] + m["bcals"]*cals + m["bfat"]*fat + m["bsugar"]*sugar + m["bp"]*price), share_pred = exp(delta_hat)/(1 + sum(exp(delta_hat))))
  p <- ggplot(pred, aes(share, share_pred)) + geom_point() + geom_abline(linetype = "dashed") + labs(title = "Shares observados vs previstos - logit simples", x = "s_j observado", y = "s_j previsto") + theme_blp()
  save_plot_both(p, "14_observed_vs_predicted_shares_simple_logit")
}

if (file.exists(file.path(OUTDATA, "R_after_simple_gmm.rds"))) {
  res <- readRDS(file.path(OUTDATA, "R_after_simple_gmm.rds"))
  p <- ggplot(res, aes(xi_gmm_both)) + geom_histogram(aes(y = after_stat(density)), bins = 20) + geom_density() + labs(title = "Distribuição do resíduo estrutural", x = "xi_j estimado", y = "Densidade") + theme_blp()
  save_plot_both(p, "15_structural_residual_hist_density")
  qq <- tibble(sample = sort(res$xi_gmm_both), theoretical = qnorm(ppoints(length(res$xi_gmm_both))))
  p <- ggplot(qq, aes(theoretical, sample)) + geom_point() + geom_abline(linetype = "dashed") + labs(title = "QQ plot do resíduo estrutural", x = "Quantis normais", y = "Quantis amostrais") + theme_blp()
  save_plot_both(p, "16_structural_residual_qqplot")
}

message("Gráficos principais exportados.")
