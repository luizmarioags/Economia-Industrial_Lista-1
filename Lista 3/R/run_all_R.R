# COMENTÁRIOS DETALHADOS
# Este script é o orquestrador da replicação em R.
# Ele define a raiz do pacote, abre o log, imprime o cabeçalho do grupo, chama cada etapa modular e imprime o encerramento.

# Run all - Lista Berry/BLP em R
# Execute a partir da raiz do pacote: source("R/run_all_R.R")

ROOT <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
if (basename(ROOT) == "R") ROOT <- dirname(ROOT)
source(file.path(ROOT, "R", "00_config.R"))
log_file <- file.path(LOG_DIR, "run_all_R.log")
sink(log_file, split = TRUE)
sink(log_file, type = "message", append = TRUE)
cat("Run all R - Lista Berry/BLP\n")
# Limpa tabelas antigas para manter apenas o conjunto padronizado desta execução.
unlink(Sys.glob(file.path(TAB_CSV, "*.csv")))
unlink(Sys.glob(file.path(TAB_TEX, "*.tex")))

cat("#########################################################################\n")
cat("#                            INÍCIO                                     #\n")
cat("#             Lista 3 - Modelo BLP.                                    #\n")
cat("#             Grupo: Luiz Mario Andrade (Matrícula: 252029360)          #\n")
cat("#                    Felipe Santos (Matrícula: 232010719)               #\n")
cat("#                    Luiza Nodari (Matrícula: 242011335)                #\n")
cat("#                    Diogo Martins (Matrícula: 232001578)               #\n")
cat("#                    Sarah Moura (Matrícula: 211060316)                 #\n")
cat("#                    Pedro Bijos (Matrícula: 241003849)                 #\n")
cat("#########################################################################\n")

source(file.path(ROOT, "R", "01_prepare_data.R"))
source(file.path(ROOT, "R", "02_estimators_manual.R"))
source(file.path(ROOT, "R", "03_estimate_logit_iv_gmm.R"))
source(file.path(ROOT, "R", "04_nested_gmm.R"))
source(file.path(ROOT, "R", "05_elasticities_markups.R"))
source(file.path(ROOT, "R", "06_diagnostics.R"))
source(file.path(ROOT, "R", "07_visualizations.R"))
source(file.path(ROOT, "R", "08_extra_visualizations.R"))

cat("\nR concluído. Saídas em outputs/r/.\n")
cat("#########################################################################\n")
cat("#                            FIM                                        #\n")
cat("#                                                                       #\n")
cat("#########################################################################\n")

sink(type = "message")
sink()
