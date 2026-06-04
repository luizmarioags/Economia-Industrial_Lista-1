/********************************************************************
 Questão 14: Simulação Monte Carlo de instrumentos fracos

 Objetivo:
   - Simular, por Monte Carlo, o problema de instrumentos fracos;
   - Comparar MQO e 2SLS;
   - Avaliar viés, dispersão, RMSE, cobertura, força do primeiro estágio,
     frequência de instrumento fraco e distribuição das estimativas;
   - Gerar tabelas e gráficos individuais para visualização.

 Modelo verdadeiro:
   y = beta*x + u

 Primeiro estágio:
   x = pi*z + v

 Onde:
   - z é o instrumento exógeno;
   - pi controla a força do instrumento;
   - u e v são correlacionados para gerar endogeneidade;
   - quanto menor pi, mais fraco é o instrumento.

 Parâmetro verdadeiro:
   beta = -1
********************************************************************/

clear all
set more off
set seed 26052026

* ------------------------------------------------------------
* Carrega configuração do projeto, se existir
* ------------------------------------------------------------

capture confirm file "Stata/_load_config_if_needed.do"
if _rc == 0 {
    do "Stata/_load_config_if_needed.do"
}

* ------------------------------------------------------------
* Diretórios de saída
* ------------------------------------------------------------

local tabs_global "$TABS"
if `"`tabs_global'"' == "" {
    global TABS "output/tables"
}

local figs_global "$FIGS"
if `"`figs_global'"' == "" {
    global FIGS "output/figures"
}

capture mkdir "output"
capture mkdir "$TABS"
capture mkdir "$FIGS"

di as text _newline "[Monte Carlo] Questão 14: instrumentos fracos"
di as text "[Monte Carlo] Modelo estrutural: y = beta*x + u"
di as text "[Monte Carlo] Primeiro estágio: x = pi*z + v"
di as text "[Monte Carlo] beta verdadeiro = -1"
di as text "[Monte Carlo] u e v correlacionados para gerar endogeneidade"

* ------------------------------------------------------------
* Parâmetros da simulação Monte Carlo
* ------------------------------------------------------------

local reps      = 2000
local n         = 200
local true_beta = -1
local rho       = 0.6

* Valores da força do instrumento
local pilist "1 0.5 0.25 0.10 0.05 0.02"

di as text "[Monte Carlo] Repetições por valor de pi: `reps'"
di as text "[Monte Carlo] Tamanho amostral por repetição: `n'"
di as text "[Monte Carlo] Correlação entre u e v: `rho'"

* ------------------------------------------------------------
* Arquivo com resultados de cada repetição
* ------------------------------------------------------------

tempname mc

postfile `mc' ///
    double pi ///
    int rep ///
    int n ///
    double true_beta ///
    double rho ///
    double beta_iv ///
    double se_iv ///
    double t_true_iv ///
    double ci_low ///
    double ci_high ///
    double covered ///
    double reject_5 ///
    double ci_width ///
    double beta_ols ///
    double se_ols ///
    double f_fs ///
    double p_fs ///
    double pi_hat_fs ///
    double se_pi_fs ///
    double corr_xu ///
    double corr_zx ///
    double corr_zu ///
    using "$TABS/stata_question_14_montecarlo_draws.dta", replace

* ------------------------------------------------------------
* Loop Monte Carlo
* ------------------------------------------------------------

foreach p of local pilist {

    di as text _newline "[Monte Carlo] Simulando pi = `p'"

    forvalues r = 1/`reps' {

        quietly {

            clear
            set obs `n'

            * Instrumento exógeno
            gen double z = rnormal()

            * Erros correlacionados
            gen double e1 = rnormal()
            gen double e2 = rnormal()

            gen double u = e1
            gen double v = `rho'*e1 + sqrt(1 - `rho'^2)*e2

            * Variável endógena
            gen double x = `p'*z + v

            * Equação estrutural verdadeira
            gen double y = `true_beta'*x + u

            * Correlações diagnósticas da amostra simulada
            correlate x u
            scalar corr_xu_rep = r(rho)

            correlate z x
            scalar corr_zx_rep = r(rho)

            correlate z u
            scalar corr_zu_rep = r(rho)

            * MQO
            regress y x, vce(robust)
            scalar b_ols_rep  = _b[x]
            scalar se_ols_rep = _se[x]

            * Primeiro estágio
            regress x z, vce(robust)
            scalar pi_hat_rep = _b[z]
            scalar se_pi_rep  = _se[z]

            test z
            scalar f_fs_rep = r(F)
            scalar p_fs_rep = r(p)

            * 2SLS
            capture noisily ivregress 2sls y (x = z), vce(robust)

            if _rc == 0 {

                scalar b_iv_rep  = _b[x]
                scalar se_iv_rep = _se[x]

                scalar t_true_rep = (b_iv_rep - `true_beta') / se_iv_rep

                scalar lo_rep = b_iv_rep - invnormal(0.975)*se_iv_rep
                scalar hi_rep = b_iv_rep + invnormal(0.975)*se_iv_rep

                scalar covered_rep = ///
                    (lo_rep <= `true_beta' & hi_rep >= `true_beta')

                scalar reject_rep = 1 - covered_rep

                scalar width_rep = hi_rep - lo_rep
            }

            if _rc != 0 {
                scalar b_iv_rep     = .
                scalar se_iv_rep    = .
                scalar t_true_rep   = .
                scalar lo_rep       = .
                scalar hi_rep       = .
                scalar covered_rep  = .
                scalar reject_rep   = .
                scalar width_rep    = .
            }
        }

        post `mc' ///
            (`p') ///
            (`r') ///
            (`n') ///
            (`true_beta') ///
            (`rho') ///
            (b_iv_rep) ///
            (se_iv_rep) ///
            (t_true_rep) ///
            (lo_rep) ///
            (hi_rep) ///
            (covered_rep) ///
            (reject_rep) ///
            (width_rep) ///
            (b_ols_rep) ///
            (se_ols_rep) ///
            (f_fs_rep) ///
            (p_fs_rep) ///
            (pi_hat_rep) ///
            (se_pi_rep) ///
            (corr_xu_rep) ///
            (corr_zx_rep) ///
            (corr_zu_rep)
    }
}

