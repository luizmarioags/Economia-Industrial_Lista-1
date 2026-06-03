/****************************************************************************************
COMENTÁRIOS DETALHADOS
- use carrega a base preparada pelo script 01.
- As globals ZOWN, ZRIVAL e ZBOTH organizam os conjuntos de instrumentos solicitados na lista.
- reg estima o logit simples por MQO com erros robustos.
- ivregress 2sls estima as referências IV/2SLS para cada conjunto de instrumentos.
- gmm implementa os momentos estruturais E[Z_j xi_j(theta)] = 0; bp é o coeficiente de preço (= -alpha).
- onestep usa matriz inicial; twostep atualiza a matriz de ponderação para a versão eficiente.
- eststo guarda cada resultado para exportação comparável.
- gen xi_gmm_both calcula explicitamente o resíduo estrutural da especificação GMM principal.
- esttab exporta tabelas em TEX e CSV para a pasta outputs/stata/tables.
****************************************************************************************/
/****************************************************************************************
02 - MQO, 2SLS e GMM estrutural do logit simples
****************************************************************************************/
use "$OUTDATA/prepared_data_stata.dta", clear

global ZOWN "own_cals own_fat own_sugar"
global ZRIVAL "rival_cals rival_fat rival_sugar"
global ZBOTH "$ZOWN $ZRIVAL"

eststo clear

* Q1: MQO
reg delta price $XVARS, vce(robust)
eststo OLS

* Q2: 2SLS de referência
ivregress 2sls delta $XVARS (price = $ZOWN), vce(robust)
eststo IV_own
ivregress 2sls delta $XVARS (price = $ZRIVAL), vce(robust)
eststo IV_rival
ivregress 2sls delta $XVARS (price = $ZBOTH), vce(robust)
eststo IV_both

* Q3: GMM estrutural. O momento é E[Z * xi(theta)] = 0.
* Coeficiente estimado de price = -alpha.
gmm (delta - {b0} - {bcals}*cals - {bfat}*fat - {bsugar}*sugar - {bp}*price), ///
    instruments($XVARS $ZOWN) onestep winitial(unadjusted) vce(robust)
eststo GMM_own_1
capture estimates scalar Q = e(Q)

gmm (delta - {b0} - {bcals}*cals - {bfat}*fat - {bsugar}*sugar - {bp}*price), ///
    instruments($XVARS $ZOWN) twostep winitial(unadjusted) vce(robust)
eststo GMM_own_2

gmm (delta - {b0} - {bcals}*cals - {bfat}*fat - {bsugar}*sugar - {bp}*price), ///
    instruments($XVARS $ZRIVAL) onestep winitial(unadjusted) vce(robust)
eststo GMM_rival_1

gmm (delta - {b0} - {bcals}*cals - {bfat}*fat - {bsugar}*sugar - {bp}*price), ///
    instruments($XVARS $ZRIVAL) twostep winitial(unadjusted) vce(robust)
eststo GMM_rival_2

gmm (delta - {b0} - {bcals}*cals - {bfat}*fat - {bsugar}*sugar - {bp}*price), ///
    instruments($XVARS $ZBOTH) onestep winitial(unadjusted) vce(robust)
eststo GMM_both_1

gmm (delta - {b0} - {bcals}*cals - {bfat}*fat - {bsugar}*sugar - {bp}*price), ///
    instruments($XVARS $ZBOTH) twostep winitial(unadjusted) vce(robust)
eststo GMM_both_2

* Calcula o resíduo estrutural explicitamente.
* Isso evita depender de predict pós-gmm, cuja sintaxe pode variar entre versões do Stata.
gen xi_gmm_both = delta - _b[/b0] - _b[/bcals]*cals - _b[/bfat]*fat - _b[/bsugar]*sugar - _b[/bp]*price
save "$OUTDATA/stata_after_simple_gmm.dta", replace

* Exportação padronizada transferida para 08_standard_tables.do.
* Exportação padronizada transferida para 08_standard_tables.do.
