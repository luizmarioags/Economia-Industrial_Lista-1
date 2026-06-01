################################################################################
# Arquivo: R/00_config_aids.R
# Objetivo: definir diretórios, pacotes e opções gerais da resolução AIDS em R.
################################################################################

rm(list = ls())                                      # Remove objetos antigos da sessão R.
options(stringsAsFactors = FALSE)                    # Evita conversão automática de texto em fatores.
options(scipen = 999)                                # Evita notação científica em tabelas pequenas.

ROOT <- getwd()                                      # Usa a pasta atual como raiz do projeto.
RAW <- file.path(ROOT, "data", "raw")                # Define pasta dos dados brutos.
PROC <- file.path(ROOT, "data", "processed")         # Define pasta dos dados processados.
OUT <- file.path(ROOT, "output")                     # Define pasta geral de resultados.
TABLES <- file.path(OUT, "tables")                   # Define pasta de tabelas.
FIGURES <- file.path(OUT, "figures")                 # Define pasta de gráficos.
LOGS <- file.path(OUT, "logs")                       # Define pasta de logs.
MODELS <- file.path(OUT, "models")                   # Define pasta de modelos salvos.

dir.create(PROC, recursive = TRUE, showWarnings = FALSE)    # Cria pasta de dados processados.
dir.create(TABLES, recursive = TRUE, showWarnings = FALSE)  # Cria pasta de tabelas.
dir.create(FIGURES, recursive = TRUE, showWarnings = FALSE) # Cria pasta de gráficos.
dir.create(LOGS, recursive = TRUE, showWarnings = FALSE)    # Cria pasta de logs.
dir.create(MODELS, recursive = TRUE, showWarnings = FALSE)  # Cria pasta de modelos.

RAW_CSV <- file.path(RAW, "meatdata.csv")            # Define caminho do CSV bruto.
PROC_CSV <- file.path(PROC, "meatdata_aids_preparado_R.csv") # Define caminho do CSV processado.

GOODS <- c("bfvl", "pork", "poult", "fish")          # Define os quatro produtos do sistema.
EST_GOODS <- c("bfvl", "pork", "fish")               # Define as equações estimadas.
OMIT_GOOD <- "poult"                                  # Define o produto omitido como equação.

needed_packages <- c("readr", "dplyr", "tidyr", "ggplot2", "purrr", "stringr", "tibble") # Lista pacotes necessários.
missing_packages <- needed_packages[!vapply(needed_packages, requireNamespace, logical(1), quietly = TRUE)] # Identifica pacotes ausentes.
if (length(missing_packages) > 0) {                   # Verifica se há pacotes ausentes.
  stop(paste("Instale os pacotes antes de rodar:", paste(missing_packages, collapse = ", "))) # Interrompe com mensagem clara.
}                                                     # Fecha a verificação de pacotes.

library(readr)                                        # Carrega funções de leitura e escrita de CSV.
library(dplyr)                                        # Carrega manipulação de dados.
library(tidyr)                                        # Carrega transformação largo-longo.
library(ggplot2)                                      # Carrega gráficos.
library(purrr)                                        # Carrega programação funcional.
library(stringr)                                      # Carrega funções de texto.
library(tibble)                                       # Carrega tibbles.
