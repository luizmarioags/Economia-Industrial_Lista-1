/*******************************************************************************
Arquivo: stata/05_visualizations_aids_stata.do
Objetivo: gerar gráficos, matrizes e tabelas visuais para dados e resultados.
*******************************************************************************/

do "stata/00_config_aids.do"                       // Carrega caminhos, macros e opções gerais.

log using "$LOGS/05_visualizations_aids_stata.log", replace text // Abre log dos gráficos.

********************************************************************************
* Garantia dos subdiretorios de exportacao.
* Este bloco evita o erro r(691) quando as pastas PDF/PNG ainda nao existem
* ou quando o usuario rodou o script com uma versao antiga do config.
********************************************************************************
if "${FIGURES}" == "" {
    global FIGURES "$ROOT/output/figures"
}
if "${FIGURES_PDF}" == "" {
    global FIGURES_PDF "$FIGURES/PDF"
}
if "${FIGURES_PNG}" == "" {
    global FIGURES_PNG "$FIGURES/PNG"
}
capture mkdir "$FIGURES"
capture mkdir "$FIGURES_PDF"
capture mkdir "$FIGURES_PNG"

use "$PROC_DTA", clear                             // Abre dados processados.


********************************************************************************
* Rotulos explicativos para graficos.
* Estes rotulos substituem codigos da base, como bfvl, pork, poult e fish,
* por nomes economicos compreensiveis nas legendas, titulos e eixos.
********************************************************************************
label variable w_bfvl      "Carne bovina e vitela"
label variable w_pork      "Carne suina"
label variable w_poult     "Frango"
label variable w_fish      "Pescados"
label variable bfvlp       "Carne bovina e vitela"
label variable porkp       "Carne suina"
label variable poultp      "Frango"
label variable fishp       "Pescados"
label variable lngp_bfvl   "Carne bovina e vitela"
label variable lngp_pork   "Carne suina"
label variable lngp_poult  "Frango"
label variable lngp_fish   "Pescados"
label variable xbfvl       "Carne bovina e vitela"
label variable xpork       "Carne suina"
label variable xpoult      "Frango"
label variable xfish       "Pescados"


********************************************************************************
* Template visual dos graficos.
* O padrao segue o arquivo de referencia enviado pelo usuario:
* fundo branco, paleta discreta, linhas mais grossas, grade clara,
* legenda a direita e rotulos pequenos nos eixos.
********************************************************************************
set scheme s2color
graph set window fontface "Arial"

local cor_bovina   "navy"
local cor_suina    "cranberry"
local cor_frango   "forest_green"
local cor_pescados "orange"
local cor_extra    "purple"

local tema_base "graphregion(color(white)) plotregion(color(white)) bgcolor(white)"
local eixo_grid "xlabel(, labsize(small) grid glcolor(gs14)) ylabel(, labsize(small) grid glcolor(gs14))"
local legenda4  `"legend(order(1 "Carne bovina e vitela" 2 "Carne suina" 3 "Frango" 4 "Pescados") cols(1) size(small) position(3) ring(1) region(lcolor(none) fcolor(none)))"'
local legenda3  `"legend(order(1 "Carne bovina e vitela" 2 "Carne suina" 3 "Pescados") cols(1) size(small) position(3) ring(1) region(lcolor(none) fcolor(none)))"'


********************************************************************************
* Visualizações descritivas dos dados.
********************************************************************************

