/********************************************************************
 Questões 6, 8, 9 e 10:
 - especificações alternativas de instrumentos (Z1-Z7);
 - primeiro estágio;
 - 2SLS;
 - weakivtest de Montiel Olea-Pflueger;
 - Hansen J nos modelos sobreidentificados.

 CORREÇÕES APLICADAS NESTA VERSÃO:
   - pval_p (p-valor de beta_p) adicionado à tabela comparativa.
   - p_F (p-valor do F usual) transferido diretamente à tabela comparativa.
   - F_eff do weakivtest capturado de r(F_eff).
   - Valores críticos MOP agora capturados corretamente de:
       r(c_TSLS_5), r(c_TSLS_10), r(c_TSLS_20)
     Em versões anteriores o código tentava r(cv5), r(cv10), r(cv20),
     que não são nomes retornados por weakivtest; por isso cv5/cv10/cv20
     estavam saindo missing mesmo com weakivtest funcionando.
   - Para Z1, exatamente identificado, Hansen J e p(J) são salvos como missing,
     pois não há graus de liberdade de sobreidentificação.
   - N do primeiro estágio e N do IV são guardados em escalares antes de
     rotinas auxiliares, evitando depender de e(N) após regressões intermediárias.
   - Tabela 09 contém:
     model N k_inst beta_p se_p pval_p ci_low ci_high
     F_usual p_F F_eff cv5 cv10 cv20 hansen_J hansen_p
********************************************************************/


* Carrega configuração se o script for rodado individualmente.
do "Stata/_load_config_if_needed.do"

use "$PROC/chicken_prepared_stata.dta", clear

di as text _newline "[Stata] Questões 6, 8, 9 e 10: Z1-Z7, primeiro estágio, 2SLS, weakivtest e Hansen J"
di as text "[Stata] Equação estrutural em todos os modelos: ln_q ~ ln_pch + ln_y + ln_pb"
di as text "[Stata] Variável endógena em todos os modelos: ln_pch"
di as text "[Stata] Controles/instrumentos incluídos: ln_y ln_pb"

local Z1 "z"
local Z2 "z z_sq"
local Z3 "z z_sq z_cu"
local Z4 "z_lag"
local Z5 "z_lag z_lag_sq"
local Z6 "z z_lag"
local Z7 "z z_sq z_lag z_lag_sq"

di as text "[Stata] Z1 = {z}"
di as text "[Stata] Z2 = {z, z_sq}"
di as text "[Stata] Z3 = {z, z_sq, z_cu}"
di as text "[Stata] Z4 = {z_lag}"
di as text "[Stata] Z5 = {z_lag, z_lag_sq}"
di as text "[Stata] Z6 = {z, z_lag}"
di as text "[Stata] Z7 = {z, z_sq, z_lag, z_lag_sq}"

* Tabela de primeiros estágios (Q8).
postfile fst_all ///
    str5 model int N k_inst ///
    double partial_R2 F_usual p_F ///
    using "$TABS/stata_question_08_first_stage_all.dta", replace

* Tabela comparativa principal (Q9).
postfile comp ///
    str5 model int N k_inst ///
    double beta_p se_p pval_p ci_low ci_high ///
    double F_usual p_F F_eff cv5 cv10 cv20 ///
    double hansen_J hansen_p ///
    using "$TABS/stata_question_09_comparative.dta", replace

