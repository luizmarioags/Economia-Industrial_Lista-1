/****************************************************************************************
03 - Nested logit por GMM usando eberry/b_program como base operacional
****************************************************************************************
COMENTÁRIOS DETALHADOS
- O 2SLS nested continua como referência linear.
- O GMM nested NÃO usa mais o comando nativo gmm do Stata.
- O núcleo operacional é o mesmo de eberry/b_program: eberry_fit define Y, X, Z e
  berry_gmm_code resolve o critério GMM em Mata.
- Os estimates são mantidos como IV_nested, GMM_nested_1 e GMM_nested_2.
****************************************************************************************/

use "$OUTDATA/prepared_data_stata.dta", clear

quietly run "$ROOT/stata/eberry_operational.do"

global ZOWN     "own_cals own_fat own_sugar"
global ZRIVAL   "rival_cals rival_fat rival_sugar"
global ZNEST    "n_same_nest_other n_rival_nest nest_own_cals nest_own_fat nest_own_sugar nest_rival_cals nest_rival_fat nest_rival_sugar"
global ZNESTALL "$ZOWN $ZRIVAL $ZNEST"

* Referência 2SLS com duas endógenas: preço e log(s_j|g).
ivregress 2sls delta $XVARS (price log_share_within_nest = $ZNESTALL), vce(robust)
eststo IV_nested

/****************************************************************************************
GMM nested:
    delta_j = b0 + bcals*cals_j + bfat*fat_j + bsugar*sugar_j
              + bp*price_j + sigma*ln(s_{j|g}) + xi_j.
****************************************************************************************/

eberry_fit, ///
    y("delta") ///
    x("cons cals fat sugar price log_share_within_nest") ///
    z("cons cals fat sugar $ZNESTALL") ///
    bnames("b0 bcals bfat bsugar bp sigma") ///
    step(1)
eststo GMM_nested_1

eberry_fit, ///
    y("delta") ///
    x("cons cals fat sugar price log_share_within_nest") ///
    z("cons cals fat sugar $ZNESTALL") ///
    bnames("b0 bcals bfat bsugar bp sigma") ///
    step(2)
eststo GMM_nested_2

scalar sigma_nested = _b[sigma]
display as text "Sigma nested = " %9.4f sigma_nested " ; intervalo teórico: 0 <= sigma < 1"

* Resíduo estrutural nested.
use "$OUTDATA/prepared_data_stata.dta", clear
estimates restore GMM_nested_2
gen xi_nested = delta - _b[b0] - _b[bcals]*cals - _b[bfat]*fat - _b[bsugar]*sugar - _b[bp]*price - _b[sigma]*log_share_within_nest
save "$OUTDATA/stata_after_nested_gmm.dta", replace

* Exportação padronizada em CSV/TEX fica em 08_standard_tables.do.
