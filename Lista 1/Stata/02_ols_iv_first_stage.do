/********************************************************************
 Questões 1, 3 e 4: MQO, 2SLS com Z1 e primeiro estágio
 CORREÇÕES APLICADAS:
   - Q1 : p-valor individual de beta_p, beta_y e beta_b adicionados
   - Q1 : coeficientes beta_y e beta_b agora armazenados na tabela
   - Q3 : p-valor individual de beta_p adicionado
   - Q4 : p-valor individual de pi_z adicionado
   - Q4 : verificação numérica de equivalência 2SLS == GMM exato
********************************************************************/


* Carrega configuração se o script for rodado individualmente.
do "Stata/_load_config_if_needed.do"

use "$PROC/chicken_prepared_stata.dta", clear

di as text _newline "[Stata] Questão 1: estimando MQO robusto"
di as text "[Stata] Modelo: ln_q = beta0 + beta_p*ln_pch + beta_y*ln_y + beta_b*ln_pb + u"
di as text "[Stata] Variável dependente: ln_q"
di as text "[Stata] Regressores: ln_pch ln_y ln_pb"

/********************************************************************
 Questão 1: MQO com erro-padrão robusto
 CORREÇÃO: p-valor de beta_p; coeficientes e p-valores de beta_y e beta_b
********************************************************************/
reg ln_q ln_pch ln_y ln_pb, vce(robust)
di as text "[Stata] MQO concluído: beta_p = " %9.6f _b[ln_pch] "; EP robusto = " %9.6f _se[ln_pch]

* Guarda resíduos e valores ajustados para gráficos da questão 7.
predict double ols_resid, resid
predict double ols_fitted, xb
save "$PROC/chicken_with_ols_residuals_stata.dta", replace
di as text "[Stata] Resíduos e valores ajustados do MQO salvos para gráficos"

* ---------- extração de escalares ----------
scalar b_p   = _b[ln_pch]
scalar se_p  = _se[ln_pch]
scalar b_y   = _b[ln_y]
scalar se_y  = _se[ln_y]
scalar b_b   = _b[ln_pb]
scalar se_b  = _se[ln_pb]
scalar cv_t  = invttail(e(df_r), 0.025)   // valor crítico t bicaudal 5 %

* p-valores individuais: P(|T| > |t|) sob t com e(df_r) graus de liberdade
scalar pval_p = 2 * ttail(e(df_r), abs(b_p / se_p))
scalar pval_y = 2 * ttail(e(df_r), abs(b_y / se_y))
scalar pval_b = 2 * ttail(e(df_r), abs(b_b / se_b))

di as text "[Stata] Q1 p-valores: p(beta_p)=" %9.6f pval_p ///
           " | p(beta_y)=" %9.6f pval_y " | p(beta_b)=" %9.6f pval_b

* ---------- salva tabela com TODAS as elasticidades e p-valores ----------
postfile ols ///
    str20 method int N ///
    double beta_p se_p pval_p ci_low_p ci_high_p ///
    double beta_y se_y pval_y ///
    double beta_b se_b pval_b ///
    using "$TABS/stata_question_01_ols.dta", replace

post ols ///
    ("OLS_robust") (e(N)) ///
    (b_p) (se_p) (pval_p) (b_p - cv_t*se_p) (b_p + cv_t*se_p) ///
    (b_y) (se_y) (pval_y) ///
    (b_b) (se_b) (pval_b)

postclose ols
use "$TABS/stata_question_01_ols.dta", clear
export delimited using "$TABS/stata_question_01_ols.csv", replace
di as text "[Stata] Tabela salva: output/tables/stata_question_01_ols.csv"

/********************************************************************
 Questão 3: 2SLS com um instrumento excluído, Z1 = {z}
 CORREÇÃO: p-valor individual de beta_p adicionado à tabela
********************************************************************/
use "$PROC/chicken_prepared_stata.dta", clear

di as text _newline "[Stata] Questão 3: estimando 2SLS com Z1 = {z}"
di as text "[Stata] Equação estrutural: ln_q ~ ln_pch + ln_y + ln_pb"
di as text "[Stata] Variável endógena: ln_pch"
di as text "[Stata] Instrumento excluído: z"
di as text "[Stata] Controles/instrumentos incluídos: ln_y ln_pb"
ivreg2 ln_q ln_y ln_pb (ln_pch = z), robust first
di as text "[Stata] 2SLS Z1: beta_p = " %9.6f _b[ln_pch] "; EP = " %9.6f _se[ln_pch]

