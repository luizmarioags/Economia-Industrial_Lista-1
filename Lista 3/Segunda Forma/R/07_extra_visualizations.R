# 07_extra_visualizations.R -----------------------------------------------
# Gráficos extras para inspeção estatística e econômica.

source(file.path(ROOT, "R", "functions_gmm.R"))
df <- readRDS(file.path(OUTDATA, "prepared_data_R.rds"))
work <- if (file.exists(file.path(OUTDATA, "R_after_simple_gmm.rds"))) readRDS(file.path(OUTDATA, "R_after_simple_gmm.rds")) else df

firm_share <- df %>% group_by(firm) %>% summarise(total_share = sum(share), n_products = n(), .groups = "drop") %>% arrange(desc(total_share))
p <- ggplot(firm_share, aes(reorder(firm, total_share), total_share)) + geom_col() + coord_flip() + labs(title = "Concentração de share por firma", x = NULL, y = "Share total") + theme_blp()
save_plot_both(p, "extra_01_firm_share_concentration")

nest_sizes <- df %>% group_by(segment) %>% summarise(n_products = n(), total_share = sum(share), .groups = "drop")
p <- ggplot(nest_sizes, aes(reorder(segment, n_products), n_products)) + geom_col() + coord_flip() + labs(title = "Número de produtos por nest/segmento", x = NULL, y = "Produtos") + theme_blp()
save_plot_both(p, "extra_02_nest_sizes")

for (x in XVARS) {
  seg <- df %>% group_by(segment) %>% summarise(mean_value = mean(.data[[x]], na.rm = TRUE), .groups = "drop")
  p <- ggplot(seg, aes(reorder(segment, mean_value), mean_value)) + geom_col() + coord_flip() + labs(title = paste("Média de", x, "por segmento"), x = NULL, y = paste("Média de", x)) + theme_blp()
  save_plot_both(p, paste0("extra_03_mean_", x, "_by_segment"))
}

inst <- df %>% select(all_of(c(ZBOTH, ZNEST)))
cor_mat <- cor(inst, use = "pairwise.complete.obs")
cor_long <- as.data.frame(as.table(cor_mat))
names(cor_long) <- c("instrumento_1", "instrumento_2", "correlacao")
p <- ggplot(cor_long, aes(instrumento_1, instrumento_2, fill = correlacao)) + geom_tile() + labs(title = "Matriz de correlação dos instrumentos", x = NULL, y = NULL) + theme_blp() + theme(axis.text.x = element_text(angle = 45, hjust = 1))
save_plot_both(p, "extra_04_instrument_correlation_matrix", width = 10, height = 8)

if ("xi_gmm_both" %in% names(work)) {
  p <- ggplot(work, aes(price, xi_gmm_both)) + geom_point() + geom_smooth(method = "lm", se = FALSE) + geom_hline(yintercept = 0, linetype = "dashed") + labs(title = "Resíduos estruturais vs preço", x = "Preço", y = "xi_j estimado") + theme_blp()
  save_plot_both(p, "extra_05_structural_residuals_vs_price")
  p <- ggplot(work, aes(firm, xi_gmm_both)) + geom_boxplot() + coord_flip() + labs(title = "Resíduos estruturais por firma", x = NULL, y = "xi_j estimado") + theme_blp()
  save_plot_both(p, "extra_06_structural_residuals_by_firm")
}

# Ajuste do primeiro estágio: preço observado vs previsto.
fs <- fit_ols(df, "price", c("cons", XVARS, ZBOTH), bnames = c("cons", XVARS, ZBOTH))
X <- as.matrix(df[, c("cons", XVARS, ZBOTH)])
df$price_hat_first_stage <- as.numeric(X %*% fs$coefficients)
p <- ggplot(df, aes(price, price_hat_first_stage)) + geom_point() + geom_abline(linetype = "dashed") + labs(title = "Primeiro estágio: preço observado vs previsto", x = "Preço observado", y = "Preço previsto") + theme_blp()
save_plot_both(p, "extra_07_first_stage_price_fit")

message("Gráficos extras exportados.")
