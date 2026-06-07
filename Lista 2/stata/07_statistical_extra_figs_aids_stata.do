/*******************************************************************************
Arquivo: stata/07_statistical_extra_figs_aids_stata.do
Objetivo: gerar diagnosticos estatisticos adicionais para o pacote AIDS em Stata.

Graficos gerados:
    01. QQ-plots dos residuos por equacao.
    02. ACF dos residuos.
    03. PACF dos residuos.
    04. Residuos padronizados com bandas +/- 2 desvios-padrao.
    05. Distancia de Cook da primeira etapa.
    06. Leverage da primeira etapa.
    07. Partial regression plot da primeira etapa usando o proprio preco defasado.
    08. Residuos versus valores ajustados.
    09. Heatmap da correlacao dos residuos entre equacoes.
    10. Leave-one-out das elasticidades-preco proprias.
    11. Bootstrap das elasticidades-preco proprias com IC percentil.
    12. Rolling-window das elasticidades-preco proprias.
    13. CUSUM dos residuos padronizados.
    14. Contribuicao padronizada por observacao para os momentos GMM.

Como rodar:
    do stata/07_statistical_extra_figs_aids_stata.do

Recomendacao:
    Rode depois de run_all_aids_stata.do, pois este arquivo usa os dados
    processados e os modelos salvos em output/models.
*******************************************************************************/

version 18.0
clear all
set more off
set linesize 255

********************************************************************************
* Configuracao geral.
********************************************************************************

do "stata/00_config_aids.do"

capture log close _all
log using "$LOGS/07_statistical_extra_figs_aids_stata.log", replace text

global EXTRA_FIGS "$FIGURES/Extra_Figs"
global EXTRA_PDF  "$EXTRA_FIGS/PDF"
global EXTRA_PNG  "$EXTRA_FIGS/PNG"

capture mkdir "$EXTRA_FIGS"
capture mkdir "$EXTRA_PDF"
capture mkdir "$EXTRA_PNG"

set scheme s2color
graph set window fontface "Arial"

local cor_bovina   "navy"
local cor_suina    "cranberry"
local cor_frango   "forest_green"
local cor_pescados "orange"
local cor_pos      "navy"
local cor_neg      "cranberry"
local cor_neutro   "gs8"
local cor_extra    "purple"
local tema_base    "graphregion(color(white)) plotregion(color(white)) bgcolor(white)"

********************************************************************************
* Parametros ajustaveis dos graficos pesados.
********************************************************************************

local BOOT_REPS = 200       // Aumente para 500 ou 1000 se quiser ICs mais estaveis.
local ROLL_W    = 10        // Tamanho da janela movel, em anos.
local ACF_LAGS  = 10        // Maximo de defasagens nos graficos ACF/PACF.

********************************************************************************
* Checagem de arquivos necessarios.
********************************************************************************

foreach arq in ///
    "$PROC_DTA" ///
    "$MODELS/aids_hsym.ster" ///
    "$MODELS/aids_hsym_L2.ster" {

    capture confirm file "`arq'"
    if _rc {
        di as error "Arquivo necessario nao encontrado: `arq'"
        di as error "Rode antes o pacote principal: do stata/run_all_aids_stata.do"
        log close
        exit 601
    }
}

********************************************************************************
* Programas auxiliares.
********************************************************************************

