/********************************************************************
 Questão 14: simulação de instrumentos fracos

 Objetivo:
   - Simular o problema de instrumentos fracos;
   - Mostrar como a redução da força do instrumento afeta:
       1. viés do estimador 2SLS;
       2. dispersão do estimador 2SLS;
       3. cobertura dos intervalos convencionais de 95%;
       4. força do primeiro estágio.

 Estrutura da simulação:
   y = beta*x + u, com beta verdadeiro = -1
   x = pi*z + v
   pi controla a força do instrumento.
********************************************************************/

clear all
set seed 26052026

* Carrega configuração se o script for rodado individualmente.
do "Stata/_load_config_if_needed.do"

di as text _newline "[Stata] Questão 14: simulação de instrumentos fracos"
di as text "[Stata] Equação simulada: y = beta*x + u, com beta verdadeiro = -1"
di as text "[Stata] Primeiro estágio simulado: x = pi*z + v; pi controla a força do instrumento"
di as text "[Stata] Erros u e v são correlacionados (rho=0.6) para gerar endogeneidade"

* ------------------------------------------------------------
* Parâmetros da simulação
* ------------------------------------------------------------

local reps      = 250
local n         = 200
local true_beta = -1

di as text "[Stata] Parâmetros: reps=`reps' | n=`n' | beta verdadeiro=`true_beta'"

* ------------------------------------------------------------
* Arquivo de resultados agregados por nível de pi
* ------------------------------------------------------------

postfile sim ///
    str10 strength double pi int reps ///
    double mean_iv b_ols bias_iv sd_iv mean_f_fs coverage_95 ///
    using "$TABS/stata_question_14_simulation.dta", replace

foreach pi in 1 0.5 0.25 0.10 0.05 0.02 {

    di as text "[Stata] Simulando pi = `pi'"

    tempfile draws

    postfile one ///
        double beta_iv beta_ols f_fs ci_low ci_high covered ///
        using `draws', replace

    forvalues r = 1/`reps' {

        clear
        set obs `n'

        * Instrumento exógeno.
        gen double z = rnormal()

        * Erros estrutural e de primeiro estágio correlacionados.
        * rho = 0.6 gera endogeneidade entre x e u.
        gen double e1 = rnormal()
        gen double e2 = rnormal()
        gen double u  = e1
        gen double v  = 0.6*e1 + sqrt(1 - 0.6^2)*e2

        * Variável endógena.
        gen double x = `pi'*z + v

        * Equação estrutural verdadeira.
        gen double y = `true_beta'*x + u

        * MQO de referência.
        quietly regress y x, vce(robust)
        scalar b_ols_rep = _b[x]

        * Primeiro estágio e F robusto.
        quietly regress x z, vce(robust)
        quietly test z
        scalar f_fs_rep = r(F)

        * Estimação por 2SLS.
        quietly ivregress 2sls y (x = z), vce(robust)

        scalar b  = _b[x]
        scalar se = _se[x]
        scalar lo = b - invnormal(0.975)*se
        scalar hi = b + invnormal(0.975)*se
        scalar ok = (lo <= `true_beta' & hi >= `true_beta')

        post one (b) (b_ols_rep) (f_fs_rep) (lo) (hi) (ok)
    }

    postclose one

    use `draws', clear

    quietly summarize beta_iv
    scalar mean_iv  = r(mean)
    scalar sd_iv    = r(sd)

    quietly summarize beta_ols
    scalar b_ols    = r(mean)

    quietly summarize f_fs
    scalar mean_ffs = r(mean)

    quietly summarize covered
    scalar cov_iv   = r(mean)

    scalar bias_iv  = mean_iv - `true_beta'

    di as text "[Stata] pi=`pi': 2SLS=" %9.6f mean_iv ///
               " | MQO=" %9.6f b_ols ///
               " | viés=" %9.6f bias_iv ///
               " | sd=" %9.6f sd_iv ///
               " | F_fs médio=" %9.2f mean_ffs ///
               " | cobertura=" %9.6f cov_iv

    post sim ("pi=`pi'") (`pi') (`reps') ///
        (mean_iv) (b_ols) (bias_iv) (sd_iv) (mean_ffs) (cov_iv)
}

postclose sim

