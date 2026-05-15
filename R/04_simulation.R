# -------------------------------------------------------------------
# Questão 14: simulação de instrumentos fracos
# CORREÇÕES APLICADAS:
#   - F médio do primeiro estágio calculado e salvo por nível de pi
#   - Estimador MQO de referência rodado em cada replicação (b_ols)
#   - Tabela final: pi, b_iv, b_ols, bias_iv, sd_iv, f_fs, cov_iv
#   - Gráfico adicional: b_iv e b_ols por pi (convergência IV -> OLS)
#   - Gráfico adicional: F médio do primeiro estágio por pi
# -------------------------------------------------------------------

source("R/00_setup.R")
source("R/00_functions.R")
log_step("Questão 14 em R: simulação de instrumentos fracos")

set.seed(26052026)

# Roda `reps` replicações para um dado nível de força do instrumento `pi_strength`.
# CORREÇÃO: agora retorna b_ols e f_fs (F médio do 1º estágio).
simulate_one_strength <- function(pi_strength, reps = 250, n = 200, beta_true = -1) {
  estimates_iv  <- numeric(reps)
  estimates_ols <- numeric(reps)
  f_stats       <- numeric(reps)
  covered       <- logical(reps)

  for (r in seq_len(reps)) {
    # DGP
    z  <- rnorm(n)
    e1 <- rnorm(n)
    v  <- 0.6 * e1 + sqrt(1 - 0.6^2) * rnorm(n)
    x  <- pi_strength * z + v
    y  <- beta_true * x + e1            # u = e1

    X <- add_const(data.frame(x = x))
    Z <- add_const(data.frame(z = z))

    # CORREÇÃO: MQO de referência
    fit_ols          <- ols_hc1(y, as.matrix(X))
    estimates_ols[r] <- fit_ols$beta[2]

    # CORREÇÃO: F do primeiro estágio em cada replicação
    fit_fs      <- ols_hc1(x, as.matrix(Z))
    wt_fs       <- wald_test(fit_fs$beta, fit_fs$vcov,
                             matrix(c(0, 1), nrow = 1),
                             df_denom = fit_fs$df)
    f_stats[r]  <- wt_fs$F

    # IV/2SLS
    fit              <- iv_2sls(y, as.matrix(X), as.matrix(Z))
    b                <- fit$beta[2]
    se               <- fit$se[2]
    estimates_iv[r]  <- b
    covered[r]       <- (b - 1.96 * se) <= beta_true && (b + 1.96 * se) >= beta_true
  }

  log_step(sprintf(
    "  pi=%.2f: IV=%.4f | OLS=%.4f | viés=%.4f | sd=%.4f | F_fs=%.2f | cobertura=%.4f",
    pi_strength,
    mean(estimates_iv), mean(estimates_ols),
    mean(estimates_iv) - beta_true,
    sd(estimates_iv),
    mean(f_stats),
    mean(covered)
  ))

  data.frame(
    pi     = pi_strength,
    b_iv   = mean(estimates_iv),
    b_ols  = mean(estimates_ols),      # CORREÇÃO: OLS médio de referência
    bias_iv = mean(estimates_iv) - beta_true,
    sd_iv  = sd(estimates_iv),
    f_fs   = mean(f_stats),            # CORREÇÃO: F médio do 1º estágio
    cov_iv = mean(covered)
  )
}

# Executa para os seis níveis de pi usados no Stata.
sim <- do.call(rbind, lapply(c(1, 0.5, 0.25, 0.10, 0.05, 0.02), simulate_one_strength))
readr::write_csv(sim, file.path(TABS, "r_question_14_simulation.csv"))
log_step("Tabela salva: output/tables/r_question_14_simulation.csv")

# -----------------------------------------------------------------------
# Gráficos da simulação
# -----------------------------------------------------------------------
load_or_install("ggplot2")

# Gráfico 1: dispersão do estimador IV quando o instrumento enfraquece.
ggplot(sim, aes(x = pi, y = sd_iv)) +
  geom_line(color = "navy") +
  geom_point(color = "navy") +
  labs(
    title    = "Simulação: dispersão do IV quando o instrumento enfraquece",
    x        = "Força do instrumento (pi)",
    y        = "Desvio-padrão do estimador IV"
  ) +
  theme_minimal()
ggsave(file.path(FIGS, "r_fig06_simulation_sd.png"), width = 8, height = 5, dpi = 300)
log_step("Gráfico salvo: output/figures/r_fig06_simulation_sd.png")

# CORREÇÃO: Gráfico 2 — b_iv e b_ols por pi (convergência IV -> OLS quando pi -> 0).
sim_long <- data.frame(
  pi        = rep(sim$pi, 2),
  estimador = rep(c("IV médio", "OLS médio"), each = nrow(sim)),
  valor     = c(sim$b_iv, sim$b_ols)
)
ggplot(sim_long, aes(x = pi, y = valor, color = estimador, linetype = estimador)) +
  geom_line() +
  geom_point() +
  geom_hline(yintercept = -1, linetype = "dotted", color = "gray40") +
  scale_color_manual(values = c("IV médio" = "navy", "OLS médio" = "firebrick")) +
  labs(
    title    = "IV converge para OLS quando instrumento enfraquece",
    subtitle = "Linha pontilhada: valor verdadeiro (beta = -1)",
    x        = "Força do instrumento (pi)",
    y        = "Estimativa média de beta",
    color    = NULL, linetype = NULL
  ) +
  theme_minimal()
ggsave(file.path(FIGS, "r_fig07_simulation_bias_convergence.png"), width = 8, height = 5, dpi = 300)
log_step("Gráfico salvo: output/figures/r_fig07_simulation_bias_convergence.png")

# CORREÇÃO: Gráfico 3 — F médio do primeiro estágio por pi.
ggplot(sim, aes(x = pi, y = f_fs)) +
  geom_line(color = "darkgreen") +
  geom_point(color = "darkgreen") +
  geom_hline(yintercept = 10, linetype = "dashed", color = "red") +
  annotate("text", x = max(sim$pi) * 0.6, y = 11.5,
           label = "Limiar convencional F = 10", color = "red", size = 3.5) +
  labs(
    title = "F médio do primeiro estágio por nível de pi",
    x     = "Força do instrumento (pi)",
    y     = "F médio (primeiro estágio)"
  ) +
  theme_minimal()
ggsave(file.path(FIGS, "r_fig08_simulation_ffs.png"), width = 8, height = 5, dpi = 300)
log_step("Gráfico salvo: output/figures/r_fig08_simulation_ffs.png")

log_step("Questão 14 em R: concluída")
