/****************************************************************************************
COMENTÁRIOS DETALHADOS
- clear all e set more off limpam a sessão e impedem pausas interativas.
- ROOT identifica a raiz do pacote mesmo quando o script é chamado de dentro da pasta stata.
- As globals de diretórios são usadas por todos os scripts chamados com do.
- foreach mkdir cria as subpastas de outputs caso elas ainda não existam.
- log using abre o log geral antes de imprimir o cabeçalho e executar as rotinas.
- Cada comando do chama uma etapa modular: configuração, tratamento, estimação, diagnóstico e gráficos.
- O bloco final imprime o encerramento e log close fecha o arquivo de log.
****************************************************************************************/
/****************************************************************************************
Run all - Lista Berry/BLP em Stata
Execute a partir da raiz do pacote:
    do stata/run_all_stata.do
Saídas: outputs/stata/logs, outputs/stata/figures/{pdf,png}, outputs/stata/tables/{csv,tex}
****************************************************************************************/
clear all
set more off
version 17

* Raiz do pacote
local cwd "`c(pwd)'"
global ROOT "`cwd'"
if substr("$ROOT", -6, .)=="/stata" | substr("$ROOT", -6, .)=="\\stata" {
    global ROOT = substr("$ROOT", 1, length("$ROOT")-6)
}

global DATA "$ROOT/data/exemplo.csv"
global OUTROOT "$ROOT/outputs"
global OUT "$OUTROOT/stata"
global LOG "$OUT/logs"
global FIGPDF "$OUT/figures/pdf"
global FIGPNG "$OUT/figures/png"
global TABCsv "$OUT/tables/csv"
global TABTEX "$OUT/tables/tex"
global OUTDATA "$OUT/data"

foreach d in "$OUTROOT" "$OUT" "$LOG" "$FIGPDF" "$FIGPNG" "$TABCsv" "$TABTEX" "$OUTDATA" {
    capture mkdir "`d'"
}

* Limpa tabelas antigas para que a pasta contenha apenas o conjunto padronizado desta execução.
local oldcsv : dir "$TABCsv" files "*.csv"
foreach f of local oldcsv {
    capture erase "$TABCsv/`f'"
}
local oldtex : dir "$TABTEX" files "*.tex"
foreach f of local oldtex {
    capture erase "$TABTEX/`f'"
}

capture log close _all
log using "$LOG/run_all_stata.log", text replace

display "#########################################################################"
display "#                            INÍCIO                                     #"
display "#             Lista 3 - Modelo BLP.                                    #"
display "#             Grupo: Luiz Mario Andrade (Matrícula: 252029360)          #"
display "#                    Felipe Santos (Matrícula: 232010719)               #"
display "#                    Luiza Nodari (Matrícula: 242011335)                #"
display "#                    Diogo Martins (Matrícula: 232001578)               #"
display "#                    Sarah Moura (Matrícula: 211060316)                 #"
display "#                    Pedro Bijos (Matrícula: 241003849)                 #"
display "#########################################################################"

do "$ROOT/stata/00_config.do"
do "$ROOT/stata/01_prepare_data.do"
do "$ROOT/stata/02_estimate_logit_iv_gmm.do"
do "$ROOT/stata/03_nested_gmm.do"
do "$ROOT/stata/04_elasticities_markups.do"
do "$ROOT/stata/05_diagnostics_weakiv.do"
do "$ROOT/stata/08_standard_tables.do"
do "$ROOT/stata/06_visualizations.do"
do "$ROOT/stata/07_extra_visualizations.do"

display "#########################################################################"
display "#                            FIM                                        #"
display "#                                                                       #"
display "#########################################################################"

log close