postclose `mc'

* ------------------------------------------------------------
* Base completa das repetições
* ------------------------------------------------------------

use "$TABS/stata_question_14_montecarlo_draws.dta", clear

gen double bias_iv       = beta_iv - true_beta
gen double abs_bias_iv   = abs(bias_iv)
gen double sq_error_iv   = (beta_iv - true_beta)^2
gen double abs_error_iv  = abs(beta_iv - true_beta)

gen double bias_ols      = beta_ols - true_beta
gen double abs_bias_ols  = abs(bias_ols)
gen double sq_error_ols  = (beta_ols - true_beta)^2

gen double weak_f10      = f_fs < 10
gen double weak_f16      = f_fs < 16.38

label variable pi           "Força do instrumento"
label variable beta_iv      "Estimativa 2SLS"
label variable beta_ols     "Estimativa MQO"
label variable f_fs         "F do primeiro estágio"
label variable pi_hat_fs    "Coeficiente estimado do primeiro estágio"
label variable covered      "IC 95% cobre beta verdadeiro"
label variable reject_5     "Rejeição incorreta a 5%"
label variable ci_width     "Amplitude do IC 95%"
label variable bias_iv      "Viés do 2SLS"
label variable abs_bias_iv  "Viés absoluto do 2SLS"
label variable abs_error_iv "Erro absoluto do 2SLS"

* Ordem e rótulos de pi para gráficos categóricos
gen int pi_ord = .
replace pi_ord = 1 if abs(pi - 0.02) < 1e-10
replace pi_ord = 2 if abs(pi - 0.05) < 1e-10
replace pi_ord = 3 if abs(pi - 0.10) < 1e-10
replace pi_ord = 4 if abs(pi - 0.25) < 1e-10
replace pi_ord = 5 if abs(pi - 0.50) < 1e-10
replace pi_ord = 6 if abs(pi - 1.00) < 1e-10

label define pi_ord_lbl ///
    1 "0,02" ///
    2 "0,05" ///
    3 "0,10" ///
    4 "0,25" ///
    5 "0,50" ///
    6 "1,00", replace

label values pi_ord pi_ord_lbl

save "$TABS/stata_question_14_montecarlo_draws.dta", replace
export delimited using "$TABS/stata_question_14_montecarlo_draws.csv", replace

di as text "[Monte Carlo] Base completa salva:"
di as text "$TABS/stata_question_14_montecarlo_draws.csv"

* ------------------------------------------------------------
* Tabela agregada por pi
* ------------------------------------------------------------

preserve

collapse ///
    (count) reps = beta_iv ///
    (mean) ///
        mean_iv        = beta_iv ///
        mean_ols       = beta_ols ///
        mean_f_fs      = f_fs ///
        mean_pihat     = pi_hat_fs ///
        coverage_95    = covered ///
        rejection_5    = reject_5 ///
        weak_f10       = weak_f10 ///
        weak_f16       = weak_f16 ///
        mean_ci_width  = ci_width ///
        mean_abs_bias  = abs_bias_iv ///
        mse_iv         = sq_error_iv ///
        mse_ols        = sq_error_ols ///
        mean_corr_xu   = corr_xu ///
        mean_corr_zx   = corr_zx ///
        mean_corr_zu   = corr_zu ///
    (sd) ///
        sd_iv          = beta_iv ///
        sd_ols         = beta_ols ///
        sd_f_fs        = f_fs ///
        sd_pihat       = pi_hat_fs ///
    (p5) ///
        p5_iv          = beta_iv ///
        p5_f           = f_fs ///
    (p25) ///
        p25_iv         = beta_iv ///
        p25_f          = f_fs ///
    (p50) ///
        median_iv       = beta_iv ///
        median_ols      = beta_ols ///
        median_f        = f_fs ///
        median_ci_width = ci_width ///
    (p75) ///
        p75_iv         = beta_iv ///
        p75_f          = f_fs ///
    (p95) ///
        p95_iv         = beta_iv ///
        p95_f          = f_fs, ///
    by(pi)

gen double bias_iv       = mean_iv - `true_beta'
gen double bias_ols      = mean_ols - `true_beta'
gen double abs_bias_mean = abs(bias_iv)

gen double rmse_iv       = sqrt(mse_iv)
gen double rmse_ols      = sqrt(mse_ols)

gen double iqr_iv        = p75_iv - p25_iv
gen double iqr_f         = p75_f - p25_f

gen double coverage_pct  = 100*coverage_95
gen double rejection_pct = 100*rejection_5
gen double weak_f10_pct  = 100*weak_f10
gen double weak_f16_pct  = 100*weak_f16

gen int pi_ord = .
replace pi_ord = 1 if abs(pi - 0.02) < 1e-10
replace pi_ord = 2 if abs(pi - 0.05) < 1e-10
replace pi_ord = 3 if abs(pi - 0.10) < 1e-10
replace pi_ord = 4 if abs(pi - 0.25) < 1e-10
replace pi_ord = 5 if abs(pi - 0.50) < 1e-10
replace pi_ord = 6 if abs(pi - 1.00) < 1e-10

label values pi_ord pi_ord_lbl

sort pi

save "$TABS/stata_question_14_montecarlo_summary.dta", replace
export delimited using "$TABS/stata_question_14_montecarlo_summary.csv", replace

di as text "[Monte Carlo] Tabela agregada salva:"
di as text "$TABS/stata_question_14_montecarlo_summary.csv"

restore

* ============================================================
* Gráficos individuais
* ============================================================

local xlabels 0.02 "0,02" 0.05 "0,05" 0.10 "0,10" 0.25 "0,25" 0.50 "0,50" 1.00 "1,00"

* ------------------------------------------------------------
* Gráficos agregados por pi
* ------------------------------------------------------------

use "$TABS/stata_question_14_montecarlo_summary.dta", clear

* ------------------------------------------------------------
* Gráfico 1: média das estimativas 2SLS e MQO
* ------------------------------------------------------------

twoway ///
    (function y = `true_beta', range(0.02 1) ///
        lcolor(gs8) lpattern(dot) lwidth(medthick)) ///
    (line mean_iv pi, sort ///
        lcolor(navy) lpattern(solid) lwidth(medthick)) ///
    (scatter mean_iv pi, ///
        mcolor(navy) msymbol(circle) msize(medium)) ///
    (line mean_ols pi, sort ///
        lcolor(cranberry) lpattern(dash) lwidth(medthick)) ///
    (scatter mean_ols pi, ///
        mcolor(cranberry) msymbol(triangle) msize(medium)), ///
    xscale(log) ///
    xlabel(`xlabels', labsize(small)) ///
    yline(0, lcolor(gs13)) ///
    title("Monte Carlo: estimativa média por força do instrumento") ///
    subtitle("Comparação entre 2SLS, MQO e o valor verdadeiro") ///
    xtitle("Força do instrumento: coeficiente do primeiro estágio ({&pi})") ///
    ytitle("Estimativa média de {&beta}") ///
    legend( ///
        order(1 "Valor verdadeiro: {&beta} = -1" ///
              2 "2SLS" ///
              4 "MQO") ///
        cols(1) ///
        position(3) ring(1) ///
        region(lcolor(none) fcolor(none)) ///
    ) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_mc_estimativas, replace)

graph export "$FIGS/mc_q14_01_estimativas_medias.png", replace width(3600)
graph export "$FIGS/mc_q14_01_estimativas_medias.pdf", replace

* ------------------------------------------------------------
* Gráfico 2: viés absoluto e RMSE do 2SLS
* ------------------------------------------------------------

twoway ///
    (line abs_bias_mean pi, sort ///
        lcolor(navy) lpattern(solid) lwidth(medthick)) ///
    (scatter abs_bias_mean pi, ///
        mcolor(navy) msymbol(circle) msize(medium)) ///
    (line rmse_iv pi, sort ///
        lcolor(maroon) lpattern(dash) lwidth(medthick)) ///
    (scatter rmse_iv pi, ///
        mcolor(maroon) msymbol(triangle) msize(medium)), ///
    xscale(log) ///
    xlabel(`xlabels', labsize(small)) ///
    title("Viés absoluto e RMSE do estimador 2SLS") ///
    subtitle("Quanto menor {&pi}, mais fraco é o instrumento") ///
    xtitle("Força do instrumento: {&pi}") ///
    ytitle("Magnitude do erro") ///
    legend( ///
        order(1 "Viés absoluto médio" 3 "RMSE") ///
        cols(1) position(3) ring(1) ///
        region(lcolor(none) fcolor(none)) ///
    ) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_mc_bias_rmse, replace)

