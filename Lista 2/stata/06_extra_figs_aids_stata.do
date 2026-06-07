/*******************************************************************************
Arquivo: stata/06_extra_figs_aids_stata.do
Objetivo: gerar graficos extras para melhorar a discussao das questoes finais:
          (i) elasticidades proprias Marshallianas vs compensadas;
          (ii) diferenca Hicksiana - Marshalliana;
          (iii) rede simplificada de elasticidades cruzadas;
          (iv) residuos por equacao ao longo do tempo;
          (v) observado vs ajustado na primeira etapa;
          (vi) estabilidade das elasticidades proprias por especificacao;
          (vii) estatistica objetivo do GMM por especificacao.

Como rodar:
    do stata/06_extra_figs_aids_stata.do

Observacao:
    Rode depois de:
    02_estimate_aids_stata.do
    03_elasticities_aids_stata.do
    04_tests_diagnostics_aids_stata.do
    05_visualizations_aids_stata.do
*******************************************************************************/

version 18.0
clear all
set more off
set linesize 255

do "stata/00_config_aids.do"

capture log close _all
log using "$LOGS/06_extra_figs_aids_stata.log", replace text

********************************************************************************
* Subdiretorios de saida.
********************************************************************************

global EXTRA_FIGS "$FIGURES/Extra_Figs"
global EXTRA_PDF  "$EXTRA_FIGS/PDF"
global EXTRA_PNG  "$EXTRA_FIGS/PNG"

capture mkdir "$EXTRA_FIGS"
capture mkdir "$EXTRA_PDF"
capture mkdir "$EXTRA_PNG"

********************************************************************************
* Padrao visual.
********************************************************************************

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

local tema_base "graphregion(color(white)) plotregion(color(white)) bgcolor(white)"
local eixo_grid "xlabel(, labsize(small) grid glcolor(gs14)) ylabel(, labsize(small) grid glcolor(gs14))"

********************************************************************************
* Checagem dos arquivos necessarios.
********************************************************************************

foreach arq in ///
    "$TABLES/elasticidades_marshallianas_hsym_stata.csv" ///
    "$TABLES/elasticidades_compensadas_hsym_stata.csv" ///
    "$TABLES/elasticidade_dispendio_hsym_stata.csv" ///
    "$TABLES/diagnostico_primeira_etapa_stata.csv" ///
    "$TABLES/comparacao_modelos_stata.csv" {

    capture confirm file "`arq'"
    if _rc {
        di as error "Arquivo necessario nao encontrado: `arq'"
        di as error "Rode primeiro as etapas 02, 03, 04 e 05 do pacote."
        log close
        exit 601
    }
}

********************************************************************************
* 1. Elasticidades proprias: Marshallianas versus compensadas.
********************************************************************************

tempfile own_em own_eh own_all

import delimited using "$TABLES/elasticidades_marshallianas_hsym_stata.csv", clear case(lower)

rename bfvl  valor_bfvl
rename pork  valor_pork
rename poult valor_poult
rename fish  valor_fish

reshape long valor_, i(produto_linha) j(produto_coluna) string
keep if produto_linha == produto_coluna

rename valor_ elasticidade
gen str20 tipo = "Marshalliana"

save `own_em', replace

import delimited using "$TABLES/elasticidades_compensadas_hsym_stata.csv", clear case(lower)

rename bfvl  valor_bfvl
rename pork  valor_pork
rename poult valor_poult
rename fish  valor_fish

reshape long valor_, i(produto_linha) j(produto_coluna) string
keep if produto_linha == produto_coluna

rename valor_ elasticidade
gen str20 tipo = "Compensada"

append using `own_em'

gen byte ordem_produto = .
replace ordem_produto = 1 if produto_linha == "bfvl"
replace ordem_produto = 2 if produto_linha == "pork"
replace ordem_produto = 3 if produto_linha == "poult"
replace ordem_produto = 4 if produto_linha == "fish"

gen byte ordem_tipo = .
replace ordem_tipo = 1 if tipo == "Marshalliana"
replace ordem_tipo = 2 if tipo == "Compensada"

gen double xpos = ordem_produto
replace xpos = xpos - 0.13 if tipo == "Marshalliana"
replace xpos = xpos + 0.13 if tipo == "Compensada"

gen str8 rotulo = string(elasticidade, "%5.2f")

