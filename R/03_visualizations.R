# -------------------------------------------------------------------
# Gráficos auxiliares
# -------------------------------------------------------------------

source("R/00_setup.R")
log_step("Visualizações em R: iniciando")

dat <- readRDS(file.path(PROC, "chicken_with_ols_residuals_r.rds"))

# Figura 1
series_df <- data.frame(
  year = rep(dat$year, 5),
  variable = rep(c("ln_q", "ln_pch", "ln_y", "ln_pb", "z"), each = nrow(dat)),
  value = c(dat$ln_q, dat$ln_pch, dat$ln_y, dat$ln_pb, dat$z)
)

ggplot(series_df, aes(x = year, y = value, linetype = variable)) +
  geom_line() +
  labs(title = "Séries logarítmicas principais", x = "Ano", y = "Log") +
  theme_minimal()
ggsave(file.path(FIGS, "r_fig01_series.png"), width = 9, height = 5, dpi = 300)

# Figura 2
ggplot(dat, aes(x = ln_pch, y = ln_q)) +
  geom_point() +
  geom_smooth(method = "lm", se = FALSE) +
  labs(title = "Demanda observada: ln_q versus ln_pch",
       x = "ln preço real do frango", y = "ln quantidade per capita") +
  theme_minimal()
ggsave(file.path(FIGS, "r_fig02_scatter_demand.png"), width = 7, height = 5, dpi = 300)

# Figura 3
ggplot(dat, aes(x = ols_fitted, y = ols_resid)) +
  geom_point() +
  geom_hline(yintercept = 0) +
  labs(title = "Resíduos MQO versus valores ajustados", x = "Valor ajustado", y = "Resíduo") +
  theme_minimal()
ggsave(file.path(FIGS, "r_fig03_residuals_fitted.png"), width = 7, height = 5, dpi = 300)

# Figura 4
comp <- readr::read_csv(file.path(TABS, "r_question_09_comparative.csv"), show_col_types = FALSE)
ggplot(comp, aes(x = model, y = beta_p)) +
  geom_point() +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0.15) +
  geom_hline(yintercept = 0) +
  labs(title = "Elasticidade-preço por especificação IV", x = "Instrumentos", y = "beta_p e IC 95%") +
  theme_minimal()
ggsave(file.path(FIGS, "r_fig04_beta_p_by_instrument.png"), width = 8, height = 5, dpi = 300)