graph export "$FIGS/mc_q14_02_bias_rmse.png", replace width(3600)
graph export "$FIGS/mc_q14_02_bias_rmse.pdf", replace

* ------------------------------------------------------------
* Gráfico 3: dispersão e intervalo interquartil do 2SLS
* ------------------------------------------------------------

twoway ///
    (line sd_iv pi, sort ///
        lcolor(forest_green) lpattern(solid) lwidth(medthick)) ///
    (scatter sd_iv pi, ///
        mcolor(forest_green) msymbol(circle) msize(medium)) ///
    (line iqr_iv pi, sort ///
        lcolor(dkorange) lpattern(dash) lwidth(medthick)) ///
    (scatter iqr_iv pi, ///
        mcolor(dkorange) msymbol(triangle) msize(medium)), ///
    xscale(log) ///
    xlabel(`xlabels', labsize(small)) ///
    title("Dispersão do estimador 2SLS") ///
    subtitle("Desvio-padrão e intervalo interquartil das estimativas") ///
    xtitle("Força do instrumento: {&pi}") ///
    ytitle("Dispersão das estimativas") ///
    legend( ///
        order(1 "Desvio-padrão" 3 "Intervalo interquartil") ///
        cols(1) position(3) ring(1) ///
        region(lcolor(none) fcolor(none)) ///
    ) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_mc_dispersao, replace)

graph export "$FIGS/mc_q14_03_dispersao_2sls.png", replace width(3600)
graph export "$FIGS/mc_q14_03_dispersao_2sls.pdf", replace

* ------------------------------------------------------------
* Gráfico 4: F médio e mediano do primeiro estágio
* ------------------------------------------------------------

twoway ///
    (function y = 10, range(0.02 1) ///
        lcolor(red) lpattern(dash) lwidth(medthick)) ///
    (line mean_f_fs pi, sort ///
        lcolor(navy) lpattern(solid) lwidth(medthick)) ///
    (scatter mean_f_fs pi, ///
        mcolor(navy) msymbol(circle) msize(medium)) ///
    (line median_f pi, sort ///
        lcolor(cranberry) lpattern(shortdash) lwidth(medthick)) ///
    (scatter median_f pi, ///
        mcolor(cranberry) msymbol(triangle) msize(medium)), ///
    xscale(log) ///
    xlabel(`xlabels', labsize(small)) ///
    title("Força do primeiro estágio") ///
    subtitle("Estatística F por nível de {&pi}") ///
    xtitle("Força do instrumento: {&pi}") ///
    ytitle("F do primeiro estágio") ///
    legend( ///
        order(1 "Regra de bolso: F = 10" ///
              2 "F médio" ///
              4 "F mediano") ///
        cols(1) position(3) ring(1) ///
        region(lcolor(none) fcolor(none)) ///
    ) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_mc_f, replace)