capture program drop _fit_hsym_aids
program define _fit_hsym_aids
    syntax [, L2]

    if "`l2'" == "" {
        local Z "ln_real_x L1_lngp_bfvl L1_lngp_pork L1_lngp_poult L1_lngp_fish"
    }
    else {
        local Z "ln_real_x L1_lngp_bfvl L1_lngp_pork L1_lngp_poult L1_lngp_fish L2_lngp_bfvl L2_lngp_pork L2_lngp_poult L2_lngp_fish"
    }

    gmm                                                                          ///
        (eq_bfvl: w_bfvl - {a_bfvl} - {g11}*(lngp_bfvl-lngp_poult) - {g12}*(lngp_pork-lngp_poult) - {g14}*(lngp_fish-lngp_poult) - {b_bfvl}*ln_real_x) ///
        (eq_pork: w_pork - {a_pork} - {g12}*(lngp_bfvl-lngp_poult) - {g22}*(lngp_pork-lngp_poult) - {g24}*(lngp_fish-lngp_poult) - {b_pork}*ln_real_x) ///
        (eq_fish: w_fish - {a_fish} - {g14}*(lngp_bfvl-lngp_poult) - {g24}*(lngp_pork-lngp_poult) - {g44}*(lngp_fish-lngp_poult) - {b_fish}*ln_real_x), ///
        instruments(eq_bfvl: `Z')                                               ///
        instruments(eq_pork: `Z')                                               ///
        instruments(eq_fish: `Z')                                               ///
        winitial(unadjusted, independent) wmatrix(unadjusted) twostep nolog
end

capture program drop _calc_own_elast_hsym
program define _calc_own_elast_hsym, rclass

    quietly summarize w_bfvl if e(sample), meanonly
    scalar wbar_bfvl = r(mean)
    quietly summarize w_pork if e(sample), meanonly
    scalar wbar_pork = r(mean)
    quietly summarize w_poult if e(sample), meanonly
    scalar wbar_poult = r(mean)
    quietly summarize w_fish if e(sample), meanonly
    scalar wbar_fish = r(mean)

    scalar b_bfvl  = _b[/b_bfvl]
    scalar b_pork  = _b[/b_pork]
    scalar b_fish  = _b[/b_fish]
    scalar b_poult = - b_bfvl - b_pork - b_fish

    scalar g11 = _b[/g11]
    scalar g12 = _b[/g12]
    scalar g14 = _b[/g14]
    scalar g22 = _b[/g22]
    scalar g24 = _b[/g24]
    scalar g44 = _b[/g44]

    scalar g13 = -(g11 + g12 + g14)
    scalar g21 = g12
    scalar g23 = -(g21 + g22 + g24)
    scalar g31 = g13
    scalar g32 = g23
    scalar g34 = -(g14 + g24 + g44)
    scalar g41 = g14
    scalar g42 = g24
    scalar g43 = g34
    scalar g33 = -(g31 + g32 + g34)

    scalar eta_bfvl  = 1 + b_bfvl/wbar_bfvl
    scalar eta_pork  = 1 + b_pork/wbar_pork
    scalar eta_poult = 1 + b_poult/wbar_poult
    scalar eta_fish  = 1 + b_fish/wbar_fish

    scalar em_bfvl  = -1 + g11/wbar_bfvl  - b_bfvl
    scalar em_pork  = -1 + g22/wbar_pork  - b_pork
    scalar em_poult = -1 + g33/wbar_poult - b_poult
    scalar em_fish  = -1 + g44/wbar_fish  - b_fish

    scalar eh_bfvl  = em_bfvl  + eta_bfvl*wbar_bfvl
    scalar eh_pork  = em_pork  + eta_pork*wbar_pork
    scalar eh_poult = em_poult + eta_poult*wbar_poult
    scalar eh_fish  = em_fish  + eta_fish*wbar_fish

    return scalar eta_bfvl  = eta_bfvl
    return scalar eta_pork  = eta_pork
    return scalar eta_poult = eta_poult
    return scalar eta_fish  = eta_fish

    return scalar em_bfvl  = em_bfvl
    return scalar em_pork  = em_pork
    return scalar em_poult = em_poult
    return scalar em_fish  = em_fish

    return scalar eh_bfvl  = eh_bfvl
    return scalar eh_pork  = eh_pork
    return scalar eh_poult = eh_poult
    return scalar eh_fish  = eh_fish
end

capture program drop _make_residual_data_hsym
program define _make_residual_data_hsym

    use "$PROC_DTA", clear
    drop if missing(w_bfvl, w_pork, w_poult, w_fish, lngp_bfvl, lngp_pork, lngp_poult, lngp_fish, ln_real_x, L1_lngp_bfvl, L1_lngp_pork, L1_lngp_poult, L1_lngp_fish)

    estimates use "$MODELS/aids_hsym.ster"

    scalar a_bfvl = _b[/a_bfvl]
    scalar a_pork = _b[/a_pork]
    scalar a_fish = _b[/a_fish]

    scalar b_bfvl = _b[/b_bfvl]
    scalar b_pork = _b[/b_pork]
    scalar b_fish = _b[/b_fish]

    scalar g11 = _b[/g11]
    scalar g12 = _b[/g12]
    scalar g14 = _b[/g14]
    scalar g22 = _b[/g22]
    scalar g24 = _b[/g24]
    scalar g44 = _b[/g44]

    gen double fit_bfvl = a_bfvl + g11*(lngp_bfvl-lngp_poult) + g12*(lngp_pork-lngp_poult) + g14*(lngp_fish-lngp_poult) + b_bfvl*ln_real_x
    gen double fit_pork = a_pork + g12*(lngp_bfvl-lngp_poult) + g22*(lngp_pork-lngp_poult) + g24*(lngp_fish-lngp_poult) + b_pork*ln_real_x
    gen double fit_fish = a_fish + g14*(lngp_bfvl-lngp_poult) + g24*(lngp_pork-lngp_poult) + g44*(lngp_fish-lngp_poult) + b_fish*ln_real_x
    gen double fit_poult = 1 - fit_bfvl - fit_pork - fit_fish

    gen double res_bfvl  = w_bfvl  - fit_bfvl
    gen double res_pork  = w_pork  - fit_pork
    gen double res_poult = w_poult - fit_poult
    gen double res_fish  = w_fish  - fit_fish

    foreach g in bfvl pork poult fish {
        quietly summarize res_`g'
        gen double zres_`g' = (res_`g' - r(mean))/r(sd)
    }

    order year w_* fit_* res_* zres_*
    save "$TABLES/diagnosticos_residuos_hsym_stata.dta", replace
    export delimited using "$TABLES/diagnosticos_residuos_hsym_stata.csv", replace
end

********************************************************************************
* Cria base padrao de residuos e ajustados do modelo final.
********************************************************************************

_make_residual_data_hsym

********************************************************************************
* 1. QQ-plots dos residuos por equacao.
********************************************************************************

use "$TABLES/diagnosticos_residuos_hsym_stata.dta", clear

local qqgraphs ""
foreach g in bfvl pork poult fish {

    local titulo ""
    if "`g'" == "bfvl"  local titulo "Carne bovina e vitela"
    if "`g'" == "pork"  local titulo "Carne suina"
    if "`g'" == "poult" local titulo "Frango"
    if "`g'" == "fish"  local titulo "Pescados"

    qnorm zres_`g', ///
        title("`titulo'", size(small)) ///
        xtitle("Quantis teoricos normais", size(vsmall)) ///
        ytitle("Quantis dos residuos", size(vsmall)) ///
        xlabel(, labsize(vsmall) grid glcolor(gs14)) ///
        ylabel(, labsize(vsmall) grid glcolor(gs14)) ///
        mcolor(`cor_bovina'%70) msymbol(circle) ///
        `tema_base' ///
        name(g_qq_`g', replace)

    local qqgraphs "`qqgraphs' g_qq_`g'"
}

graph combine `qqgraphs', cols(2) ///
    title("QQ-plots dos residuos padronizados", size(medsmall)) ///
    graphregion(color(white)) ///
    name(g_extra_stat_qq, replace)

graph export "$EXTRA_PDF/stata_extra_stat_01_qqplot_residuos.pdf", replace
graph export "$EXTRA_PNG/stata_extra_stat_01_qqplot_residuos.png", replace width(2400)

********************************************************************************
* 2. ACF dos residuos por equacao.
********************************************************************************

use "$TABLES/diagnosticos_residuos_hsym_stata.dta", clear
tsset year

local acgraphs ""
foreach g in bfvl pork poult fish {

    local titulo ""
    if "`g'" == "bfvl"  local titulo "Carne bovina e vitela"
    if "`g'" == "pork"  local titulo "Carne suina"
    if "`g'" == "poult" local titulo "Frango"
    if "`g'" == "fish"  local titulo "Pescados"

    ac zres_`g', lags(`ACF_LAGS') ///
        title("`titulo'", size(small)) ///
        xlabel(, labsize(vsmall) grid glcolor(gs14)) ///
        ylabel(, labsize(vsmall) grid glcolor(gs14)) ///
        `tema_base' ///
        name(g_ac_`g', replace)

    local acgraphs "`acgraphs' g_ac_`g'"
}

graph combine `acgraphs', cols(2) ///
    title("ACF dos residuos padronizados", size(medsmall)) ///
    graphregion(color(white)) ///
    name(g_extra_stat_acf, replace)

graph export "$EXTRA_PDF/stata_extra_stat_02_acf_residuos.pdf", replace
graph export "$EXTRA_PNG/stata_extra_stat_02_acf_residuos.png", replace width(2400)

********************************************************************************
* 3. PACF dos residuos por equacao.
********************************************************************************

use "$TABLES/diagnosticos_residuos_hsym_stata.dta", clear
tsset year

local pacgraphs ""
foreach g in bfvl pork poult fish {

    local titulo ""
    if "`g'" == "bfvl"  local titulo "Carne bovina e vitela"
    if "`g'" == "pork"  local titulo "Carne suina"
    if "`g'" == "poult" local titulo "Frango"
    if "`g'" == "fish"  local titulo "Pescados"

    pac zres_`g', lags(`ACF_LAGS') ///
        title("`titulo'", size(small)) ///
        xlabel(, labsize(vsmall) grid glcolor(gs14)) ///
        ylabel(, labsize(vsmall) grid glcolor(gs14)) ///
        `tema_base' ///
        name(g_pac_`g', replace)

    local pacgraphs "`pacgraphs' g_pac_`g'"
}

graph combine `pacgraphs', cols(2) ///
    title("PACF dos residuos padronizados", size(medsmall)) ///
    graphregion(color(white)) ///
    name(g_extra_stat_pacf, replace)

graph export "$EXTRA_PDF/stata_extra_stat_03_pacf_residuos.pdf", replace
graph export "$EXTRA_PNG/stata_extra_stat_03_pacf_residuos.png", replace width(2400)

********************************************************************************
* 4. Residuos padronizados com bandas de +/- 2 desvios-padrao.
********************************************************************************

use "$TABLES/diagnosticos_residuos_hsym_stata.dta", clear
keep year zres_bfvl zres_pork zres_poult zres_fish
reshape long zres_, i(year) j(produto) string
rename zres_ zresiduo

gen str28 produto_nome = ""
replace produto_nome = "Carne bovina e vitela" if produto == "bfvl"
replace produto_nome = "Carne suina"           if produto == "pork"
replace produto_nome = "Frango"                if produto == "poult"
replace produto_nome = "Pescados"              if produto == "fish"

twoway ///
    (line zresiduo year, lcolor(`cor_bovina') lwidth(medthick)), ///
    by(produto_nome, cols(2) note("") graphregion(color(white))) ///
    yline(0, lcolor(black) lpattern(solid) lwidth(thin)) ///
    yline(-2 2, lcolor(`cor_neg') lpattern(dash) lwidth(thin)) ///
    title("Residuos padronizados por equacao", size(medsmall)) ///
    subtitle("Bandas de referencia: +/- 2 desvios-padrao", size(small)) ///
    xtitle("Ano", size(small)) ///
    ytitle("Residuo padronizado", size(small)) ///
    xlabel(, labsize(small) grid glcolor(gs14)) ///
    ylabel(, labsize(small) grid glcolor(gs14)) ///
    legend(off) ///
    `tema_base' ///
    name(g_extra_stat_zres, replace)

graph export "$EXTRA_PDF/stata_extra_stat_04_residuos_padronizados_bandas.pdf", replace
graph export "$EXTRA_PNG/stata_extra_stat_04_residuos_padronizados_bandas.png", replace width(2400)

********************************************************************************
* 5. Distancia de Cook e leverage na primeira etapa.
********************************************************************************

tempfile diag_fs
tempname postfs
postfile `postfs' str8 produto int year double cook leverage rstandard fitted observed using `diag_fs', replace

use "$PROC_DTA", clear
drop if missing(ln_real_x, L1_lngp_bfvl, L1_lngp_pork, L1_lngp_poult, L1_lngp_fish)

foreach g in bfvl pork poult fish {

    quietly regress lngp_`g' ln_real_x L1_lngp_bfvl L1_lngp_pork L1_lngp_poult L1_lngp_fish
    predict double cook_`g' if e(sample), cooksd
    predict double lev_`g'  if e(sample), hat
    predict double rst_`g'  if e(sample), rstandard
    predict double fit_`g'  if e(sample), xb

    quietly levelsof year if e(sample), local(anos_fs)
    foreach yy of local anos_fs {
        quietly summarize cook_`g' if year == `yy', meanonly
        scalar scook = r(mean)
        quietly summarize lev_`g' if year == `yy', meanonly
        scalar slev = r(mean)
        quietly summarize rst_`g' if year == `yy', meanonly
        scalar srst = r(mean)
        quietly summarize fit_`g' if year == `yy', meanonly
        scalar sfit = r(mean)
        quietly summarize lngp_`g' if year == `yy', meanonly
        scalar sobs = r(mean)
        post `postfs' ("`g'") (`yy') (scook) (slev) (srst) (sfit) (sobs)
    }

    drop cook_`g' lev_`g' rst_`g' fit_`g'
}

postclose `postfs'
use `diag_fs', clear

gen str28 produto_nome = ""
replace produto_nome = "Carne bovina e vitela" if produto == "bfvl"
replace produto_nome = "Carne suina"           if produto == "pork"
replace produto_nome = "Frango"                if produto == "poult"
replace produto_nome = "Pescados"              if produto == "fish"

quietly count
local Nfs = r(N)/4
local cook_ref = 4/`Nfs'

twoway ///
    (bar cook year, fcolor(`cor_bovina'%65) lcolor(`cor_bovina')), ///
    by(produto_nome, cols(2) note("") graphregion(color(white))) ///
    yline(`cook_ref', lcolor(`cor_neg') lpattern(dash) lwidth(thin)) ///
    title("Distancia de Cook na primeira etapa", size(medsmall)) ///
    subtitle("Linha tracejada: referencia 4/n", size(small)) ///
    xtitle("Ano", size(small)) ///
    ytitle("Distancia de Cook", size(small)) ///
    xlabel(, labsize(vsmall) angle(45) grid glcolor(gs14)) ///
    ylabel(, labsize(small) grid glcolor(gs14)) ///
    legend(off) ///
    `tema_base' ///
    name(g_extra_stat_cook, replace)

graph export "$EXTRA_PDF/stata_extra_stat_05_cook_primeira_etapa.pdf", replace
graph export "$EXTRA_PNG/stata_extra_stat_05_cook_primeira_etapa.png", replace width(2400)

quietly summarize leverage
local lev_ref = 2*r(mean)

twoway ///
    (bar leverage year, fcolor(`cor_suina'%65) lcolor(`cor_suina')), ///
    by(produto_nome, cols(2) note("") graphregion(color(white))) ///
    yline(`lev_ref', lcolor(`cor_neg') lpattern(dash) lwidth(thin)) ///
    title("Leverage na primeira etapa", size(medsmall)) ///
    subtitle("Linha tracejada: duas vezes o leverage medio", size(small)) ///
    xtitle("Ano", size(small)) ///
    ytitle("Leverage", size(small)) ///
    xlabel(, labsize(vsmall) angle(45) grid glcolor(gs14)) ///
    ylabel(, labsize(small) grid glcolor(gs14)) ///
    legend(off) ///
    `tema_base' ///
    name(g_extra_stat_leverage, replace)

graph export "$EXTRA_PDF/stata_extra_stat_06_leverage_primeira_etapa.pdf", replace
graph export "$EXTRA_PNG/stata_extra_stat_06_leverage_primeira_etapa.png", replace width(2400)

save "$TABLES/diagnostico_influencia_primeira_etapa_stata.dta", replace
export delimited using "$TABLES/diagnostico_influencia_primeira_etapa_stata.csv", replace

********************************************************************************
* 6. Partial regression plot da primeira etapa.
*    Para cada preco corrente, residualiza o preco corrente e o proprio preco
*    defasado contra os demais controles/instrumentos.
********************************************************************************

use "$PROC_DTA", clear
drop if missing(ln_real_x, L1_lngp_bfvl, L1_lngp_pork, L1_lngp_poult, L1_lngp_fish)

local prgraphs ""
foreach g in bfvl pork poult fish {

    local others ""
    foreach h in bfvl pork poult fish {
        if "`h'" != "`g'" local others "`others' L1_lngp_`h'"
    }

    quietly regress lngp_`g' ln_real_x `others'
    predict double yres_`g' if e(sample), resid

    quietly regress L1_lngp_`g' ln_real_x `others'
    predict double xres_`g' if e(sample), resid

    local titulo ""
    if "`g'" == "bfvl"  local titulo "Carne bovina e vitela"
    if "`g'" == "pork"  local titulo "Carne suina"
    if "`g'" == "poult" local titulo "Frango"
    if "`g'" == "fish"  local titulo "Pescados"

    twoway ///
        (scatter yres_`g' xres_`g', mcolor(`cor_bovina'%70) msymbol(circle) msize(medium)) ///
        (lfit yres_`g' xres_`g', lcolor(`cor_neg') lwidth(medthick)), ///
        title("`titulo'", size(small)) ///
        xtitle("Residuo do proprio preco defasado", size(vsmall)) ///
        ytitle("Residuo do preco corrente", size(vsmall)) ///
        xlabel(, labsize(vsmall) grid glcolor(gs14)) ///
        ylabel(, labsize(vsmall) grid glcolor(gs14)) ///
        legend(off) ///
        `tema_base' ///
        name(g_pr_`g', replace)

    local prgraphs "`prgraphs' g_pr_`g'"
}