scalar b_p2  = _b[ln_pch]
scalar se_p2 = _se[ln_pch]
scalar cv_n  = invnormal(0.975)   // aproximação normal assintótica para 2SLS

* CORREÇÃO: p-valor via normal padrão (aproximação assintótica do 2SLS)
scalar pval_p2 = 2 * (1 - normal(abs(b_p2 / se_p2)))
di as text "[Stata] Q3 p-valor de beta_p (2SLS): " %9.6f pval_p2

postfile ivz1 ///
    str20 method int N ///
    double beta_p se_p pval_p ci_low ci_high ///
    using "$TABS/stata_question_03_iv_z1.dta", replace

post ivz1 ///
    ("2SLS_Z1_robust") (e(N)) ///
    (b_p2) (se_p2) (pval_p2) (b_p2 - cv_n*se_p2) (b_p2 + cv_n*se_p2)

postclose ivz1
use "$TABS/stata_question_03_iv_z1.dta", clear
export delimited using "$TABS/stata_question_03_iv_z1.csv", replace
di as text "[Stata] Tabela salva: output/tables/stata_question_03_iv_z1.csv"

/********************************************************************
 Questão 4: Primeiro estágio, R2 parcial e F usual robusto
 CORREÇÃO: p-valor individual de pi_z adicionado à tabela
          + verificação numérica equivalência 2SLS=GMM no caso exato
********************************************************************/
use "$PROC/chicken_prepared_stata.dta", clear

di as text _newline "[Stata] Questão 4: estimando primeiro estágio de Z1"
di as text "[Stata] Modelo: ln_pch = pi0 + pi_z*z + pi_y*ln_y + pi_b*ln_pb + v"
di as text "[Stata] Variável dependente: ln_pch"
di as text "[Stata] Regressores: z ln_y ln_pb"

* Primeiro estágio completo.
reg ln_pch z ln_y ln_pb, vce(robust)
test z
scalar F_usual = r(F)
scalar p_F     = r(p)
scalar pi_z    = _b[z]
scalar se_z    = _se[z]

* CORREÇÃO: p-valor individual de pi_z (teste t bilateral)
scalar p_z = 2 * ttail(e(df_r), abs(pi_z / se_z))

di as text "[Stata] Primeiro estágio Z1: pi_z=" %9.6f pi_z " | SE=" %9.6f se_z " | p(t)=" %9.6f p_z
di as text "[Stata] F usual (conjunto) = " %9.6f F_usual " | p(F) = " %9.6f p_F

* R2 parcial: residualiza ln_pch e z contra controles.
di as text "[Stata] Calculando R2 parcial: residualizando ln_pch e z contra ln_y ln_pb"
reg ln_pch ln_y ln_pb
predict double r_ln_pch, resid
reg z ln_y ln_pb
predict double r_z, resid
reg r_ln_pch r_z, noconstant
scalar partial_R2 = e(r2)
di as text "[Stata] R2 parcial do instrumento z = " %9.6f partial_R2

* Verificação numérica: no caso exatamente identificado, GMM de dois passos
* e 2SLS produzem estimativas idênticas independentemente da ponderação.
di as text "[Stata] Verificação: 2SLS vs GMM no caso exatamente identificado (Z1)"
quietly ivreg2 ln_q ln_y ln_pb (ln_pch = z), robust
scalar b_2sls = _b[ln_pch]
quietly ivreg2 ln_q ln_y ln_pb (ln_pch = z), gmm2s robust
scalar b_gmm  = _b[ln_pch]
scalar diff_2sls_gmm = abs(b_2sls - b_gmm)
di as text "[Stata] beta_p 2SLS = " %12.9f b_2sls " | beta_p GMM = " %12.9f b_gmm " | |diferença| = " %12.9f diff_2sls_gmm
di as text "[Stata] (diferença numericamente zero confirma equivalência teórica no caso exato)"

* Tabela do primeiro estágio — CORREÇÃO: inclui p_z
postfile fs ///
    str20 model int N ///
    double pi_z se_z p_z partial_R2 F_usual p_F ///
    using "$TABS/stata_question_04_first_stage.dta", replace

post fs ("Z1_first_stage") (e(N)) (pi_z) (se_z) (p_z) (partial_R2) (F_usual) (p_F)

postclose fs
use "$TABS/stata_question_04_first_stage.dta", clear
export delimited using "$TABS/stata_question_04_first_stage.csv", replace
di as text "[Stata] Tabela salva: output/tables/stata_question_04_first_stage.csv"