use "$TABS/stata_question_14_simulation.dta", clear
export delimited using "$TABS/stata_question_14_simulation.csv", replace

di as text "[Stata] Tabela salva: output/tables/stata_question_14_simulation.csv"

* ============================================================
* Gráficos auxiliares da simulação
* ============================================================

* ------------------------------------------------------------
* Gráfico auxiliar 1: dispersão do estimador 2SLS
* Legenda à direita do gráfico
* ------------------------------------------------------------

di as text "[Stata] Gerando gráfico auxiliar 1: dispersão do estimador 2SLS"

twoway ///
    (line sd_iv pi, ///
        sort ///
        lcolor(navy) ///
        lwidth(medthick)) ///
    (scatter sd_iv pi, ///
        mcolor(cranberry) ///
        msymbol(circle) ///
        msize(medium)), ///
    title("Dispersão do 2SLS quando o instrumento enfraquece", size(medsmall)) ///
    subtitle("Simulação com redução gradual da força do primeiro estágio", size(small)) ///
    xtitle("Força do instrumento: coeficiente do primeiro estágio ({&pi})", size(small)) ///
    ytitle("Desvio-padrão das estimativas 2SLS", size(small)) ///
    legend( ///
        order(1 "Dispersão das estimativas 2SLS") ///
        cols(1) ///
        size(small) ///
        position(3) ///
        ring(1) ///
        region(lcolor(none) fcolor(none)) ///
    ) ///
    note( ///
        "Cada ponto representa o desvio-padrão das estimativas 2SLS em 250 repetições da simulação." ///
        "Valores menores de {&pi} indicam instrumentos mais fracos e maior instabilidade do estimador.", ///
        size(vsmall) ///
    ) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_simulation_sd, replace)

graph export "$FIGS/stata_fig06_simulation_sd.png", replace width(3200)
graph export "$FIGS/stata_fig06_simulation_sd.pdf", replace

di as text "[Stata] Gráfico salvo: output/figures/stata_fig06_simulation_sd.png"
di as text "[Stata] Gráfico salvo: output/figures/stata_fig06_simulation_sd.pdf"

* ------------------------------------------------------------
* Gráfico auxiliar 2: estimativa média 2SLS, MQO e valor verdadeiro
* ------------------------------------------------------------

di as text "[Stata] Gerando gráfico auxiliar 2: 2SLS, MQO e valor verdadeiro"

