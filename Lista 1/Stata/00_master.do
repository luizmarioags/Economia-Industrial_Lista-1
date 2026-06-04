/********************************************************************
 Script mestre: roda toda a replicação em Stata
********************************************************************/

clear all
set more off

di as text _newline "[Stata] INÍCIO DA REPLICAÇÃO EM STATA"

* ------------------------------------------------------------
* Carrega caminhos, pastas e dependências
* ------------------------------------------------------------

di as text "[Stata] Rodando Stata/config.do: caminhos, pastas e dependências"
do "Stata/config.do"

* ------------------------------------------------------------
* Abre log geral da execução
* Se o log antigo estiver travado ou somente leitura, cria log alternativo
* ------------------------------------------------------------

cap log close _all

capture log using "$LOGS/stata_master.log", replace text

if _rc {
    di as error "[Stata] Não consegui sobrescrever $LOGS/stata_master.log"
    di as error "[Stata] O arquivo pode estar aberto, travado ou como somente leitura."
    di as text  "[Stata] Tentando criar log alternativo com data e hora..."

    local data_log = subinstr("`c(current_date)'", " ", "_", .)
    local hora_log = subinstr("`c(current_time)'", ":", "", .)
    local hora_log = subinstr("`hora_log'", ".", "", .)

    local log_alt "$LOGS/stata_master_`data_log'_`hora_log'.log"

    capture log using "`log_alt'", replace text

    if _rc {
        di as error "[Stata] Também não consegui criar log alternativo."
        di as error "[Stata] A replicação continuará sem log geral."
    }
    else {
        di as text "[Stata] Log alternativo criado em:"
        di as text "`log_alt'"
    }
}
else {
    di as text "[Stata] Log geral criado em:"
    di as text "$LOGS/stata_master.log"
}

* ------------------------------------------------------------
* Roda os scripts na ordem correta
* ------------------------------------------------------------

di as text _newline "[Stata] Rodando 01_prepare_data.do"
do "Stata/01_prepare_data.do"

di as text _newline "[Stata] Rodando 02_ols_iv_first_stage.do"
do "Stata/02_ols_iv_first_stage.do"

di as text _newline "[Stata] Rodando 03_gmm_hansen.do"
do "Stata/03_gmm_hansen.do"

di as text _newline "[Stata] Rodando 04_alt_instruments_weakiv.do"
do "Stata/04_alt_instruments_weakiv.do"

di as text _newline "[Stata] Rodando 05_ar_intervals.do"
do "Stata/05_ar_intervals.do"

di as text _newline "[Stata] Rodando 06_visualizations.do"
do "Stata/06_visualizations.do"

di as text _newline "[Stata] Rodando 07_simulation_weak_instruments.do"
do "Stata/07_simulation_weak_instruments.do"

di as result _newline "[Stata] REPLICAÇÃO FINALIZADA COM SUCESSO"

cap log close _all