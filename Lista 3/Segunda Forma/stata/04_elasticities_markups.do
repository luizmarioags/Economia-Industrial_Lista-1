/****************************************************************************************
04 - Elasticidades e markups implícitos
-----------------------------------------------------------------------------------------
Correção central:
- Usa alpha estimado diretamente como coeficiente de neg_price = -price.
- Não usa abs(alpha) e não força demanda decrescente.
- Se alpha <= 0, o script avisa que as elasticidades/markups não são economicamente
  compatíveis com demanda decrescente, mas mantém o cálculo estrutural sem imposição.
- A solução multiproduto usa qrsolve()/pinv(), em vez de invsym(), para evitar colapso
  numérico indevido da matriz Delta.
****************************************************************************************/

use "$OUTDATA/stata_after_simple_gmm.dta", clear

capture drop neg_price
gen double neg_price = -price

global ZOWN   "own_cals own_fat own_sugar"
global ZRIVAL "rival_cals rival_fat rival_sugar"
global ZBOTH  "$ZOWN $ZRIVAL"

local need_reestimate = 0
capture estimates restore GMM_both_2
if _rc local need_reestimate = 1
if !`need_reestimate' {
    capture scalar alpha = _b[alpha]
    if _rc local need_reestimate = 1
}

if `need_reestimate' {
    display as text "GMM_both_2 não estava em memória ou não tinha alpha; reestimando o logit simples."
    use "$OUTDATA/prepared_data_stata.dta", clear
    capture drop neg_price
    gen double neg_price = -price
    save "$OUTDATA/prepared_data_stata.dta", replace
    quietly run "$ROOT/stata/eberry_operational.do"
    eberry_fit, ///
        y("delta") ///
        x("cons cals fat sugar neg_price") ///
        z("cons cals fat sugar $ZBOTH") ///
        bnames("b0 bcals bfat bsugar alpha") ///
        step(2)
    estimates store GMM_both_2
    scalar alpha = _b[alpha]
    use "$OUTDATA/stata_after_simple_gmm.dta", clear
    capture drop neg_price
    gen double neg_price = -price
}

scalar price_coef = -alpha
display as text "Alpha estimado do logit simples = " %9.5f alpha
display as text "Coeficiente estimado do preço (= -alpha) = " %9.5f price_coef

if (alpha <= 0) {
    display as error "Atenção: alpha <= 0. O modelo estimado não implica demanda própria decrescente."
    display as error "O cálculo abaixo NÃO impõe demanda decrescente; os resultados devem ser tratados como diagnóstico da estimação."
}

capture drop own_elasticity_simple_logit markup_monoproduct mc_monoproduct
capture drop markup_multiproduct mc_multiproduct markup_multi_over_price markup_mono_over_price

gen double own_elasticity_simple_logit = -alpha*price*(1-share)
gen double markup_monoproduct = 1/(alpha*(1-share))
gen double mc_monoproduct = price - markup_monoproduct

mata:
    p = st_data(., "price")
    s = st_data(., "share")
    f = st_data(., "idfirm")
    alpha = st_numscalar("alpha")
    n = rows(s)
    Delta = J(n,n,0)

    for (j=1; j<=n; j++) {
        for (k=1; k<=n; k++) {
            if (f[j] == f[k]) {
                if (j == k) Delta[j,k] = alpha*s[j]*(1-s[j])
                else        Delta[j,k] = -alpha*s[j]*s[k]
            }
        }
    }

    mu = qrsolve(Delta, s)
    if (sum(missing(mu)) > 0) mu = pinv(Delta)*s

    st_addvar("double", "markup_multiproduct")
    st_store(., "markup_multiproduct", mu)
end

gen double mc_multiproduct = price - markup_multiproduct
gen double markup_multi_over_price = markup_multiproduct/price
gen double markup_mono_over_price = markup_monoproduct/price

save "$OUTDATA/stata_elasticities_markups_work.dta", replace
