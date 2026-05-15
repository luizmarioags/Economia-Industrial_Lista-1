# -------------------------------------------------------------------
# Configuração geral do pacote em R
# -------------------------------------------------------------------

# Define a raiz como o diretório atual. Rode sempre a partir da raiz do pacote.
ROOT <- getwd()

# Define caminhos usados em todos os scripts.
RAW  <- file.path(ROOT, "data", "raw")
PROC <- file.path(ROOT, "data", "processed")
TABS <- file.path(ROOT, "output", "tables")
FIGS <- file.path(ROOT, "output", "figures")
LOGS <- file.path(ROOT, "output", "logs")

# Função simples de marcação no console.
log_step <- function(msg) {
  cat("
", paste0("[R | ", format(Sys.time(), "%H:%M:%S"), "] ", msg), "
", sep = "")
}

log_vars <- function(label, vars) {
  log_step(paste0(label, ": ", paste(vars, collapse = ", ")))
}

log_step("Configuração inicial do R")
log_step(paste0("Raiz do pacote: ", ROOT))

# Cria as pastas de saída, caso não existam.
dir.create(PROC, recursive = TRUE, showWarnings = FALSE)
dir.create(TABS, recursive = TRUE, showWarnings = FALSE)
dir.create(FIGS, recursive = TRUE, showWarnings = FALSE)
dir.create(LOGS, recursive = TRUE, showWarnings = FALSE)
log_step("Pastas verificadas/criadas: data/processed, output/tables, output/figures, output/logs")

# Instala e carrega pacotes mínimos para leitura e gráficos.
load_or_install <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    log_step(paste0("Pacote ausente; instalando: ", pkg))
    install.packages(pkg)
  }
  suppressPackageStartupMessages(library(pkg, character.only = TRUE))
  log_step(paste0("Pacote carregado: ", pkg))
}

load_or_install("haven")
load_or_install("readr")
load_or_install("ggplot2")