twoway ///
    (bar elasticidade xpos if tipo == "Marshalliana", barwidth(0.22) fcolor(`cor_bovina'%65) lcolor(`cor_bovina')) ///
    (bar elasticidade xpos if tipo == "Compensada",   barwidth(0.22) fcolor(`cor_suina'%65)  lcolor(`cor_suina')) ///
    (scatter elasticidade xpos, msymbol(i) mlabel(rotulo) mlabposition(12) mlabsize(vsmall) mlabcolor(black)), ///
    yline(0, lcolor(black) lpattern(dash) lwidth(thin)) ///
    xlabel(1 "bfvl" 2 "pork" 3 "poult" 4 "fish", labsize(small)) ///
    ylabel(, labsize(small) grid glcolor(gs14)) ///
    title("Elasticidades-preco proprias", size(medsmall)) ///
    subtitle("Comparacao entre Marshallianas e compensadas", size(small)) ///
    xtitle("Produto", size(small)) ///
    ytitle("Elasticidade-preco propria", size(small)) ///
    legend(order(1 "Marshalliana" 2 "Compensada") cols(1) position(3) ring(1) region(lcolor(none) fcolor(none)) size(small)) ///
    `tema_base' ///
    name(g_extra_own, replace)

graph export "$EXTRA_PDF/stata_extra_01_elasticidades_proprias_marshallianas_compensadas.pdf", replace
graph export "$EXTRA_PNG/stata_extra_01_elasticidades_proprias_marshallianas_compensadas.png", replace width(2400)

********************************************************************************
* 2. Heatmap da diferenca Slutsky: compensada - Marshalliana.
********************************************************************************

tempfile em_long eh_long diff_long

import delimited using "$TABLES/elasticidades_marshallianas_hsym_stata.csv", clear case(lower)

rename bfvl  em_bfvl
rename pork  em_pork
rename poult em_poult
rename fish  em_fish

reshape long em_, i(produto_linha) j(produto_coluna) string
rename em_ em
save `em_long', replace

import delimited using "$TABLES/elasticidades_compensadas_hsym_stata.csv", clear case(lower)

rename bfvl  eh_bfvl
rename pork  eh_pork
rename poult eh_poult
rename fish  eh_fish

reshape long eh_, i(produto_linha) j(produto_coluna) string
rename eh_ eh

merge 1:1 produto_linha produto_coluna using `em_long', nogenerate

gen double diff = eh - em
gen str8 rotulo = string(diff, "%5.2f")
gen double peso = abs(diff) + 0.05

gen byte row = .
replace row = 4 if produto_linha == "bfvl"
replace row = 3 if produto_linha == "pork"
replace row = 2 if produto_linha == "poult"
replace row = 1 if produto_linha == "fish"

gen byte col = .
replace col = 1 if produto_coluna == "bfvl"
replace col = 2 if produto_coluna == "pork"
replace col = 3 if produto_coluna == "poult"
replace col = 4 if produto_coluna == "fish"

twoway ///
    (scatter row col if diff >= 0 [aw=peso], msymbol(square) msize(vlarge) mcolor(`cor_pos'%65) mlabcolor(black) mlabel(rotulo) mlabposition(0) mlabsize(small)) ///
    (scatter row col if diff < 0  [aw=peso], msymbol(square) msize(vlarge) mcolor(`cor_neg'%65) mlabcolor(black) mlabel(rotulo) mlabposition(0) mlabsize(small)), ///
    xlabel(1 "bfvl" 2 "pork" 3 "poult" 4 "fish", angle(0) labsize(small)) ///
    ylabel(1 "fish" 2 "poult" 3 "pork" 4 "bfvl", labsize(small)) ///
    title("Diferenca entre elasticidades compensadas e Marshallianas", size(medsmall)) ///
    subtitle("Efeito-renda removido pela relacao de Slutsky: EH - EM", size(small)) ///
    xtitle("Preco", size(small)) ///
    ytitle("Demanda", size(small)) ///
    legend(order(1 "Diferenca positiva" 2 "Diferenca negativa") cols(1) position(3) ring(1) region(lcolor(none) fcolor(none)) size(small)) ///
    `tema_base' ///
    name(g_extra_diff, replace)

graph export "$EXTRA_PDF/stata_extra_02_heatmap_diferenca_slutsky.pdf", replace
graph export "$EXTRA_PNG/stata_extra_02_heatmap_diferenca_slutsky.png", replace width(2400)

********************************************************************************
* 3. Rede simplificada das elasticidades cruzadas compensadas.
*    Seta: preco do produto de origem -> demanda do produto de destino.
********************************************************************************

import delimited using "$TABLES/elasticidades_compensadas_hsym_stata.csv", clear case(lower)

rename bfvl  valor_bfvl
rename pork  valor_pork
rename poult valor_poult
rename fish  valor_fish

reshape long valor_, i(produto_linha) j(produto_coluna) string
rename valor_ elasticidade

keep if produto_linha != produto_coluna
gen double abs_elast = abs(elasticidade)

* Mantem relacoes economicamente mais visiveis no grafico.
keep if abs_elast >= 0.10

gen byte sinal = .
replace sinal = 1  if elasticidade > 0
replace sinal = -1 if elasticidade < 0

gen double x_from = .
gen double y_from = .
gen double x_to   = .
gen double y_to   = .

* Coordenadas do produto cujo preco varia.
replace x_from = 0 if produto_coluna == "bfvl"
replace y_from = 1 if produto_coluna == "bfvl"

replace x_from = 1 if produto_coluna == "pork"
replace y_from = 1 if produto_coluna == "pork"

replace x_from = 1 if produto_coluna == "poult"
replace y_from = 0 if produto_coluna == "poult"

replace x_from = 0 if produto_coluna == "fish"
replace y_from = 0 if produto_coluna == "fish"

* Coordenadas do produto cuja demanda responde.
replace x_to = 0 if produto_linha == "bfvl"
replace y_to = 1 if produto_linha == "bfvl"

replace x_to = 1 if produto_linha == "pork"
replace y_to = 1 if produto_linha == "pork"

replace x_to = 1 if produto_linha == "poult"
replace y_to = 0 if produto_linha == "poult"

replace x_to = 0 if produto_linha == "fish"
replace y_to = 0 if produto_linha == "fish"

gen str28 nome_from = ""
replace nome_from = "Carne bovina e vitela" if produto_coluna == "bfvl"
replace nome_from = "Carne suina"           if produto_coluna == "pork"
replace nome_from = "Frango"                if produto_coluna == "poult"
replace nome_from = "Pescados"              if produto_coluna == "fish"

bysort produto_coluna: gen byte tag_node = (_n == 1)

twoway ///
    (pcarrow y_from x_from y_to x_to if sinal == 1, lcolor(`cor_pos'%55) mcolor(`cor_pos'%55) lwidth(medthick)) ///
    (pcarrow y_from x_from y_to x_to if sinal == -1, lcolor(`cor_neg'%55) mcolor(`cor_neg'%55) lwidth(medthick)) ///
    (scatter y_from x_from if tag_node == 1, msymbol(circle) msize(large) mcolor(gs14) mlcolor(black) mlabel(nome_from) mlabposition(12) mlabsize(small) mlabcolor(black)), ///
    xscale(range(-0.25 1.35) off) ///
    yscale(range(-0.20 1.25) off) ///
    xlabel(none) ylabel(none) ///
    title("Rede de elasticidades cruzadas compensadas", size(medsmall)) ///
    subtitle("Setas positivas indicam substituicao; negativas indicam relacao negativa", size(vsmall)) ///
    legend(order(1 "Elasticidade cruzada positiva" 2 "Elasticidade cruzada negativa") cols(1) position(6) ring(0) region(lcolor(none) fcolor(none)) size(small)) ///
    aspectratio(1) ///
    `tema_base' ///
    name(g_extra_rede, replace)

graph export "$EXTRA_PDF/stata_extra_03_rede_elasticidades_cruzadas_compensadas.pdf", replace
graph export "$EXTRA_PNG/stata_extra_03_rede_elasticidades_cruzadas_compensadas.png", replace width(2400)

********************************************************************************
* 4. Residuos por equacao ao longo do tempo, incluindo a equacao omitida recuperada.
********************************************************************************

use "$PROC_DTA", clear

drop if missing(w_bfvl, w_pork, w_poult, w_fish, lngp_bfvl, lngp_pork, lngp_poult, lngp_fish, ln_real_x)

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

preserve

keep year res_bfvl res_pork res_poult res_fish

reshape long res_, i(year) j(produto) string
rename res_ residuo

gen str28 produto_nome = ""
replace produto_nome = "Carne bovina e vitela" if produto == "bfvl"
replace produto_nome = "Carne suina"           if produto == "pork"
replace produto_nome = "Frango"                if produto == "poult"
replace produto_nome = "Pescados"              if produto == "fish"

twoway ///
    (line residuo year, lcolor(`cor_bovina') lwidth(medthick)), ///
    by(produto_nome, cols(2) note("") graphregion(color(white))) ///
    yline(0, lcolor(black) lpattern(dash) lwidth(thin)) ///
    title("Residuos do modelo AIDS por equacao", size(medsmall)) ///
    xtitle("Ano", size(small)) ///
    ytitle("Residuo da participacao no dispendio", size(small)) ///
    xlabel(, labsize(small) grid glcolor(gs14)) ///
    ylabel(, labsize(small) grid glcolor(gs14)) ///
    legend(off) ///
    `tema_base' ///
    name(g_extra_residuos, replace)

graph export "$EXTRA_PDF/stata_extra_04_residuos_por_equacao_tempo.pdf", replace
graph export "$EXTRA_PNG/stata_extra_04_residuos_por_equacao_tempo.png", replace width(2400)

restore

********************************************************************************
* 5. Primeira etapa: observado versus ajustado para cada preco endogeno.
********************************************************************************

use "$PROC_DTA", clear

drop if missing(ln_real_x, L1_lngp_bfvl, L1_lngp_pork, L1_lngp_poult, L1_lngp_fish)

foreach g in bfvl pork poult fish {

    quietly regress lngp_`g' ln_real_x L1_lngp_bfvl L1_lngp_pork L1_lngp_poult L1_lngp_fish
    predict double fit_lngp_`g' if e(sample), xb

    quietly summarize lngp_`g' if e(sample), meanonly
    local lo = r(min)
    local hi = r(max)

    quietly summarize fit_lngp_`g' if e(sample), meanonly
    if r(min) < `lo' local lo = r(min)
    if r(max) > `hi' local hi = r(max)

    local titulo ""
    if "`g'" == "bfvl"  local titulo "Carne bovina e vitela"
    if "`g'" == "pork"  local titulo "Carne suina"
    if "`g'" == "poult" local titulo "Frango"
    if "`g'" == "fish"  local titulo "Pescados"

    twoway ///
        (scatter lngp_`g' fit_lngp_`g' if e(sample), mcolor(`cor_bovina'%70) msymbol(circle) msize(medium)) ///
        (function y = x, range(`lo' `hi') lcolor(black) lpattern(dash) lwidth(thin)), ///
        title("`titulo'", size(small)) ///
        xtitle("Preco ajustado na primeira etapa", size(vsmall)) ///
        ytitle("Preco observado", size(vsmall)) ///
        xlabel(, labsize(vsmall) grid glcolor(gs14)) ///
        ylabel(, labsize(vsmall) grid glcolor(gs14)) ///
        legend(off) ///
        `tema_base' ///
        name(g_fs_`g', replace)
}

graph combine g_fs_bfvl g_fs_pork g_fs_poult g_fs_fish, ///
    cols(2) ///
    title("Primeira etapa: observado versus ajustado", size(medsmall)) ///
    note("Instrumentos: primeira defasagem dos log-precos normalizados.", size(vsmall)) ///
    graphregion(color(white)) ///
    name(g_extra_firststage_fit, replace)

graph export "$EXTRA_PDF/stata_extra_05_primeira_etapa_observado_ajustado.pdf", replace
graph export "$EXTRA_PNG/stata_extra_05_primeira_etapa_observado_ajustado.png", replace width(2400)

********************************************************************************
* 6. Estabilidade das elasticidades proprias por especificacao.
********************************************************************************

use "$PROC_DTA", clear

drop if missing(w_bfvl, w_pork, w_poult, w_fish, lngp_bfvl, lngp_pork, lngp_poult, lngp_fish, ln_real_x, L1_lngp_bfvl, L1_lngp_pork, L1_lngp_poult, L1_lngp_fish)

foreach g in bfvl pork poult fish {
    quietly summarize w_`g', meanonly
    scalar wbar_`g' = r(mean)
}

matrix WBAR = (scalar(wbar_bfvl) \ scalar(wbar_pork) \ scalar(wbar_poult) \ scalar(wbar_fish))
matrix rownames WBAR = bfvl pork poult fish
matrix colnames WBAR = wbar

capture program drop _post_own_elast
program define _post_own_elast
    syntax , HANDLE(name) SPEC(string) MODELPATH(string) LABEL(string)

    estimates use "`modelpath'"

    scalar a_bfvl = _b[/a_bfvl]
    scalar a_pork = _b[/a_pork]
    scalar a_fish = _b[/a_fish]
    scalar a_poult = 1 - a_bfvl - a_pork - a_fish

    scalar b_bfvl = _b[/b_bfvl]
    scalar b_pork = _b[/b_pork]
    scalar b_fish = _b[/b_fish]
    scalar b_poult = - b_bfvl - b_pork - b_fish

    matrix BETA = (b_bfvl \ b_pork \ b_poult \ b_fish)
    matrix rownames BETA = bfvl pork poult fish
    matrix colnames BETA = beta

    matrix GAMMA = J(4,4,.)
    matrix rownames GAMMA = bfvl pork poult fish
    matrix colnames GAMMA = bfvl pork poult fish

    if "`spec'" == "unres" {

        scalar g11 = _b[/gbfvl_bfvl]
        scalar g12 = _b[/gbfvl_pork]
        scalar g13 = _b[/gbfvl_poult]
        scalar g14 = _b[/gbfvl_fish]

        scalar g21 = _b[/gpork_bfvl]
        scalar g22 = _b[/gpork_pork]
        scalar g23 = _b[/gpork_poult]
        scalar g24 = _b[/gpork_fish]

        scalar g41 = _b[/gfish_bfvl]
        scalar g42 = _b[/gfish_pork]
        scalar g43 = _b[/gfish_poult]
        scalar g44 = _b[/gfish_fish]

        scalar g31 = -(g11 + g21 + g41)
        scalar g32 = -(g12 + g22 + g42)
        scalar g33 = -(g13 + g23 + g43)
        scalar g34 = -(g14 + g24 + g44)
    }

    if "`spec'" == "hom" {

        scalar g11 = _b[/gbfvl_bfvl]
        scalar g12 = _b[/gbfvl_pork]
        scalar g14 = _b[/gbfvl_fish]
        scalar g13 = -(g11 + g12 + g14)

        scalar g21 = _b[/gpork_bfvl]
        scalar g22 = _b[/gpork_pork]
        scalar g24 = _b[/gpork_fish]
        scalar g23 = -(g21 + g22 + g24)

        scalar g41 = _b[/gfish_bfvl]
        scalar g42 = _b[/gfish_pork]
        scalar g44 = _b[/gfish_fish]
        scalar g43 = -(g41 + g42 + g44)

        scalar g31 = -(g11 + g21 + g41)
        scalar g32 = -(g12 + g22 + g42)
        scalar g33 = -(g13 + g23 + g43)
        scalar g34 = -(g14 + g24 + g44)
    }

    if inlist("`spec'", "hsym", "hsym_L2") {

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
    }

    matrix GAMMA[1,1] = g11
    matrix GAMMA[1,2] = g12
    matrix GAMMA[1,3] = g13
    matrix GAMMA[1,4] = g14

    matrix GAMMA[2,1] = g21
    matrix GAMMA[2,2] = g22
    matrix GAMMA[2,3] = g23
    matrix GAMMA[2,4] = g24

    matrix GAMMA[3,1] = g31
    matrix GAMMA[3,2] = g32
    matrix GAMMA[3,3] = g33
    matrix GAMMA[3,4] = g34

    matrix GAMMA[4,1] = g41
    matrix GAMMA[4,2] = g42
    matrix GAMMA[4,3] = g43
    matrix GAMMA[4,4] = g44

    forvalues i = 1/4 {

        scalar wi = WBAR[`i',1]
        scalar bi = BETA[`i',1]

        scalar eta_i = 1 + bi/wi
        scalar em_ii = -1 + GAMMA[`i',`i']/wi - bi
        scalar eh_ii = em_ii + eta_i*wi

        local produto : word `i' of bfvl pork poult fish

        post `handle' ("`label'") ("`produto'") (eta_i) (em_ii) (eh_ii)
    }
end

tempfile elast_modelos
tempname postelast

postfile `postelast' str24 modelo str8 produto double eta em_propria eh_propria using `elast_modelos', replace

_post_own_elast, handle(`postelast') spec(unres)   modelpath("$MODELS/aids_unrestricted.ster") label("Irrestrito")
_post_own_elast, handle(`postelast') spec(hom)     modelpath("$MODELS/aids_homogeneity.ster")  label("Homogeneidade")
_post_own_elast, handle(`postelast') spec(hsym)    modelpath("$MODELS/aids_hsym.ster")         label("Homog. + simetria")
_post_own_elast, handle(`postelast') spec(hsym_L2) modelpath("$MODELS/aids_hsym_L2.ster")      label("Homog. + simetria L2")

postclose `postelast'

use `elast_modelos', clear
export delimited using "$TABLES/elasticidades_proprias_por_modelo_stata.csv", replace

gen byte ordem_produto = .
replace ordem_produto = 1 if produto == "bfvl"
replace ordem_produto = 2 if produto == "pork"
replace ordem_produto = 3 if produto == "poult"
replace ordem_produto = 4 if produto == "fish"

gen byte ordem_modelo = .
replace ordem_modelo = 1 if modelo == "Irrestrito"
replace ordem_modelo = 2 if modelo == "Homogeneidade"
replace ordem_modelo = 3 if modelo == "Homog. + simetria"
replace ordem_modelo = 4 if modelo == "Homog. + simetria L2"

gen double xpos = ordem_produto + (ordem_modelo - 2.5)*0.14

twoway ///
    (bar em_propria xpos if modelo == "Irrestrito",            barwidth(0.12) fcolor(`cor_bovina'%65)   lcolor(`cor_bovina')) ///
    (bar em_propria xpos if modelo == "Homogeneidade",         barwidth(0.12) fcolor(`cor_suina'%65)    lcolor(`cor_suina')) ///
    (bar em_propria xpos if modelo == "Homog. + simetria",     barwidth(0.12) fcolor(`cor_frango'%65)   lcolor(`cor_frango')) ///
    (bar em_propria xpos if modelo == "Homog. + simetria L2",  barwidth(0.12) fcolor(`cor_pescados'%65) lcolor(`cor_pescados')), ///
    yline(0, lcolor(black) lpattern(dash) lwidth(thin)) ///
    xlabel(1 "bfvl" 2 "pork" 3 "poult" 4 "fish", labsize(small)) ///
    ylabel(, labsize(small) grid glcolor(gs14)) ///
    title("Estabilidade das elasticidades-preco proprias", size(medsmall)) ///
    subtitle("Elasticidades Marshallianas por especificacao", size(small)) ///
    xtitle("Produto", size(small)) ///
    ytitle("Elasticidade-preco propria", size(small)) ///
    legend(order(1 "Irrestrito" 2 "Homogeneidade" 3 "Homog. + simetria" 4 "Homog. + simetria L2") cols(1) position(3) ring(1) region(lcolor(none) fcolor(none)) size(small)) ///
    `tema_base' ///
    name(g_extra_stability, replace)

graph export "$EXTRA_PDF/stata_extra_06_estabilidade_elasticidades_proprias.pdf", replace
graph export "$EXTRA_PNG/stata_extra_06_estabilidade_elasticidades_proprias.png", replace width(2400)

********************************************************************************
* 7. Estatistica objetivo do GMM por especificacao.
********************************************************************************

import delimited using "$TABLES/comparacao_modelos_stata.csv", clear case(lower)

capture confirm variable j_obj
if _rc {
    di as error "A variavel j_obj nao foi encontrada em comparacao_modelos_stata.csv."
}
else {

    gen str30 modelo_nome = modelo
    replace modelo_nome = "Irrestrito"              if modelo == "aids_unrestricted"
    replace modelo_nome = "Homogeneidade"           if modelo == "aids_homogeneity"
    replace modelo_nome = "Homog. + simetria"       if modelo == "aids_hsym"
    replace modelo_nome = "Homog. + simetria L2"    if modelo == "aids_hsym_L2"

    graph bar j_obj if !missing(j_obj), ///
        over(modelo_nome, label(angle(25) labsize(vsmall))) ///
        title("Estatistica objetivo do GMM por especificacao", size(medsmall)) ///
        ytitle("J do GMM", size(small)) ///
        ylabel(, labsize(small) grid glcolor(gs14)) ///
        bar(1, fcolor(`cor_extra'%65) lcolor(`cor_extra')) ///
        graphregion(color(white)) plotregion(color(white)) ///
        name(g_extra_j, replace)

    graph export "$EXTRA_PDF/stata_extra_07_estatistica_objetivo_gmm.pdf", replace
    graph export "$EXTRA_PNG/stata_extra_07_estatistica_objetivo_gmm.png", replace width(2400)
}

log close