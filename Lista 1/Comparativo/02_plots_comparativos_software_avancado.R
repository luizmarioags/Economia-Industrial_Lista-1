# -----------------------------------------------------------------------------
# Plots comparativos avançados entre Stata, R e Python
# -----------------------------------------------------------------------------
# Objetivo:
#   - Evitar gráficos ilegíveis com linhas sobrepostas.
#   - Gerar painéis separados por software: Stata, R e Python.
#   - Comparar beta_p, erro-padrão, p-valores, F usual, F efetivo MOP,
#     Hansen J e intervalos Anderson-Rubin.
#   - Gerar diferenças contra Stata, resumo de precisão e heatmaps.
#
# Como usar, a partir da raiz do pacote:
#   Rscript Comparativo/02_plots_comparativos_software_avancado.R
#
# Opções:
#   Rscript Comparativo/02_plots_comparativos_software_avancado.R \
#     --tables-dir=output/tables \
#     --figures-dir=output/figures/comparative_software_advanced_R
#
# Também aceita um zip contendo uma pasta tables/:
#   Rscript Comparativo/02_plots_comparativos_software_avancado.R \
#     --tables-zip=tables.zip
# -----------------------------------------------------------------------------

# ---------------------------
# 0. Pacotes e argumentos
# ---------------------------
load_or_install <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg)
  }
  suppressPackageStartupMessages(library(pkg, character.only = TRUE))
}

load_or_install("ggplot2")
load_or_install("readr")
load_or_install("dplyr")
load_or_install("tidyr")
load_or_install("stringr")
load_or_install("scales")

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(prefix, default = NULL) {
  hit <- args[startsWith(args, prefix)]
  if (length(hit) == 0) return(default)
  sub(prefix, "", hit[1], fixed = TRUE)
}

ROOT <- getwd()
TABLES_DIR <- get_arg("--tables-dir=", file.path(ROOT, "output", "tables"))
FIGURES_DIR <- get_arg("--figures-dir=", file.path(ROOT, "output", "figures", "comparative_software_advanced_R"))
TABLES_ZIP <- get_arg("--tables-zip=", NULL)

if (!is.null(TABLES_ZIP)) {
  tmp_dir <- tempfile("tables_zip_R_")
  dir.create(tmp_dir, recursive = TRUE, showWarnings = FALSE)
  unzip(TABLES_ZIP, exdir = tmp_dir)
  if (dir.exists(file.path(tmp_dir, "tables"))) {
    TABLES_DIR <- file.path(tmp_dir, "tables")
  } else {
    TABLES_DIR <- tmp_dir
  }
}

