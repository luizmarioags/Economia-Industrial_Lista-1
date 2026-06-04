/********************************************************************
 Gráficos auxiliares para interpretação dos resultados

 Correções principais:
   - Carrega config.do automaticamente se o script for rodado sozinho;
   - Gera chicken_with_ols_residuals_stata.dta caso ele não exista;
   - Se tabelas necessárias estiverem ausentes, orienta/roda scripts prévios;
   - Inclui gráfico MQO versus 2SLS com intervalos de confiança;
   - Inclui Figura 6 com EATEX/MEATEX e preço real da carne bovina,
     carregando diretamente a base bruta usada em 01_prepare_data.do;
   - Ajusta rótulos matemáticos nos gráficos usando marcação do Stata,
     como {it:p}{subscript:b} e ln({it:EATEX}{subscript:t}).
********************************************************************/

clear all

* Carrega configuração se o script for rodado individualmente.
do "Stata/_load_config_if_needed.do"

* ------------------------------------------------------------
* Garante que a base tratada exista
* ------------------------------------------------------------

capture confirm file "$PROC/chicken_prepared_stata.dta"
if _rc {
    di as text "[Stata] Base tratada não encontrada. Rodando 01_prepare_data.do..."
    do "Stata/01_prepare_data.do"
}

* ------------------------------------------------------------
* Garante que a base com resíduos exista
* ------------------------------------------------------------

capture confirm file "$PROC/chicken_with_ols_residuals_stata.dta"

if _rc {
    di as text "[Stata] Base com resíduos não encontrada. Gerando a partir da base preparada..."

    use "$PROC/chicken_prepared_stata.dta", clear

    foreach v in ln_q ln_pch ln_y ln_pb {
        capture confirm variable `v'
        if _rc {
            di as error "[Stata] Variável `v' não encontrada em $PROC/chicken_prepared_stata.dta."
            di as error "[Stata] Rode Stata/01_prepare_data.do e verifique a importação da base."
            exit 111
        }
    }

    quietly regress ln_q ln_pch ln_y ln_pb, vce(robust)
    predict double ols_fitted, xb
    predict double ols_resid, resid

    label variable ols_fitted "Valor ajustado pelo MQO"
    label variable ols_resid  "Resíduo do MQO"

    save "$PROC/chicken_with_ols_residuals_stata.dta", replace
    di as text "[Stata] Base com resíduos criada: $PROC/chicken_with_ols_residuals_stata.dta"
}

use "$PROC/chicken_with_ols_residuals_stata.dta", clear

/********************************************************************
 Figura 1: séries logarítmicas principais
********************************************************************/

di as text "[Stata] Gerando Figura 1: séries logarítmicas principais"

twoway ///
    (line ln_q year,   lcolor(navy)         lwidth(medthick)) ///
    (line ln_pch year, lcolor(cranberry)    lwidth(medthick)) ///
    (line ln_y year,   lcolor(forest_green) lwidth(medthick)) ///
    (line ln_pb year,  lcolor(orange)       lwidth(medthick)) ///
    (line z year,      lcolor(purple)       lwidth(medthick)), ///
    title("Séries logarítmicas principais", size(medsmall)) ///
    xtitle("Ano", size(small)) ///
    ytitle("Logaritmo", size(small)) ///
    legend( ///
        order(1 "Quantidade per capita de frango" ///
              2 "Preço real do frango" ///
              3 "Renda real per capita" ///
              4 "Preço real da carne bovina" ///
              5 "Preço real do milho") ///
        cols(1) ///
        size(small) ///
        position(3) ///
        ring(1) ///
        region(lcolor(none) fcolor(none)) ///
    ) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_series, replace)

graph export "$FIGS/stata_fig01_series.png", replace width(2800)
graph export "$FIGS/stata_fig01_series.pdf", replace

/********************************************************************
 Figura 2: demanda observada
********************************************************************/

di as text "[Stata] Gerando Figura 2: demanda observada"

twoway ///
    (scatter ln_q ln_pch, mcolor(navy) msymbol(circle) msize(medium)) ///
    (lfit ln_q ln_pch, lcolor(cranberry) lwidth(medthick)), ///
    title("Demanda observada: quantidade versus preço do frango", size(medsmall)) ///
    xtitle("Log do preço real do frango", size(small)) ///
    ytitle("Log da quantidade per capita de frango", size(small)) ///
    legend( ///
        order(1 "Observações anuais" ///
              2 "Ajuste linear") ///
        cols(1) ///
        size(small) ///
        position(3) ///
        ring(1) ///
        region(lcolor(none) fcolor(none)) ///
    ) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_scatter_demand, replace)

