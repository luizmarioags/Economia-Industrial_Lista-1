# -------------------------------------------------------------------
# Script mestre em R
# -------------------------------------------------------------------

source("R/00_setup.R")
log_step("INÍCIO DA REPLICAÇÃO EM R")

log_step("Rodando R/01_prepare_data.R: importação, correção de escala e criação de variáveis")
source("R/01_prepare_data.R")

log_step("Rodando R/02_estimations.R: MQO, 2SLS, primeiro estágio, GMM, Hansen J e AR")
source("R/02_estimations.R")

log_step("Rodando R/03_visualizations.R: gráficos auxiliares")
source("R/03_visualizations.R")

log_step("Rodando R/04_simulation.R: simulação de instrumentos fracos")
source("R/04_simulation.R")

log_step("FIM DA REPLICAÇÃO EM R")
