/****************************************************************************************
COMENTÁRIOS DETALHADOS
- clear matrix limpa matrizes antigas para evitar contaminação entre execuções.
- set scheme s1color o tema visual padrão dos gráficos exportados pelo Stata.
- set linesize e set matsize ajustam a exibição e o tamanho máximo das matrizes.
- As globals S0, XVARS, PRICE, PRICE_ORIG, DELTA e ENDOG_* padronizam os nomes usados nos scripts seguintes.
- capture which verifica se um comando/pacote existe; se não existir, capture ssc install tenta instalar.
****************************************************************************************/
/****************************************************************************************
Elaborado por: 
Luiz Mario Andrade (Matrícula: 252029360)
Felipe Santos (Matrícula: 232010719)
Luiza Nodari (Matrícula: 242011335)
Diogo Martins (Matrícula: 232001578)
Sarah Moura (Matrícula: 211060316)
Pedro Bijos (Matrícula: 241003849)
*******************************************************************************/
****************************************************************************************/


clear matrix
set scheme s1color
capture graph set window fontface "Arial"

* Template visual padrão dos gráficos:
* - fundo branco;
* - grade cinza clara tracejada;
* - pontos azul-escuro;
* - linhas de ajuste em cranberry/vermelho;
* - legenda à direita quando necessário.
set linesize 120
set matsize 11000

global S0 = 0.2429
global XVARS "cals fat sugar"
global PRICE "neg_price"
global PRICE_ORIG "price"
global DELTA "delta"
global ENDOG_SIMPLE "neg_price"
global ENDOG_NESTED "neg_price log_share_within_nest"

* Pacotes opcionais/consolidados. O pacote roda melhor com estout, ivreg2 e weakivtest.
capture which esttab
if _rc capture ssc install estout, replace
capture which ivreg2
if _rc capture ssc install ivreg2, replace
capture which weakivtest
if _rc capture ssc install weakivtest, replace


/****************************************************************************************
Template gráfico nativo usado por 06_visualizations.do e 07_extra_visualizations.do.
Este bloco NÃO depende de pacote externo. Ele replica o padrão visual do gráfico-modelo:
fundo branco, área de plotagem branca, grade cinza clara tracejada, pontos azul-escuro,
linhas de ajuste em cranberry e legenda à direita quando útil.
****************************************************************************************/
set scheme s1color
capture graph set window fontface "Arial"
global GRAPH_BASE   `"graphregion(color(white)) plotregion(color(white))"'
global GRAPH_GRIDXY `"xlabel(, labsize(small) grid glcolor(gs14) glpattern(dash)) ylabel(, labsize(small) angle(horizontal) grid glcolor(gs14) glpattern(dash))"'
global GRAPH_GRIDX  `"xlabel(, labsize(small) grid glcolor(gs14) glpattern(dash))"'
global GRAPH_GRIDY  `"ylabel(, labsize(small) angle(horizontal) grid glcolor(gs14) glpattern(dash))"'
global GRAPH_LEGEND_RIGHT `"legend(position(3) ring(1) cols(1) size(small) region(lcolor(none) fcolor(none)))"'
global GRAPH_LEGEND_BOTTOM `"legend(rows(1) size(small) region(lcolor(none) fcolor(none)))"'
global GRAPH_ZERO   `"lcolor(black) lpattern(dash) lwidth(medthin)"'
global GRAPH_POINT_COLOR "navy"
global GRAPH_FIT_COLOR "cranberry"