twoway ///
    (function y = `true_beta', range(0.02 1) lcolor(gs8) lpattern(dot) lwidth(medthick)) ///
    (line mean_iv pi, sort lcolor(navy) lpattern(solid) lwidth(medthick)) ///
    (scatter mean_iv pi, mcolor(navy) msymbol(circle) msize(medium)) ///
    (line b_ols pi, sort lcolor(cranberry) lpattern(dash) lwidth(medthick)) ///
    (scatter b_ols pi, mcolor(cranberry) msymbol(triangle) msize(medium)), ///
    title("2SLS se torna instável quando o instrumento enfraquece") ///
    xtitle("Força do instrumento: coeficiente do primeiro estágio ({&pi})") ///
    ytitle("Estimativa média de {&beta}{subscript:p}") ///
    legend( ///
        order(1 "Valor verdadeiro: {&beta}{subscript:p} = -1" ///
              2 "Estimativa média por 2SLS" ///
              4 "Estimativa média por MQO") ///
        cols(1) ///
        size(small) ///
        position(3) ///
        ring(1) ///
        region(lcolor(none) fcolor(none)) ///
    ) ///
    graphregion(color(white)) ///
    plotregion(color(white))

graph export "$FIGS/stata_fig07_simulation_bias_convergence.png", replace width(2600)

di as text "[Stata] Gráfico salvo: output/figures/stata_fig07_simulation_bias_convergence.png"

* ------------------------------------------------------------
* Gráfico auxiliar 3: F médio do primeiro estágio
* Legenda à direita do gráfico
* ------------------------------------------------------------

di as text "[Stata] Gerando gráfico auxiliar 3: F médio do primeiro estágio"

twoway ///
    (line mean_f_fs pi, ///
        sort ///
        lcolor(navy) ///
        lwidth(medthick)) ///
    (scatter mean_f_fs pi, ///
        mcolor(cranberry) ///
        msymbol(circle) ///
        msize(medium)) ///
    (function y = 10, ///
        range(0.02 1) ///
        lcolor(red) ///
        lpattern(dash) ///
        lwidth(medthick)), ///
    title("Força do primeiro estágio por nível de {&pi}", size(medsmall)) ///
    subtitle("Instrumentos mais fortes geram maior estatística F média", size(small)) ///
    xtitle("Força do instrumento: coeficiente do primeiro estágio ({&pi})", size(small)) ///
    ytitle("Estatística F média do primeiro estágio", size(small)) ///
    legend( ///
        order(1 "Estatística F média do primeiro estágio" ///
              3 "Limiar convencional: F = 10") ///
        cols(1) ///
        size(small) ///
        position(3) ///
        ring(1) ///
        region(lcolor(none) fcolor(none)) ///
    ) ///
    note( ///
        "Cada ponto mostra o F médio do primeiro estágio em 250 repetições da simulação." ///
        "A linha vermelha indica a regra de bolso convencional abaixo da qual há indício de instrumento fraco.", ///
        size(vsmall) ///
    ) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_simulation_ffs, replace)

graph export "$FIGS/stata_fig08_simulation_ffs.png", replace width(3200)
graph export "$FIGS/stata_fig08_simulation_ffs.pdf", replace

di as text "[Stata] Gráfico salvo: output/figures/stata_fig08_simulation_ffs.png"
di as text "[Stata] Gráfico salvo: output/figures/stata_fig08_simulation_ffs.pdf"
* ============================================================
* Figura principal da Questão 14
* ============================================================

di as text _newline "[Stata] Questão 14: gerando visualização sintética da simulação"

use "$TABS/stata_question_14_simulation.dta", clear

* ------------------------------------------------------------
* Variáveis auxiliares apenas para o gráfico principal
* ------------------------------------------------------------

gen double vies_abs_2sls = abs(bias_iv)
gen double cobertura_pct = 100*coverage_95

label variable pi              "Força do instrumento: coeficiente do primeiro estágio"
label variable mean_iv         "Elasticidade-preço estimada por 2SLS"
label variable b_ols           "Elasticidade-preço estimada por MQO"
label variable vies_abs_2sls   "Viés absoluto do 2SLS"
label variable sd_iv           "Dispersão do estimador 2SLS"
label variable mean_f_fs       "Estatística F média do primeiro estágio"
label variable cobertura_pct   "Cobertura do IC convencional de 95%"

local xlabels 0.02 "0,02" 0.05 "0,05" 0.10 "0,10" 0.25 "0,25" 0.50 "0,50" 1.00 "1,00"

* ------------------------------------------------------------
* Painel A: estimativa média do parâmetro estrutural
* ------------------------------------------------------------

twoway ///
    (function y = -1, range(0.02 1) lcolor(gs8) lpattern(dot) lwidth(medthick)) ///
    (line mean_iv pi, sort lcolor(navy) lpattern(solid) lwidth(medthick)) ///
    (scatter mean_iv pi, mcolor(navy) msymbol(circle) msize(medium)) ///
    (line b_ols pi, sort lcolor(cranberry) lpattern(dash) lwidth(medthick)) ///
    (scatter b_ols pi, mcolor(cranberry) msymbol(triangle) msize(medium)), ///
    xscale(log) ///
    xlabel(`xlabels', labsize(vsmall)) ///
    ylabel(, labsize(vsmall)) ///
    yline(0, lcolor(gs12) lpattern(solid)) ///
    title("A. Estimativa média do parâmetro estrutural", size(small)) ///
    xtitle("Força do instrumento: coeficiente do primeiro estágio ({&pi})", size(vsmall)) ///
    ytitle("Elasticidade-preço ({&beta}{subscript:p})", size(vsmall) margin(small)) ///
    legend( ///
        order(1 "Valor verdadeiro: {&beta}{subscript:p} = -1" ///
              2 "Estimativa média por 2SLS" ///
              4 "Estimativa média por MQO") ///
        cols(1) ///
        size(vsmall) ///
        position(3) ///
        ring(1) ///
        region(lcolor(none) fcolor(none)) ///
    ) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_q14_media, replace)

* ------------------------------------------------------------
* Painel B: viés absoluto do 2SLS
* ------------------------------------------------------------