graph export "$FIGS/mc_q14_04_f_primeiro_estagio.png", replace width(3600)
graph export "$FIGS/mc_q14_04_f_primeiro_estagio.pdf", replace

* ------------------------------------------------------------
* Gráfico 5: cobertura do IC 95%
* ------------------------------------------------------------

twoway ///
    (function y = 95, range(0.02 1) ///
        lcolor(gs8) lpattern(dot) lwidth(medthick)) ///
    (line coverage_pct pi, sort ///
        lcolor(navy) lpattern(solid) lwidth(medthick)) ///
    (scatter coverage_pct pi, ///
        mcolor(navy) msymbol(circle) msize(medium)), ///
    xscale(log) ///
    xlabel(`xlabels', labsize(small)) ///
    ylabel(0(10)100, labsize(small)) ///
    title("Cobertura dos intervalos convencionais de 95%") ///
    subtitle("Proporção de vezes em que o IC contém o beta verdadeiro") ///
    xtitle("Força do instrumento: {&pi}") ///
    ytitle("Cobertura observada (%)") ///
    legend( ///
        order(1 "Cobertura nominal: 95%" ///
              2 "Cobertura Monte Carlo") ///
        cols(1) position(3) ring(1) ///
        region(lcolor(none) fcolor(none)) ///
    ) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_mc_cobertura, replace)

graph export "$FIGS/mc_q14_05_cobertura_ic95.png", replace width(3600)
graph export "$FIGS/mc_q14_05_cobertura_ic95.pdf", replace

* ------------------------------------------------------------
* Gráfico 6: taxa de rejeição incorreta
* ------------------------------------------------------------

twoway ///
    (function y = 5, range(0.02 1) ///
        lcolor(gs8) lpattern(dot) lwidth(medthick)) ///
    (line rejection_pct pi, sort ///
        lcolor(maroon) lpattern(solid) lwidth(medthick)) ///
    (scatter rejection_pct pi, ///
        mcolor(maroon) msymbol(circle) msize(medium)), ///
    xscale(log) ///
    xlabel(`xlabels', labsize(small)) ///
    ylabel(0(10)100, labsize(small)) ///
    title("Taxa de rejeição incorreta") ///
    subtitle("Rejeição de H0: {&beta} = -1 quando H0 é verdadeira") ///
    xtitle("Força do instrumento: {&pi}") ///
    ytitle("Rejeição incorreta (%)") ///
    legend( ///
        order(1 "Nível nominal: 5%" ///
              2 "Rejeição observada") ///
        cols(1) position(3) ring(1) ///
        region(lcolor(none) fcolor(none)) ///
    ) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_mc_rejeicao, replace)

