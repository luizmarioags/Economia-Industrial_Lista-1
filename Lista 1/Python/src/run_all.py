"""Script mestre Python."""
from config import log_step
from prepare_data import prepare_data
from estimations import run_estimations
from visualizations import run_visualizations
from simulation import run_simulation


if __name__ == "__main__":
    log_step("INÍCIO DA REPLICAÇÃO EM PYTHON")
    log_step("Rodando prepare_data(): importação, correção de escala e criação de variáveis")
    prepare_data()
    log_step("Rodando run_estimations(): MQO, 2SLS, primeiro estágio, GMM, Hansen J e AR")
    run_estimations()
    log_step("Rodando run_visualizations(): gráficos auxiliares")
    run_visualizations()
    log_step("Rodando run_simulation(): simulação de instrumentos fracos")
    run_simulation()
    log_step("FIM DA REPLICAÇÃO EM PYTHON")