graph combine `prgraphs', cols(2) ///
    title("Partial regression plots da primeira etapa", size(medsmall)) ///
    subtitle("Relacao parcial entre preco corrente e proprio preco defasado", size(small)) ///
    graphregion(color(white)) ///
    name(g_extra_stat_partial, replace)

graph export "$EXTRA_PDF/stata_extra_stat_07_partial_regression_primeira_etapa.pdf", replace
graph export "$EXTRA_PNG/stata_extra_stat_07_partial_regression_primeira_etapa.png", replace width(2400)

********************************************************************************
* 7. Residuos versus valores ajustados.
********************************************************************************

use "$TABLES/diagnosticos_residuos_hsym_stata.dta", clear

local rvfgraphs ""
foreach g in bfvl pork poult fish {

    local titulo ""
    if "`g'" == "bfvl"  local titulo "Carne bovina e vitela"
    if "`g'" == "pork"  local titulo "Carne suina"
    if "`g'" == "poult" local titulo "Frango"
    if "`g'" == "fish"  local titulo "Pescados"

    twoway ///
        (scatter res_`g' fit_`g', mcolor(`cor_bovina'%70) msymbol(circle) msize(medium)) ///
        (lfit res_`g' fit_`g', lcolor(`cor_neg') lpattern(solid) lwidth(medthick)), ///
        yline(0, lcolor(black) lpattern(dash) lwidth(thin)) ///
        title("`titulo'", size(small)) ///
        xtitle("Valor ajustado", size(vsmall)) ///
        ytitle("Residuo", size(vsmall)) ///
        xlabel(, labsize(vsmall) grid glcolor(gs14)) ///
        ylabel(, labsize(vsmall) grid glcolor(gs14)) ///
        legend(off) ///
        `tema_base' ///
        name(g_rvf_`g', replace)

    local rvfgraphs "`rvfgraphs' g_rvf_`g'"
}

