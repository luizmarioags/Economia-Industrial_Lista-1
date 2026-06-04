/****************************************************************************************
COMENTÁRIOS DETALHADOS
- Este script replica em Stata as visualizações extras da rotina Python.
- extra_01 e extra_02 agregam market shares por firma e por nest.
- extra_03 resume características médias por segmento para cals, fat e sugar.
- extra_04 transforma a matriz de correlação dos instrumentos em uma grade visual.
- extra_05 e extra_06 usam resíduos estruturais do GMM principal para diagnóstico.
- extra_07 compara preço observado e preço ajustado no primeiro estágio.
****************************************************************************************/
/****************************************************************************************
07 - Visualizações extras para enriquecer a resposta com tema visual aplicado
****************************************************************************************/


/****************************************************************************************
Rótulos matemáticos para gráficos do Stata via SMCL.
****************************************************************************************/
local L_XI `"{&xi}{subscript:j} estimado"'
local L_SHARE_AGG `"Market share agregado"'

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


use "$OUTDATA/prepared_data_stata.dta", clear

* extra_01: concentração de market share por firma.
preserve
    collapse (sum) share, by(firm)
    graph hbar share, over(firm, sort(share) descending label(labsize(vsmall))) ///
        title("Concentração de market share por firma", size(medsmall) color(black)) ///
        ytitle("`L_SHARE_AGG'") ///
        bar(1, fcolor(navy) lcolor(navy)) ///
        `GBASE' `GRIDHBAR'
    graph export "$FIGPDF/extra_01_firm_share_concentration.pdf", replace
    graph export "$FIGPNG/extra_01_firm_share_concentration.png", replace width(2800)
restore

* extra_02: tamanho dos nests/segmentos.
preserve
    collapse (sum) share, by(segment)
    graph bar share, over(segment, label(labsize(small))) ///
        title("Tamanho dos nests", size(medsmall) color(black)) ///
        ytitle("`L_SHARE_AGG'") ///
        bar(1, fcolor(navy) lcolor(navy)) ///
        `GBASE' `GRIDY'
    graph export "$FIGPDF/extra_02_nest_sizes.pdf", replace
    graph export "$FIGPNG/extra_02_nest_sizes.png", replace width(2800)
restore

* extra_03: médias de características por segmento.
foreach x in cals fat sugar {
    preserve
        collapse (mean) `x', by(segment)
        graph bar `x', over(segment, label(labsize(small))) ///
            title("Média de `x' por segmento", size(medsmall) color(black)) ///
            ytitle("`x'") ///
            bar(1, fcolor(navy) lcolor(navy)) ///
            `GBASE' `GRIDY'
        graph export "$FIGPDF/extra_03_mean_`x'_by_segment.pdf", replace
        graph export "$FIGPNG/extra_03_mean_`x'_by_segment.png", replace width(2800)
    restore
}

* extra_04: correlação entre instrumentos excluídos.
global ZOWN "own_cals own_fat own_sugar"
global ZRIVAL "rival_cals rival_fat rival_sugar"
global ZNEST "n_same_nest_other n_rival_nest nest_own_cals nest_own_fat nest_own_sugar nest_rival_cals nest_rival_fat nest_rival_sugar"
global ZNESTALL "$ZOWN $ZRIVAL $ZNEST"
corr $ZNESTALL
matrix C = r(C)
clear
svmat C, names(c)
gen row = _n
reshape long c, i(row) j(col)
gen label_c = string(c, "%4.2f")
twoway (scatter row col, msymbol(square) msize(large) mcolor(navy)) ///
       (scatter row col, msymbol(none) mlabel(label_c) mlabsize(tiny) mlabcolor(white)), ///
       title("Correlação entre instrumentos excluídos", size(medsmall) color(black)) ///
       xtitle("Instrumento") ytitle("Instrumento") ///
       xlabel(1(1)14, labsize(vsmall) grid glcolor(gs14) glpattern(dash)) ///
       ylabel(1(1)14, labsize(vsmall) grid glcolor(gs14) glpattern(dash)) ///
       legend(off) ///
       `GBASE'
graph export "$FIGPDF/extra_04_instrument_correlation_matrix.pdf", replace
graph export "$FIGPNG/extra_04_instrument_correlation_matrix.png", replace width(2800)

* extra_05: resíduos estruturais contra preço.
use "$OUTDATA/stata_after_simple_gmm.dta", clear
twoway (scatter xi_gmm_both price, msymbol(circle) mcolor(navy)) ///
       (lowess xi_gmm_both price, lcolor(cranberry) lwidth(medthick)), ///
    yline(0, `ZERO_LINE') ///
    title("Resíduos estruturais ({&xi}{subscript:j}) e preço", size(medsmall) color(black)) ///
    subtitle("Com curva de ajuste não linear LOWESS", size(small) color(black)) ///
    xtitle("Preço de transação") ///
    ytitle("`L_XI'") ///
    legend(order(1 "Resíduos estruturais" 2 "Ajuste não linear LOWESS") position(3) ring(1) cols(1) region(lcolor(none) fcolor(none)) size(small)) ///
    `GBASE' `GRIDXY'
graph export "$FIGPDF/extra_05_structural_residuals_vs_price.pdf", replace
graph export "$FIGPNG/extra_05_structural_residuals_vs_price.png", replace width(2800)

* extra_06: resíduos estruturais por firma.
graph box xi_gmm_both, over(firm, label(labsize(vsmall))) ///
    yline(0, `ZERO_LINE') ///
    title("Resíduos estruturais ({&xi}{subscript:j}) por firma", size(medsmall) color(black)) ///
    ytitle("`L_XI'") ///
    box(1, fcolor(navy) lcolor(navy)) ///
    marker(1, mcolor(navy)) ///
    `GBASE' `GRIDY'
graph export "$FIGPDF/extra_06_structural_residuals_by_firm.pdf", replace
graph export "$FIGPNG/extra_06_structural_residuals_by_firm.png", replace width(2800)

* extra_07: primeiro estágio, preço observado versus ajustado.
use "$OUTDATA/prepared_data_stata.dta", clear
global ZBOTH "$ZOWN $ZRIVAL"
reg price $XVARS $ZBOTH
predict price_hat, xb
summarize price price_hat
local lo = min(r(min), r(min))
quietly summarize price
local minp = r(min)
local maxp = r(max)
quietly summarize price_hat
local minh = r(min)
local maxh = r(max)
local lo = min(`minp', `minh')
local hi = max(`maxp', `maxh')
twoway (scatter price_hat price, msymbol(circle) mcolor(navy)) ///
       (function y=x, range(`lo' `hi') lcolor(cranberry) lpattern(dash) lwidth(medthick)), ///
    title("Primeiro estágio: preço observado vs ajustado", size(medsmall) color(black)) ///
    xtitle("Preço observado") ///
    ytitle("Preço ajustado no primeiro estágio") ///
    legend(off) ///
    `GBASE' `GRIDXY'
graph export "$FIGPDF/extra_07_first_stage_price_fit.pdf", replace
graph export "$FIGPNG/extra_07_first_stage_price_fit.png", replace width(2800)