dir.create(TABLES_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(FIGURES_DIR, recursive = TRUE, showWarnings = FALSE)

ts_msg <- function(msg) {
  cat("\n[Comparativo R | ", format(Sys.time(), "%H:%M:%S"), "] ", msg, "\n", sep = "")
}

MODEL_ORDER <- paste0("Z", 1:7)
SOFTWARE_ORDER <- c("Stata", "R", "Python")

METRICS_MAIN <- c("beta_p", "se_p", "pval_p", "F_usual", "p_F", "F_eff_MOP", "hansen_p")
METRIC_LABELS <- c(
  beta_p = "beta[p]",
  se_p = "Erro-padrão robusto de beta[p]",
  pval_p = "p-valor de beta[p]",
  F_usual = "F usual do primeiro estágio",
  p_F = "p-valor do F usual",
  F_eff_MOP = "F efetivo MOP",
  hansen_p = "p-valor do teste J de Hansen"
)

# ---------------------------
# 1. Funções auxiliares
# ---------------------------
read_csv_flex <- function(path) {
  out <- tryCatch(
    readr::read_csv(path, show_col_types = FALSE, progress = FALSE),
    error = function(e) NULL
  )
  if (is.null(out) || ncol(out) <= 1) {
    out <- readr::read_delim(path, delim = ";", show_col_types = FALSE, progress = FALSE)
  }
  out
}

to_num <- function(x) {
  if (is.numeric(x)) return(x)
  x <- as.character(x)
  x <- stringr::str_trim(x)
  x <- gsub("%", "", x, fixed = TRUE)
  x <- gsub(" ", "", x, fixed = TRUE)
  x <- gsub(",", ".", x, fixed = TRUE)
  x[x %in% c("", ".", "nan", "NaN", "None", "NA", "NULL")] <- NA_character_
  suppressWarnings(as.numeric(x))
}

bool_to_num <- function(x) {
  if (is.numeric(x)) return(as.integer(x != 0))
  z <- tolower(stringr::str_trim(as.character(x)))
  as.integer(z %in% c("1", "true", "t", "yes", "sim"))
}

standardize_names <- function(df) {
  nm <- names(df)
  nm2 <- nm
  lower <- tolower(nm)

  alias <- c(
    model = "model", modelo = "model", instrumentos = "model", instruments = "model", spec = "model",
    n = "N", obs = "N", observations = "N",
    k = "k_inst", k_inst = "k_inst", n_inst = "k_inst", num_inst = "k_inst",
    beta_p = "beta_p", b = "beta_p", coef = "beta_p", coefficient = "beta_p", estimate = "beta_p", ln_pch = "beta_p",
    se_p = "se_p", se = "se_p", std_err = "se_p", stderr = "se_p", std.error = "se_p", robust_se = "se_p",
    pval_p = "pval_p", p_value = "pval_p", pval = "pval_p", p_beta = "pval_p",
    ci_low = "ci_low", ci_lower = "ci_low", lower = "ci_low", lb = "ci_low", low_95 = "ci_low",
    ci_high = "ci_high", ci_upper = "ci_high", upper = "ci_high", ub = "ci_high", high_95 = "ci_high",
    f_usual = "F_usual", F_usual = "F_usual", f_first = "F_usual", first_stage_f = "F_usual", first_stage_F = "F_usual",
    p_f = "p_F", p_F = "p_F", p_first = "p_F",
    f_eff = "F_eff_MOP", F_eff = "F_eff_MOP", f_eff_mop = "F_eff_MOP", F_eff_MOP = "F_eff_MOP", mop_f = "F_eff_MOP",
    cv5 = "cv5", cv10 = "cv10", cv20 = "cv20",
    hansen_j = "hansen_J", Hansen_J = "hansen_J", j = "hansen_J",
    hansen_p = "hansen_p", Hansen_p = "hansen_p", jp = "hansen_p", j_p = "hansen_p", p_j = "hansen_p", p_hansen = "hansen_p",
    ar_low = "ar_low", ar_high = "ar_high", ar_low_grid = "ar_low_grid", ar_high_grid = "ar_high_grid",
    beta0_minp = "beta0_minp", p_min = "p_min", p_max = "p_max",
    grid_min = "grid_min", grid_max = "grid_max", grid_step = "grid_step",
    open_left = "open_left", open_right = "open_right", empty_interval = "empty_interval",
    n_expand = "n_expand", npoints_final = "npoints_final"
  )

  for (i in seq_along(nm)) {
    if (nm[i] %in% names(alias)) nm2[i] <- unname(alias[nm[i]])
    else if (lower[i] %in% names(alias)) nm2[i] <- unname(alias[lower[i]])
  }
  names(df) <- nm2
  df
}

standardize_model <- function(df) {
  if (!"model" %in% names(df)) df$model <- paste0("Z", seq_len(nrow(df)))
  df$model <- df$model |>
    as.character() |>
    stringr::str_trim() |>
    toupper() |>
    stringr::str_replace_all(" ", "") |>
    stringr::str_replace_all("GMM_", "") |>
    stringr::str_replace_all("2SLS_", "")
  df <- df[df$model %in% MODEL_ORDER, , drop = FALSE]
  df$model <- factor(df$model, levels = MODEL_ORDER, ordered = TRUE)
  df$model_num <- as.integer(df$model)
  df[order(df$model), , drop = FALSE]
}

find_file <- function(software, kind = c("q09", "ar")) {
  kind <- match.arg(kind)
  s <- tolower(software)
  patterns <- if (kind == "q09") {
    c(paste0(s, "_question_09_comparative.csv"), paste0(s, "_iv_results_weakivtest.csv"), paste0(s, "_iv_results.csv"))
  } else {
    c(paste0(s, "_question_11_ar_intervals.csv"))
  }

  candidates <- c(
    file.path(TABLES_DIR, patterns),
    file.path(TABLES_DIR, software, patterns),
    file.path(TABLES_DIR, s, patterns)
  )
  existing <- candidates[file.exists(candidates)]
  if (length(existing) > 0) return(existing[1])

  recursive <- list.files(TABLES_DIR, pattern = paste(patterns, collapse = "|"), recursive = TRUE, full.names = TRUE)
  recursive <- recursive[file.exists(recursive)]
  if (length(recursive) > 0) return(recursive[1])
  NA_character_
}

read_question09 <- function() {
  frames <- list()
  used <- data.frame(software = character(), file = character(), stringsAsFactors = FALSE)

  for (soft in SOFTWARE_ORDER) {
    path <- find_file(soft, "q09")
    used <- rbind(used, data.frame(software = soft, file = ifelse(is.na(path), NA, path)))
    if (is.na(path)) next

    df <- read_csv_flex(path) |> standardize_names() |> standardize_model()
    df$software <- soft

    needed <- c("N", "k_inst", "beta_p", "se_p", "pval_p", "ci_low", "ci_high",
                "F_usual", "p_F", "F_eff_MOP", "cv5", "cv10", "cv20", "hansen_J", "hansen_p")
    for (v in needed) if (!v %in% names(df)) df[[v]] <- NA_real_
    for (v in needed) df[[v]] <- to_num(df[[v]])

    miss_ci <- is.na(df$ci_low) | is.na(df$ci_high)
    can_ci <- !is.na(df$beta_p) & !is.na(df$se_p)
    df$ci_low[miss_ci & can_ci] <- df$beta_p[miss_ci & can_ci] - 1.96 * df$se_p[miss_ci & can_ci]
    df$ci_high[miss_ci & can_ci] <- df$beta_p[miss_ci & can_ci] + 1.96 * df$se_p[miss_ci & can_ci]

    frames[[soft]] <- df[, c("software", "model", "model_num", needed), drop = FALSE]
  }

  if (length(frames) == 0) stop("Nenhuma tabela Q09 encontrada em ", TABLES_DIR)
  out <- dplyr::bind_rows(frames)
  out$software <- factor(out$software, levels = SOFTWARE_ORDER, ordered = TRUE)
  out <- out |> arrange(model, software)
  readr::write_csv(out, file.path(TABLES_DIR, "comparative_software_results_advanced_R.csv"))
  readr::write_csv(used, file.path(TABLES_DIR, "comparative_software_files_used_R.csv"))
  out
}

read_question11 <- function() {
  frames <- list()
  for (soft in SOFTWARE_ORDER) {
    path <- find_file(soft, "ar")
    if (is.na(path)) next
    df <- read_csv_flex(path) |> standardize_names() |> standardize_model()
    df$software <- soft

    needed <- c("N", "k_inst", "ar_low", "ar_high", "ar_low_grid", "ar_high_grid",
                "beta0_minp", "p_min", "p_max", "grid_min", "grid_max", "grid_step",
                "n_expand", "npoints_final", "open_left", "open_right", "empty_interval")
    for (v in needed) if (!v %in% names(df)) df[[v]] <- NA
    for (v in setdiff(needed, c("open_left", "open_right", "empty_interval"))) df[[v]] <- to_num(df[[v]])
    for (v in c("open_left", "open_right", "empty_interval")) df[[v]] <- bool_to_num(df[[v]])

    df$ar_low_grid[is.na(df$ar_low_grid)] <- df$ar_low[is.na(df$ar_low_grid)]
    df$ar_high_grid[is.na(df$ar_high_grid)] <- df$ar_high[is.na(df$ar_high_grid)]

    frames[[soft]] <- df[, c("software", "model", "model_num", needed), drop = FALSE]
  }

  if (length(frames) == 0) return(NULL)
  out <- dplyr::bind_rows(frames)
  out$software <- factor(out$software, levels = SOFTWARE_ORDER, ordered = TRUE)
  out <- out |> arrange(model, software)
  readr::write_csv(out, file.path(TABLES_DIR, "comparative_AR_intervals_advanced_R.csv"))
  out
}

# ---------------------------
# 2. Leitura das tabelas
# ---------------------------
ts_msg("Lendo tabelas comparativas")
comp <- read_question09()
ar_comp <- read_question11()

# ---------------------------
# 3. Plots em painéis por software
# ---------------------------
plot_metric_facet <- function(df, metric, filename, title, ylab, ref = NULL) {
  sub <- df |> filter(!is.na(.data[[metric]]))
  if (nrow(sub) == 0) return(invisible(NULL))

  p <- ggplot(sub, aes(x = model, y = .data[[metric]], group = 1)) +
    geom_line(linewidth = 0.8) +
    geom_point(size = 2.2) +
    facet_wrap(~ software, nrow = 1) +
    labs(title = title, x = "Conjunto de instrumentos", y = ylab) +
    theme_minimal(base_size = 12) +
    theme(legend.position = "none")

  if (!is.null(ref)) {
    p <- p + geom_hline(yintercept = ref, linetype = "dashed")
  }

  ggsave(file.path(FIGURES_DIR, filename), p, width = 12, height = 4.6, dpi = 300)
}

plot_metric_facet(comp, "F_usual", "facet_first_stage_F_usual_by_software_R.png",
                  "F usual do primeiro estágio — painéis por software", "F usual", ref = 10)
plot_metric_facet(comp, "F_eff_MOP", "facet_F_eff_MOP_by_software_R.png",
                  "F efetivo MOP — painéis por software", "F efetivo MOP")
plot_metric_facet(comp, "se_p", "facet_standard_errors_by_software_R.png",
                  "Precisão convencional das estimativas de beta[p]", "Erro-padrão robusto")
plot_metric_facet(comp, "hansen_p", "facet_hansen_p_by_software_R.png",
                  "Teste J de Hansen — painéis por software", "p-valor Hansen J", ref = 0.05)
plot_metric_facet(comp, "pval_p", "facet_pval_beta_p_by_software_R.png",
                  "p-valor de beta[p] — painéis por software", "p-valor", ref = 0.05)

# beta_p com IC convencional por software
sub_beta <- comp |> filter(!is.na(beta_p))
if (nrow(sub_beta) > 0) {
  p_beta <- ggplot(sub_beta, aes(x = model, y = beta_p)) +
    geom_hline(yintercept = 0, linetype = "dashed") +
    geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0.12, na.rm = TRUE) +
    geom_point(size = 2.1) +
    facet_wrap(~ software, nrow = 1) +
    labs(title = "Estimativa de beta[p] e IC 95% — painéis por software",
         x = "Conjunto de instrumentos", y = "beta[p]") +
    theme_minimal(base_size = 12)
  ggsave(file.path(FIGURES_DIR, "facet_beta_p_ci_by_software_R.png"), p_beta, width = 12, height = 4.6, dpi = 300)
}

