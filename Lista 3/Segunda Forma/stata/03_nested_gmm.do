/****************************************************************************************
03 - Nested logit por GMM
-----------------------------------------------------------------------------------------
Correção central:
- O parâmetro alpha é estimado diretamente usando neg_price = -price.
- O código não impõe alpha > 0; ele apenas estima a especificação da lista.
****************************************************************************************/

use "$OUTDATA/prepared_data_stata.dta", clear

capture drop neg_price
gen double neg_price = -price
label variable neg_price "Preço com sinal negativo (-price), coeficiente estrutural alpha"
save "$OUTDATA/prepared_data_stata.dta", replace

quietly run "$ROOT/stata/eberry_operational.do"

global ZOWN     "own_cals own_fat own_sugar"
global ZRIVAL   "rival_cals rival_fat rival_sugar"
global ZNEST    "n_same_nest_other n_rival_nest nest_own_cals nest_own_fat nest_own_sugar nest_rival_cals nest_rival_fat nest_rival_sugar"
global ZNESTALL "$ZOWN $ZRIVAL $ZNEST"

* Referência 2SLS com duas endógenas: -preço e log(s_j|g).
ivregress 2sls delta $XVARS (neg_price log_share_within_nest = $ZNESTALL), vce(robust)
eststo IV_nested

/****************************************************************************************
GMM nested:
    delta_j = b0 + bcals*cals_j + bfat*fat_j + bsugar*sugar_j
              + alpha*(-price_j) + sigma*ln(s_{j|g}) + xi_j.
****************************************************************************************/

eberry_fit, ///
    y("delta") ///
    x("cons cals fat sugar neg_price log_share_within_nest") ///
    z("cons cals fat sugar $ZNESTALL") ///
    bnames("b0 bcals bfat bsugar alpha sigma") ///
    step(1)
eststo GMM_nested_1

eberry_fit, ///
    y("delta") ///
    x("cons cals fat sugar neg_price log_share_within_nest") ///
    z("cons cals fat sugar $ZNESTALL") ///
    bnames("b0 bcals bfat bsugar alpha sigma") ///
    step(2)
eststo GMM_nested_2

scalar alpha_nested = _b[alpha]
scalar sigma_nested = _b[sigma]
display as text "Alpha nested = " %9.4f alpha_nested " ; esperado teoricamente: alpha > 0"
display as text "Sigma nested = " %9.4f sigma_nested " ; intervalo teórico: 0 <= sigma < 1"

* Resíduo estrutural nested.
use "$OUTDATA/prepared_data_stata.dta", clear
capture drop neg_price
gen double neg_price = -price
estimates restore GMM_nested_2
gen double xi_nested = delta - _b[b0] - _b[bcals]*cals - _b[bfat]*fat - _b[bsugar]*sugar - _b[alpha]*neg_price - _b[sigma]*log_share_within_nest
save "$OUTDATA/stata_after_nested_gmm.dta", replace

* Exportação padronizada em CSV/TEX fica em 08_standard_tables.do.