graph combine `rvfgraphs', cols(2) ///
    title("Residuos versus valores ajustados", size(medsmall)) ///
    graphregion(color(white)) ///
    name(g_extra_stat_rvf, replace)

graph export "$EXTRA_PDF/stata_extra_stat_08_residuos_vs_ajustados.pdf", replace
graph export "$EXTRA_PNG/stata_extra_stat_08_residuos_vs_ajustados.png", replace width(2400)

********************************************************************************
* 8. Heatmap da matriz de correlacao dos residuos entre equacoes.
********************************************************************************

use "$TABLES/diagnosticos_residuos_hsym_stata.dta", clear
corr res_bfvl res_pork res_poult res_fish
matrix C = r(C)

tempfile corr_resid
tempname postcorr
postfile `postcorr' str8 linha str8 coluna double corr using `corr_resid', replace

local names "bfvl pork poult fish"
forvalues i = 1/4 {
    local li : word `i' of `names'
    forvalues j = 1/4 {
        local cj : word `j' of `names'
        scalar cc = C[`i',`j']
        post `postcorr' ("`li'") ("`cj'") (cc)
    }
}
postclose `postcorr'

use `corr_resid', clear

gen byte row = .
replace row = 4 if linha == "bfvl"
replace row = 3 if linha == "pork"
replace row = 2 if linha == "poult"
replace row = 1 if linha == "fish"

gen byte col = .
replace col = 1 if coluna == "bfvl"
replace col = 2 if coluna == "pork"
replace col = 3 if coluna == "poult"
replace col = 4 if coluna == "fish"

gen double peso = abs(corr) + 0.10
gen str8 rotulo = string(corr, "%5.2f")

twoway ///
    (scatter row col if corr >= 0 [aw=peso], msymbol(square) msize(vlarge) mcolor(`cor_pos'%65) mlabel(rotulo) mlabposition(0) mlabsize(small) mlabcolor(black)) ///
    (scatter row col if corr < 0  [aw=peso], msymbol(square) msize(vlarge) mcolor(`cor_neg'%65) mlabel(rotulo) mlabposition(0) mlabsize(small) mlabcolor(black)), ///
    xlabel(1 "bfvl" 2 "pork" 3 "poult" 4 "fish", labsize(small)) ///
    ylabel(1 "fish" 2 "poult" 3 "pork" 4 "bfvl", labsize(small)) ///
    title("Correlacao dos residuos entre equacoes", size(medsmall)) ///
    xtitle("Equacao", size(small)) ///
    ytitle("Equacao", size(small)) ///
    legend(order(1 "Correlacao positiva" 2 "Correlacao negativa") cols(1) position(3) ring(1) region(lcolor(none) fcolor(none)) size(small)) ///
    `tema_base' ///
    name(g_extra_stat_corr_resid, replace)

graph export "$EXTRA_PDF/stata_extra_stat_09_heatmap_correlacao_residuos.pdf", replace
graph export "$EXTRA_PNG/stata_extra_stat_09_heatmap_correlacao_residuos.png", replace width(2400)

********************************************************************************
* 9. Leave-one-out das elasticidades-preco proprias.
********************************************************************************

use "$PROC_DTA", clear
drop if missing(w_bfvl, w_pork, w_poult, w_fish, lngp_bfvl, lngp_pork, lngp_poult, lngp_fish, ln_real_x, L1_lngp_bfvl, L1_lngp_pork, L1_lngp_poult, L1_lngp_fish)

_fit_hsym_aids
_calc_own_elast_hsym
scalar full_em_bfvl  = r(em_bfvl)
scalar full_em_pork  = r(em_pork)
scalar full_em_poult = r(em_poult)
scalar full_em_fish  = r(em_fish)

levelsof year, local(anos_loo)

tempfile loo_elast
tempname postloo
postfile `postloo' int omitted_year str8 produto double em_full em_loo dev using `loo_elast', replace

foreach yy of local anos_loo {

    preserve
    keep if year != `yy'

    capture noisily _fit_hsym_aids
    if !_rc {
        capture noisily _calc_own_elast_hsym
        if !_rc {
            foreach g in bfvl pork poult fish {
                scalar full = full_em_`g'
                scalar loo  = r(em_`g')
                scalar dev  = loo - full
                post `postloo' (`yy') ("`g'") (full) (loo) (dev)
            }
        }
    }
    restore
}

