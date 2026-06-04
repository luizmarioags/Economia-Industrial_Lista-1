/****************************************************************************************
COMENTÁRIOS DETALHADOS
- use carrega a base com resíduos do GMM simples.
- estimates restore GMM_both_2 recupera explicitamente o alpha do logit simples; se falhar, o script reestima o GMM principal.
- gen calcula elasticidade própria, markup monoproduto e custo marginal implícito.
- O bloco Mata monta a matriz Delta de Bertrand multiproduto e resolve Delta^{-1}s.
- Este script salva uma base de trabalho em outputs/stata/data; as tabelas CSV/TEX finais são produzidas por 08_standard_tables.do.
****************************************************************************************/
/****************************************************************************************
04 - Elasticidades e markups implícitos
****************************************************************************************/
use "$OUTDATA/stata_after_simple_gmm.dta", clear

global ZOWN "own_cals own_fat own_sugar"
global ZRIVAL "rival_cals rival_fat rival_sugar"
global ZBOTH "$ZOWN $ZRIVAL"

capture estimates restore GMM_both_2
if _rc {
    display as text "GMM_both_2 não estava em memória; reestimando o logit simples para recuperar alpha."
    gmm (delta - {b0} - {bcals}*cals - {bfat}*fat - {bsugar}*sugar - {bp}*price), ///
        instruments($XVARS $ZBOTH) twostep winitial(unadjusted) vce(robust)
}
scalar alpha = -_b[/bp]
display as text "Alpha do logit simples usado nas elasticidades/markups = " %9.5f alpha

gen own_elasticity_simple_logit = -alpha*price*(1-share)
gen markup_monoproduct = 1/(alpha*(1-share))
gen mc_monoproduct = price - markup_monoproduct

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
                else Delta[j,k] = -alpha*s[j]*s[k]
            }
        }
    }
    mu = invsym(Delta)*s
    st_addvar("double", "markup_multiproduct")
    st_store(., "markup_multiproduct", mu)
end

gen mc_multiproduct = price - markup_multiproduct
gen markup_multi_over_price = markup_multiproduct/price
gen markup_mono_over_price = markup_monoproduct/price

save "$OUTDATA/stata_elasticities_markups_work.dta", replace
