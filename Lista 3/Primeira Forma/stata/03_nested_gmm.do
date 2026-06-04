/****************************************************************************************
COMENTÁRIOS DETALHADOS
- use carrega a base preparada com a variável ln(s_j|g).
- ZNEST reúne instrumentos de número e características de produtos dentro do nest e em nests rivais.
- ivregress 2sls fornece uma referência linear com duas variáveis endógenas: preço e ln(s_j|g).
- gmm estima o nested logit pela condição de momento estrutural, incluindo o parâmetro sigma.
- scalar sigma_nested extrai a estimativa de sigma para checar 0 <= sigma < 1.
- gen xi_nested calcula explicitamente o resíduo estrutural nested; save guarda a base com esses resíduos.
- esttab exporta os resultados nested em TEX e CSV.
****************************************************************************************/
/****************************************************************************************
03 - Nested logit por GMM
****************************************************************************************/
use "$OUTDATA/prepared_data_stata.dta", clear

global ZOWN "own_cals own_fat own_sugar"
global ZRIVAL "rival_cals rival_fat rival_sugar"
global ZNEST "n_same_nest_other n_rival_nest nest_own_cals nest_own_fat nest_own_sugar nest_rival_cals nest_rival_fat nest_rival_sugar"
global ZNESTALL "$ZOWN $ZRIVAL $ZNEST"

* Referência 2SLS com duas endógenas: preço e log(s_j|g).
ivregress 2sls delta $XVARS (price log_share_within_nest = $ZNESTALL), vce(robust)
eststo IV_nested

* GMM nested: delta = X beta + bp price + sigma log_share_within_nest + xi.
gmm (delta - {b0} - {bcals}*cals - {bfat}*fat - {bsugar}*sugar - {bp}*price - {sigma}*log_share_within_nest), ///
    instruments($XVARS $ZNESTALL) onestep winitial(unadjusted) vce(robust)
eststo GMM_nested_1

gmm (delta - {b0} - {bcals}*cals - {bfat}*fat - {bsugar}*sugar - {bp}*price - {sigma}*log_share_within_nest), ///
    instruments($XVARS $ZNESTALL) twostep winitial(unadjusted) vce(robust)
eststo GMM_nested_2

scalar sigma_nested = _b[/sigma]
display as text "Sigma nested = " %9.4f sigma_nested " ; intervalo teórico: 0 <= sigma < 1"

* Calcula o resíduo estrutural nested explicitamente.
* xi_j(theta) = delta_j - X_j beta - bp*p_j - sigma*ln(s_j|g).
gen xi_nested = delta - _b[/b0] - _b[/bcals]*cals - _b[/bfat]*fat - _b[/bsugar]*sugar - _b[/bp]*price - _b[/sigma]*log_share_within_nest
save "$OUTDATA/stata_after_nested_gmm.dta", replace

* Exportação padronizada transferida para 08_standard_tables.do.
* Exportação padronizada transferida para 08_standard_tables.do.
