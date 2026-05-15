/********************************************************************
 Plots comparativos avançados entre Stata, R e Python
 --------------------------------------------------------------------
 Objetivo:
   - Evitar gráficos ilegíveis com linhas sobrepostas.
   - Gerar painéis separados por software: Stata, R e Python.
   - Comparar beta_p, erro-padrão, p-valores, F usual, F efetivo MOP,
     Hansen J e intervalos Anderson-Rubin.
   - Gerar diferenças contra Stata e resumo de precisão.

 Como usar a partir da raiz do pacote:
   do Comparativo/02_plots_comparativos_software_avancado.do

 Requer apenas comandos nativos do Stata.
********************************************************************/

version 16.0
set more off

* ------------------------------------------------------------------
* 0. Caminhos padrão
* ------------------------------------------------------------------
capture confirm global TABS
if _rc global TABS "output/tables/Comparative_Code"

capture confirm global FIGS
if _rc global FIGS "output/figures/comparative_software_advanced_stata"

capture mkdir "output"
capture mkdir "output/figures"
capture mkdir "$FIGS"
capture mkdir "$TABS"

di as text _newline "[Comparativo Stata] Tabelas: $TABS"
di as text "[Comparativo Stata] Figuras: $FIGS"

* ------------------------------------------------------------------
* 1. Lê e padroniza as tabelas Q09 de Stata/R/Python
* ------------------------------------------------------------------
tempfile q09_all
local first = 1

foreach soft in Stata R Python {
    local sl = lower("`soft'")
    local f "$TABS/`sl'_question_09_comparative.csv"
    capture confirm file "`f'"
    if _rc {
        local f "tables/`sl'_question_09_comparative.csv"
        capture confirm file "`f'"
    }
    if _rc {
        di as error "[Comparativo Stata] Tabela Q09 não encontrada para `soft'. Pulando."
        continue
    }

    di as text "[Comparativo Stata] Lendo Q09 `soft': `f'"
    import delimited using "`f'", clear varnames(1) case(preserve) bindquote(strict)
    rename *, lower

    gen str10 software = "`soft'"

    * Padronização de nomes frequentes.
    capture confirm variable f_eff_mop
    if _rc {
        capture confirm variable f_eff
        if !_rc rename f_eff f_eff_mop
    }
    capture confirm variable p_f
    if _rc {
        capture confirm variable p_first
        if !_rc rename p_first p_f
    }
    capture confirm variable hansen_j
    if _rc {
        capture confirm variable j
        if !_rc rename j hansen_j
    }
    capture confirm variable hansen_p
    if _rc {
        capture confirm variable jp
        if !_rc rename jp hansen_p
    }

    * Garante colunas necessárias.
    foreach v in n k_inst beta_p se_p pval_p ci_low ci_high f_usual p_f f_eff_mop cv5 cv10 cv20 hansen_j hansen_p {
        capture confirm variable `v'
        if _rc gen double `v' = .
        capture confirm numeric variable `v'
        if _rc {
            gen double __`v' = real(subinstr(`v', ",", ".", .))
            drop `v'
            rename __`v' `v'
        }
    }

    capture confirm variable model
    if _rc {
        gen str5 model = "Z" + string(_n)
    }
    replace model = upper(strtrim(model))
    replace model = subinstr(model, "GMM_", "", .)
    replace model = subinstr(model, "2SLS_", "", .)
    gen byte model_num = real(substr(model, 2, .))
    keep if inrange(model_num, 1, 7)

    * Se IC convencional não veio, reconstrói por beta +/- 1.96*SE.
    replace ci_low  = beta_p - 1.96*se_p if missing(ci_low)  & !missing(beta_p, se_p)
    replace ci_high = beta_p + 1.96*se_p if missing(ci_high) & !missing(beta_p, se_p)

    keep software model model_num n k_inst beta_p se_p pval_p ci_low ci_high ///
         f_usual p_f f_eff_mop cv5 cv10 cv20 hansen_j hansen_p
    order software model model_num
    sort model_num software

    if `first' {
        save `q09_all', replace
        local first = 0
    }
    else {
        append using `q09_all'
        save `q09_all', replace
    }
}