# AR intervals
if (!is.null(ar_comp) && nrow(ar_comp) > 0) {
  ar_plot <- ar_comp |> mutate(
    interval_label = dplyr::case_when(
      empty_interval == 1 ~ "vazio",
      open_left == 1 & open_right == 1 ~ "aberto nos dois lados",
      open_left == 1 ~ "aberto à esquerda",
      open_right == 1 ~ "aberto à direita",
      TRUE ~ "fechado"
    )
  )
  p_ar <- ggplot(ar_plot, aes(x = model)) +
    geom_errorbar(aes(ymin = ar_low_grid, ymax = ar_high_grid, linetype = interval_label), width = 0.15, na.rm = TRUE) +
    geom_point(aes(y = beta0_minp), size = 2, na.rm = TRUE) +
    facet_wrap(~ software, nrow = 1) +
    labs(title = "Intervalos Anderson-Rubin — painéis por software",
         subtitle = "Linhas mostram o intervalo observado na grade; ponto indica beta0 menos rejeitado",
         x = "Conjunto de instrumentos", y = "beta[p]", linetype = "Tipo") +
    theme_minimal(base_size = 12)
  ggsave(file.path(FIGURES_DIR, "facet_AR_intervals_by_software_R.png"), p_ar, width = 12, height = 4.8, dpi = 300)
}

