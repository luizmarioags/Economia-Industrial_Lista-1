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
