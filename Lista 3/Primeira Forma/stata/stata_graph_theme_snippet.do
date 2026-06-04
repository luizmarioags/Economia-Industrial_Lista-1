/****************************************************************************************
Template visual dos gráficos - Lista 3 Berry/BLP

Use quando quiser aplicar o mesmo padrão visual do gráfico de referência:
    do "$ROOT/stata/stata_graph_theme_snippet.do"

Observação:
- Este arquivo define GLOBALS para que o template sobreviva ao fim do .do.
- Não depende de pacote externo; usa apenas opções nativas do Stata.
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
global GRAPH_AUX1_COLOR "forest_green"
global GRAPH_AUX2_COLOR "orange"
global GRAPH_AUX3_COLOR "purple"
