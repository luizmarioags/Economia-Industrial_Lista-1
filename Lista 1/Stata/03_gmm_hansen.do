/********************************************************************
 Questão 5: GMM e sobreidentificação com Hansen J
 CORREÇÕES APLICADAS:
   - p-valor individual de beta_p adicionado para GMM_Z1 e GMM_Z2
   - verificação numérica explícita de equivalência 2SLS == GMM no caso exato
   - hansen_df registrado corretamente para caso exato (0) e sobreidentificado (1)
********************************************************************/


* Carrega configuração se o script for rodado individualmente.
do "Stata/_load_config_if_needed.do"

use "$PROC/chicken_prepared_stata.dta", clear

di as text _newline "[Stata] Questão 5: estimando GMM em dois passos"
di as text "[Stata] Equação estrutural: ln_q ~ ln_pch + ln_y + ln_pb"
di as text "[Stata] Variável endógena: ln_pch; controles exógenos: ln_y ln_pb"

* CORREÇÃO: postfile agora inclui pval_p (p-valor de beta_p)
postfile gmmtab ///
    str20 model int N ///
    double beta_p se_p pval_p ci_low ci_high ///
    double hansen_J hansen_p hansen_df ///
    using "$TABS/stata_question_05_gmm.dta", replace

* ------------------------------------------------------------------
* GMM exatamente identificado: Z1 = {z}
* ------------------------------------------------------------------
di as text "[Stata] GMM_Z1: instrumento excluído = z"
ivreg2 ln_q ln_y ln_pb (ln_pch = z), gmm2s robust
scalar b  = _b[ln_pch]
scalar se = _se[ln_pch]
scalar cv = invnormal(0.975)

* CORREÇÃO: p-valor via normal assintótica
scalar pval_p = 2 * (1 - normal(abs(b / se)))
di as text "[Stata] GMM_Z1: beta_p=" %9.6f b " | EP=" %9.6f se " | p=" %9.6f pval_p

* No caso exatamente identificado (1 instrumento = 1 endógena), Hansen J é
* identicamente zero — não há graus de liberdade para o teste ser informativo.
post gmmtab ("GMM_Z1") (e(N)) (b) (se) (pval_p) (b - cv*se) (b + cv*se) (.) (.) (0)

* ------------------------------------------------------------------
* Verificação numérica: 2SLS == GMM no caso exatamente identificado
* ------------------------------------------------------------------
quietly ivreg2 ln_q ln_y ln_pb (ln_pch = z), robust
scalar b_2sls = _b[ln_pch]
quietly ivreg2 ln_q ln_y ln_pb (ln_pch = z), gmm2s robust
scalar b_gmm  = _b[ln_pch]
di as text "[Stata] Verificação Q5 — caso exato:"
di as text "[Stata]   beta_p 2SLS = " %14.10f b_2sls
di as text "[Stata]   beta_p GMM  = " %14.10f b_gmm
di as text "[Stata]   |diferença| = " %14.10f abs(b_2sls - b_gmm)
di as text "[Stata]   (valor zero confirma equivalência independente da ponderação)"

* ------------------------------------------------------------------
* GMM sobreidentificado: Z2 = {z, z^2}
* ------------------------------------------------------------------
di as text "[Stata] GMM_Z2: instrumentos excluídos = z z_sq"
ivreg2 ln_q ln_y ln_pb (ln_pch = z z_sq), gmm2s robust
scalar b  = _b[ln_pch]
scalar se = _se[ln_pch]
scalar cv = invnormal(0.975)

* CORREÇÃO: p-valor de beta_p
scalar pval_p = 2 * (1 - normal(abs(b / se)))

* Extrai estatística J com proteção contra ausência
cap scalar J   = e(j)
if _rc scalar J = .
cap scalar Jp  = e(jp)
if _rc scalar Jp = .
cap scalar Jdf = e(jdf)
if _rc scalar Jdf = .

di as text "[Stata] GMM_Z2: beta_p=" %9.6f b " | EP=" %9.6f se " | p=" %9.6f pval_p
di as text "[Stata] GMM_Z2: Hansen J=" %9.6f J " | p(J)=" %9.6f Jp " | gl=" %2.0f Jdf
post gmmtab ("GMM_Z2") (e(N)) (b) (se) (pval_p) (b - cv*se) (b + cv*se) (J) (Jp) (Jdf)

postclose gmmtab
use "$TABS/stata_question_05_gmm.dta", clear
export delimited using "$TABS/stata_question_05_gmm.csv", replace
di as text "[Stata] Tabela salva: output/tables/stata_question_05_gmm.csv"