twoway ///
    (line vies_abs_2sls pi, sort lcolor(navy) lpattern(solid) lwidth(medthick)) ///
    (scatter vies_abs_2sls pi, mcolor(navy) msymbol(circle) msize(medium)), ///
    xscale(log) ///
    xlabel(`xlabels', labsize(vsmall)) ///
    ylabel(, labsize(vsmall)) ///
    title("B. Viés absoluto do estimador 2SLS", size(small)) ///
    xtitle("Força do instrumento: coeficiente do primeiro estágio ({&pi})", size(vsmall)) ///
    ytitle("Viés absoluto", size(vsmall) margin(small)) ///
    legend(off) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_q14_vies, replace)

* ------------------------------------------------------------
* Painel C: dispersão do estimador 2SLS
* ------------------------------------------------------------

twoway ///
    (line sd_iv pi, sort lcolor(forest_green) lpattern(solid) lwidth(medthick)) ///
    (scatter sd_iv pi, mcolor(forest_green) msymbol(circle) msize(medium)), ///
    xscale(log) ///
    xlabel(`xlabels', labsize(vsmall)) ///
    ylabel(, labsize(vsmall)) ///
    title("C. Dispersão do estimador 2SLS", size(small)) ///
    xtitle("Força do instrumento: coeficiente do primeiro estágio ({&pi})", size(vsmall)) ///
    ytitle("Desvio-padrão do 2SLS", size(vsmall) margin(small)) ///
    legend(off) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_q14_dispersao, replace)

* ------------------------------------------------------------
* Painel D: cobertura dos intervalos convencionais
* ------------------------------------------------------------

twoway ///
    (function y = 95, range(0.02 1) lcolor(gs8) lpattern(dot) lwidth(medthick)) ///
    (line cobertura_pct pi, sort lcolor(maroon) lpattern(solid) lwidth(medthick)) ///
    (scatter cobertura_pct pi, mcolor(maroon) msymbol(circle) msize(medium)), ///
    xscale(log) ///
    xlabel(`xlabels', labsize(vsmall)) ///
    ylabel(90(2)100, labsize(vsmall)) ///
    title("D. Cobertura do intervalo convencional de 95%", size(small)) ///
    xtitle("Força do instrumento: coeficiente do primeiro estágio ({&pi})", size(vsmall)) ///
    ytitle("Cobertura do IC 95% (%)", size(vsmall) margin(small)) ///
    legend( ///
        order(1 "Cobertura nominal de 95%" ///
              2 "Cobertura observada na simulação") ///
        cols(1) ///
        size(vsmall) ///
        position(3) ///
        ring(1) ///
        region(lcolor(none) fcolor(none)) ///
    ) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_q14_cobertura, replace)

* ------------------------------------------------------------
* Figura combinada
* ------------------------------------------------------------

graph combine ///
    g_q14_media ///
    g_q14_vies ///
    g_q14_dispersao ///
    g_q14_cobertura, ///
    cols(2) ///
    imargin(5 10 5 10) ///
    iscale(0.82) ///
    xsize(14) ///
    ysize(8) ///
    title("Simulação de instrumentos fracos e desempenho do estimador 2SLS", size(medsmall)) ///
    subtitle("À esquerda do eixo horizontal, o instrumento é mais fraco; à direita, mais forte", size(vsmall)) ///
    note( ///
        "A força do instrumento é medida pelo coeficiente do primeiro estágio ({&pi}) na equação simulada." ///
        "O parâmetro estrutural verdadeiro é {&beta}{subscript:p} = -1." ///
        "Quando o instrumento enfraquece, o 2SLS fica mais viesado, mais disperso e a inferência convencional torna-se menos confiável.", ///
        size(vsmall) ///
    ) ///
    graphregion(color(white)) ///
    name(g_q14_simulacao_final, replace)

graph export "$FIGS/stata_fig09_q14_simulacao_instrumentos_fracos.png", ///
    replace width(4200)

graph export "$FIGS/stata_fig09_q14_simulacao_instrumentos_fracos.pdf", ///
    replace

di as text "[Stata] Figura salva em PNG: output/figures/stata_fig09_q14_simulacao_instrumentos_fracos.png"
di as text "[Stata] Figura salva em PDF: output/figures/stata_fig09_q14_simulacao_instrumentos_fracos.pdf"
