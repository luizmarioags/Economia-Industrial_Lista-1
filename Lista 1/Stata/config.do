/********************************************************************
 Configuração geral do pacote Stata
********************************************************************/

version 16
clear all
set more off
set linesize 120

di as text _newline "[Stata] Configuração inicial"

* Define a raiz como o diretório atual; rode sempre a partir da raiz do pacote.
global ROOT "`c(pwd)'"
global RAW  "$ROOT/data/raw"
global PROC "$ROOT/data/processed"
global TABS "$ROOT/output/tables"
global FIGS "$ROOT/output/figures"
global LOGS "$ROOT/output/logs"

di as text "[Stata] Raiz do pacote: $ROOT"
di as text "[Stata] Dados brutos: $RAW"
di as text "[Stata] Dados processados: $PROC"
di as text "[Stata] Tabelas: $TABS"
di as text "[Stata] Figuras: $FIGS"

* Garante que as pastas de saída existam.
cap mkdir "$ROOT/output"
cap mkdir "$TABS"
cap mkdir "$FIGS"
cap mkdir "$LOGS"
cap mkdir "$PROC"
di as text "[Stata] Pastas verificadas/criadas"

* Instala comandos necessários, caso ainda não existam.
cap which ivreg2
if _rc {
    di as text "[Stata] Instalando ivreg2"
    ssc install ivreg2, replace
}
else di as text "[Stata] Comando disponível: ivreg2"

cap which ranktest
if _rc {
    di as text "[Stata] Instalando ranktest"
    ssc install ranktest, replace
}
else di as text "[Stata] Comando disponível: ranktest"

cap which weakivtest
if _rc {
    di as text "[Stata] Instalando weakivtest"
    ssc install weakivtest, replace
}
else di as text "[Stata] Comando disponível: weakivtest"
