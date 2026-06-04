/****************************************************************************************
COMENTÁRIOS DETALHADOS
- Este script gera os mesmos gráficos principais da rotina Python, mas salvando tudo em
  outputs/stata/figures/pdf e outputs/stata/figures/png.
- Os gráficos 01--04 usam a base preparada: share-preço, ranking de shares, preço por nest
  e inversão logit versus preço.
- O gráfico 05 coleta coeficientes de preço das estimações já guardadas em memória.
- Os gráficos 06--09 usam elasticidades e markups calculados no script 04.
- O gráfico 10 reestima regressões de primeiro estágio e resume os F/Wald-F dos instrumentos.
****************************************************************************************/
/****************************************************************************************
06 - Gráficos principais em PDF e PNG com tema visual aplicado
****************************************************************************************/


/****************************************************************************************
Rótulos matemáticos para gráficos do Stata
- O Stata não renderiza LaTeX diretamente em títulos/eixos.
- Para obter saída tipográfica semelhante ao LaTeX nos PDFs/PNGs, usamos SMCL:
  {&delta}, {&alpha}, {&xi}, {&epsilon}, {it:...}, {subscript:...} etc.
****************************************************************************************/
local L_DELTA `"{&delta}{subscript:j} = ln({it:s}{subscript:j}) - ln({it:s}{subscript:0})"'
local L_PRICECOEF `"Coeficiente do preço (= -{&alpha})"'
local L_EJK `"{&epsilon}{subscript:jk}"'
local L_EJJ `"{&epsilon}{subscript:jj}"'
local L_XI `"{&xi}{subscript:j} estimado"'
local L_SJ `"{it:s}{subscript:j} previsto"'
local L_SOBS `"{it:s}{subscript:j} observado"'
local L_VREL `"{it:V}{subscript:j} - ln({it:C}{subscript:j})"'
local L_DSDP `"d{it:s}{subscript:j}/d{it:p}{subscript:j}"'
local L_PRICEJ `"{it:p}{subscript:j} simulado"'
local L_SHARE `"Market share ({it:s}{subscript:j})"'

/****************************************************************************************
Tema visual dos gráficos
- Inspirado no arquivo de referência enviado: fundo branco, grade cinza clara tracejada,
  pontos azul-escuro, linhas de ajuste em vermelho/cranberry e legenda à direita quando útil.
- As macros abaixo são usadas em todos os gráficos deste script.
****************************************************************************************/
set scheme s1color
capture graph set window fontface "Arial"

* Template visual fixo, copiado do padrão do gráfico de referência:
* fundo branco, grade cinza clara tracejada, pontos navy,
* linha de ajuste cranberry e linha zero preta tracejada.
local GBASE `"scheme(s1color) graphregion(color(white)) plotregion(color(white) lcolor(none)) bgcolor(white)"'
local GRIDXY `"xlabel(, labsize(small) grid glcolor(gs14) glpattern(dash)) ylabel(, labsize(small) angle(horizontal) grid glcolor(gs14) glpattern(dash))"'
local GRIDHBAR `"ylabel(, labsize(small) grid glcolor(gs14) glpattern(dash))"'
local GRIDY  `"ylabel(, labsize(small) angle(horizontal) grid glcolor(gs14) glpattern(dash))"'
local GRIDX  `"xlabel(, labsize(small) grid glcolor(gs14) glpattern(dash))"'
local LEGEND_RIGHT `"legend(position(3) ring(1) cols(1) region(lcolor(none) fcolor(none)) size(small))"'
local LEGEND_BOTTOM `"legend(rows(1) region(lcolor(none) fcolor(none)) size(small))"'
local ZERO_LINE `"lcolor(black) lpattern(dash) lwidth(medthin)"'


* 1. Share vs preço, com rótulos de produto para inspeção de outliers.
use "$OUTDATA/prepared_data_stata.dta", clear
twoway (scatter share price, mlabel(product) mlabsize(vsmall) msymbol(circle) mcolor(navy)), ///
    title("Share e preço por segmento", size(medsmall) color(black)) ///
    xtitle("Preço de transação") ///
    ytitle("`L_SHARE'") ///
    legend(off) ///
    `GBASE' `GRIDXY'