graph export "$FIGS/mc_q14_06_rejeicao_incorreta.png", replace width(3600)
graph export "$FIGS/mc_q14_06_rejeicao_incorreta.pdf", replace

* ------------------------------------------------------------
* Gráfico 7: frequência de instrumento fraco
* ------------------------------------------------------------

twoway ///
    (line weak_f10_pct pi, sort ///
        lcolor(navy) lpattern(solid) lwidth(medthick)) ///
    (scatter weak_f10_pct pi, ///
        mcolor(navy) msymbol(circle) msize(medium)) ///
    (line weak_f16_pct pi, sort ///
        lcolor(cranberry) lpattern(dash) lwidth(medthick)) ///
    (scatter weak_f16_pct pi, ///
        mcolor(cranberry) msymbol(triangle) msize(medium)), ///
    xscale(log) ///
    xlabel(`xlabels', labsize(small)) ///
    ylabel(0(10)100, labsize(small)) ///
    title("Frequência de instrumentos fracos") ///
    subtitle("Percentual de repetições com F abaixo de limiares convencionais") ///
    xtitle("Força do instrumento: {&pi}") ///
    ytitle("Repetições classificadas como fracas (%)") ///
    legend( ///
        order(1 "F < 10" 3 "F < 16,38") ///
        cols(1) position(3) ring(1) ///
        region(lcolor(none) fcolor(none)) ///
    ) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_mc_fraco, replace)

graph export "$FIGS/mc_q14_07_frequencia_instrumento_fraco.png", replace width(3600)
graph export "$FIGS/mc_q14_07_frequencia_instrumento_fraco.pdf", replace

* ------------------------------------------------------------
* Gráfico 8: amplitude média do IC 95%
* ------------------------------------------------------------

twoway ///
    (line mean_ci_width pi, sort ///
        lcolor(navy) lpattern(solid) lwidth(medthick)) ///
    (scatter mean_ci_width pi, ///
        mcolor(navy) msymbol(circle) msize(medium)) ///
    (line median_ci_width pi, sort ///
        lcolor(cranberry) lpattern(dash) lwidth(medthick)) ///
    (scatter median_ci_width pi, ///
        mcolor(cranberry) msymbol(triangle) msize(medium)), ///
    xscale(log) ///
    xlabel(`xlabels', labsize(small)) ///
    title("Amplitude dos intervalos de confiança do 2SLS") ///
    subtitle("Instrumentos fracos geram intervalos mais instáveis") ///
    xtitle("Força do instrumento: {&pi}") ///
    ytitle("Amplitude do IC 95%") ///
    legend( ///
        order(1 "Amplitude média" 3 "Amplitude mediana") ///
        cols(1) position(3) ring(1) ///
        region(lcolor(none) fcolor(none)) ///
    ) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_mc_ic_width, replace)

graph export "$FIGS/mc_q14_08_amplitude_ic.png", replace width(3600)
graph export "$FIGS/mc_q14_08_amplitude_ic.pdf", replace

* ------------------------------------------------------------
* Gráfico 9: coeficiente estimado do primeiro estágio
* ------------------------------------------------------------