forvalues m = 1/7 {
    local inst  "`Z`m''"
    local model "Z`m'"
    local k_inst : word count `inst'

    di as text _newline "[Stata] Estimando `model'"
    di as text "[Stata] Instrumentos excluídos em `model': `inst'"
    di as text "[Stata] Primeiro estágio `model': ln_pch ~ `inst' + ln_y + ln_pb"

    /**************************************************************
     Primeiro estágio do modelo Zm
    **************************************************************/
    reg ln_pch `inst' ln_y ln_pb, vce(robust)
    scalar N_fs = e(N)

    test `inst'
    scalar F_usual = r(F)
    scalar p_F     = r(p)
    di as text "[Stata] `model' primeiro estágio: F usual=" %9.6f F_usual " | p=" %9.6f p_F

    * R2 parcial: residualiza ln_pch e cada instrumento nos controles.
    di as text "[Stata] `model': calculando R2 parcial dos instrumentos excluídos condicional a ln_y e ln_pb"
    preserve
        keep if e(sample)
        reg ln_pch ln_y ln_pb
        predict double r_x, resid
        local rinst ""
        foreach v of local inst {
            reg `v' ln_y ln_pb
            predict double r_`v', resid
            local rinst "`rinst' r_`v'"
        }
        reg r_x `rinst', noconstant
        scalar partial_R2 = e(r2)
    restore
    di as text "[Stata] `model': R2 parcial = " %9.6f partial_R2

    post fst_all ("`model'") (N_fs) (`k_inst') (partial_R2) (F_usual) (p_F)

    /**************************************************************
     2SLS estrutural com erro-padrão robusto
    **************************************************************/
    di as text "[Stata] `model' 2SLS: ln_q ~ ln_pch + ln_y + ln_pb; ln_pch instrumentado por `inst'"
    ivreg2 ln_q ln_y ln_pb (ln_pch = `inst'), robust first

    scalar N_iv = e(N)
    scalar b    = _b[ln_pch]
    scalar se   = _se[ln_pch]
    scalar cv   = invnormal(0.975)

    * p-valor de beta_p via normal assintótica.
    scalar pval_p = 2 * (1 - normal(abs(b / se)))
    di as text "[Stata] `model' 2SLS: beta_p=" %9.6f b " | EP=" %9.6f se " | p=" %9.6f pval_p

    * Hansen J: somente em modelos sobreidentificados.
    if (`k_inst' <= 1) {
        scalar J  = .
        scalar Jp = .
        di as text "[Stata] `model': Hansen J não se aplica; modelo exatamente identificado."
    }
    else {
        cap scalar J  = e(j)
        if _rc scalar J = .
        cap scalar Jp = e(jp)
        if _rc scalar Jp = .
        di as text "[Stata] `model': Hansen J=" %9.6f J " | p=" %9.6f Jp
    }

    /**************************************************************
     weakivtest — F efetivo MOP e valores críticos
    **************************************************************/
    di as text "[Stata] `model': rodando weakivtest (Montiel Olea-Pflueger)"
    cap noisily weakivtest

    if _rc {
        scalar Feff = .
        scalar cv5  = .
        scalar cv10 = .
        scalar cv20 = .
        di as text "[Stata] `model': weakivtest não disponível — F_eff e valores críticos definidos como ."
    }
    else {
        * Estatística F efetiva.
        cap scalar Feff = r(F_eff)
        if _rc scalar Feff = .

        * Valores críticos TSLS do weakivtest para tau = 5%, 10% e 20%.
        * O weakivtest retorna estes nomes, como mostrado por return list:
        *   r(c_TSLS_5), r(c_TSLS_10), r(c_TSLS_20)
        cap scalar cv5 = r(c_TSLS_5)
        if _rc scalar cv5 = .
        cap scalar cv10 = r(c_TSLS_10)
        if _rc scalar cv10 = .
        cap scalar cv20 = r(c_TSLS_20)
        if _rc scalar cv20 = .
    }

    di as text "[Stata] `model': F efetivo MOP=" %9.6f Feff ///
        " | cv5_TSLS=" %9.6f cv5 ///
        " | cv10_TSLS=" %9.6f cv10 ///
        " | cv20_TSLS=" %9.6f cv20

    * Log textual do weakivtest para cada modelo.
    cap log close weaklog
    log using "$TABS/stata_question_06_weakivtest_`model'.txt", replace text name(weaklog)
        di "Modelo `model': instrumentos excluídos = `inst'"
        cap noisily weakivtest
        return list
    log close weaklog
    di as text "[Stata] `model': log do weakivtest salvo em output/tables/stata_question_06_weakivtest_`model'.txt"

    post comp ("`model'") (N_iv) (`k_inst') ///
              (b) (se) (pval_p) (b - cv*se) (b + cv*se) ///
              (F_usual) (p_F) (Feff) (cv5) (cv10) (cv20) ///
              (J) (Jp)
}

postclose fst_all
postclose comp

use "$TABS/stata_question_08_first_stage_all.dta", clear
export delimited using "$TABS/stata_question_08_first_stage_all.csv", replace
di as text "[Stata] Tabela salva: output/tables/stata_question_08_first_stage_all.csv"

use "$TABS/stata_question_09_comparative.dta", clear
export delimited using "$TABS/stata_question_09_comparative.csv", replace
di as text "[Stata] Tabela salva: output/tables/stata_question_09_comparative.csv"


/********************************************************************
 Questão 10: Teste J de Hansen para modelos sobreidentificados

 Gera:
   - Tabela CSV com estatística J, graus de liberdade e valor-p
   - Tabela LaTeX pronta para Overleaf
   - Gráfico dos valores-p do teste J de Hansen
********************************************************************/

di as text _newline "[Stata] Questão 10: gerando tabela e gráfico do teste J de Hansen"

* ------------------------------------------------------------
* Carrega config se necessário
* ------------------------------------------------------------

local procdir "$PROC"

if `"`procdir'"' == "" {
    di as text "[Stata] Globais ainda não carregados. Tentando rodar Stata/config.do..."

    capture noisily do "Stata/config.do"

    if _rc {
        di as error "[Stata] Não consegui carregar Stata/config.do."
        di as error "[Stata] Rode o projeto a partir da pasta raiz ou ajuste o caminho do config.do."
        exit 601
    }
}

capture mkdir "$TABS"
capture mkdir "$FIGS"

* ------------------------------------------------------------
* Garante que a tabela comparativa exista
* ------------------------------------------------------------

capture confirm file "$TABS/stata_question_09_comparative.csv"

if _rc {
    di as text "[Stata] Tabela comparativa não encontrada. Rodando 04_alt_instruments_weakiv.do..."
    do "Stata/04_alt_instruments_weakiv.do"
}

* ------------------------------------------------------------
* Importa resultados da questão 9
* ------------------------------------------------------------

import delimited "$TABS/stata_question_09_comparative.csv", clear

* ------------------------------------------------------------
* Limpa variáveis auxiliares caso já existam no CSV
* ------------------------------------------------------------

capture drop modelo
capture drop k_instr
capture drop hansen_df
capture drop hansen_p
capture drop decisao_5
capture drop instrumentos
capture drop ordem

* ------------------------------------------------------------
* Garante tipos numéricos
* ------------------------------------------------------------

foreach v in hansen_j {
    capture confirm numeric variable `v'
    if _rc {
        destring `v', replace force
    }
}

* ------------------------------------------------------------
* Padroniza nome do modelo
* ------------------------------------------------------------

capture confirm variable model
if _rc {
    di as error "[Stata] A variável 'model' não foi encontrada em stata_question_09_comparative.csv."
    exit 111
}

gen str10 modelo = upper(model)

* ------------------------------------------------------------
* Mantém apenas modelos sobreidentificados
* Z1 e Z4 são exatamente identificados: não têm Hansen J
* ------------------------------------------------------------

keep if inlist(modelo, "Z2", "Z3", "Z5", "Z6", "Z7")

* ------------------------------------------------------------
* Número de instrumentos excluídos por especificação
* Como há uma variável endógena, gl = k_instr - 1
* ------------------------------------------------------------

gen k_instr = .
replace k_instr = 2 if modelo == "Z2"
replace k_instr = 3 if modelo == "Z3"
replace k_instr = 2 if modelo == "Z5"
replace k_instr = 2 if modelo == "Z6"
replace k_instr = 4 if modelo == "Z7"

gen hansen_df = k_instr - 1

* ------------------------------------------------------------
* Valor-p do teste J de Hansen
* Sob H0, J ~ qui-quadrado(gl)
* ------------------------------------------------------------

gen double hansen_p = chi2tail(hansen_df, hansen_j)

gen str20 decisao_5 = ""
replace decisao_5 = "Rejeita H0" if hansen_p < 0.05
replace decisao_5 = "Não rejeita H0" if hansen_p >= 0.05

* ------------------------------------------------------------
* Rótulos dos instrumentos
* ------------------------------------------------------------

gen str100 instrumentos = ""
replace instrumentos = "{z_t, z_t^2}" if modelo == "Z2"
replace instrumentos = "{z_t, z_t^2, z_t^3}" if modelo == "Z3"
replace instrumentos = "{z_{t-1}, z_{t-1}^2}" if modelo == "Z5"
replace instrumentos = "{z_t, z_{t-1}}" if modelo == "Z6"
replace instrumentos = "{z_t, z_t^2, z_{t-1}, z_{t-1}^2}" if modelo == "Z7"

* ------------------------------------------------------------
* Organiza e salva tabela em CSV
* ------------------------------------------------------------

keep modelo instrumentos hansen_j hansen_df hansen_p decisao_5
sort modelo

format hansen_j %9.3f
format hansen_p %9.4f

export delimited using "$TABS/stata_question_10_hansen_overid.csv", replace

di as text "[Stata] Tabela CSV salva em:"
di as text "$TABS/stata_question_10_hansen_overid.csv"

* ------------------------------------------------------------
* Gera tabela LaTeX
* ------------------------------------------------------------

tempname fh
file open `fh' using "$TABS/stata_question_10_hansen_overid.tex", write replace text

file write `fh' "\begin{table}[H]" _n
file write `fh' "    \centering" _n
file write `fh' "    \small" _n
file write `fh' "    \caption{Teste \$J\$ de Hansen para modelos sobreidentificados}" _n
file write `fh' "    \label{tab:hansen_sobreidentificados}" _n
file write `fh' "    \setlength{\tabcolsep}{5pt}" _n
file write `fh' "    \begin{tabular}{lcccc}" _n
file write `fh' "        \hline" _n
file write `fh' "        Modelo & Instrumentos excluídos & Hansen \$J\$ & gl & Valor-\$p\$ \\" _n
file write `fh' "        \hline" _n

forvalues i = 1/`=_N' {
    local m   = modelo[`i']
    local ins = instrumentos[`i']
    local j   : display %9.3f hansen_j[`i']
    local gl  : display %2.0f hansen_df[`i']
    local pv  : display %9.4f hansen_p[`i']

    local j  = strtrim("`j'")
    local gl = strtrim("`gl'")
    local pv = strtrim("`pv'")

    * troca ponto por vírgula para padrão brasileiro
    local j  = subinstr("`j'", ".", ",", .)
    local pv = subinstr("`pv'", ".", ",", .)

    file write `fh' "        \$`m'\$ & \$`ins'\$ & `j' & `gl' & `pv' \\" _n
}

file write `fh' "        \hline" _n
file write `fh' "    \end{tabular}" _n
file write `fh' "" _n
file write `fh' "    \vspace{0.3em}" _n
file write `fh' "    \begin{minipage}{0.92\textwidth}" _n
file write `fh' "    \footnotesize" _n
file write `fh' "    Nota: \$gl\$ indica os graus de liberdade do teste, dados pelo número de instrumentos excluídos menos o número de variáveis endógenas. Os modelos \$Z_1\$ e \$Z_4\$ são exatamente identificados e, por isso, não possuem restrições sobreidentificadoras a serem testadas." _n
file write `fh' "    \end{minipage}" _n
file write `fh' "\end{table}" _n

file close `fh'

di as text "[Stata] Tabela LaTeX salva em:"
di as text "$TABS/stata_question_10_hansen_overid.tex"

* ------------------------------------------------------------
* Gráfico dos valores-p do teste J de Hansen
* ------------------------------------------------------------

gen ordem = .
replace ordem = 1 if modelo == "Z2"
replace ordem = 2 if modelo == "Z3"
replace ordem = 3 if modelo == "Z5"
replace ordem = 4 if modelo == "Z6"
replace ordem = 5 if modelo == "Z7"

twoway ///
    (bar hansen_p ordem, ///
        barwidth(0.55) ///
        fcolor(navy%65) ///
        lcolor(navy)) ///
    (function y = 0.05, ///
        range(0.5 5.5) ///
        lcolor(cranberry) ///
        lpattern(dash) ///
        lwidth(medthick)), ///
    xlabel(1 "Z2" 2 "Z3" 3 "Z5" 4 "Z6" 5 "Z7", labsize(small)) ///
    ylabel(0(0.05)0.20, labsize(small)) ///
    title("Teste J de Hansen: valor-p por especificação", size(medsmall)) ///
    subtitle("Modelos sobreidentificados", size(small)) ///
    xtitle("Conjunto de instrumentos", size(small)) ///
    ytitle("Valor-p do teste J de Hansen", size(small)) ///
    legend( ///
        order(1 "Valor-p observado" ///
              2 "Nível de significância de 5%") ///
        cols(1) ///
        size(small) ///
        position(3) ///
        ring(1) ///
        region(lcolor(none) fcolor(none)) ///
    ) ///
    note("Valores abaixo de 0,05 indicam rejeição da validade conjunta das restrições sobreidentificadoras.", ///
        size(vsmall)) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_hansen_pvalues, replace)

graph export "$FIGS/stata_fig12_hansen_pvalues.png", replace width(3000)
graph export "$FIGS/stata_fig12_hansen_pvalues.pdf", replace

di as text "[Stata] Gráfico salvo em PNG:"
di as text "$FIGS/stata_fig12_hansen_pvalues.png"

di as text "[Stata] Gráfico salvo em PDF:"
di as text "$FIGS/stata_fig12_hansen_pvalues.pdf"