graph export "$FIGPDF/01_share_vs_transaction_price.pdf", replace
graph export "$FIGPNG/01_share_vs_transaction_price.png", replace width(2800)

* 2. Top 15 produtos por market share.
gsort -share
graph hbar share in 1/15, over(product, sort(share) descending label(labsize(vsmall))) ///
    title("Maiores produtos por market share", size(medsmall) color(black)) ///
    ytitle("Market share") ///
    bar(1, fcolor(navy) lcolor(navy)) ///
    `GBASE' `GRIDHBAR'
graph export "$FIGPDF/02_top15_market_shares.pdf", replace
graph export "$FIGPNG/02_top15_market_shares.png", replace width(2800)

* 3. Distribuição de preço por segmento/nest.
use "$OUTDATA/prepared_data_stata.dta", clear
graph box price, over(segment) ///
    title("Distribuição de preços por nest/segmento", size(medsmall) color(black)) ///
    ytitle("Preço de transação") ///
    box(1, fcolor(navy) lcolor(navy)) ///
    marker(1, mcolor(navy)) ///
    `GBASE' `GRIDY'
graph export "$FIGPDF/03_price_by_segment.pdf", replace
graph export "$FIGPNG/03_price_by_segment.png", replace width(2800)

* 4. Relação entre delta de Berry e preço, com ajuste linear auxiliar.
twoway (scatter delta price, msymbol(circle) mcolor(navy)) ///
       (lfit delta price, lcolor(cranberry) lwidth(medthick)), ///
    title("Inversão logit de Berry e preço", size(medsmall) color(black)) ///
    xtitle("Preço de transação") ///
    ytitle("`L_DELTA'") ///
    legend(off) ///
    `GBASE' `GRIDXY'
graph export "$FIGPDF/04_delta_vs_price.pdf", replace
graph export "$FIGPNG/04_delta_vs_price.png", replace width(2800)

* 5. Comparação dos coeficientes de preço entre especificações.
tempfile pricecomp
postfile pc str32 model double price_coef using `pricecomp', replace
foreach m in OLS IV_own IV_rival IV_both IV_nested {
    capture estimates restore `m'
    if !_rc {
        capture scalar bp = _b[price]
        if !_rc post pc ("`m'") (bp)
    }
}
foreach m in GMM_own_1 GMM_own_2 GMM_rival_1 GMM_rival_2 GMM_both_1 GMM_both_2 GMM_nested_1 GMM_nested_2 {
    capture estimates restore `m'
    if !_rc {
        capture scalar bp = _b[/bp]
        if !_rc post pc ("`m'") (bp)
    }
}
postclose pc
use `pricecomp', clear
export delimited using "$OUTDATA/price_parameter_comparison_stata_graph.csv", replace
graph hbar price_coef, over(model, label(labsize(tiny))) ///
    yline(0, `ZERO_LINE') ///
    title("Comparação das estimativas de preço", size(medsmall) color(black)) ///
    ytitle("`L_PRICECOEF'") ///
    bar(1, fcolor(navy) lcolor(navy)) ///
    `GBASE' `GRIDHBAR'
graph export "$FIGPDF/05_price_coefficient_comparison.pdf", replace
graph export "$FIGPNG/05_price_coefficient_comparison.png", replace width(2800)