use `q09_all', clear
sort model_num software
save "$TABS/comparative_software_results_advanced_stata.dta", replace
export delimited using "$TABS/comparative_software_results_advanced_stata.csv", replace

* ------------------------------------------------------------------
* 2. Lê e padroniza as tabelas AR/Q11, se existirem
* ------------------------------------------------------------------
tempfile ar_all
local first_ar = 1
local has_ar = 0

foreach soft in Stata R Python {
    local sl = lower("`soft'")
    local f "$TABS/`sl'_question_11_ar_intervals.csv"
    capture confirm file "`f'"
    if _rc {
        local f "tables/`sl'_question_11_ar_intervals.csv"
        capture confirm file "`f'"
    }
    if _rc {
        di as error "[Comparativo Stata] Tabela AR/Q11 não encontrada para `soft'. Pulando."
        continue
    }

    di as text "[Comparativo Stata] Lendo AR/Q11 `soft': `f'"
    import delimited using "`f'", clear varnames(1) case(preserve) bindquote(strict)
    rename *, lower
    gen str10 software = "`soft'"

    capture confirm variable model
    if _rc gen str5 model = "Z" + string(_n)
    replace model = upper(strtrim(model))
    replace model = subinstr(model, "GMM_", "", .)
    replace model = subinstr(model, "2SLS_", "", .)
    gen byte model_num = real(substr(model, 2, .))
    keep if inlist(model, "Z1", "Z2", "Z7")

    foreach v in n k_inst ar_low ar_high ar_low_grid ar_high_grid beta0_minp p_min p_max grid_min grid_max grid_step n_expand npoints_final {
        capture confirm variable `v'
        if _rc gen double `v' = .
        capture confirm numeric variable `v'
        if _rc {
            gen double __`v' = real(subinstr(`v', ",", ".", .))
            drop `v'
            rename __`v' `v'
        }
    }

    foreach b in open_left open_right empty_interval {
        capture confirm variable `b'
        if _rc gen byte `b' = 0
        capture confirm numeric variable `b'
        if _rc {
            gen byte __`b' = inlist(lower(strtrim(`b')), "1", "true", "t", "yes", "sim")
            drop `b'
            rename __`b' `b'
        }
    }

    replace ar_low_grid  = ar_low  if missing(ar_low_grid)
    replace ar_high_grid = ar_high if missing(ar_high_grid)

    keep software model model_num n k_inst ar_low ar_high ar_low_grid ar_high_grid ///
         beta0_minp p_min p_max grid_min grid_max grid_step n_expand npoints_final ///
         open_left open_right empty_interval
    sort model_num software

    if `first_ar' {
        save `ar_all', replace
        local first_ar = 0
        local has_ar = 1
    }
    else {
        append using `ar_all'
        save `ar_all', replace
    }
}

if `has_ar' {
    use `ar_all', clear
    sort model_num software
    save "$TABS/comparative_AR_intervals_advanced_stata.dta", replace
    export delimited using "$TABS/comparative_AR_intervals_advanced_stata.csv", replace
}

* ------------------------------------------------------------------
* 3. Programas de gráficos em painéis
* ------------------------------------------------------------------
capture program drop plot_metric_panels
program define plot_metric_panels
    * Usamos anything, e não varname, porque syntax varname valida a variável
    * no dataset que estiver na memória ANTES do programa carregar a tabela
    * comparativa. Se a memória estiver com a tabela AR/Q11, f_usual não existe
    * ali e o Stata para com: variable f_usual not found.
    syntax anything(name=metric), OUTName(string) Title(string) YTitle(string) [REFLine(real -999999)]
    local varlist = strtrim("`metric'")
    if strpos("`varlist'", " ") {
        di as error "plot_metric_panels espera apenas uma variável. Recebido: `varlist'"
        exit 198
    }

    local graphs ""
    local i = 0
    foreach soft in Stata R Python {
        local ++i
        use "$TABS/comparative_software_results_advanced_stata.dta", clear
        capture confirm variable `varlist'
        if _rc {
            di as error "[Comparativo Stata] Variável `varlist' não encontrada em comparative_software_results_advanced_stata.dta."
            di as error "[Comparativo Stata] Variáveis disponíveis:"
            describe, short
            exit 111
        }
        keep if software == "`soft'"
        sort model_num
        count if !missing(`varlist')
        local nobs = r(N)

        local refplot ""
        if `refline' > -999998 {
            local refplot "(function y = `refline', range(0.7 7.3) lpattern(dash) lwidth(medthin))"
        }

        if `nobs' > 0 {
            twoway ///
                (connected `varlist' model_num if !missing(`varlist'), msymbol(O) lwidth(medthick)) ///
                `refplot', ///
                xlabel(1 "Z1" 2 "Z2" 3 "Z3" 4 "Z4" 5 "Z5" 6 "Z6" 7 "Z7") ///
                xtitle("Conjunto de instrumentos") ///
                ytitle("`ytitle'") ///
                title("`soft'") ///
                legend(off) ///
                name(g_`varlist'_`i', replace)
        }
        else {
            clear
            set obs 7
            gen model_num = _n
            gen double empty_y = 0
            twoway (scatter empty_y model_num if 0) `refplot', ///
                xlabel(1 "Z1" 2 "Z2" 3 "Z3" 4 "Z4" 5 "Z5" 6 "Z6" 7 "Z7") ///
                xtitle("Conjunto de instrumentos") ///
                ytitle("`ytitle'") ///
                title("`soft' — sem dados") ///
                legend(off) ///
                name(g_`varlist'_`i', replace)
        }
        local graphs "`graphs' g_`varlist'_`i'"
    }

    graph combine `graphs', cols(3) ycommon imargin(small) title("`title'")
    graph export "$FIGS/`outname'.png", replace width(2400)