graph export "$FIGS/stata_fig02_scatter_demand.png", replace width(2800)
graph export "$FIGS/stata_fig02_scatter_demand.pdf", replace

/********************************************************************
 Figura 3: resíduos do MQO versus valores ajustados
 Com curva de ajuste não linear LOWESS
********************************************************************/

di as text "[Stata] Gerando Figura 3: resíduos MQO versus valores ajustados com ajuste não linear"

twoway ///
    (scatter ols_resid ols_fitted, ///
        mcolor(navy) ///
        msymbol(circle) ///
        msize(medium)) ///
    (lowess ols_resid ols_fitted, ///
        lcolor(cranberry) ///
        lwidth(medthick) ///
        bwidth(0.8)), ///
    yline(0, ///
        lcolor(black) ///
        lpattern(dash) ///
        lwidth(medthin)) ///
    title("Resíduos do MQO versus valores ajustados", size(medsmall)) ///
    subtitle("Com curva de ajuste não linear dos resíduos", size(small)) ///
    xtitle("Valor ajustado pelo MQO", size(small)) ///
    ytitle("Resíduo do MQO", size(small)) ///
    legend( ///
        order(1 "Resíduos do MQO" ///
              2 "Ajuste não linear LOWESS" ///
              3 "Linha de resíduo zero") ///
        cols(1) ///
        size(small) ///
        position(3) ///
        ring(1) ///
        region(lcolor(none) fcolor(none)) ///
    ) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_resid_fitted, replace)

graph export "$FIGS/stata_fig03_residuals_fitted.png", replace width(2800)
graph export "$FIGS/stata_fig03_residuals_fitted.pdf", replace

di as text "[Stata] Gráfico salvo em PNG: output/figures/stata_fig03_residuals_fitted.png"
di as text "[Stata] Gráfico salvo em PDF: output/figures/stata_fig03_residuals_fitted.pdf"

/********************************************************************
 Figura 4: elasticidade-preço estimada: MQO versus 2SLS
********************************************************************/

di as text "[Stata] Gerando Figura 4: elasticidade-preço estimada — MQO versus 2SLS"

capture confirm file "$TABS/stata_question_01_ols.csv"
if _rc {
    di as text "[Stata] Tabela de MQO não encontrada. Rodando 02_ols_iv_first_stage.do..."
    do "Stata/02_ols_iv_first_stage.do"
}

capture confirm file "$TABS/stata_question_09_comparative.csv"
if _rc {
    di as text "[Stata] Tabela comparativa não encontrada. Rodando 04_alt_instruments_weakiv.do..."
    do "Stata/04_alt_instruments_weakiv.do"
}

tempfile resultados_iv resultados_ols

* ------------------------------------------------------------
* Resultados 2SLS: Z1 a Z7
* ------------------------------------------------------------

import delimited "$TABS/stata_question_09_comparative.csv", clear

keep model n beta_p ci_low ci_high

foreach v in n beta_p ci_low ci_high {
    capture confirm numeric variable `v'
    if _rc {
        destring `v', replace force
    }
}

gen str20 modelo = upper(model)
gen str20 estimador = "2SLS"

* Se model for Z1, Z2, ..., Z7
gen ordem = real(substr(modelo, 2, .)) + 1

keep modelo estimador ordem n beta_p ci_low ci_high