* 6. Matriz de elasticidades para os 12 maiores produtos.
use "$OUTDATA/stata_after_simple_gmm.dta", clear
capture estimates restore GMM_both_2
if _rc {
    global ZOWN "own_cals own_fat own_sugar"
    global ZRIVAL "rival_cals rival_fat rival_sugar"
    global ZBOTH "$ZOWN $ZRIVAL"
    gmm (delta - {b0} - {bcals}*cals - {bfat}*fat - {bsugar}*sugar - {bp}*price), ///
        instruments($XVARS $ZBOTH) twostep winitial(unadjusted) vce(robust)
}
scalar alpha_graph = -_b[/bp]
gsort -share
keep in 1/12
mata:
    p = st_data(., "price")
    s = st_data(., "share")
    a = st_numscalar("alpha_graph")
    n = rows(s)
    E = J(n,n,.)
    for (j=1; j<=n; j++) {
        for (k=1; k<=n; k++) {
            if (j==k) E[j,k] = -a*p[j]*(1-s[j])
            else E[j,k] = a*p[k]*s[k]
        }
    }
    st_matrix("Egraph", E)
end
clear
svmat Egraph, names(e)
gen row = _n
reshape long e, i(row) j(col)
gen label_e = string(e, "%4.2f")
twoway (scatter row col, msymbol(square) msize(large) mcolor(navy)) ///
       (scatter row col, msymbol(none) mlabel(label_e) mlabsize(tiny) mlabcolor(white)), ///
       title("Matriz de elasticidades-preço ({&epsilon}{subscript:jk})", size(medsmall) color(black)) ///
       xtitle("Produto {it:k}") ytitle("Produto {it:j}") ///
       xlabel(1(1)12, labsize(vsmall) grid glcolor(gs14) glpattern(dash)) ///
       ylabel(1(1)12, labsize(vsmall) grid glcolor(gs14) glpattern(dash)) ///
       legend(off) ///
       `GBASE'
graph export "$FIGPDF/06_elasticity_matrix_subset.pdf", replace
graph export "$FIGPNG/06_elasticity_matrix_subset.png", replace width(2800)

* 7. Elasticidades próprias mais intensas.
import delimited "$TABCsv/05_own_elasticities_simple_logit.csv", clear varnames(1)
gsort own_elasticity_simple_logit
graph hbar own_elasticity_simple_logit in 1/15, over(product, label(labsize(vsmall))) ///
    yline(0, `ZERO_LINE') ///
    title("Elasticidades próprias mais intensas ({&epsilon}{subscript:jj})", size(medsmall) color(black)) ///
    ytitle("`L_EJJ'") ///
    bar(1, fcolor(navy) lcolor(navy)) ///
    `GBASE' `GRIDHBAR'
graph export "$FIGPDF/07_own_price_elasticities.pdf", replace
graph export "$FIGPNG/07_own_price_elasticities.png", replace width(2800)

