/****************************************************************************************
02 - MQO, 2SLS e GMM estrutural do logit simples usando eberry/b_program como base
****************************************************************************************
COMENTÁRIOS DETALHADOS
- use carrega a base preparada pelo script 01.
- As globals ZOWN, ZRIVAL e ZBOTH organizam os conjuntos de instrumentos solicitados.
- reg e ivregress continuam como referências MQO/2SLS.
- O núcleo GMM NÃO usa mais o comando nativo gmm do Stata.
- O GMM agora passa por eberry_operational.do, que chama b_program_operational.do.
- eberry_fit define Y, X, Z, nomes dos parâmetros e step; berry_gmm_code monta o
  critério GMM em Mata, otimiza e posta os resultados em eclass.
- Os nomes de estimates são mantidos: GMM_own_1, GMM_own_2, GMM_rival_1,
  GMM_rival_2, GMM_both_1 e GMM_both_2. Assim, tabelas e gráficos seguem iguais.
****************************************************************************************/

use "$OUTDATA/prepared_data_stata.dta", clear

* Carrega o wrapper eberry operacional, que por sua vez chama o b_program operacional.
quietly run "$ROOT/stata/eberry_operational.do"

global ZOWN   "own_cals own_fat own_sugar"
global ZRIVAL "rival_cals rival_fat rival_sugar"
global ZBOTH  "$ZOWN $ZRIVAL"

eststo clear

* Q1: MQO de referência.
reg delta price $XVARS, vce(robust)
eststo OLS

* Q2: 2SLS de referência.
ivregress 2sls delta $XVARS (price = $ZOWN), vce(robust)
eststo IV_own

ivregress 2sls delta $XVARS (price = $ZRIVAL), vce(robust)
eststo IV_rival

ivregress 2sls delta $XVARS (price = $ZBOTH), vce(robust)
eststo IV_both

/****************************************************************************************
Q3: GMM estrutural no estilo b_program/eberry.
Modelo estimado:
    delta_j = b0 + bcals*cals_j + bfat*fat_j + bsugar*sugar_j + bp*price_j + xi_j
com bp = -alpha.

Momentos:
    E[Z_j xi_j(theta)] = 0.
****************************************************************************************/

eberry_fit, ///
    y("delta") ///
    x("cons cals fat sugar price") ///
    z("cons cals fat sugar $ZOWN") ///
    bnames("b0 bcals bfat bsugar bp") ///
    step(1)
eststo GMM_own_1

eberry_fit, ///
    y("delta") ///
    x("cons cals fat sugar price") ///
    z("cons cals fat sugar $ZOWN") ///
    bnames("b0 bcals bfat bsugar bp") ///
    step(2)
eststo GMM_own_2

eberry_fit, ///
    y("delta") ///
    x("cons cals fat sugar price") ///
    z("cons cals fat sugar $ZRIVAL") ///
    bnames("b0 bcals bfat bsugar bp") ///
    step(1)
eststo GMM_rival_1

eberry_fit, ///
    y("delta") ///
    x("cons cals fat sugar price") ///
    z("cons cals fat sugar $ZRIVAL") ///
    bnames("b0 bcals bfat bsugar bp") ///
    step(2)
eststo GMM_rival_2

eberry_fit, ///
    y("delta") ///
    x("cons cals fat sugar price") ///
    z("cons cals fat sugar $ZBOTH") ///
    bnames("b0 bcals bfat bsugar bp") ///
    step(1)
eststo GMM_both_1

eberry_fit, ///
    y("delta") ///
    x("cons cals fat sugar price") ///
    z("cons cals fat sugar $ZBOTH") ///
    bnames("b0 bcals bfat bsugar bp") ///
    step(2)
eststo GMM_both_2

* Resíduo estrutural da especificação GMM principal.
use "$OUTDATA/prepared_data_stata.dta", clear
estimates restore GMM_both_2
gen xi_gmm_both = delta - _b[b0] - _b[bcals]*cals - _b[bfat]*fat - _b[bsugar]*sugar - _b[bp]*price
save "$OUTDATA/stata_after_simple_gmm.dta", replace

* Exportação padronizada em CSV/TEX fica em 08_standard_tables.do.
