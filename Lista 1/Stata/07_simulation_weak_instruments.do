/********************************************************************
 Questão 14: simulação de instrumentos fracos

 CORREÇÕES APLICADAS:
   - F médio do primeiro estágio calculado por nível de pi e salvo na tabela
   - Estimador MQO de referência rodado em cada replicação e salvo (b_ols)
   - Tabela final: strength pi reps mean_iv b_ols bias_iv sd_iv mean_f_fs coverage_95
   - Gráfico adicional: b_iv e b_ols por nível de pi (mostra convergência quando pi -> 0)
********************************************************************/

clear all
set seed 26052026

di as text _newline "[Stata] Questão 14: simulação de instrumentos fracos"
di as text "[Stata] Equação simulada: y = beta*x + u, com beta verdadeiro = -1"
di as text "[Stata] Primeiro estágio simulado: x = pi*z + v; pi controla a força do instrumento"
di as text "[Stata] Erros u e v são correlacionados (rho=0.6) para gerar endogeneidade"

* CORREÇÃO: tabela agora inclui b_ols (MQO médio de referência) e mean_f_fs (F médio do 1º estágio)
postfile sim ///
    str10 strength double pi int reps ///
    double mean_iv b_ols bias_iv sd_iv mean_f_fs coverage_95 ///
    using "$TABS/stata_question_14_simulation.dta", replace

local reps     = 250
local n        = 200
local true_beta = -1

di as text "[Stata] Parâmetros: reps=`reps' | n=`n' | beta verdadeiro=`true_beta'"

foreach pi in 1 0.5 0.25 0.10 0.05 0.02 {
    di as text "[Stata] Simulando pi = `pi'"

    tempfile draws
    * CORREÇÃO: postfile de replicações agora inclui beta_ols e f_fs
    postfile one ///
        double beta_iv beta_ols f_fs ci_low ci_high covered ///
        using `draws', replace

    forvalues r = 1/`reps' {
        clear
        set obs `n'

        * Instrumento exógeno.
        gen double z = rnormal()

        * Erros estrutural e de primeiro estágio correlacionados (rho = 0.6).
        gen double e1 = rnormal()
        gen double e2 = rnormal()
        gen double u  = e1
        gen double v  = 0.6*e1 + sqrt(1 - 0.6^2)*e2

        * Variável endógena.
        gen double x = `pi'*z + v

        * Equação estrutural verdadeira.
        gen double y = `true_beta'*x + u

        * CORREÇÃO: MQO de referência para comparação de viés
        quietly regress y x, vce(robust)
        scalar b_ols_rep = _b[x]

        * CORREÇÃO: F do primeiro estágio em cada replicação
        quietly regress x z, vce(robust)
        quietly test z
        scalar f_fs_rep = r(F)

        * Estimação IV com erro-padrão robusto.
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

    di as text "[Stata] pi=`pi': IV=" %9.6f mean_iv " | OLS=" %9.6f b_ols ///
               " | viés=" %9.6f bias_iv " | sd=" %9.6f sd_iv ///
               " | F_fs médio=" %9.2f mean_ffs " | cobertura=" %9.6f cov_iv

    post sim ("pi=`pi'") (`pi') (`reps') (mean_iv) (b_ols) (bias_iv) (sd_iv) (mean_ffs) (cov_iv)
}

postclose sim
use "$TABS/stata_question_14_simulation.dta", clear
export delimited using "$TABS/stata_question_14_simulation.csv", replace
di as text "[Stata] Tabela salva: output/tables/stata_question_14_simulation.csv"

* Gráfico 1: dispersão do estimador IV quando o instrumento enfraquece.
di as text "[Stata] Gerando gráfico 1: dispersão do IV por pi"
twoway line sd_iv pi, sort || scatter sd_iv pi, ///
    title("Simulação: dispersão do IV quando o instrumento enfraquece") ///
    xtitle("Força do instrumento, pi") ytitle("Desvio-padrão do estimador IV")
graph export "$FIGS/stata_fig06_simulation_sd.png", replace width(2000)
di as text "[Stata] Gráfico salvo: output/figures/stata_fig06_simulation_sd.png"

* CORREÇÃO: Gráfico 2 — b_iv e b_ols por nível de pi (convergência IV -> OLS quando pi -> 0).
di as text "[Stata] Gerando gráfico 2: b_iv e b_ols (convergência quando instrumento fraca)"
twoway ///
    (line mean_iv pi, sort lcolor(navy) lpattern(solid)) ///
    (line b_ols  pi, sort lcolor(cranberry) lpattern(dash)) ///
    (scatter mean_iv pi, mcolor(navy)) ///
    (scatter b_ols   pi, mcolor(cranberry) msymbol(triangle)), ///
    yline(`=-1', lcolor(gray) lpattern(dot)) ///
    legend(order(1 "IV médio" 2 "OLS médio" 5 "Valor verdadeiro")) ///
    title("IV converge para OLS quando instrumento enfraquece") ///
    xtitle("Força do instrumento, pi") ytitle("Estimativa média de beta")
graph export "$FIGS/stata_fig07_simulation_bias_convergence.png", replace width(2000)
di as text "[Stata] Gráfico salvo: output/figures/stata_fig07_simulation_bias_convergence.png"

* CORREÇÃO: Gráfico 3 — F médio do primeiro estágio por nível de pi.
di as text "[Stata] Gerando gráfico 3: F médio do primeiro estágio por pi"
twoway line mean_f_fs pi, sort || scatter mean_f_fs pi, ///
    yline(10, lcolor(red) lpattern(dash)) ///
    title("F médio do primeiro estágio por nível de pi") ///
    xtitle("Força do instrumento, pi") ytitle("F médio (1º estágio)") ///
    note("Linha vermelha: limiar convencional F = 10")
graph export "$FIGS/stata_fig08_simulation_ffs.png", replace width(2000)
di as text "[Stata] Gráfico salvo: output/figures/stata_fig08_simulation_ffs.png"
