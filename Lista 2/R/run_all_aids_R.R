# Elaborado por:
# Luiz Mario Andrade (Matrícula: 252029360)
# Felipe Santos (Matrícula: 232010719)
# Luiza Nodari (Matrícula: 242011335)
# Diogo Martins (Matrícula: 232001578)
# Sarah Moura (Matrícula: 211060316)
# Pedro Bijos (Matrícula: 241003849)

################################################################################
# Arquivo: R/run_all_aids_R.R
# Objetivo: rodar toda a resolução AIDS em R, após a resolução Stata se desejado.
################################################################################

source("R/01_prepare_aids_data.R")                    # Prepara dados e cria variáveis da lista.
source("R/02_estimate_aids_R.R")                      # Estima modelos GMM em R.
source("R/03_elasticities_aids_R.R")                  # Calcula parâmetros completos e elasticidades.
source("R/04_visualizations_aids_R.R")                # Gera gráficos e tabelas visuais.
source("R/05_diagnostico_resultados_aids_R.R")   
source("R/06_compara_resultados_R_Stata.R")
source("R/07_resumo_comparacao_R_Stata.R")
message("Pacote AIDS em R concluído com sucesso.")    # Mostra mensagem final.
