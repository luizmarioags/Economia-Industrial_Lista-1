cat("\n[run_all_R] Iniciando execução do script principal...\n")
flush.console()

# ============================================================
# 1. Raiz do projeto
# ============================================================

ROOT <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)

if (basename(ROOT) == "R") {
  ROOT <- dirname(ROOT)
}

cat("[run_all_R] ROOT definido como:\n")
cat(ROOT, "\n")
flush.console()

config_path <- file.path(ROOT, "R", "00_config.R")

cat("[run_all_R] Procurando arquivo de configuração:\n")
cat(config_path, "\n")
flush.console()

if (!file.exists(config_path)) {
  stop("Arquivo 00_config.R não encontrado em: ", config_path)
}

# ============================================================
# 2. Carrega configuração
# ============================================================

cat("[run_all_R] Carregando 00_config.R...\n")
flush.console()

t0_config <- Sys.time()

source(config_path, encoding = "UTF-8", chdir = TRUE)

t1_config <- Sys.time()

cat("[run_all_R] 00_config.R carregado com sucesso.\n")
cat(
  "[run_all_R] Tempo do 00_config.R: ",
  round(as.numeric(difftime(t1_config, t0_config, units = "secs")), 2),
  " segundos\n",
  sep = ""
)
flush.console()

# ============================================================
# 3. Log sem sink()
# ============================================================

cat("[run_all_R] Preparando arquivo de log...\n")
flush.console()

dir.create(LOG_DIR, recursive = TRUE, showWarnings = FALSE)

log_file <- file.path(LOG_DIR, "run_all_R.log")

# Reinicia o log desta execução
cat("", file = log_file, append = FALSE)

log_cat <- function(...) {
  texto <- paste0(...)

  cat(texto)
  flush.console()

  cat(texto, file = log_file, append = TRUE)
}

log_cat("[run_all_R] Log criado em: ", log_file, "\n\n")

cat("#########################################################################\n")
cat("#                            INÍCIO                                     #\n")
cat("#             Lista Berry/BLP - Replicação em R                         #\n")
cat("#########################################################################\n")

source(file.path(ROOT, "R", "01_prepare_data.R"))
source(file.path(ROOT, "R", "02_estimate_logit_iv_gmm.R"))
source(file.path(ROOT, "R", "03_nested_gmm.R"))
source(file.path(ROOT, "R", "04_elasticities_markups.R"))
source(file.path(ROOT, "R", "05_diagnostics_weakiv.R"))
source(file.path(ROOT, "R", "08_standard_tables.R"))
source(file.path(ROOT, "R", "06_visualizations.R"))
source(file.path(ROOT, "R", "07_extra_visualizations.R"))

cat("#########################################################################\n")
cat("#                            FIM                                        #\n")
cat("#########################################################################\n")
