/****************************************************************************************
02 - MQO, 2SLS e GMM estrutural do logit simples
-----------------------------------------------------------------------------------------
Correção central:
- A especificação teórica da lista é
      delta_j = X_j'beta - alpha*p_j + xi_j.
- Para estimar alpha diretamente, sem impor alpha > 0, cria-se:
      neg_price = -price.
- Assim, a equação estimada fica
      delta_j = X_j'beta + alpha*neg_price_j + xi_j.
- Se alpha for negativo, isso será resultado da estimação; o código não usa abs() e não
  impõe demanda decrescente.
****************************************************************************************/

use "$OUTDATA/prepared_data_stata.dta", clear

capture drop neg_price
gen double neg_price = -price
label variable neg_price "Preço com sinal negativo (-price), coeficiente estrutural alpha"
save "$OUTDATA/prepared_data_stata.dta", replace

quietly run "$ROOT/stata/eberry_operational.do"

global ZOWN   "own_cals own_fat own_sugar"
global ZRIVAL "rival_cals rival_fat rival_sugar"
global ZBOTH  "$ZOWN $ZRIVAL"

eststo clear

* Q1: MQO de referência.
reg delta neg_price $XVARS, vce(robust)
eststo OLS

* Q2: 2SLS de referência.
ivregress 2sls delta $XVARS (neg_price = $ZOWN), vce(robust)
eststo IV_own

ivregress 2sls delta $XVARS (neg_price = $ZRIVAL), vce(robust)
eststo IV_rival

ivregress 2sls delta $XVARS (neg_price = $ZBOTH), vce(robust)
eststo IV_both

/****************************************************************************************
Q3: GMM estrutural no estilo Berry/BLP.
Modelo estimado:
    delta_j = b0 + bcals*cals_j + bfat*fat_j + bsugar*sugar_j
              + alpha*(-price_j) + xi_j.
****************************************************************************************/

eberry_fit, ///
    y("delta") ///
    x("cons cals fat sugar neg_price") ///
    z("cons cals fat sugar $ZOWN") ///
    bnames("b0 bcals bfat bsugar alpha") ///
    step(1)
eststo GMM_own_1

eberry_fit, ///
    y("delta") ///
    x("cons cals fat sugar neg_price") ///
    z("cons cals fat sugar $ZOWN") ///
    bnames("b0 bcals bfat bsugar alpha") ///
    step(2)
eststo GMM_own_2

eberry_fit, ///
    y("delta") ///
    x("cons cals fat sugar neg_price") ///
    z("cons cals fat sugar $ZRIVAL") ///
    bnames("b0 bcals bfat bsugar alpha") ///
    step(1)
eststo GMM_rival_1

eberry_fit, ///
    y("delta") ///
    x("cons cals fat sugar neg_price") ///
    z("cons cals fat sugar $ZRIVAL") ///
    bnames("b0 bcals bfat bsugar alpha") ///
    step(2)
eststo GMM_rival_2

eberry_fit, ///
    y("delta") ///
    x("cons cals fat sugar neg_price") ///
    z("cons cals fat sugar $ZBOTH") ///
    bnames("b0 bcals bfat bsugar alpha") ///
    step(1)
eststo GMM_both_1

eberry_fit, ///
    y("delta") ///
    x("cons cals fat sugar neg_price") ///
    z("cons cals fat sugar $ZBOTH") ///
    bnames("b0 bcals bfat bsugar alpha") ///
    step(2)
eststo GMM_both_2

* Resíduo estrutural da especificação GMM principal.
use "$OUTDATA/prepared_data_stata.dta", clear
capture drop neg_price
gen double neg_price = -price
estimates restore GMM_both_2
gen double xi_gmm_both = delta - _b[b0] - _b[bcals]*cals - _b[bfat]*fat - _b[bsugar]*sugar - _b[alpha]*neg_price
save "$OUTDATA/stata_after_simple_gmm.dta", replace

* Exportação padronizada em CSV/TEX fica em 08_standard_tables.do.
