# COMENTÁRIOS DETALHADOS
# Este script é o orquestrador da replicação em R.
# Ele define a raiz do pacote, abre o log, imprime o cabeçalho do grupo,
# chama cada etapa modular e imprime o encerramento.

# Run all - Lista Berry/BLP em R
# Execute a partir da raiz do pacote: source("R/run_all_R.R")

# ============================================================
# 0. Mensagem inicial antes de qualquer source()
# ============================================================

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

# ============================================================
# 4. Cabeçalho da execução
# ============================================================

log_cat("Run all R - Lista Berry/BLP\n")

log_cat("#########################################################################\n")
log_cat("#                            INÍCIO                                     #\n")
log_cat("#             Lista 3 - Modelo BLP.                                    #\n")
log_cat("#             Grupo: Luiz Mario Andrade (Matrícula: 252029360)          #\n")
log_cat("#                    Felipe Santos (Matrícula: 232010719)               #\n")
log_cat("#                    Luiza Nodari (Matrícula: 242011335)                #\n")
log_cat("#                    Diogo Martins (Matrícula: 232001578)               #\n")
log_cat("#                    Sarah Moura (Matrícula: 211060316)                 #\n")
log_cat("#                    Pedro Bijos (Matrícula: 241003849)                 #\n")
log_cat("#########################################################################\n\n")

log_cat("Diretório raiz: ", ROOT, "\n")
log_cat("Arquivo de log: ", log_file, "\n\n")

# ============================================================
# 5. Limpeza de tabelas antigas
# ============================================================

log_cat("Limpando tabelas antigas...\n")

unlink(Sys.glob(file.path(TAB_CSV, "*.csv")))
unlink(Sys.glob(file.path(TAB_TEX, "*.tex")))

log_cat("Limpeza concluída.\n\n")

# ============================================================
# 6. Função para executar cada módulo
# ============================================================

run_step <- function(script) {
  script_path <- file.path(ROOT, "R", script)

  log_cat("---------------------------------------------------------------------\n")
  log_cat("[", format(Sys.time(), "%H:%M:%S"), "] Iniciando: ", script, "\n")
  log_cat("Caminho: ", script_path, "\n")
  log_cat("---------------------------------------------------------------------\n")

  if (!file.exists(script_path)) {
    stop("Script não encontrado: ", script_path)
  }

  t0 <- Sys.time()

  tryCatch(
    {
      withCallingHandlers(
        {
          source(script_path, encoding = "UTF-8", chdir = TRUE)
        },
        warning = function(w) {
          log_cat("\n[WARNING em ", script, "] ", conditionMessage(w), "\n")
          invokeRestart("muffleWarning")
        },
        message = function(m) {
          log_cat("\n[MESSAGE em ", script, "] ", conditionMessage(m), "\n")
          invokeRestart("muffleMessage")
        }
      )
    },
    error = function(e) {
      log_cat("\n[ERRO em ", script, "] ", conditionMessage(e), "\n")
      stop(e)
    }
  )

  t1 <- Sys.time()

  log_cat("[", format(Sys.time(), "%H:%M:%S"), "] Concluído: ", script, "\n")
  log_cat(
    "Tempo da etapa: ",
    round(as.numeric(difftime(t1, t0, units = "secs")), 2),
    " segundos\n\n"
  )
}

# ============================================================
# 7. Execução dos módulos
# ============================================================

scripts <- c(
  "01_prepare_data.R",
  "02_estimators_manual.R",
  "03_estimate_logit_iv_gmm.R",
  "04_nested_gmm.R",
  "05_elasticities_markups.R",
  "06_diagnostics.R",
  "07_visualizations.R",
  "08_extra_visualizations.R"
)

for (script in scripts) {
  run_step(script)
}

# ============================================================
# 8. Encerramento
# ============================================================

log_cat("\nR concluído. Saídas em outputs/r/.\n")

log_cat("#########################################################################\n")
log_cat("#                            FIM                                        #\n")
log_cat("#                                                                       #\n")
log_cat("#########################################################################\n")