twoway ///
    (line w_bfvl  year, lcolor(`cor_bovina')   lwidth(medthick)) ///
    (line w_pork  year, lcolor(`cor_suina')    lwidth(medthick)) ///
    (line w_poult year, lcolor(`cor_frango')   lwidth(medthick)) ///
    (line w_fish  year, lcolor(`cor_pescados') lwidth(medthick)), ///
    title("Participacoes no dispendio com carnes", size(medsmall)) ///
    xtitle("Ano", size(small)) ///
    ytitle("Participacao do produto no gasto total com carnes", size(small)) ///
    `legenda4' `eixo_grid' `tema_base' ///
    name(g_shares, replace) // Gráfico de participações.
graph export "$FIGURES_PDF/stata_01_participacoes_dispendio.pdf", replace        // Exporta participações em PDF.
graph export "$FIGURES_PNG/stata_01_participacoes_dispendio.png", replace width(2400) // Exporta participações em PNG.

twoway ///
    (line bfvlp  year, lcolor(`cor_bovina')   lwidth(medthick)) ///
    (line porkp  year, lcolor(`cor_suina')    lwidth(medthick)) ///
    (line poultp year, lcolor(`cor_frango')   lwidth(medthick)) ///
    (line fishp  year, lcolor(`cor_pescados') lwidth(medthick)), ///
    title("Índices de preços das carnes", size(medsmall)) ///
    xtitle("Ano", size(small)) ///
    ytitle("Índice de preço do produto", size(small)) ///
    `legenda4' `eixo_grid' `tema_base' ///
    name(g_prices, replace) // Gráfico dos preços.
graph export "$FIGURES_PDF/stata_02_precos.pdf", replace                         // Exporta preços em PDF.
graph export "$FIGURES_PNG/stata_02_precos.png", replace width(2400)             // Exporta preços em PNG.

twoway ///
    (line lngp_bfvl  year, lcolor(`cor_bovina')   lwidth(medthick)) ///
    (line lngp_pork  year, lcolor(`cor_suina')    lwidth(medthick)) ///
    (line lngp_poult year, lcolor(`cor_frango')   lwidth(medthick)) ///
    (line lngp_fish  year, lcolor(`cor_pescados') lwidth(medthick)), ///
    yline(0, lcolor(black) lpattern(dash) lwidth(thin)) ///
    title("Preços em log normalizados pela média temporal", size(medsmall)) ///
    xtitle("Ano", size(small)) ///
    ytitle("Desvio logarítmico do preço em relação à média", size(small)) ///
    `legenda4' `eixo_grid' `tema_base' ///
    name(g_lngp, replace) // Gráfico dos log-preços normalizados.
graph export "$FIGURES_PDF/stata_03_log_precos_normalizados.pdf", replace        // Exporta log-preços em PDF.
graph export "$FIGURES_PNG/stata_03_log_precos_normalizados.png", replace width(2400) // Exporta log-preços em PNG.

twoway ///
    (line xbfvl  year, lcolor(`cor_bovina')   lwidth(medthick)) ///
    (line xpork  year, lcolor(`cor_suina')    lwidth(medthick)) ///
    (line xpoult year, lcolor(`cor_frango')   lwidth(medthick)) ///
    (line xfish  year, lcolor(`cor_pescados') lwidth(medthick)), ///
    title("Dispendio anual por tipo de carne", size(medsmall)) ///
    xtitle("Ano", size(small)) ///
    ytitle("Dispendio do produto", size(small)) ///
    `legenda4' `eixo_grid' `tema_base' ///
    name(g_exp, replace) // Gráfico dos dispêndios.
graph export "$FIGURES_PDF/stata_04_dispendios_produto.pdf", replace             // Exporta dispêndios em PDF.
graph export "$FIGURES_PNG/stata_04_dispendios_produto.png", replace width(2400) // Exporta dispêndios em PNG.

twoway ///
    (line xtotal_calc year, lcolor(`cor_bovina') lwidth(medthick)), ///
    title("Dispendio total com os quatro produtos de carne", size(medsmall)) ///
    xtitle("Ano", size(small)) ///
    ytitle("Dispendio total com carnes", size(small)) ///
    legend(off) `eixo_grid' `tema_base' ///
    name(g_xtotal, replace) // Gráfico do dispêndio total.
graph export "$FIGURES_PDF/stata_05_dispendio_total_carnes.pdf", replace         // Exporta dispêndio total em PDF.
graph export "$FIGURES_PNG/stata_05_dispendio_total_carnes.png", replace width(2400) // Exporta dispêndio total em PNG.

twoway ///
    (line lnP_stone year, lcolor(`cor_bovina') lwidth(medthick)) ///
    (line ln_real_x year, lcolor(`cor_suina')  lwidth(medthick)), ///
    title("Indice de Stone e dispendio real com carnes", size(medsmall)) ///
    xtitle("Ano", size(small)) ///
    ytitle("Valor em logaritmo", size(small)) ///
    legend(order(1 "Indice de Stone" 2 "Dispendio real com carnes") cols(1) size(small) position(3) ring(1) region(lcolor(none) fcolor(none))) ///
    `eixo_grid' `tema_base' ///
    name(g_stone, replace) // Gráfico do índice de Stone e dispêndio real.
graph export "$FIGURES_PDF/stata_06_stone_dispendio_real.pdf", replace           // Exporta Stone/real em PDF.
graph export "$FIGURES_PNG/stata_06_stone_dispendio_real.png", replace width(2400) // Exporta Stone/real em PNG.

capture confirm variable meat_pce_share                                      // Verifica se a razão carnes/PCE existe.
if !_rc {                                                                     // Entra se a variável existir.
    twoway (line meat_pce_share year, lcolor(`cor_bovina') lwidth(medthick)), title("Peso do dispendio com carnes no consumo agregado", size(medsmall)) xtitle("Ano", size(small)) ytitle("Participacao do gasto com carnes no consumo agregado", size(small)) legend(off) `eixo_grid' `tema_base' name(g_pce, replace) // Gráfico do peso no PCE.
    graph export "$FIGURES_PDF/stata_07_peso_carnes_pce.pdf", replace             // Exporta peso no PCE em PDF.
    graph export "$FIGURES_PNG/stata_07_peso_carnes_pce.png", replace width(2400) // Exporta peso no PCE em PNG.
}                                                                             // Fecha condição do PCE.

twoway ///
    (line share_sum year, lcolor(`cor_bovina') lwidth(medthick)), ///
    yline(1, lcolor(black) lpattern(dash) lwidth(thin)) ///
    title("Checagem da soma das participacoes no dispendio", size(medsmall)) ///
    xtitle("Ano", size(small)) ///
    ytitle("Soma das participacoes", size(small)) ///
    legend(off) `eixo_grid' `tema_base' ///
    name(g_add, replace) // Gráfico da soma das participações.
graph export "$FIGURES_PDF/stata_08_checagem_soma_participacoes.pdf", replace     // Exporta checagem em PDF.
graph export "$FIGURES_PNG/stata_08_checagem_soma_participacoes.png", replace width(2400) // Exporta checagem em PNG.

* Para matrizes de dispersao, usa-se o padrao nativo do Stata.
* O template customizado deixa esse tipo de grafico poluido.
label variable w_bfvl "w_bfvl"
label variable w_pork "w_pork"
label variable w_poult "w_poult"
label variable w_fish "w_fish"
graph matrix w_bfvl w_pork w_poult w_fish, ///
    title("Matriz de dispersao das participacoes no dispendio") ///
    name(g_matrix_shares, replace) // Matriz de dispersão das participações no padrão Stata.
graph export "$FIGURES_PDF/stata_09_matriz_dispersao_participacoes.pdf", replace // Exporta matriz de participações.
graph export "$FIGURES_PNG/stata_09_matriz_dispersao_participacoes.png", replace width(2400) // Exporta matriz em PNG.

label variable lngp_bfvl "lngp_bfvl"
label variable lngp_pork "lngp_pork"
label variable lngp_poult "lngp_poult"
label variable lngp_fish "lngp_fish"
graph matrix lngp_bfvl lngp_pork lngp_poult lngp_fish, ///
    title("Matriz de dispersão dos preços normalizados") ///
    name(g_matrix_prices, replace) // Matriz de dispersão dos preços no padrão Stata.
graph export "$FIGURES_PDF/stata_10_matriz_dispersao_precos.pdf", replace        // Exporta matriz de preços.
graph export "$FIGURES_PNG/stata_10_matriz_dispersao_precos.png", replace width(2400) // Exporta matriz em PNG.

* Restaura rotulos explicativos para os graficos seguintes.
label variable w_bfvl      "Carne bovina e vitela"
label variable w_pork      "Carne suina"
label variable w_poult     "Frango"
label variable w_fish      "Pescados"
label variable lngp_bfvl   "Carne bovina e vitela"
label variable lngp_pork   "Carne suina"
label variable lngp_poult  "Frango"
label variable lngp_fish   "Pescados"

pwcorr w_bfvl w_pork w_poult w_fish, sig star(.05)                            // Calcula correlações entre participações.
matrix C_w = r(C)                                                             // Guarda matriz de correlação das participações.
pwcorr lngp_bfvl lngp_pork lngp_poult lngp_fish, sig star(.05)                // Calcula correlações entre preços.
matrix C_p = r(C)                                                             // Guarda matriz de correlação dos preços.
putexcel set "$TABLES/matrizes_correlacao_stata.xlsx", replace                // Cria planilha de correlações.
putexcel A1 = matrix(C_w), names                                              // Exporta correlação das participações.
putexcel A10 = matrix(C_p), names                                             // Exporta correlação dos preços.

********************************************************************************
* Ajuste, resíduos e observado versus previsto para o modelo final.
********************************************************************************

estimates use "$MODELS/aids_hsym.ster"                 // Carrega modelo final com homogeneidade e simetria.

scalar a_bfvl = _b[/a_bfvl]                            // Guarda intercepto de bfvl.
scalar a_pork = _b[/a_pork]                            // Guarda intercepto de pork.
scalar a_fish = _b[/a_fish]                            // Guarda intercepto de fish.
scalar b_bfvl = _b[/b_bfvl]                            // Guarda beta de bfvl.
scalar b_pork = _b[/b_pork]                            // Guarda beta de pork.
scalar b_fish = _b[/b_fish]                            // Guarda beta de fish.
scalar g11 = _b[/g11]                                  // Guarda gamma 11.
scalar g12 = _b[/g12]                                  // Guarda gamma 12.
scalar g14 = _b[/g14]                                  // Guarda gamma 14.
scalar g22 = _b[/g22]                                  // Guarda gamma 22.
scalar g24 = _b[/g24]                                  // Guarda gamma 24.
scalar g44 = _b[/g44]                                  // Guarda gamma 44.

gen double fit_bfvl = a_bfvl + g11*(lngp_bfvl-lngp_poult) + g12*(lngp_pork-lngp_poult) + g14*(lngp_fish-lngp_poult) + b_bfvl*ln_real_x // Calcula participação prevista de bfvl.
gen double fit_pork = a_pork + g12*(lngp_bfvl-lngp_poult) + g22*(lngp_pork-lngp_poult) + g24*(lngp_fish-lngp_poult) + b_pork*ln_real_x // Calcula participação prevista de pork.
gen double fit_fish = a_fish + g14*(lngp_bfvl-lngp_poult) + g24*(lngp_pork-lngp_poult) + g44*(lngp_fish-lngp_poult) + b_fish*ln_real_x // Calcula participação prevista de fish.

gen double res_bfvl = w_bfvl - fit_bfvl                // Calcula resíduo de bfvl.
gen double res_pork = w_pork - fit_pork                // Calcula resíduo de pork.
gen double res_fish = w_fish - fit_fish                // Calcula resíduo de fish.
label variable res_bfvl "Carne bovina e vitela"                    // Rotula residuo para graficos.
label variable res_pork "Carne suina"                              // Rotula residuo para graficos.
label variable res_fish "Pescados"                                  // Rotula residuo para graficos.

twoway (scatter w_bfvl fit_bfvl, mcolor(`cor_bovina') msymbol(circle) msize(medium)) (lfit w_bfvl fit_bfvl, lcolor(`cor_suina') lwidth(medthick)), title("Observado versus previsto: carne bovina e vitela", size(medsmall)) xtitle("Participacao prevista", size(small)) ytitle("Participacao observada", size(small)) legend(order(1 "Observacoes anuais" 2 "Ajuste linear") cols(1) size(small) position(3) ring(1) region(lcolor(none) fcolor(none))) `eixo_grid' `tema_base' name(g_fit_bfvl, replace) // Gráfico observado-previsto de bfvl.
graph export "$FIGURES_PDF/stata_11_observado_previsto_bfvl.pdf", replace         // Exporta observado-previsto bfvl.
graph export "$FIGURES_PNG/stata_11_observado_previsto_bfvl.png", replace width(2400) // Exporta observado-previsto bfvl PNG.

twoway (scatter w_pork fit_pork, mcolor(`cor_bovina') msymbol(circle) msize(medium)) (lfit w_pork fit_pork, lcolor(`cor_suina') lwidth(medthick)), title("Observado versus previsto: carne suina", size(medsmall)) xtitle("Participacao prevista", size(small)) ytitle("Participacao observada", size(small)) legend(order(1 "Observacoes anuais" 2 "Ajuste linear") cols(1) size(small) position(3) ring(1) region(lcolor(none) fcolor(none))) `eixo_grid' `tema_base' name(g_fit_pork, replace) // Gráfico observado-previsto de pork.
graph export "$FIGURES_PDF/stata_12_observado_previsto_pork.pdf", replace         // Exporta observado-previsto pork.
graph export "$FIGURES_PNG/stata_12_observado_previsto_pork.png", replace width(2400) // Exporta observado-previsto pork PNG.

twoway (scatter w_fish fit_fish, mcolor(`cor_bovina') msymbol(circle) msize(medium)) (lfit w_fish fit_fish, lcolor(`cor_suina') lwidth(medthick)), title("Observado versus previsto: pescados", size(medsmall)) xtitle("Participacao prevista", size(small)) ytitle("Participacao observada", size(small)) legend(order(1 "Observacoes anuais" 2 "Ajuste linear") cols(1) size(small) position(3) ring(1) region(lcolor(none) fcolor(none))) `eixo_grid' `tema_base' name(g_fit_fish, replace) // Gráfico observado-previsto de fish.
graph export "$FIGURES_PDF/stata_13_observado_previsto_fish.pdf", replace         // Exporta observado-previsto fish.
graph export "$FIGURES_PNG/stata_13_observado_previsto_fish.png", replace width(2400) // Exporta observado-previsto fish PNG.

twoway ///
    (line res_bfvl year, lcolor(`cor_bovina')   lwidth(medthick)) ///
    (line res_pork year, lcolor(`cor_suina')    lwidth(medthick)) ///
    (line res_fish year, lcolor(`cor_pescados') lwidth(medthick)), ///
    yline(0, lcolor(black) lpattern(dash) lwidth(thin)) ///
    title("Residuos por equacao estimada", size(medsmall)) ///
    xtitle("Ano", size(small)) ///
    ytitle("Diferenca entre participacao observada e prevista", size(small)) ///
    `legenda3' `eixo_grid' `tema_base' ///
    name(g_resid, replace) // Resíduos por tempo.
graph export "$FIGURES_PDF/stata_14_residuos_series.pdf", replace                 // Exporta resíduos em PDF.
graph export "$FIGURES_PNG/stata_14_residuos_series.png", replace width(2400)     // Exporta resíduos em PNG.

histogram res_bfvl, density color(navy%65) lcolor(navy) addplot(kdensity res_bfvl, lcolor(red) lwidth(medthick)) title("Distribuicao dos residuos: carne bovina e vitela", size(medsmall)) xtitle("Residuo", size(small)) ytitle("Densidade", size(small)) graphregion(color(white)) plotregion(color(white)) legend(order(2 "Curva de densidade") size(small) position(3) ring(1) region(lcolor(none) fcolor(none))) name(g_hist_bfvl, replace) // Histograma de residuos bfvl com curva de densidade em vermelho.
graph export "$FIGURES_PDF/stata_15_hist_residuos_bfvl.pdf", replace              // Exporta histograma de carne bovina e vitela em PDF.
graph export "$FIGURES_PNG/stata_15_hist_residuos_bfvl.png", replace width(2400)  // Exporta histograma de carne bovina e vitela em PNG.
histogram res_pork, density color(navy%65) lcolor(navy) addplot(kdensity res_pork, lcolor(red) lwidth(medthick)) title("Distribuicao dos residuos: carne suina", size(medsmall)) xtitle("Residuo", size(small)) ytitle("Densidade", size(small)) graphregion(color(white)) plotregion(color(white)) legend(order(2 "Curva de densidade") size(small) position(3) ring(1) region(lcolor(none) fcolor(none))) name(g_hist_pork, replace) // Histograma de residuos pork com curva de densidade em vermelho.
graph export "$FIGURES_PDF/stata_16_hist_residuos_pork.pdf", replace              // Exporta histograma de carne suína em PDF.
graph export "$FIGURES_PNG/stata_16_hist_residuos_pork.png", replace width(2400)  // Exporta histograma de carne suína em PNG.
histogram res_fish, density color(navy%65) lcolor(navy) addplot(kdensity res_fish, lcolor(red) lwidth(medthick)) title("Distribuicao dos residuos: pescados", size(medsmall)) xtitle("Residuo", size(small)) ytitle("Densidade", size(small)) graphregion(color(white)) plotregion(color(white)) legend(order(2 "Curva de densidade") size(small) position(3) ring(1) region(lcolor(none) fcolor(none))) name(g_hist_fish, replace) // Histograma de residuos fish com curva de densidade em vermelho.
graph export "$FIGURES_PDF/stata_17_hist_residuos_fish.pdf", replace              // Exporta histograma de pescados em PDF.
graph export "$FIGURES_PNG/stata_17_hist_residuos_fish.png", replace width(2400)  // Exporta histograma de pescados em PNG.

********************************************************************************
* Gráficos de coeficientes, elasticidades e diagnóstico de instrumentos.
********************************************************************************

preserve                                                                       // Preserva base com resíduos.
import delimited using "$TABLES/coeficientes_stata.csv", clear                 // Importa tabela de coeficientes.
keep if modelo == "homog_simetria"                                             // Mantém apenas modelo final.
gen double lb = estimativa - 1.96*erro_padrao                                   // Calcula limite inferior de 95%.
gen double ub = estimativa + 1.96*erro_padrao                                   // Calcula limite superior de 95%.
gen id = _n                                                                     // Cria identificador para eixo x.
gen byte grupo_produto = .                                                      // Cria grupo para colorir por produto/equação.
replace grupo_produto = 1 if inlist(parametro, "a_bfvl", "g11", "g12", "g14", "b_bfvl") // Bloco da equação de carne bovina e vitela.
replace grupo_produto = 2 if inlist(parametro, "a_pork", "g22", "g24", "b_pork")          // Bloco da equação de carne suína.
replace grupo_produto = 4 if inlist(parametro, "a_fish", "g44", "b_fish")                  // Bloco da equação de pescados.
twoway ///
    (rcap lb ub id, lcolor(gs6) lwidth(medthin)) ///
    (scatter estimativa id if grupo_produto == 1, mcolor(`cor_bovina') msymbol(circle) msize(medium)) ///
    (scatter estimativa id if grupo_produto == 2, mcolor(`cor_suina') msymbol(circle) msize(medium)) ///
    (scatter estimativa id if grupo_produto == 4, mcolor(`cor_pescados') msymbol(circle) msize(medium)), ///
    yline(0, lcolor(black) lpattern(dash) lwidth(thin)) ///
    title("Coeficientes estimados no modelo com homogeneidade e simetria", size(medsmall)) ///
    xtitle("Nome do parâmetro", size(small)) ///
    ytitle("Estimativa do coeficiente", size(small)) ///
    xlabel(1 "a_bfvl" 2 "g11" 3 "g12" 4 "g14" 5 "b_bfvl" 6 "a_pork" 7 "g22" 8 "g24" 9 "b_pork" 10 "a_fish" 11 "g44" 12 "b_fish", angle(45) labsize(vsmall)) ///
    ylabel(, labsize(small) grid glcolor(gs14)) ///
    legend(order(2 "Carne bovina e vitela" 3 "Carne suína" 4 "Pescados") cols(1) position(3) ring(1) region(lcolor(none) fcolor(none)) size(small)) ///
    `tema_base' ///
    name(g_coef, replace) // Coeficientes com IC e legenda por produto.
graph export "$FIGURES_PDF/stata_18_coeficientes_hsym.pdf", replace                 // Exporta coeficientes em PDF.
graph export "$FIGURES_PNG/stata_18_coeficientes_hsym.png", replace width(2400)     // Exporta coeficientes em PNG.
restore                                                                         // Restaura base com resíduos.

preserve                                                                       // Preserva base atual.
import delimited using "$TABLES/elasticidade_dispendio_hsym_stata.csv", clear   // Importa elasticidades-dispêndio.
graph bar eta, over(produto, label(angle(25) labsize(small))) yline(1, lcolor(black) lpattern(dash) lwidth(thin)) title("Elasticidade em relacao ao dispendio real", size(medsmall)) ytitle("Elasticidade-dispendio", size(small)) ylabel(, labsize(small) grid glcolor(gs14)) bar(1, fcolor(navy%65) lcolor(navy)) graphregion(color(white)) plotregion(color(white)) name(g_eta, replace) // Grafico de elasticidade-dispêndio com nomes das variaveis da base.
graph export "$FIGURES_PDF/stata_19_elasticidades_dispendio.pdf", replace           // Exporta elasticidade-dispêndio.
graph export "$FIGURES_PNG/stata_19_elasticidades_dispendio.png", replace width(2400) // Exporta elasticidade-dispêndio PNG.
restore                                                                         // Restaura base.

foreach mat in marshallianas compensadas {                                      // Percorre os dois tipos de elasticidade.
    local titulo_elast "Elasticidades nao compensadas"
    if "`mat'" == "compensadas" local titulo_elast "Elasticidades compensadas"
    preserve                                                                    // Preserva base atual.
    if "`mat'" == "marshallianas" {                                             // Verifica se é matriz Marshalliana.
        import delimited using "$TABLES/elasticidades_marshallianas_hsym_stata.csv", clear // Importa Marshallianas.
    }                                                                           // Fecha condição.
    if "`mat'" == "compensadas" {                                               // Verifica se é matriz compensada.
        import delimited using "$TABLES/elasticidades_compensadas_hsym_stata.csv", clear // Importa compensadas.
    }                                                                           // Fecha condição.
    rename bfvl valor_bfvl                                                      // Renomeia coluna bfvl para reshape.
    rename pork valor_pork                                                      // Renomeia coluna pork para reshape.
    rename poult valor_poult                                                    // Renomeia coluna poult para reshape.
    rename fish valor_fish                                                      // Renomeia coluna fish para reshape.
    reshape long valor_, i(produto_linha) j(produto_coluna) string              // Coloca a matriz em formato longo.
    gen row = .                                                                 // Cria posição da linha.
    replace row = 4 if produto_linha == "bfvl"                                  // Posiciona bfvl no topo.
    replace row = 3 if produto_linha == "pork"                                  // Posiciona pork.
    replace row = 2 if produto_linha == "poult"                                 // Posiciona poult.
    replace row = 1 if produto_linha == "fish"                                  // Posiciona fish.
    gen col = .                                                                 // Cria posição da coluna.
    replace col = 1 if produto_coluna == "bfvl"                                 // Posiciona coluna bfvl.
    replace col = 2 if produto_coluna == "pork"                                 // Posiciona coluna pork.
    replace col = 3 if produto_coluna == "poult"                                // Posiciona coluna poult.
    replace col = 4 if produto_coluna == "fish"                                 // Posiciona coluna fish.
    gen str8 rotulo = string(valor_, "%5.2f")                                   // Cria rótulo numérico da célula.
    gen double peso = abs(valor_) + 0.05                                         // Cria peso positivo para tamanho do marcador.
    twoway ///
        (scatter row col if produto_coluna == "bfvl" [aw=peso], msymbol(square) msize(vlarge) mcolor(`cor_bovina'%65) mlabcolor(black) mlabel(rotulo) mlabposition(0) mlabsize(small)) ///
        (scatter row col if produto_coluna == "pork" [aw=peso], msymbol(square) msize(vlarge) mcolor(`cor_suina'%65) mlabcolor(black) mlabel(rotulo) mlabposition(0) mlabsize(small)) ///
        (scatter row col if produto_coluna == "poult" [aw=peso], msymbol(square) msize(vlarge) mcolor(`cor_frango'%65) mlabcolor(black) mlabel(rotulo) mlabposition(0) mlabsize(small)) ///
        (scatter row col if produto_coluna == "fish" [aw=peso], msymbol(square) msize(vlarge) mcolor(`cor_pescados'%65) mlabcolor(black) mlabel(rotulo) mlabposition(0) mlabsize(small)), ///
        xlabel(1 "bfvl" 2 "pork" 3 "poult" 4 "fish", angle(0) labsize(small)) ///
        ylabel(1 "fish" 2 "poult" 3 "pork" 4 "bfvl", labsize(small)) ///
        title("`titulo_elast'", size(medsmall)) ///
        xtitle("Preço: nome da variável", size(small)) ///
        ytitle("Demanda: nome da variável", size(small)) ///
        legend(order(1 "Carne bovina e vitela" 2 "Carne suína" 3 "Frango" 4 "Pescados") cols(1) position(3) ring(1) region(lcolor(none) fcolor(none)) size(small)) ///
        `tema_base' name(g_elast_`mat', replace) // Mapa de células das elasticidades com cores por variável e legenda à direita.
    graph export "$FIGURES_PDF/stata_20_matriz_elasticidades_`mat'.pdf", replace    // Exporta matriz em PDF.
    graph export "$FIGURES_PNG/stata_20_matriz_elasticidades_`mat'.png", replace width(2400) // Exporta matriz em PNG.
    restore                                                                     // Restaura base.
}                                                                               // Fecha loop de elasticidades.

preserve                                                                       // Preserva base atual antes de abrir a tabela de diagnóstico.
capture confirm file "$TABLES/diagnostico_primeira_etapa_stata.csv"             // Verifica se a tabela de diagnóstico foi criada pela etapa 04.
if _rc {                                                                        // Entra se o arquivo não existir.
    di as error "Arquivo diagnostico_primeira_etapa_stata.csv nao encontrado. Rode primeiro stata/04_tests_diagnostics_aids_stata.do." // Mostra mensagem clara.
    restore                                                                     // Restaura a base anterior.
    log close                                                                   // Fecha o log antes de parar.
    exit 601                                                                    // Interrompe com erro de arquivo não encontrado.
}                                                                               // Fecha verificação de arquivo.
import delimited using "$TABLES/diagnostico_primeira_etapa_stata.csv", clear case(lower) // Importa diagnóstico e força nomes de variáveis em minúsculas.
capture confirm variable f_excluidos                                            // Verifica se a coluna do F da primeira etapa existe com nome minúsculo.
if _rc {                                                                        // Entra se f_excluidos não existir.
    capture confirm variable F_excluidos                                        // Verifica se a coluna foi importada preservando maiúscula.
    if !_rc rename F_excluidos f_excluidos                                      // Renomeia para minúsculo se necessário.
}                                                                               // Fecha correção do nome do F.
capture confirm variable r2_parcial                                             // Verifica se a coluna de R2 parcial existe.
if _rc {                                                                        // Entra se r2_parcial não existir.
    capture confirm variable R2_parcial                                         // Verifica se foi importada com maiúscula.
    if !_rc rename R2_parcial r2_parcial                                        // Renomeia para minúsculo se necessário.
}                                                                               // Fecha correção do nome do R2 parcial.
capture confirm variable f_excluidos                                            // Confirma novamente a existência da coluna do F.
if _rc {                                                                        // Entra se a coluna ainda estiver ausente.
    di as error "A tabela de diagnostico nao contem a variavel f_excluidos. Verifique a etapa 04." // Mensagem de erro interpretável.
    restore                                                                     // Restaura a base anterior.
    log close                                                                   // Fecha o log antes de parar.
    exit 111                                                                    // Interrompe com erro de variável ausente.
}                                                                               // Fecha validação final.
capture confirm variable r2_parcial                                             // Confirma novamente a existência da coluna do R2 parcial.
if _rc {                                                                        // Entra se a coluna ainda estiver ausente.
    di as error "A tabela de diagnostico nao contem a variavel r2_parcial. Verifique a etapa 04." // Mensagem de erro interpretável.
    restore                                                                     // Restaura a base anterior.
    log close                                                                   // Fecha o log antes de parar.
    exit 111                                                                    // Interrompe com erro de variável ausente.
}                                                                               // Fecha validação final.
replace instrumento = "Preços defasados em t-1" if instrumento == "L1"              // Escreve no eixo o procedimento usado, em vez do código L1.
replace instrumento = "Preços defasados em t-1 e t-2" if instrumento == "L1_L2"     // Escreve no eixo o procedimento usado, em vez do código L1_L2.

gen byte xbase = .                                                             // Cria posição principal no eixo x para cada procedimento.
replace xbase = 1 if instrumento == "Preços defasados em t-1"                  // Posição do conjunto com uma defasagem.
replace xbase = 2 if instrumento == "Preços defasados em t-1 e t-2"            // Posição do conjunto com duas defasagens.
gen double desloc = .                                                          // Cria deslocamento lateral para barras por produto.
replace desloc = -0.27 if preco == "bfvl"                                      // Deslocamento da carne bovina e vitela.
replace desloc = -0.09 if preco == "pork"                                      // Deslocamento da carne suína.
replace desloc =  0.09 if preco == "poult"                                     // Deslocamento do frango.
replace desloc =  0.27 if preco == "fish"                                      // Deslocamento dos pescados.
gen double xpos = xbase + desloc                                               // Combina procedimento e produto na posição horizontal.

twoway ///
    (bar f_excluidos xpos if preco == "bfvl",  barwidth(0.16) fcolor(`cor_bovina'%65)   lcolor(`cor_bovina')) ///
    (bar f_excluidos xpos if preco == "pork",  barwidth(0.16) fcolor(`cor_suina'%65)    lcolor(`cor_suina')) ///
    (bar f_excluidos xpos if preco == "poult", barwidth(0.16) fcolor(`cor_frango'%65)   lcolor(`cor_frango')) ///
    (bar f_excluidos xpos if preco == "fish",  barwidth(0.16) fcolor(`cor_pescados'%65) lcolor(`cor_pescados')), ///
    title("Força dos instrumentos na primeira etapa", size(medsmall)) ///
    xtitle("Conjunto de instrumentos usado", size(small)) ///
    ytitle("Estatística F dos instrumentos defasados", size(small)) ///
    xlabel(1 "Preços defasados em t-1" 2 "Preços defasados em t-1 e t-2", angle(0) labsize(vsmall)) ///
    ylabel(, labsize(small) grid glcolor(gs14)) ///
    legend(order(1 "Carne bovina e vitela" 2 "Carne suína" 3 "Frango" 4 "Pescados") cols(1) position(3) ring(1) region(lcolor(none) fcolor(none)) size(small)) ///
    `tema_base' name(g_firstF, replace) // Gráfico do F da primeira etapa com nomes completos apenas na legenda.
graph export "$FIGURES_PDF/stata_21_primeira_etapa_F.pdf", replace                  // Exporta F em PDF.
graph export "$FIGURES_PNG/stata_21_primeira_etapa_F.png", replace width(2400)      // Exporta F em PNG.

twoway ///
    (bar r2_parcial xpos if preco == "bfvl",  barwidth(0.16) fcolor(`cor_bovina'%65)   lcolor(`cor_bovina')) ///
    (bar r2_parcial xpos if preco == "pork",  barwidth(0.16) fcolor(`cor_suina'%65)    lcolor(`cor_suina')) ///
    (bar r2_parcial xpos if preco == "poult", barwidth(0.16) fcolor(`cor_frango'%65)   lcolor(`cor_frango')) ///
    (bar r2_parcial xpos if preco == "fish",  barwidth(0.16) fcolor(`cor_pescados'%65) lcolor(`cor_pescados')), ///
    title("Poder explicativo adicional dos instrumentos", size(medsmall)) ///
    xtitle("Conjunto de instrumentos usado", size(small)) ///
    ytitle("R² parcial dos instrumentos defasados", size(small)) ///
    xlabel(1 "Preços defasados em t-1" 2 "Preços defasados em t-1 e t-2", angle(0) labsize(vsmall)) ///
    ylabel(, labsize(small) grid glcolor(gs14)) ///
    legend(order(1 "Carne bovina e vitela" 2 "Carne suína" 3 "Frango" 4 "Pescados") cols(1) position(3) ring(1) region(lcolor(none) fcolor(none)) size(small)) ///
    `tema_base' name(g_partialR2, replace) // Gráfico do R2 parcial com nomes completos apenas na legenda.
graph export "$FIGURES_PDF/stata_22_primeira_etapa_R2_parcial.pdf", replace         // Exporta R2 parcial em PDF.
graph export "$FIGURES_PNG/stata_22_primeira_etapa_R2_parcial.png", replace width(2400) // Exporta R2 parcial em PNG.
restore                                                                         // Restaura base.

log close                                                                       // Fecha log dos gráficos.