# ---------------------------
# 4. Diferenças contra Stata
# ---------------------------
ts_msg("Calculando diferenças contra Stata")
metrics_diff <- c("beta_p", "se_p", "F_usual", "F_eff_MOP", "hansen_p")
stata_base <- comp |>
  filter(software == "Stata") |>
  select(model, all_of(metrics_diff)) |>
  rename_with(~ paste0(.x, "_stata"), all_of(metrics_diff))

diff_long <- comp |>
  filter(software != "Stata") |>
  left_join(stata_base, by = "model") |>
  pivot_longer(cols = all_of(metrics_diff), names_to = "metric", values_to = "value") |>
  mutate(stata_value = dplyr::case_when(
    metric == "beta_p" ~ beta_p_stata,
    metric == "se_p" ~ se_p_stata,
    metric == "F_usual" ~ F_usual_stata,
    metric == "F_eff_MOP" ~ F_eff_MOP_stata,
    metric == "hansen_p" ~ hansen_p_stata,
    TRUE ~ NA_real_
  )) |>
  mutate(
    diff_vs_stata = value - stata_value,
    abs_diff_vs_stata = abs(diff_vs_stata),
    rel_abs_diff_vs_stata = abs_diff_vs_stata / pmax(abs(stata_value), .Machine$double.eps)
  ) |>
  filter(!is.na(value), !is.na(stata_value))

readr::write_csv(diff_long, file.path(TABLES_DIR, "comparative_differences_vs_stata_long_R.csv"))