end

capture program drop plot_beta_ci_panels
program define plot_beta_ci_panels
    local graphs ""
    local i = 0
    foreach soft in Stata R Python {
        local ++i
        use "$TABS/comparative_software_results_advanced_stata.dta", clear
        keep if software == "`soft'"
        sort model_num
        twoway ///
            (rcap ci_high ci_low model_num if !missing(beta_p, ci_low, ci_high), lwidth(medthin)) ///
            (scatter beta_p model_num if !missing(beta_p), msymbol(O)) ///
            (function y = 0, range(0.7 7.3) lpattern(dash) lwidth(medthin)), ///
            xlabel(1 "Z1" 2 "Z2" 3 "Z3" 4 "Z4" 5 "Z5" 6 "Z6" 7 "Z7") ///
            xtitle("Conjunto de instrumentos") ///
            ytitle("beta_p") ///
            title("`soft'") ///
            legend(off) ///
            name(g_beta_ci_`i', replace)
        local graphs "`graphs' g_beta_ci_`i'"
    }
    graph combine `graphs', cols(3) ycommon imargin(small) title("Estimativa de beta_p e IC 95% — painéis por software")
    graph export "$FIGS/facet_beta_p_ci_by_software_stata.png", replace width(2400)
end

capture program drop plot_ar_panels
program define plot_ar_panels
    local graphs ""
    local i = 0
    foreach soft in Stata R Python {
        local ++i
        use "$TABS/comparative_AR_intervals_advanced_stata.dta", clear
        keep if software == "`soft'"
        sort model_num
        twoway ///
            (rcap ar_high_grid ar_low_grid model_num if !missing(ar_low_grid, ar_high_grid), lwidth(medthin)) ///
            (scatter beta0_minp model_num if !missing(beta0_minp), msymbol(O)) ///
            , ///
            xlabel(1 "Z1" 2 "Z2" 7 "Z7") ///
            xtitle("Conjunto de instrumentos") ///
            ytitle("beta_p") ///
            title("`soft'") ///
            legend(order(1 "Intervalo na grade" 2 "beta0 menos rejeitado") size(small)) ///
            name(g_ar_`i', replace)
        local graphs "`graphs' g_ar_`i'"
    }
    graph combine `graphs', cols(3) ycommon imargin(small) ///
        title("Intervalos Anderson-Rubin — painéis por software")
    graph export "$FIGS/facet_AR_intervals_by_software_stata.png", replace width(2400)
end

* ------------------------------------------------------------------
* 4. Gera gráficos principais em painéis
* ------------------------------------------------------------------
* Recarrega a tabela Q09 antes das chamadas. Sem isso, se a última base
* em memória for a tabela AR/Q11, chamadas com syntax varname poderiam
* procurar f_usual no dataset errado.
use "$TABS/comparative_software_results_advanced_stata.dta", clear

plot_metric_panels f_usual,    outname("facet_first_stage_F_usual_by_software_stata") title("F usual do primeiro estágio — painéis por software") ytitle("F usual") refline(10)
plot_metric_panels f_eff_mop,  outname("facet_F_eff_MOP_by_software_stata") title("F efetivo MOP — painéis por software") ytitle("F efetivo MOP")
plot_metric_panels se_p,       outname("facet_standard_errors_by_software_stata") title("Precisão convencional das estimativas de beta_p") ytitle("Erro-padrão robusto")
plot_metric_panels hansen_p,   outname("facet_hansen_p_by_software_stata") title("Teste J de Hansen — painéis por software") ytitle("p-valor Hansen J") refline(0.05)
plot_metric_panels pval_p,     outname("facet_pval_beta_p_by_software_stata") title("p-valor de beta_p — painéis por software") ytitle("p-valor") refline(0.05)
plot_beta_ci_panels

if `has_ar' {
    plot_ar_panels
}

* ------------------------------------------------------------------
* 5. Diferenças contra Stata e gráficos adicionais
* ------------------------------------------------------------------
use "$TABS/comparative_software_results_advanced_stata.dta", clear
preserve
    keep if software == "Stata"
    keep model model_num beta_p se_p f_usual f_eff_mop hansen_p
    rename beta_p    beta_p_stata
    rename se_p      se_p_stata
    rename f_usual   f_usual_stata
    rename f_eff_mop f_eff_mop_stata
    rename hansen_p  hansen_p_stata
    tempfile stata_base
    save `stata_base', replace
restore

keep if software != "Stata"
merge m:1 model_num using `stata_base', nogen keep(match)