* 18. Distribuição das elasticidades próprias: histograma + densidade kernel.
histogram own_elasticity_simple_logit, density kdensity ///
    fcolor(navy) lcolor(white) ///
    kdenopts(lcolor(cranberry) lwidth(medthick)) ///
    xline(0, `ZERO_LINE') ///
    title("Distribuição das elasticidades próprias ({&epsilon}{subscript:jj})", size(medsmall) color(black)) ///
    xtitle("`L_EJJ'") ///
    ytitle("Densidade") ///
    `GBASE' `GRIDXY'
graph export "$FIGPDF/18_own_elasticity_hist_density.pdf", replace
graph export "$FIGPNG/18_own_elasticity_hist_density.png", replace width(2800)

* 20. Boxplot das elasticidades próprias.
graph box own_elasticity_simple_logit, ///
    yline(0, `ZERO_LINE') ///
    title("Boxplot das elasticidades próprias ({&epsilon}{subscript:jj})", size(medsmall) color(black)) ///
    ytitle("`L_EJJ'") ///
    box(1, fcolor(navy) lcolor(navy)) ///
    marker(1, mcolor(navy)) ///
    `GBASE' `GRIDY'
graph export "$FIGPDF/20_own_elasticity_boxplot.pdf", replace
graph export "$FIGPNG/20_own_elasticity_boxplot.png", replace width(2800)

* 8. Markups monoproduto versus multiproduto para os maiores markups multiproduto.
import delimited "$TABCsv/08_markups.csv", clear varnames(1)
gsort -markup_multiproduct
graph hbar markup_monoproduct markup_multiproduct in 1/15, ///
    over(product, label(labsize(vsmall))) ///
    title("Comparação de markups implícitos", size(medsmall) color(black)) ///
    ytitle("Markup implícito") ///
    bar(1, fcolor(navy) lcolor(navy)) ///
    bar(2, fcolor(cranberry) lcolor(cranberry)) ///
    legend(order(1 "Monoproduto" 2 "Multiproduto") position(3) ring(1) cols(1) region(lcolor(none) fcolor(none)) size(small)) ///
    `GBASE' `GRIDHBAR'
graph export "$FIGPDF/08_markups_mono_vs_multi.pdf", replace
graph export "$FIGPNG/08_markups_mono_vs_multi.png", replace width(2800)

* 9. Preço observado versus markup multiproduto.
twoway (scatter markup_multiproduct price, msymbol(circle) mcolor(navy)), ///
    title("Preço observado e markup multiproduto", size(medsmall) color(black)) ///
    xtitle("Preço observado") ytitle("Markup multiproduto") ///
    legend(off) ///
    `GBASE' `GRIDXY'
graph export "$FIGPDF/09_price_vs_multiproduct_markup.pdf", replace
graph export "$FIGPNG/09_price_vs_multiproduct_markup.png", replace width(2800)

* 19. Distribuição dos markups multiproduto: histograma + densidade kernel.
histogram markup_multiproduct, density kdensity ///
    fcolor(navy) lcolor(white) ///
    kdenopts(lcolor(cranberry) lwidth(medthick)) ///
    xline(0, `ZERO_LINE') ///
    title("Distribuição dos markups multiproduto", size(medsmall) color(black)) ///
    xtitle("Markup multiproduto") ///
    ytitle("Densidade") ///
    `GBASE' `GRIDXY'
graph export "$FIGPDF/19_markup_multiproduct_hist_density.pdf", replace
graph export "$FIGPNG/19_markup_multiproduct_hist_density.png", replace width(2800)

* 21. Boxplot dos markups multiproduto.
graph box markup_multiproduct, ///
    yline(0, `ZERO_LINE') ///
    title("Boxplot dos markups multiproduto", size(medsmall) color(black)) ///
    ytitle("Markup multiproduto") ///
    box(1, fcolor(navy) lcolor(navy)) ///
    marker(1, mcolor(navy)) ///
    `GBASE' `GRIDY'
graph export "$FIGPDF/21_markup_multiproduct_boxplot.pdf", replace
graph export "$FIGPNG/21_markup_multiproduct_boxplot.png", replace width(2800)

* 10. Diagnóstico de força dos instrumentos: F/Wald-F robusto dos primeiros estágios.
use "$OUTDATA/prepared_data_stata.dta", clear
global ZOWN "own_cals own_fat own_sugar"
global ZRIVAL "rival_cals rival_fat rival_sugar"
global ZBOTH "$ZOWN $ZRIVAL"
global ZNEST "n_same_nest_other n_rival_nest nest_own_cals nest_own_fat nest_own_sugar nest_rival_cals nest_rival_fat nest_rival_sugar"
global ZNESTALL "$ZOWN $ZRIVAL $ZNEST"
reg price $XVARS $ZBOTH, vce(robust)
test $ZBOTH
scalar F_simple = r(F)
reg price $XVARS $ZNESTALL, vce(robust)
test $ZNESTALL
scalar F_nested_price = r(F)
reg log_share_within_nest $XVARS $ZNESTALL, vce(robust)
test $ZNESTALL
scalar F_nested_lnsjg = r(F)
clear
set obs 3
gen str32 endogenous_variable = ""
replace endogenous_variable = "price_simple" in 1
replace endogenous_variable = "price_nested" in 2
replace endogenous_variable = "ln(s_j|g)" in 3
gen robust_Wald_F_manual = .
replace robust_Wald_F_manual = F_simple in 1
replace robust_Wald_F_manual = F_nested_price in 2
replace robust_Wald_F_manual = F_nested_lnsjg in 3
export delimited using "$OUTDATA/first_stage_diagnostics_for_graph_stata.csv", replace
graph bar robust_Wald_F_manual, over(endogenous_variable, label(labsize(small))) ///
    yline(10, `ZERO_LINE') ///
    title("Diagnóstico de força dos instrumentos", size(medsmall) color(black)) ///
    ytitle("F/Wald-F robusto") ///
    bar(1, fcolor(navy) lcolor(navy)) ///
    `GBASE' `GRIDY'
graph export "$FIGPDF/10_first_stage_robust_f.pdf", replace
graph export "$FIGPNG/10_first_stage_robust_f.png", replace width(2800)

/****************************************************************************************
11--17 - Gráficos clássicos e diagnósticos estatísticos do logit simples
- A curva em S é produzida por simulação: mantém-se a concorrência e as características
  fixas e varia-se a utilidade média ou o preço de um produto focal.
- O produto focal é escolhido automaticamente como o produto de maior market share.
- Os gráficos estatísticos adicionais avaliam ajuste previsto, distribuição dos resíduos
  e formato da resposta ao preço implicada pelo modelo.
****************************************************************************************/

use "$OUTDATA/stata_after_simple_gmm.dta", clear

global ZOWN "own_cals own_fat own_sugar"
global ZRIVAL "rival_cals rival_fat rival_sugar"
global ZBOTH "$ZOWN $ZRIVAL"

capture estimates restore GMM_both_2
if _rc {
    gmm (delta - {b0} - {bcals}*cals - {bfat}*fat - {bsugar}*sugar - {bp}*price), ///
        instruments($XVARS $ZBOTH) twostep winitial(unadjusted) vce(robust)
}

scalar b0logit = _b[/b0]
scalar bcalslogit = _b[/bcals]
scalar bfatlogit = _b[/bfat]
scalar bsugarlogit = _b[/bsugar]
scalar pricecoeflogit = _b[/bp]

/*
Correção para os gráficos de curva de demanda e efeito marginal:
- Em Stata, pricecoeflogit é o coeficiente estimado diretamente sobre price.
- Pela notação da lista, esse coeficiente corresponde a -alpha.
- Como as curvas didáticas 12, 13 e 17 devem representar demanda decrescente,
  usamos alpha_plot_logit = abs(pricecoeflogit) e a inclinação simulada
  price_slope_plot = -alpha_plot_logit.
- Se o coeficiente estimado vier positivo por ruído/endogeneidade/fragilidade dos
  instrumentos, o gráfico deixa isso registrado em nota, mas não desenha uma
  curva de demanda positivamente inclinada.
*/
scalar alpha_plot_logit = abs(pricecoeflogit)
scalar price_slope_plot = -alpha_plot_logit

local note_slope "Inclinação do preço usada nas curvas: -|coeficiente estimado do preço|, garantindo demanda decrescente."
if (pricecoeflogit < 0) {
    local note_slope "Inclinação do preço usada nas curvas igual ao coeficiente estimado, pois ele já é negativo."
}

gen v_no_price = b0logit + bcalslogit*cals + bfatlogit*fat + bsugarlogit*sugar
gen vhat_logit = v_no_price + pricecoeflogit*price
gen expv_logit = exp(vhat_logit)
egen total_exp_logit = total(expv_logit)
gen share_pred_logit = expv_logit/(1 + total_exp_logit)

* Intercepto ajustado para curvas didáticas decrescentes, preservando o
* índice médio previsto no preço observado de cada produto.
gen v_intercept_plot = vhat_logit - price_slope_plot*price

gsort -share
scalar focal_vhat = vhat_logit[1]
scalar focal_price = price[1]
scalar focal_share = share[1]
scalar focal_v_no_price = v_no_price[1]
scalar focal_v_intercept_plot = v_intercept_plot[1]
scalar focal_expv = expv_logit[1]
scalar total_exp_scalar = total_exp_logit[1]
scalar C_focal = 1 + total_exp_scalar - focal_expv
scalar rel_observed_index = focal_vhat - ln(C_focal)

* 11. Curva clássica em S: share previsto contra utilidade relativa V_j - ln(C_j).
* Nessa escala, s_j = 1/(1 + exp(-(V_j - ln C_j))).
preserve
    clear
    set obs 250
    gen rel_grid = -6 + (_n - 1)*(12/249)
    gen share_pred = 1/(1 + exp(-rel_grid))
    twoway (line share_pred rel_grid, lcolor(navy) lwidth(medthick)), ///
        title("Curva clássica do logit - produto focal", size(medsmall) color(black)) ///
        xtitle("`L_VREL'") ///
        ytitle("`L_SJ'") ///
        legend(off) ///
        `GBASE' `GRIDXY'
    graph export "$FIGPDF/11_classic_logit_curve_share_vs_utility.pdf", replace
    graph export "$FIGPNG/11_classic_logit_curve_share_vs_utility.png", replace width(2800)
restore

* 12. Share previsto contra preço simulado do produto focal.
scalar p_low = max(0.01, 0.5*focal_price)
scalar p_high = 1.5*focal_price
preserve
    clear
    set obs 250
    gen price_grid = p_low + (_n - 1)*((p_high - p_low)/249)
    gen v_price = focal_v_intercept_plot + price_slope_plot*price_grid
    gen share_pred = exp(v_price)/(C_focal + exp(v_price))
    twoway (line share_pred price_grid, lcolor(navy) lwidth(medthick)), ///
        title("Resposta do share ao preço - produto focal", size(medsmall) color(black)) ///
        xtitle("`L_PRICEJ'") ///
        ytitle("`L_SJ'") ///
        note("`note_slope'", size(vsmall)) ///
        legend(off) ///
        `GBASE' `GRIDXY'
    graph export "$FIGPDF/12_focal_product_share_vs_price.pdf", replace
    graph export "$FIGPNG/12_focal_product_share_vs_price.png", replace width(2800)
restore

* 13. Efeito marginal ds_j/dp_j ao longo da curva simulada de preço.
preserve
    clear
    set obs 250
    gen price_grid = p_low + (_n - 1)*((p_high - p_low)/249)
    gen v_price = focal_v_intercept_plot + price_slope_plot*price_grid
    gen share_pred = exp(v_price)/(C_focal + exp(v_price))

    * Efeito marginal próprio correto: ds_j/dp_j = -alpha*s_j*(1-s_j).
    * Como price_slope_plot = -alpha_plot_logit < 0, a curva fica abaixo de zero.
    gen marginal_effect = price_slope_plot*share_pred*(1-share_pred)

    twoway (line marginal_effect price_grid, lcolor(cranberry) lwidth(medthick)), ///
        yline(0, `ZERO_LINE') ///
        title("Efeito marginal do preço - produto focal", size(medsmall) color(black)) ///
        xtitle("`L_PRICEJ'") ///
        ytitle("`L_DSDP'") ///
        note("`note_slope'", size(vsmall)) ///
        legend(off) ///
        `GBASE' `GRIDXY'
    graph export "$FIGPDF/13_focal_product_marginal_effect_vs_price.pdf", replace
    graph export "$FIGPNG/13_focal_product_marginal_effect_vs_price.png", replace width(2800)
restore

* 14. Share observado versus share previsto pelo logit simples.
summarize share share_pred_logit, meanonly
local lo = min(r(min), r(min))
quietly summarize share
local min_obs = r(min)
local max_obs = r(max)
quietly summarize share_pred_logit
local min_pred = r(min)
local max_pred = r(max)
local lo = min(`min_obs', `min_pred')
local hi = max(`max_obs', `max_pred')
twoway (scatter share share_pred_logit, msymbol(circle) mcolor(navy)) ///
       (function y=x, range(`lo' `hi') lcolor(cranberry) lpattern(dash) lwidth(medthick)), ///
    title("Share observado versus previsto", size(medsmall) color(black)) ///
    xtitle("`L_SJ'") ///
    ytitle("`L_SOBS'") ///
    legend(off) ///
    `GBASE' `GRIDXY'
graph export "$FIGPDF/14_observed_vs_predicted_shares_simple_logit.pdf", replace
graph export "$FIGPNG/14_observed_vs_predicted_shares_simple_logit.png", replace width(2800)

* 15. Histograma dos resíduos estruturais com curva de densidade kernel.
histogram xi_gmm_both, density kdensity ///
    fcolor(navy) lcolor(white) ///
    kdenopts(lcolor(cranberry) lwidth(medthick)) ///
    xline(0, `ZERO_LINE') ///
    title("Distribuição dos resíduos estruturais ({&xi}{subscript:j})", size(medsmall) color(black)) ///
    xtitle("`L_XI'") ///
    ytitle("Densidade") ///
    `GBASE' `GRIDXY'
graph export "$FIGPDF/15_structural_residual_hist_density.pdf", replace
graph export "$FIGPNG/15_structural_residual_hist_density.png", replace width(2800)

* 16. QQ plot dos resíduos estruturais.
qnorm xi_gmm_both, ///
    mcolor(navy) msymbol(circle) ///
    rlopts(lcolor(cranberry) lwidth(medthick)) ///
    title("QQ plot dos resíduos estruturais ({&xi}{subscript:j})", size(medsmall) color(black)) ///
    ytitle("Quantis de {&xi}{subscript:j}") ///
    xtitle("Quantis teóricos normais") ///
    `GBASE' `GRIDXY'
graph export "$FIGPDF/16_structural_residual_qqplot.pdf", replace
graph export "$FIGPNG/16_structural_residual_qqplot.png", replace width(2800)

* 17. Curvas de resposta ao preço dos cinco maiores produtos.
preserve
    keep product share price v_no_price vhat_logit v_intercept_plot expv_logit
    gsort -share
    keep in 1/5
    gen id = _n
    gen C_i = 1 + total_exp_scalar - expv_logit
    tempfile top5_logit
    save `top5_logit', replace

    clear
    set obs 200
    gen grid_id = _n
    gen grid_scale = 0.5 + (_n - 1)*(1/199)
    tempfile grid_logit
    save `grid_logit', replace

    use `top5_logit', clear
    cross using `grid_logit'
    gen price_grid = price*grid_scale
    gen v_grid = v_intercept_plot + price_slope_plot*price_grid
    gen share_grid = exp(v_grid)/(C_i + exp(v_grid))

    twoway ///
        (line share_grid price_grid if id==1, sort lcolor(navy) lwidth(medthick)) ///
        (line share_grid price_grid if id==2, sort lcolor(cranberry) lwidth(medthick)) ///
        (line share_grid price_grid if id==3, sort lcolor(forest_green) lwidth(medthick)) ///
        (line share_grid price_grid if id==4, sort lcolor(dkorange) lwidth(medthick)) ///
        (line share_grid price_grid if id==5, sort lcolor(purple) lwidth(medthick)), ///
        title("Curvas de resposta ao preço - top 5 produtos", size(medsmall) color(black)) ///
        xtitle("Preço simulado ({it:p}{subscript:j})") ///
        ytitle("`L_SJ'") ///
        note("`note_slope'", size(vsmall)) ///
        legend(order(1 "Produto 1" 2 "Produto 2" 3 "Produto 3" 4 "Produto 4" 5 "Produto 5") position(3) ring(1) cols(1) region(lcolor(none) fcolor(none)) size(small)) ///
        `GBASE' `GRIDXY'
    graph export "$FIGPDF/17_price_response_curves_top5_products.pdf", replace
    graph export "$FIGPNG/17_price_response_curves_top5_products.png", replace width(2800)
restore
