/********************************************************************
 Script mestre: roda toda a replicação em Stata
********************************************************************/

clear all
set more off

di as text _newline "[Stata] INÍCIO DA REPLICAÇÃO EM STATA"

* Carrega caminhos, pastas e dependências.
di as text "[Stata] Rodando Stata/config.do: caminhos, pastas e dependências"
do "Stata/config.do"

* Abre log geral da execução.
cap log close _all
log using "$LOGS/stata_master.log", replace text

di as text "[Stata] Log geral aberto em output/logs/stata_master.log"

* Prepara a base e constrói variáveis da lista.
di as text "[Stata] Rodando Stata/01_prepare_data.do: importação, correção de escala e criação de variáveis"
do "Stata/01_prepare_data.do"

* Resolve as questões 1, 3 e 4.
di as text "[Stata] Rodando Stata/02_ols_iv_first_stage.do: MQO, 2SLS Z1 e primeiro estágio"
do "Stata/02_ols_iv_first_stage.do"

* Resolve a questão 5: GMM e Hansen J.
di as text "[Stata] Rodando Stata/03_gmm_hansen.do: GMM e Hansen J"
do "Stata/03_gmm_hansen.do"

* Resolve as questões 6, 8, 9 e 10: weakivtest e tabela comparativa.
di as text "[Stata] Rodando Stata/04_alt_instruments_weakiv.do: Z1-Z7, weakivtest e tabela comparativa"
do "Stata/04_alt_instruments_weakiv.do"

* Resolve a questão 11: intervalos Anderson-Rubin por grade.
di as text "[Stata] Rodando Stata/05_ar_intervals.do: intervalos Anderson-Rubin"
do "Stata/05_ar_intervals.do"

* Gera gráficos auxiliares para interpretação e heterocedasticidade.
di as text "[Stata] Rodando Stata/06_visualizations.do: gráficos auxiliares"
do "Stata/06_visualizations.do"

* Resolve a questão 14: simulação de instrumentos fracos.
di as text "[Stata] Rodando Stata/07_simulation_weak_instruments.do: simulação de instrumentos fracos"
do "Stata/07_simulation_weak_instruments.do"

di as text "[Stata] FIM DA REPLICAÇÃO EM STATA"
log close _all