foreach m in beta_p se_p f_usual f_eff_mop hansen_p {
    gen double diff_`m'    = `m' - `m'_stata
    gen double absdiff_`m' = abs(diff_`m')
    gen double sqdiff_`m'  = diff_`m'^2
}

save "$TABS/comparative_differences_vs_stata_wide_stata.dta", replace
export delimited using "$TABS/comparative_differences_vs_stata_wide_stata.csv", replace

* Resumo MAE/RMSE/MaxAbs por software e métrica.
tempfile acc
postfile acctab str10 software str20 metric double MAE RMSE MaxAbs using `acc', replace
levelsof software, local(softs)
foreach soft of local softs {
    foreach m in beta_p se_p f_usual f_eff_mop hansen_p {
        quietly summarize absdiff_`m' if software == "`soft'", meanonly
        scalar mae = r(mean)
        scalar maxabs = r(max)
        quietly summarize sqdiff_`m' if software == "`soft'", meanonly
        scalar rmse = sqrt(r(mean))
        post acctab ("`soft'") ("`m'") (mae) (rmse) (maxabs)
    }
}
postclose acctab
use `acc', clear
export delimited using "$TABS/comparative_accuracy_summary_vs_stata_stata.csv", replace

graph bar MAE, over(metric, angle(35)) over(software) ///
    title("Erro absoluto médio em relação ao Stata") ///
    ytitle("MAE") ///
    name(g_mae, replace)
graph export "$FIGS/summary_MAE_vs_Stata_by_metric_stata.png", replace width(2200)

* Scatter R/Python versus Stata para métricas principais.
capture program drop plot_scatter_vs_stata
program define plot_scatter_vs_stata
    syntax varname, STATAvar(varname) OUTName(string) Title(string)
    quietly summarize `varlist' `statavar' if !missing(`varlist', `statavar'), meanonly
    local minv = r(min)
    local maxv = r(max)
    if missing(`minv') | missing(`maxv') exit
    if `minv' == `maxv' {
        local minv = `minv' - 1
        local maxv = `maxv' + 1
    }
    twoway ///
        (scatter `varlist' `statavar' if software == "R", msymbol(O) mlabel(model) mlabpos(12)) ///
        (scatter `varlist' `statavar' if software == "Python", msymbol(T) mlabel(model) mlabpos(12)) ///
        (function y = x, range(`minv' `maxv') lpattern(dash)), ///
        legend(order(1 "R" 2 "Python" 3 "45 graus")) ///
        xtitle("Stata") ytitle("R/Python") ///
        title("`title'") ///
        name(g_scat, replace)
    graph export "$FIGS/`outname'.png", replace width(1800)
end

use "$TABS/comparative_differences_vs_stata_wide_stata.dta", clear
plot_scatter_vs_stata beta_p,    statavar(beta_p_stata)    outname("scatter_vs_Stata_beta_p_stata")    title("beta_p: R/Python versus Stata")
plot_scatter_vs_stata se_p,      statavar(se_p_stata)      outname("scatter_vs_Stata_se_p_stata")      title("se_p: R/Python versus Stata")
plot_scatter_vs_stata f_usual,   statavar(f_usual_stata)   outname("scatter_vs_Stata_F_usual_stata")   title("F usual: R/Python versus Stata")
plot_scatter_vs_stata f_eff_mop, statavar(f_eff_mop_stata) outname("scatter_vs_Stata_F_eff_MOP_stata") title("F efetivo MOP: R/Python versus Stata")
plot_scatter_vs_stata hansen_p,  statavar(hansen_p_stata)  outname("scatter_vs_Stata_hansen_p_stata")  title("Hansen p: R/Python versus Stata")

* Relatório textual simples.
file open rep using "$FIGS/relatorio_comparativo_avancado_stata.txt", write replace
file write rep "Relatório dos gráficos comparativos avançados em Stata" _n
file write rep "======================================================" _n _n
file write rep "Tabelas lidas de: $TABS" _n
file write rep "Figuras salvas em: $FIGS" _n _n
file write rep "Tabelas geradas:" _n
file write rep "- comparative_software_results_advanced_stata.csv" _n
file write rep "- comparative_AR_intervals_advanced_stata.csv, se houver tabelas AR" _n
file write rep "- comparative_differences_vs_stata_wide_stata.csv" _n
file write rep "- comparative_accuracy_summary_vs_stata_stata.csv" _n
file close rep

di as text _newline "[Comparativo Stata] Concluído. Figuras salvas em: $FIGS"