save `resultados_iv', replace

* ------------------------------------------------------------
* Resultado MQO
* ------------------------------------------------------------

import delimited "$TABS/stata_question_01_ols.csv", clear

keep n beta_p ci_low_p ci_high_p

foreach v in n beta_p ci_low_p ci_high_p {
    capture confirm numeric variable `v'
    if _rc {
        destring `v', replace force
    }
}

rename ci_low_p  ci_low
rename ci_high_p ci_high

gen str20 modelo = "MQO"
gen str20 estimador = "MQO"
gen ordem = 1

keep modelo estimador ordem n beta_p ci_low ci_high

save `resultados_ols', replace

* ------------------------------------------------------------
* Junta MQO e 2SLS
* ------------------------------------------------------------

use `resultados_ols', clear
append using `resultados_iv'

drop if missing(beta_p)
sort ordem

gen y = ordem

capture label drop lab_modelo
label define lab_modelo ///
    1 "MQO" ///
    2 "Z1" ///
    3 "Z2" ///
    4 "Z3" ///
    5 "Z4" ///
    6 "Z5" ///
    7 "Z6" ///
    8 "Z7", replace

label values y lab_modelo

twoway ///
    (rcap ci_low ci_high y, horizontal ///
        lcolor(gs6) ///
        lwidth(medthin)) ///
    (scatter y beta_p if estimador == "MQO", ///
        mcolor(black) ///
        msymbol(circle) ///
        msize(medium)) ///
    (scatter y beta_p if estimador == "2SLS", ///
        mcolor(black) ///
        msymbol(circle) ///
        msize(medium)), ///
    xline(0, lcolor(black) lpattern(solid) lwidth(thin)) ///
    yscale(reverse) ///
    ylabel(1(1)8, valuelabel angle(0) labsize(small) noticks) ///
    xlabel(, labsize(small)) ///
    title("Elasticidade-preço estimada: MQO versus 2SLS", size(medsmall)) ///
    xtitle("{&beta}{subscript:p}", size(small)) ///
    ytitle("Modelo", size(small)) ///
    legend(off) ///
    note("Pontos: estimativas de {&beta}{subscript:p}. Barras horizontais: intervalos de confiança de 95%. Linha vertical: elasticidade igual a zero.", ///
         size(vsmall)) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_beta_mqo_2sls, replace)

graph export "$FIGS/stata_fig04_beta_p_mqo_versus_2sls.png", ///
    replace width(2600)

graph export "$FIGS/stata_fig04_beta_p_mqo_versus_2sls.pdf", ///
    replace

di as text "[Stata] Gráfico salvo em PNG: output/figures/stata_fig04_beta_p_mqo_versus_2sls.png"
di as text "[Stata] Gráfico salvo em PDF: output/figures/stata_fig04_beta_p_mqo_versus_2sls.pdf"

/********************************************************************
 Figura GMM: elasticidade-preço e teste J de Hansen
 Questão 5
********************************************************************/

di as text _newline "[Stata] Gerando figura GMM: beta_p e Hansen J"

local procdir "$PROC"

if `"`procdir'"' == "" {
    capture noisily do "Stata/config.do"
    if _rc {
        di as error "[Stata] Não consegui carregar Stata/config.do."
        exit 601
    }
}

capture confirm file "$TABS/stata_question_05_gmm.csv"
if _rc {
    di as text "[Stata] Tabela GMM não encontrada. Rodando 03_gmm_hansen.do..."
    do "Stata/03_gmm_hansen.do"
}

* ============================================================
* Painel A: coeficiente beta_p por GMM
* ============================================================

import delimited "$TABS/stata_question_05_gmm.csv", clear

foreach v in n beta_p se_p pval_p ci_low ci_high hansen_j hansen_p hansen_df {
    capture confirm numeric variable `v'
    if _rc {
        capture destring `v', replace force
    }
}

gen ordem = .
replace ordem = 1 if model == "GMM_Z1"
replace ordem = 2 if model == "GMM_Z2"

gen y = ordem

capture label drop lab_gmm
label define lab_gmm ///
    1 "GMM Z1: {{it:z}{subscript:t}}" ///
    2 "GMM Z2: {{it:z}{subscript:t}, {it:z}{subscript:t}{superscript:2}}", replace

label values y lab_gmm

twoway ///
    (rcap ci_low ci_high y, horizontal ///
        lcolor(gs6) ///
        lwidth(medthin)) ///
    (scatter y beta_p, ///
        mcolor(black) ///
        msymbol(circle) ///
        msize(medium)), ///
    xline(0, lcolor(black) lpattern(solid) lwidth(thin)) ///
    yscale(reverse) ///
    ylabel(1(1)2, valuelabel angle(0) labsize(small) noticks) ///
    xlabel(, labsize(small)) ///
    title("A. Elasticidade-preço estimada por GMM", size(medsmall)) ///
    xtitle("{&beta}{subscript:p}", size(small)) ///
    ytitle("") ///
    legend(off) ///
    note("Pontos: estimativas de {&beta}{subscript:p}. Barras horizontais: IC 95%.", ///
         size(vsmall)) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_gmm_beta, replace)

* ============================================================
* Painel B: Hansen J para modelo sobreidentificado
* ============================================================

preserve

keep if hansen_df > 0
gen x = 1
gen crit_5 = invchi2tail(hansen_df, 0.05)

