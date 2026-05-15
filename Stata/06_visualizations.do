/********************************************************************
 Gráficos auxiliares para interpretação dos resultados
********************************************************************/

use "$PROC/chicken_with_ols_residuals_stata.dta", clear

di as text _newline "[Stata] Visualizações: iniciando"
di as text "[Stata] Base usada: data/processed/chicken_with_ols_residuals_stata.dta"

* Séries temporais principais em log.
di as text "[Stata] Figura 1: séries temporais de ln_q, ln_pch, ln_y, ln_pb e z"
twoway line ln_q year || line ln_pch year || line ln_y year || line ln_pb year || line z year, ///
    legend(order(1 "ln_q" 2 "ln_pch" 3 "ln_y" 4 "ln_pb" 5 "z")) ///
    title("Séries logarítmicas principais") xtitle("Ano") ytitle("Log")
graph export "$FIGS/stata_fig01_series.png", replace width(2000)
di as text "[Stata] Gráfico salvo: output/figures/stata_fig01_series.png"

* Dispersão quantidade-preço com reta de ajuste MQO.
di as text "[Stata] Figura 2: dispersão ln_q versus ln_pch com reta de ajuste"
twoway scatter ln_q ln_pch || lfit ln_q ln_pch, ///
    title("Demanda observada: ln_q versus ln_pch") ///
    xtitle("ln preço real do frango") ytitle("ln quantidade per capita")
graph export "$FIGS/stata_fig02_scatter_demand.png", replace width(2000)
di as text "[Stata] Gráfico salvo: output/figures/stata_fig02_scatter_demand.png"

* Resíduos versus ajustados para discutir heterocedasticidade.
di as text "[Stata] Figura 3: resíduos MQO versus valores ajustados"
twoway scatter ols_resid ols_fitted, ///
    yline(0) title("Resíduos MQO versus valores ajustados") ///
    xtitle("Valor ajustado") ytitle("Resíduo")
graph export "$FIGS/stata_fig03_residuals_fitted.png", replace width(2000)
di as text "[Stata] Gráfico salvo: output/figures/stata_fig03_residuals_fitted.png"

* Coeficiente beta_p e IC 95% para Z1-Z7.
di as text "[Stata] Figura 4: beta_p e IC 95% para especificações IV Z1-Z7"
import delimited "$TABS/stata_question_09_comparative.csv", clear
encode model, gen(model_id)
twoway rcap ci_low ci_high model_id || scatter beta_p model_id, ///
    yline(0) xlabel(1 "Z1" 2 "Z2" 3 "Z3" 4 "Z4" 5 "Z5" 6 "Z6" 7 "Z7") ///
    title("Elasticidade-preço por especificação IV") ///
    xtitle("Instrumentos") ytitle("beta_p e IC 95%") legend(off)
graph export "$FIGS/stata_fig04_beta_p_by_instrument.png", replace width(2000)
di as text "[Stata] Gráfico salvo: output/figures/stata_fig04_beta_p_by_instrument.png"

* F efetivo MOP, quando capturado pelo weakivtest.
di as text "[Stata] Figura 5: F efetivo MOP por especificação"
twoway bar f_eff model_id, ///
    xlabel(1 "Z1" 2 "Z2" 3 "Z3" 4 "Z4" 5 "Z5" 6 "Z6" 7 "Z7") ///
    title("F efetivo MOP por especificação") ///
    xtitle("Instrumentos") ytitle("F efetivo")
graph export "$FIGS/stata_fig05_f_eff.png", replace width(2000)
di as text "[Stata] Gráfico salvo: output/figures/stata_fig05_f_eff.png"
di as text "[Stata] Visualizações: concluídas"