postclose `postloo'
use `loo_elast', clear
export delimited using "$TABLES/elasticidades_leave_one_out_stata.csv", replace
save "$TABLES/elasticidades_leave_one_out_stata.dta", replace

gen str28 produto_nome = ""
replace produto_nome = "Carne bovina e vitela" if produto == "bfvl"
replace produto_nome = "Carne suina"           if produto == "pork"
replace produto_nome = "Frango"                if produto == "poult"
replace produto_nome = "Pescados"              if produto == "fish"

twoway ///
    (connected dev omitted_year, lcolor(`cor_bovina') mcolor(`cor_bovina') msymbol(circle) lwidth(medthick)), ///
    by(produto_nome, cols(2) note("") graphregion(color(white))) ///
    yline(0, lcolor(black) lpattern(dash) lwidth(thin)) ///
    title("Leave-one-out das elasticidades-preco proprias", size(medsmall)) ///
    subtitle("Desvio em relacao a elasticidade do modelo completo", size(small)) ///
    xtitle("Ano retirado da amostra", size(small)) ///
    ytitle("Elasticidade sem o ano - elasticidade completa", size(small)) ///
    xlabel(, labsize(vsmall) angle(45) grid glcolor(gs14)) ///
    ylabel(, labsize(small) grid glcolor(gs14)) ///
    legend(off) ///
    `tema_base' ///
    name(g_extra_stat_loo, replace)

graph export "$EXTRA_PDF/stata_extra_stat_10_leave_one_out_elasticidades.pdf", replace
graph export "$EXTRA_PNG/stata_extra_stat_10_leave_one_out_elasticidades.png", replace width(2400)

********************************************************************************
* 10. Bootstrap das elasticidades-preco proprias com IC percentil.
********************************************************************************

use "$PROC_DTA", clear
drop if missing(w_bfvl, w_pork, w_poult, w_fish, lngp_bfvl, lngp_pork, lngp_poult, lngp_fish, ln_real_x, L1_lngp_bfvl, L1_lngp_pork, L1_lngp_poult, L1_lngp_fish)
tempfile base_boot
save `base_boot', replace

_fit_hsym_aids
_calc_own_elast_hsym
scalar full_em_bfvl  = r(em_bfvl)
scalar full_em_pork  = r(em_pork)
scalar full_em_poult = r(em_poult)
scalar full_em_fish  = r(em_fish)

tempfile boot_elast
tempname postboot
postfile `postboot' int rep str8 produto double em_boot using `boot_elast', replace

set seed 123456
forvalues b = 1/`BOOT_REPS' {

    quietly use `base_boot', clear
    quietly bsample

    capture noisily _fit_hsym_aids
    if !_rc {
        capture noisily _calc_own_elast_hsym
        if !_rc {
            foreach g in bfvl pork poult fish {
                scalar eb = r(em_`g')
                if !missing(eb) post `postboot' (`b') ("`g'") (eb)
            }
        }
    }
}
postclose `postboot'

use `boot_elast', clear
export delimited using "$TABLES/bootstrap_elasticidades_proprias_stata.csv", replace
save "$TABLES/bootstrap_elasticidades_proprias_stata.dta", replace

tempfile boot_ci
tempname postci
postfile `postci' str8 produto double em_full p025 p500 p975 using `boot_ci', replace

foreach g in bfvl pork poult fish {
    quietly count if produto == "`g'"
    if r(N) > 0 {
        quietly centile em_boot if produto == "`g'", centile(2.5 50 97.5)
        scalar c025 = r(c_1)
        scalar c500 = r(c_2)
        scalar c975 = r(c_3)
        scalar fval = full_em_`g'
        post `postci' ("`g'") (fval) (c025) (c500) (c975)
    }
}
postclose `postci'

use `boot_ci', clear
export delimited using "$TABLES/bootstrap_ic_elasticidades_proprias_stata.csv", replace
save "$TABLES/bootstrap_ic_elasticidades_proprias_stata.dta", replace

gen byte xpos = .
replace xpos = 1 if produto == "bfvl"
replace xpos = 2 if produto == "pork"
replace xpos = 3 if produto == "poult"
replace xpos = 4 if produto == "fish"

gen str8 rotulo = string(em_full, "%5.2f")

twoway ///
    (rspike p025 p975 xpos, lcolor(`cor_bovina') lwidth(medthick)) ///
    (scatter em_full xpos, mcolor(`cor_neg') msymbol(circle) msize(large) mlabel(rotulo) mlabposition(12) mlabsize(small) mlabcolor(black)) ///
    (scatter p500 xpos, mcolor(`cor_bovina') msymbol(diamond) msize(medium)), ///
    yline(0, lcolor(black) lpattern(dash) lwidth(thin)) ///
    xlabel(1 "bfvl" 2 "pork" 3 "poult" 4 "fish", labsize(small)) ///
    ylabel(, labsize(small) grid glcolor(gs14)) ///
    title("Bootstrap das elasticidades-preco proprias", size(medsmall)) ///
    subtitle("Intervalo percentil de 95%; marcador vermelho = estimativa completa", size(vsmall)) ///
    xtitle("Produto", size(small)) ///
    ytitle("Elasticidade-preco propria Marshalliana", size(small)) ///
    legend(order(1 "IC percentil 95%" 2 "Modelo completo" 3 "Mediana bootstrap") cols(1) position(3) ring(1) region(lcolor(none) fcolor(none)) size(small)) ///
    `tema_base' ///
    name(g_extra_stat_boot, replace)

graph export "$EXTRA_PDF/stata_extra_stat_11_bootstrap_ic_elasticidades.pdf", replace
graph export "$EXTRA_PNG/stata_extra_stat_11_bootstrap_ic_elasticidades.png", replace width(2400)

********************************************************************************
* 11. Rolling-window das elasticidades-preco proprias.
********************************************************************************

use "$PROC_DTA", clear
drop if missing(w_bfvl, w_pork, w_poult, w_fish, lngp_bfvl, lngp_pork, lngp_poult, lngp_fish, ln_real_x, L1_lngp_bfvl, L1_lngp_pork, L1_lngp_poult, L1_lngp_fish)
levelsof year, local(anos_roll)
local n_anos : word count `anos_roll'

tempfile roll_elast
tempname postroll
postfile `postroll' int year_start int year_end double year_mid str8 produto double em_roll using `roll_elast', replace

if `n_anos' >= `ROLL_W' {
    local last_start = `n_anos' - `ROLL_W' + 1

    forvalues s = 1/`last_start' {
        local e = `s' + `ROLL_W' - 1
        local y0 : word `s' of `anos_roll'
        local y1 : word `e' of `anos_roll'
        local ym = (`y0' + `y1')/2

        preserve
        keep if inrange(year, `y0', `y1')

        capture noisily _fit_hsym_aids
        if !_rc {
            capture noisily _calc_own_elast_hsym
            if !_rc {
                foreach g in bfvl pork poult fish {
                    scalar er = r(em_`g')
                    post `postroll' (`y0') (`y1') (`ym') ("`g'") (er)
                }
            }
        }
        restore
    }
}
else {
    di as error "A serie tem menos anos que a janela definida em ROLL_W=`ROLL_W'."
}

postclose `postroll'
use `roll_elast', clear
export delimited using "$TABLES/rolling_window_elasticidades_proprias_stata.csv", replace
save "$TABLES/rolling_window_elasticidades_proprias_stata.dta", replace

gen str28 produto_nome = ""
replace produto_nome = "Carne bovina e vitela" if produto == "bfvl"
replace produto_nome = "Carne suina"           if produto == "pork"
replace produto_nome = "Frango"                if produto == "poult"
replace produto_nome = "Pescados"              if produto == "fish"

twoway ///
    (connected em_roll year_mid, lcolor(`cor_bovina') mcolor(`cor_bovina') msymbol(circle) lwidth(medthick)), ///
    by(produto_nome, cols(2) note("") graphregion(color(white))) ///
    yline(0, lcolor(black) lpattern(dash) lwidth(thin)) ///
    title("Rolling-window das elasticidades-preco proprias", size(medsmall)) ///
    subtitle("Janela movel de `ROLL_W' anos", size(small)) ///
    xtitle("Centro da janela", size(small)) ///
    ytitle("Elasticidade-preco propria Marshalliana", size(small)) ///
    xlabel(, labsize(vsmall) grid glcolor(gs14)) ///
    ylabel(, labsize(small) grid glcolor(gs14)) ///
    legend(off) ///
    `tema_base' ///
    name(g_extra_stat_rolling, replace)

graph export "$EXTRA_PDF/stata_extra_stat_12_rolling_window_elasticidades.pdf", replace
graph export "$EXTRA_PNG/stata_extra_stat_12_rolling_window_elasticidades.png", replace width(2400)

********************************************************************************
* 12. CUSUM dos residuos padronizados.
********************************************************************************

use "$TABLES/diagnosticos_residuos_hsym_stata.dta", clear
keep year zres_bfvl zres_pork zres_poult zres_fish
reshape long zres_, i(year) j(produto) string
rename zres_ zresiduo
sort produto year
by produto: gen int t = _n
by produto: gen int n = _N
by produto: gen double cusum = sum(zresiduo)/sqrt(n)

gen str28 produto_nome = ""
replace produto_nome = "Carne bovina e vitela" if produto == "bfvl"
replace produto_nome = "Carne suina"           if produto == "pork"
replace produto_nome = "Frango"                if produto == "poult"
replace produto_nome = "Pescados"              if produto == "fish"

twoway ///
    (line cusum year, lcolor(`cor_bovina') lwidth(medthick)), ///
    by(produto_nome, cols(2) note("") graphregion(color(white))) ///
    yline(0, lcolor(black) lpattern(solid) lwidth(thin)) ///
    yline(-1.36 1.36, lcolor(`cor_neg') lpattern(dash) lwidth(thin)) ///
    title("CUSUM dos residuos padronizados", size(medsmall)) ///
    subtitle("Linhas tracejadas: referencia visual +/- 1,36", size(vsmall)) ///
    xtitle("Ano", size(small)) ///
    ytitle("Soma acumulada padronizada", size(small)) ///
    xlabel(, labsize(vsmall) angle(45) grid glcolor(gs14)) ///
    ylabel(, labsize(small) grid glcolor(gs14)) ///
    legend(off) ///
    `tema_base' ///
    name(g_extra_stat_cusum, replace)

graph export "$EXTRA_PDF/stata_extra_stat_13_cusum_residuos.pdf", replace
graph export "$EXTRA_PNG/stata_extra_stat_13_cusum_residuos.png", replace width(2400)

********************************************************************************
* 13. Contribuicao padronizada por observacao para os momentos GMM.
*     Medida descritiva: soma dos quadrados dos momentos z_i * residuo_i,
*     padronizados por momento. Nao substitui o Hansen-J formal, mas ajuda a
*     localizar anos que pesam mais nas condicoes de momento.
********************************************************************************

use "$TABLES/diagnosticos_residuos_hsym_stata.dta", clear

local insts "ln_real_x L1_lngp_bfvl L1_lngp_pork L1_lngp_poult L1_lngp_fish"
local momvars ""

foreach eq in bfvl pork fish {
    foreach z of local insts {
        gen double m_`eq'_`z' = res_`eq' * `z'
        quietly summarize m_`eq'_`z'
        gen double ms_`eq'_`z' = (m_`eq'_`z' - r(mean))/r(sd)
        gen double ms2_`eq'_`z' = ms_`eq'_`z'^2
        local momvars "`momvars' ms2_`eq'_`z'"
    }
}

egen double gmm_contrib_std = rowtotal(`momvars')

gen double contrib_bfvl = 0
gen double contrib_pork = 0
gen double contrib_fish = 0
foreach z of local insts {
    replace contrib_bfvl = contrib_bfvl + ms2_bfvl_`z'
    replace contrib_pork = contrib_pork + ms2_pork_`z'
    replace contrib_fish = contrib_fish + ms2_fish_`z'
}

export delimited year gmm_contrib_std contrib_bfvl contrib_pork contrib_fish using "$TABLES/contribuicao_momentos_gmm_por_ano_stata.csv", replace
save "$TABLES/contribuicao_momentos_gmm_por_ano_stata.dta", replace

twoway ///
    (bar gmm_contrib_std year, fcolor(`cor_extra'%65) lcolor(`cor_extra')), ///
    title("Contribuicao padronizada aos momentos GMM", size(medsmall)) ///
    subtitle("Soma dos momentos z_i vezes residuo_i, padronizados", size(vsmall)) ///
    xtitle("Ano", size(small)) ///
    ytitle("Contribuicao padronizada", size(small)) ///
    xlabel(, labsize(vsmall) angle(45) grid glcolor(gs14)) ///
    ylabel(, labsize(small) grid glcolor(gs14)) ///
    legend(off) ///
    `tema_base' ///
    name(g_extra_stat_gmm_contrib_total, replace)

graph export "$EXTRA_PDF/stata_extra_stat_14_contribuicao_momentos_gmm_total.pdf", replace
graph export "$EXTRA_PNG/stata_extra_stat_14_contribuicao_momentos_gmm_total.png", replace width(2400)

preserve
keep year contrib_bfvl contrib_pork contrib_fish
reshape long contrib_, i(year) j(eq) string
rename contrib_ contribuicao

gen str28 eq_nome = ""
replace eq_nome = "Eq. carne bovina e vitela" if eq == "bfvl"
replace eq_nome = "Eq. carne suina"           if eq == "pork"
replace eq_nome = "Eq. pescados"              if eq == "fish"

twoway ///
    (bar contribuicao year, fcolor(`cor_bovina'%65) lcolor(`cor_bovina')), ///
    by(eq_nome, cols(1) note("") graphregion(color(white))) ///
    title("Contribuicao aos momentos GMM por equacao", size(medsmall)) ///
    xtitle("Ano", size(small)) ///
    ytitle("Contribuicao padronizada", size(small)) ///
    xlabel(, labsize(vsmall) angle(45) grid glcolor(gs14)) ///
    ylabel(, labsize(small) grid glcolor(gs14)) ///
    legend(off) ///
    `tema_base' ///
    name(g_extra_stat_gmm_contrib_eq, replace)

graph export "$EXTRA_PDF/stata_extra_stat_15_contribuicao_momentos_gmm_equacao.pdf", replace
graph export "$EXTRA_PNG/stata_extra_stat_15_contribuicao_momentos_gmm_equacao.png", replace width(2400)
restore

********************************************************************************
* Encerramento.
********************************************************************************

di as result "Graficos estatisticos extras salvos em:"
di as result "  $EXTRA_PDF"
di as result "  $EXTRA_PNG"

log close