twoway ///
    (function y = x, range(0.02 1) ///
        lcolor(gs8) lpattern(dot) lwidth(medthick)) ///
    (line mean_pihat pi, sort ///
        lcolor(navy) lpattern(solid) lwidth(medthick)) ///
    (scatter mean_pihat pi, ///
        mcolor(navy) msymbol(circle) msize(medium)), ///
    xscale(log) ///
    xlabel(`xlabels', labsize(small)) ///
    title("Coeficiente estimado do primeiro estágio") ///
    subtitle("Comparação entre {&pi} verdadeiro e coeficiente médio estimado") ///
    xtitle("{&pi} verdadeiro") ///
    ytitle("{&pi} estimado no primeiro estágio") ///
    legend( ///
        order(1 "Linha de 45 graus" ///
              2 "Média estimada") ///
        cols(1) position(3) ring(1) ///
        region(lcolor(none) fcolor(none)) ///
    ) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_mc_pi_hat, replace)

graph export "$FIGS/mc_q14_09_coeficiente_primeiro_estagio.png", replace width(3600)
graph export "$FIGS/mc_q14_09_coeficiente_primeiro_estagio.pdf", replace

* ------------------------------------------------------------
* Gráfico 10: faixa de quantis do 2SLS
* ------------------------------------------------------------

twoway ///
    (rarea p5_iv p95_iv pi, sort ///
        color(gs14)) ///
    (rarea p25_iv p75_iv pi, sort ///
        color(gs10)) ///
    (function y = `true_beta', range(0.02 1) ///
        lcolor(red) lpattern(dot) lwidth(medthick)) ///
    (line mean_iv pi, sort ///
        lcolor(navy) lpattern(solid) lwidth(medthick)) ///
    (scatter mean_iv pi, ///
        mcolor(navy) msymbol(circle) msize(medium)), ///
    xscale(log) ///
    xlabel(`xlabels', labsize(small)) ///
    title("Distribuição das estimativas 2SLS por força do instrumento") ///
    subtitle("Faixas p5-p95 e p25-p75 das estimativas Monte Carlo") ///
    xtitle("Força do instrumento: {&pi}") ///
    ytitle("Estimativa 2SLS") ///
    legend( ///
        order(1 "p5-p95" ///
              2 "p25-p75" ///
              3 "Valor verdadeiro" ///
              4 "Média 2SLS") ///
        cols(1) position(3) ring(1) ///
        region(lcolor(none) fcolor(none)) ///
    ) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_mc_quantis, replace)

graph export "$FIGS/mc_q14_10_quantis_2sls.png", replace width(3600)
graph export "$FIGS/mc_q14_10_quantis_2sls.pdf", replace

* ------------------------------------------------------------
* Gráficos com distribuição das repetições individuais
* ------------------------------------------------------------

use "$TABS/stata_question_14_montecarlo_draws.dta", clear

* Janelas de visualização para evitar que outliers extremos destruam a escala
quietly summarize beta_iv if beta_iv < ., detail
local xmin = max(r(p1), -20)
local xmax = min(r(p99), 20)

quietly summarize f_fs if f_fs < ., detail
local fmax = min(r(p99), 200)

quietly summarize t_true_iv if t_true_iv < ., detail
local txmin = max(r(p1), -8)
local txmax = min(r(p99), 8)

* ------------------------------------------------------------
* Gráfico 11: densidades das estimativas 2SLS
* ------------------------------------------------------------

twoway ///
    (kdensity beta_iv if abs(pi - 1.00) < 1e-10 & inrange(beta_iv, `xmin', `xmax'), ///
        lcolor(navy) lwidth(medthick)) ///
    (kdensity beta_iv if abs(pi - 0.50) < 1e-10 & inrange(beta_iv, `xmin', `xmax'), ///
        lcolor(blue) lpattern(shortdash) lwidth(medthick)) ///
    (kdensity beta_iv if abs(pi - 0.25) < 1e-10 & inrange(beta_iv, `xmin', `xmax'), ///
        lcolor(forest_green) lpattern(dash) lwidth(medthick)) ///
    (kdensity beta_iv if abs(pi - 0.10) < 1e-10 & inrange(beta_iv, `xmin', `xmax'), ///
        lcolor(dkorange) lpattern(longdash) lwidth(medthick)) ///
    (kdensity beta_iv if abs(pi - 0.05) < 1e-10 & inrange(beta_iv, `xmin', `xmax'), ///
        lcolor(maroon) lpattern(dash_dot) lwidth(medthick)) ///
    (kdensity beta_iv if abs(pi - 0.02) < 1e-10 & inrange(beta_iv, `xmin', `xmax'), ///
        lcolor(cranberry) lpattern(dot) lwidth(medthick)), ///
    xline(`true_beta', lcolor(gs8) lpattern(dot) lwidth(medthick)) ///
    title("Densidade das estimativas 2SLS") ///
    subtitle("Distribuição Monte Carlo por força do instrumento") ///
    xtitle("Estimativa 2SLS") ///
    ytitle("Densidade") ///
    legend( ///
        order(1 "{&pi}=1,00" ///
              2 "{&pi}=0,50" ///
              3 "{&pi}=0,25" ///
              4 "{&pi}=0,10" ///
              5 "{&pi}=0,05" ///
              6 "{&pi}=0,02") ///
        cols(1) position(3) ring(1) ///
        region(lcolor(none) fcolor(none)) ///
    ) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_mc_density_beta, replace)

graph export "$FIGS/mc_q14_11_densidade_2sls.png", replace width(3600)
graph export "$FIGS/mc_q14_11_densidade_2sls.pdf", replace

* ------------------------------------------------------------
* Gráfico 12: histogramas das estimativas 2SLS por pi
* ------------------------------------------------------------

histogram beta_iv if inrange(beta_iv, `xmin', `xmax'), ///
    by(pi_ord, ///
        cols(3) ///
        title("Histogramas das estimativas 2SLS por força do instrumento") ///
        note("A linha vertical indica o beta verdadeiro. A escala foi limitada entre p1 e p99 para visualização.")) ///
    percent ///
    normal ///
    xline(`true_beta', lcolor(red) lpattern(dot) lwidth(medthick)) ///
    xtitle("Estimativa 2SLS") ///
    ytitle("Percentual") ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_mc_hist_beta, replace)

graph export "$FIGS/mc_q14_12_histogramas_2sls.png", replace width(3600)
graph export "$FIGS/mc_q14_12_histogramas_2sls.pdf", replace

* ------------------------------------------------------------
* Gráfico 13: boxplot das estimativas 2SLS por pi
* ------------------------------------------------------------

graph box beta_iv if inrange(beta_iv, `xmin', `xmax'), ///
    over(pi_ord) ///
    yline(`true_beta', lcolor(red) lpattern(dot) lwidth(medthick)) ///
    title("Boxplot das estimativas 2SLS por força do instrumento") ///
    subtitle("Escala limitada entre p1 e p99 para visualização") ///
    ytitle("Estimativa 2SLS") ///
    graphregion(color(white)) ///
    name(g_mc_box_beta, replace)

graph export "$FIGS/mc_q14_13_boxplot_2sls.png", replace width(3600)
graph export "$FIGS/mc_q14_13_boxplot_2sls.pdf", replace

* ------------------------------------------------------------
* Gráfico 14: densidade do F do primeiro estágio
* ------------------------------------------------------------

twoway ///
    (kdensity f_fs if abs(pi - 1.00) < 1e-10 & f_fs <= `fmax', ///
        lcolor(navy) lwidth(medthick)) ///
    (kdensity f_fs if abs(pi - 0.50) < 1e-10 & f_fs <= `fmax', ///
        lcolor(blue) lpattern(shortdash) lwidth(medthick)) ///
    (kdensity f_fs if abs(pi - 0.25) < 1e-10 & f_fs <= `fmax', ///
        lcolor(forest_green) lpattern(dash) lwidth(medthick)) ///
    (kdensity f_fs if abs(pi - 0.10) < 1e-10 & f_fs <= `fmax', ///
        lcolor(dkorange) lpattern(longdash) lwidth(medthick)) ///
    (kdensity f_fs if abs(pi - 0.05) < 1e-10 & f_fs <= `fmax', ///
        lcolor(maroon) lpattern(dash_dot) lwidth(medthick)) ///
    (kdensity f_fs if abs(pi - 0.02) < 1e-10 & f_fs <= `fmax', ///
        lcolor(cranberry) lpattern(dot) lwidth(medthick)), ///
    xline(10, lcolor(red) lpattern(dash) lwidth(medthick)) ///
    title("Densidade do F do primeiro estágio") ///
    subtitle("Linha vertical: F = 10") ///
    xtitle("F do primeiro estágio") ///
    ytitle("Densidade") ///
    legend( ///
        order(1 "{&pi}=1,00" ///
              2 "{&pi}=0,50" ///
              3 "{&pi}=0,25" ///
              4 "{&pi}=0,10" ///
              5 "{&pi}=0,05" ///
              6 "{&pi}=0,02") ///
        cols(1) position(3) ring(1) ///
        region(lcolor(none) fcolor(none)) ///
    ) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_mc_density_f, replace)

graph export "$FIGS/mc_q14_14_densidade_f_primeiro_estagio.png", replace width(3600)
graph export "$FIGS/mc_q14_14_densidade_f_primeiro_estagio.pdf", replace

* ------------------------------------------------------------
* Gráfico 15: boxplot do F do primeiro estágio
* ------------------------------------------------------------

graph box f_fs if f_fs <= `fmax', ///
    over(pi_ord) ///
    yline(10, lcolor(red) lpattern(dash) lwidth(medthick)) ///
    title("Boxplot do F do primeiro estágio") ///
    subtitle("Escala limitada até p99 para visualização") ///
    ytitle("F do primeiro estágio") ///
    graphregion(color(white)) ///
    name(g_mc_box_f, replace)

graph export "$FIGS/mc_q14_15_boxplot_f_primeiro_estagio.png", replace width(3600)
graph export "$FIGS/mc_q14_15_boxplot_f_primeiro_estagio.pdf", replace

* ------------------------------------------------------------
* Gráfico 16: relação entre F e estimativa 2SLS
* ------------------------------------------------------------

twoway ///
    (scatter beta_iv f_fs ///
        if f_fs > 0 & f_fs <= `fmax' & inrange(beta_iv, `xmin', `xmax'), ///
        msize(tiny) mcolor(navy)) ///
    (lfit beta_iv f_fs ///
        if f_fs > 0 & f_fs <= `fmax' & inrange(beta_iv, `xmin', `xmax'), ///
        lcolor(maroon) lwidth(medthick)), ///
    xscale(log) ///
    xline(10, lcolor(red) lpattern(dash) lwidth(medthick)) ///
    yline(`true_beta', lcolor(gs8) lpattern(dot) lwidth(medthick)) ///
    title("Relação entre F do primeiro estágio e estimativa 2SLS") ///
    subtitle("Pontos são repetições individuais do Monte Carlo") ///
    xtitle("F do primeiro estágio, escala log") ///
    ytitle("Estimativa 2SLS") ///
    legend( ///
        order(1 "Repetições" 2 "Ajuste linear") ///
        cols(1) position(3) ring(1) ///
        region(lcolor(none) fcolor(none)) ///
    ) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_mc_scatter_f_beta, replace)

graph export "$FIGS/mc_q14_16_scatter_f_vs_2sls.png", replace width(3600)
graph export "$FIGS/mc_q14_16_scatter_f_vs_2sls.pdf", replace

* ------------------------------------------------------------
* Gráfico 17: relação entre F e erro absoluto do 2SLS
* ------------------------------------------------------------

twoway ///
    (scatter abs_error_iv f_fs ///
        if f_fs > 0 & f_fs <= `fmax' & abs_error_iv < ., ///
        msize(tiny) mcolor(navy)) ///
    (lfit abs_error_iv f_fs ///
        if f_fs > 0 & f_fs <= `fmax' & abs_error_iv < ., ///
        lcolor(maroon) lwidth(medthick)), ///
    xscale(log) ///
    xline(10, lcolor(red) lpattern(dash) lwidth(medthick)) ///
    title("Relação entre F do primeiro estágio e erro absoluto do 2SLS") ///
    subtitle("Instrumentos fracos tendem a gerar maior instabilidade") ///
    xtitle("F do primeiro estágio, escala log") ///
    ytitle("|Estimativa 2SLS - beta verdadeiro|") ///
    legend( ///
        order(1 "Repetições" 2 "Ajuste linear") ///
        cols(1) position(3) ring(1) ///
        region(lcolor(none) fcolor(none)) ///
    ) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_mc_scatter_f_error, replace)

graph export "$FIGS/mc_q14_17_scatter_f_vs_erro_abs.png", replace width(3600)
graph export "$FIGS/mc_q14_17_scatter_f_vs_erro_abs.pdf", replace

* ------------------------------------------------------------
* Gráfico 18: estatística t contra o valor verdadeiro
* ------------------------------------------------------------

histogram t_true_iv if inrange(t_true_iv, `txmin', `txmax'), ///
    by(pi_ord, ///
        cols(3) ///
        title("Distribuição da estatística t do 2SLS") ///
        note("t = (beta_hat - beta verdadeiro) / erro-padrão robusto")) ///
    percent ///
    normal ///
    xline(-1.96 1.96, lcolor(red) lpattern(dash) lwidth(medthick)) ///
    xtitle("Estatística t") ///
    ytitle("Percentual") ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_mc_hist_t, replace)

graph export "$FIGS/mc_q14_18_histograma_t_2sls.png", replace width(3600)
graph export "$FIGS/mc_q14_18_histograma_t_2sls.pdf", replace

* ------------------------------------------------------------
* Encerramento
* ------------------------------------------------------------

di as text _newline "[Monte Carlo] Simulação concluída."
di as text "[Monte Carlo] Tabelas salvas em:"
di as text "  $TABS/stata_question_14_montecarlo_draws.csv"
di as text "  $TABS/stata_question_14_montecarlo_summary.csv"
di as text "[Monte Carlo] Gráficos individuais salvos em:"
di as text "  $FIGS"