twoway ///
    (bar hansen_j x, ///
        barwidth(0.45) ///
        fcolor(navy%65) ///
        lcolor(navy)) ///
    (function y = crit_5[1], ///
        range(0.6 1.4) ///
        lcolor(cranberry) ///
        lpattern(dash) ///
        lwidth(medthick)), ///
    xlabel(1 "GMM Z2", labsize(small)) ///
    ylabel(, labsize(small)) ///
    title("B. Teste J de Hansen", size(medsmall)) ///
    ytitle("Estatística J", size(small)) ///
    xtitle("") ///
    legend( ///
        order(1 "Estatística J observada" ///
              2 "Valor crítico 5%") ///
        cols(1) ///
        size(small) ///
        position(3) ///
        ring(1) ///
        region(lcolor(none) fcolor(none)) ///
    ) ///
    note("Modelo sobreidentificado: Z2 = {{it:z}{subscript:t}, {it:z}{subscript:t}{superscript:2}}. Rejeição quando J excede o valor crítico.", ///
         size(vsmall)) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_gmm_hansen, replace)

restore

graph combine ///
    g_gmm_beta ///
    g_gmm_hansen, ///
    cols(2) ///
    imargin(4 4 4 4) ///
    title("GMM: elasticidade-preço e validade dos instrumentos", size(medium)) ///
    subtitle("Comparação entre o modelo exatamente identificado e o sobreidentificado", size(small)) ///
    note( ///
        "Z1 usa apenas {it:z}{subscript:t}; Z2 adiciona {it:z}{subscript:t}{superscript:2}. O teste J de Hansen só se aplica ao modelo sobreidentificado.", ///
        size(vsmall) ///
    ) ///
    graphregion(color(white)) ///
    name(g_gmm_q5, replace)

graph export "$FIGS/stata_fig11_gmm_beta_hansen.png", ///
    replace width(3200)

graph export "$FIGS/stata_fig11_gmm_beta_hansen.pdf", ///
    replace

di as text "[Stata] Figura salva em PNG: output/figures/stata_fig11_gmm_beta_hansen.png"
di as text "[Stata] Figura salva em PDF: output/figures/stata_fig11_gmm_beta_hansen.pdf"

/********************************************************************
 Figura 6 — Mecanismo de transmissão do instrumento EATEX/MEATEX
 Relação entre exportações de carne e preço real da carne bovina

 Observação:
   Esta figura NÃO depende da base tratada em data/processed.
   Ela carrega diretamente a mesma base bruta usada em 01_prepare_data.do:
       1) $RAW/chicken.dta, se existir;
       2) $RAW/chicken.csv, caso contrário.
********************************************************************/

di as text _newline "[Stata] Gerando Figura 6: EATEX/MEATEX e preço real da carne bovina"

clear

* ---------------------------------------------------------------------------
* 1. Carrega a mesma base usada no 01_prepare_data.do
* ---------------------------------------------------------------------------

capture confirm file "$RAW/chicken.dta"

if !_rc {
    di as text "[Stata] Fonte usada: data/raw/chicken.dta"
    use "$RAW/chicken.dta", clear
}
else {
    capture confirm file "$RAW/chicken.csv"

    if !_rc {
        di as text "[Stata] Fonte usada: data/raw/chicken.csv com separador ';'"
        import delimited "$RAW/chicken.csv", delimiter(";") varnames(1) clear case(lower)
        destring, replace ignore(" ")
    }
    else {
        di as error "[Stata] Não encontrei a base bruta."
        di as error "[Stata] Verifique se existe:"
        di as error "        $RAW/chicken.dta"
        di as error "        $RAW/chicken.csv"
        exit 601
    }
}

* Padroniza nomes para minúsculas, como no 01_prepare_data.do.
rename *, lower

* Harmoniza nomes alternativos que aparecem na lista.
capture confirm variable tim
if !_rc {
    capture confirm variable time
    if _rc {
        rename tim time
    }
    else {
        di as text "[Stata] Variável time já existe; renomeação de tim ignorada"
    }
}

* No 01_prepare_data.do, eatex é harmonizada para meatex.
capture confirm variable eatex
if !_rc {
    capture confirm variable meatex
    if _rc {
        rename eatex meatex
        di as text "[Stata] Nome harmonizado: eatex -> meatex"
    }
    else {
        di as text "[Stata] Variáveis eatex e meatex existem; mantendo meatex"
    }
}

