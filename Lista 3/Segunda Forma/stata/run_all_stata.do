/****************************************************************************************
Run all - Lista Berry/BLP em Stata | versão eberry/b_program operacional

Execute a partir da raiz do pacote:
    do stata/run_all_stata.do

Saídas:
    outputs/stata/logs
    outputs/stata/figures/pdf
    outputs/stata/figures/png
    outputs/stata/tables/csv
    outputs/stata/tables/tex

Diferença central desta versão:
    Os scripts 02_estimate_logit_iv_gmm.do e 03_nested_gmm.do não usam mais o
    comando nativo gmm do Stata. O núcleo de estimação GMM passa por:
        stata/eberry_operational.do
        stata/b_program_operational.do
    isto é, pela lógica operacional do eberry/b_program original.
****************************************************************************************/

clear all
set more off
version 17

* Raiz do pacote.
local cwd "`c(pwd)'"
global ROOT "`cwd'"
if substr("$ROOT", -6, .)=="/stata" | substr("$ROOT", -6, .)=="\\stata" {
    global ROOT = substr("$ROOT", 1, length("$ROOT")-6)
}

global DATA "$ROOT/data/exemplo.csv"
global OUTROOT "$ROOT/outputs"
global OUT "$OUTROOT/stata"
global LOG "$OUT/logs"
global FIGROOT "$OUT/figures"
global FIGPDF "$FIGROOT/pdf"
global FIGPNG "$FIGROOT/png"
global TABROOT "$OUT/tables"
global TABCsv "$TABROOT/csv"
global TABTEX "$TABROOT/tex"
global OUTDATA "$OUT/data"

* Cria as pastas em ordem hierárquica.
* Importante: o Stata não cria automaticamente as pastas intermediárias.
* Por isso, é necessário criar primeiro outputs/stata/tables antes de tables/csv e tables/tex.
foreach d in "$OUTROOT" "$OUT" "$LOG" "$FIGROOT" "$FIGPDF" "$FIGPNG" "$TABROOT" "$TABCsv" "$TABTEX" "$OUTDATA" {
    capture mkdir "`d'"
}

* Verifica se o CSV principal está no lugar correto.
capture confirm file "$DATA"
if _rc {
    display as error "Arquivo não encontrado: $DATA"
    display as error "Coloque o arquivo exemplo.csv dentro da pasta data/ do pacote."
    exit 601
}

* Limpa tabelas antigas.
capture local oldcsv : dir "$TABCsv" files "*.csv"
foreach f of local oldcsv {
    capture erase "$TABCsv/`f'"
}
capture local oldtex : dir "$TABTEX" files "*.tex"
foreach f of local oldtex {
    capture erase "$TABTEX/`f'"
}

* Limpa figuras antigas.
capture local oldpdf : dir "$FIGPDF" files "*.pdf"
foreach f of local oldpdf {
    capture erase "$FIGPDF/`f'"
}
capture local oldpng : dir "$FIGPNG" files "*.png"
foreach f of local oldpng {
    capture erase "$FIGPNG/`f'"
}

capture log close _all
log using "$LOG/run_all_stata.log", text replace

display "#########################################################################"
display "#                            INÍCIO                                     #"
display "#             Lista 3 - Modelo Berry/BLP                                #"
display "#             Versão operacional baseada em eberry/b_program             #"
display "#########################################################################"

do "$ROOT/stata/00_config.do"
do "$ROOT/stata/stata_graph_theme_snippet.do"
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
display "#########################################################################"

log close