acc <- diff_long |>
  group_by(software, metric) |>
  summarise(
    MAE = mean(abs_diff_vs_stata, na.rm = TRUE),
    RMSE = sqrt(mean(diff_vs_stata^2, na.rm = TRUE)),
    MaxAbs = max(abs_diff_vs_stata, na.rm = TRUE),
    .groups = "drop"
  )
readr::write_csv(acc, file.path(TABLES_DIR, "comparative_accuracy_summary_vs_stata_R.csv"))

if (nrow(acc) > 0) {
  p_mae <- ggplot(acc, aes(x = metric, y = MAE, fill = software)) +
    geom_col(position = "dodge") +
    scale_y_continuous(labels = scales::label_number(accuracy = 1e-6)) +
    labs(title = "Erro absoluto médio em relação ao Stata", x = "Métrica", y = "MAE", fill = "Software") +
    theme_minimal(base_size = 12) +
    theme(axis.text.x = element_text(angle = 35, hjust = 1))
  ggsave(file.path(FIGURES_DIR, "summary_MAE_vs_Stata_by_metric_R.png"), p_mae, width = 9, height = 5, dpi = 300)
}

if (nrow(diff_long) > 0) {
  p_heat_abs <- ggplot(diff_long, aes(x = model, y = paste(software, metric, sep = " - "), fill = abs_diff_vs_stata)) +
    geom_tile() +
    scale_fill_viridis_c(option = "C", na.value = "grey90") +
    labs(title = "Heatmap de diferenças absolutas contra Stata", x = "Modelo", y = "Software - métrica", fill = "|diferença|") +
    theme_minimal(base_size = 11)
  ggsave(file.path(FIGURES_DIR, "heatmap_abs_diff_vs_Stata_R.png"), p_heat_abs, width = 10, height = 6.5, dpi = 300)

  p_heat_rel <- ggplot(diff_long, aes(x = model, y = paste(software, metric, sep = " - "), fill = rel_abs_diff_vs_stata)) +
    geom_tile() +
    scale_fill_viridis_c(option = "C", trans = "sqrt", na.value = "grey90") +
    labs(title = "Heatmap de diferenças relativas absolutas contra Stata", x = "Modelo", y = "Software - métrica", fill = "dif. relativa") +
    theme_minimal(base_size = 11)
  ggsave(file.path(FIGURES_DIR, "heatmap_relative_abs_diff_vs_Stata_R.png"), p_heat_rel, width = 10, height = 6.5, dpi = 300)

  # Scatter R/Python versus Stata por métrica
  for (m in metrics_diff) {
    scat <- diff_long |> filter(metric == m)
    if (nrow(scat) == 0) next
    lims <- range(c(scat$value, scat$stata_value), na.rm = TRUE)
    p_scat <- ggplot(scat, aes(x = stata_value, y = value, shape = software)) +
      geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
      geom_point(size = 2.4) +
      geom_text(aes(label = model), nudge_y = 0.03 * diff(lims), size = 3, check_overlap = TRUE) +
      coord_equal(xlim = lims, ylim = lims) +
      labs(title = paste0(m, ": R/Python versus Stata"), x = "Stata", y = "R/Python", shape = "Software") +
      theme_minimal(base_size = 12)
    ggsave(file.path(FIGURES_DIR, paste0("scatter_vs_Stata_", m, "_R.png")), p_scat, width = 6.2, height = 5.5, dpi = 300)
  }
}

# ---------------------------
# 5. Relatório simples
# ---------------------------
report <- c(
  "Relatório dos gráficos comparativos avançados em R",
  "=================================================",
  "",
  paste0("Tabelas lidas de: ", normalizePath(TABLES_DIR, mustWork = FALSE)),
  paste0("Figuras salvas em: ", normalizePath(FIGURES_DIR, mustWork = FALSE)),
  "",
  "Arquivos principais gerados:",
  "- comparative_software_results_advanced_R.csv",
  "- comparative_AR_intervals_advanced_R.csv, se houver tabelas AR",
  "- comparative_differences_vs_stata_long_R.csv",
  "- comparative_accuracy_summary_vs_stata_R.csv",
  "",
  "Figuras geradas:",
  paste0("- ", basename(list.files(FIGURES_DIR, pattern = "\\.png$", full.names = FALSE)))
)
writeLines(report, file.path(FIGURES_DIR, "relatorio_comparativo_avancado_R.txt"))
ts_msg("Concluído")
ts_msg(paste0("Figuras: ", FIGURES_DIR))