* ---------------------------------------------------------------------------
* 2. Aplica as mesmas correções de escala do 01_prepare_data.do
* ---------------------------------------------------------------------------

di as text "[Stata] Aplicando regras de correção de escala"

capture confirm variable year
if !_rc {
    replace year = year/1000 if year > 9999
}

capture confirm variable q
if !_rc {
    replace q = q/100000 if q > 1000
}

capture confirm variable y
if !_rc {
    replace y = y/1000 if y > 100000
}

capture confirm variable pchick
if !_rc {
    replace pchick = pchick/100000 if pchick > 10000
}

capture confirm variable pbeef
if !_rc {
    replace pbeef = pbeef/100000 if pbeef > 10000
}

capture confirm variable pcor
if !_rc {
    replace pcor = pcor/100000 if pcor > 10000
}

capture confirm variable pf
if !_rc {
    replace pf = pf/100000 if pf > 10000 & pf < .
}

capture confirm variable cpi
if !_rc {
    replace cpi = cpi/100000 if cpi > 10000
}

capture confirm variable pop
if !_rc {
    replace pop = pop/10000 if pop > 10000
}

capture confirm variable time
if !_rc {
    replace time = time/100000 if time > 10000
}

* ---------------------------------------------------------------------------
* 3. Verifica variáveis necessárias e cria logs do gráfico
* ---------------------------------------------------------------------------

capture confirm variable pbeef
if _rc {
    di as error "[Stata] Variável pbeef/PBEEF não encontrada."
    exit 111
}

capture confirm variable cpi
if _rc {
    di as error "[Stata] Variável cpi/CPI não encontrada."
    exit 111
}

capture confirm variable meatex
if _rc {
    di as error "[Stata] Variável meatex/eatex não encontrada."
    exit 111
}

drop if missing(pbeef, cpi, meatex)
drop if pbeef <= 0 | cpi <= 0 | meatex <= 0

gen double ln_pb     = ln(pbeef/cpi)
gen double ln_meatex = ln(meatex)

label variable ln_pb     "ln({it:p}{subscript:b})"
label variable ln_meatex "ln({it:EATEX}{subscript:t})"

drop if missing(ln_pb, ln_meatex)

di as text "[Stata] Estatísticas das variáveis usadas na Figura 6"
summarize ln_pb ln_meatex

* Regressão simples apenas para registrar o mecanismo bivariado do gráfico.
regress ln_pb ln_meatex, vce(robust)

* ---------------------------------------------------------------------------
* 4. Gráfico: dispersão + ajuste linear + intervalo de confiança
* ---------------------------------------------------------------------------

twoway ///
    (lfitci ln_pb ln_meatex, ///
        level(95) ///
        ciplot(rarea) ///
        fcolor(gs14%35) ///
        lcolor(none)) ///
    (scatter ln_pb ln_meatex, ///
        msymbol(O) ///
        msize(small) ///
        mcolor(navy%60)) ///
    (lfit ln_pb ln_meatex, ///
        lcolor(red) ///
        lwidth(medthick)), ///
    title("{bf:Mecanismo de Transmissão do Instrumento (Primeiro Estágio)}", ///
        size(medsmall) color(black)) ///
    subtitle("{it:Impacto das Exportações de Carne, ln({it:EATEX}{subscript:t}), sobre o Preço Real da Carne Bovina, {it:p}{subscript:b}}", ///
        size(small) color(black)) ///
    xtitle("Log das Exportações Reais, ln({it:EATEX}{subscript:t})", size(small)) ///
    ytitle("Log do Preço Real da Carne Bovina, {it:p}{subscript:b}", size(small)) ///
    xlabel(, labsize(small) grid glcolor(gs14)) ///
    ylabel(, labsize(small) grid glcolor(gs14)) ///
    legend(off) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    bgcolor(white) ///
    name(fig_eatex_pb_first_stage, replace)

graph export "$FIGS/fig_q13_eatex_pb_first_stage.png", replace width(2400)
graph export "$FIGS/fig_q13_eatex_pb_first_stage.pdf", replace

di as text "[Stata] Figura 6 salva em PNG: output/figures/fig_q13_eatex_pb_first_stage.png"
di as text "[Stata] Figura 6 salva em PDF: output/figures/fig_q13_eatex_pb_first_stage.pdf"

di as result "[Stata] 06_visualizations.do concluído com sucesso."