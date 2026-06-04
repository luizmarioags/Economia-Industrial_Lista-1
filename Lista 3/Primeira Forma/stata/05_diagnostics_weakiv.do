/****************************************************************************************
COMENTÁRIOS DETALHADOS
- reg price ... estima o primeiro estágio do preço contra controles e instrumentos excluídos.
- test aplica o teste conjunto dos instrumentos excluídos no primeiro estágio.
- ivregress 2sls reestima a equação IV necessária para chamar weakivtest.
- weakivtest executa o teste Montiel-Olea--Pflueger no Stata quando o pacote está instalado.
- No nested logit, o primeiro estágio é feito separadamente para price e ln(s_j|g).
- esttab exporta as regressões de primeiro estágio em TEX e CSV.
****************************************************************************************/
/****************************************************************************************
05 - Diagnóstico dos instrumentos. Inclui weakivtest (Montiel-Olea-Pflueger) no Stata.
****************************************************************************************/
use "$OUTDATA/prepared_data_stata.dta", clear

global ZOWN "own_cals own_fat own_sugar"
global ZRIVAL "rival_cals rival_fat rival_sugar"
global ZBOTH "$ZOWN $ZRIVAL"
global ZNEST "n_same_nest_other n_rival_nest nest_own_cals nest_own_fat nest_own_sugar nest_rival_cals nest_rival_fat nest_rival_sugar"
global ZNESTALL "$ZOWN $ZRIVAL $ZNEST"

* Primeiro estágio do preço.
reg price $XVARS $ZBOTH, vce(robust)
eststo FS_price_simple
test $ZBOTH

* IV + weakivtest MO-P para uma endógena.
ivregress 2sls delta $XVARS (price = $ZBOTH), vce(robust)
capture noisily weakivtest

* Nested: diagnósticos separados.
reg price $XVARS $ZNESTALL, vce(robust)
eststo FS_price_nested
test $ZNESTALL
reg log_share_within_nest $XVARS $ZNESTALL, vce(robust)
eststo FS_lnsjgnested
test $ZNESTALL

* IV nested e weakivtest. Para múltiplas endógenas, reportar também testes separados acima.
ivregress 2sls delta $XVARS (price log_share_within_nest = $ZNESTALL), vce(robust)
capture noisily weakivtest

* Exportação padronizada transferida para 08_standard_tables.do.
* Exportação padronizada transferida para 08_standard_tables.do.
