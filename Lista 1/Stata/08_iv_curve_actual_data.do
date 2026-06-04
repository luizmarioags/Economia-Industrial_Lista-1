/********************************************************************
 Figura conceitual-empírica:
 Efeito do enfraquecimento do primeiro estágio sobre beta_p

 Esta figura replica o gráfico "Efeito de Instrumentos Fracos sobre beta",
 mas usando os dados da lista.

 Ideia:
   Pela fórmula IV exatamente identificada,

       beta_IV = Cov(z, q_residual) / Cov(z, pch_residual)

   ou, de forma equivalente,

       beta_IV = delta / gamma,

   onde:
       delta = coeficiente da forma reduzida;
       gamma = coeficiente do primeiro estágio.

   O gráfico mantém delta fixo no valor estimado nos dados e varia gamma,
   mostrando como beta_p explode quando o primeiro estágio se aproxima de zero.
********************************************************************/

di as text _newline "[Stata] Gerando curva IV empírica: efeito de instrumentos fracos sobre beta_p"

* ------------------------------------------------------------
* Carrega config se necessário
* ------------------------------------------------------------

local procdir "$PROC"

if `"`procdir'"' == "" {
    di as text "[Stata] Globais ainda não carregados. Tentando rodar Stata/config.do..."

    capture noisily do "Stata/config.do"

    if _rc {
        di as error "[Stata] Não consegui rodar Stata/config.do."
        di as error "[Stata] Rode o projeto a partir da pasta raiz ou ajuste o caminho do config.do."
        exit 601
    }
}

capture mkdir "$FIGS"

* ------------------------------------------------------------
* Garante que a base preparada exista
* ------------------------------------------------------------

capture confirm file "$PROC/chicken_prepared_stata.dta"

if _rc {
    di as text "[Stata] Base preparada não encontrada. Rodando 01_prepare_data.do..."
    do "Stata/01_prepare_data.do"
}

use "$PROC/chicken_prepared_stata.dta", clear

* ------------------------------------------------------------
* Verifica variáveis necessárias
* ------------------------------------------------------------

foreach v in ln_q ln_pch ln_y ln_pb z {
    capture confirm variable `v'
    if _rc {
        di as error "[Stata] Variável `v' não encontrada em $PROC/chicken_prepared_stata.dta"
        exit 111
    }
}

* ------------------------------------------------------------
* Residualização pelos controles da equação estrutural
* Controles: renda real per capita e preço real da carne bovina
* ------------------------------------------------------------

quietly regress ln_q ln_y ln_pb
predict double q_res, resid

quietly regress ln_pch ln_y ln_pb
predict double pch_res, resid

quietly regress z ln_y ln_pb
predict double z_res, resid

label variable q_res   "Quantidade residualizada"
label variable pch_res "Preço do frango residualizado"
label variable z_res   "Instrumento residualizado"

* ------------------------------------------------------------
* Forma reduzida e primeiro estágio com variáveis residualizadas
* ------------------------------------------------------------

quietly regress q_res z_res, noconstant
scalar delta_hat = _b[z_res]

quietly regress pch_res z_res, noconstant
scalar gamma_hat = _b[z_res]

scalar beta_ratio = delta_hat / gamma_hat

* ------------------------------------------------------------
* Estimação 2SLS direta, para marcar o ponto empírico
* ------------------------------------------------------------

quietly ivregress 2sls ln_q ln_y ln_pb (ln_pch = z), vce(robust)
scalar beta_2sls = _b[ln_pch]

di as text "[Stata] Forma reduzida delta_hat = " %9.6f scalar(delta_hat)
di as text "[Stata] Primeiro estágio gamma_hat = " %9.6f scalar(gamma_hat)
di as text "[Stata] Razão delta/gamma = " %9.6f scalar(beta_ratio)
di as text "[Stata] 2SLS direto = " %9.6f scalar(beta_2sls)

* ------------------------------------------------------------
* Define intervalo contrafactual para gamma
* Mantém o sinal do primeiro estágio observado nos dados.
* O limite mais próximo de zero ilustra o enfraquecimento do instrumento.
* ------------------------------------------------------------

clear
set obs 600

scalar gamma_emp = gamma_hat
scalar delta_emp = delta_hat
scalar beta_emp  = beta_2sls

scalar gamma_near_zero = gamma_emp/40
scalar gamma_strong    = gamma_emp*6

gen double gamma = .

if gamma_emp < 0 {
    replace gamma = gamma_strong + (_n - 1)*(gamma_near_zero - gamma_strong)/599
}
else {
    replace gamma = gamma_near_zero + (_n - 1)*(gamma_strong - gamma_near_zero)/599
}

gen double beta_iv_curve = delta_emp/gamma

* ------------------------------------------------------------
* Para reproduzir visualmente o gráfico enviado, limitamos a janela
* de visualização. A curva completa existe, mas valores extremos
* perto de zero são omitidos da figura.
* ------------------------------------------------------------

gen double beta_iv_plot = beta_iv_curve
replace beta_iv_plot = . if beta_iv_plot < -30 | beta_iv_plot > 5

* Ponto empírico observado nos dados
gen double gamma_observado = .
gen double beta_observado  = .

set obs 601
replace gamma_observado = gamma_emp in 601
replace beta_observado  = beta_emp  in 601

* ------------------------------------------------------------
* Gráfico
* ------------------------------------------------------------

twoway ///
    (line beta_iv_plot gamma, ///
        sort ///
        lcolor(navy) ///
        lwidth(medthick)) ///
    (scatter beta_observado gamma_observado, ///
        mcolor(cranberry) ///
        msymbol(circle) ///
        msize(medium)), ///
    xline(0, lcolor(gs10) lpattern(solid) lwidth(thin)) ///
    yline(0, lcolor(gs12) lpattern(solid) lwidth(thin)) ///
    title("Efeito de instrumentos fracos sobre {&beta}{subscript:p}", size(medsmall)) ///
    subtitle("Curva construída a partir da forma reduzida estimada nos dados da demanda por frango", size(small)) ///
    xtitle("Efeito do instrumento sobre o preço do frango ({&gamma})", size(small)) ///
    ytitle("Elasticidade-preço implícita ({&beta}{subscript:p})", size(small)) ///
    ylabel(-30(5)5, labsize(small)) ///
    xlabel(, labsize(small)) ///
    legend( ///
        order(1 "Curva IV: {&beta}{subscript:p} = {&delta}/{&gamma}" ///
              2 "Estimativa 2SLS observada nos dados") ///
        cols(1) ///
        size(small) ///
        position(6) ///
        ring(0) ///
        region(lcolor(none) fcolor(none)) ///
    ) ///
    note("A forma reduzida {&delta} é mantida fixa no valor estimado nos dados. Quando o primeiro estágio {&gamma} se aproxima de zero, a elasticidade IV torna-se instável.", ///
         size(vsmall)) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    name(g_iv_curve_actual_data, replace)

graph export "$FIGS/stata_fig10_iv_curve_actual_data.png", ///
    replace width(2600)

graph export "$FIGS/stata_fig10_iv_curve_actual_data.pdf", ///
    replace

di as text "[Stata] Figura salva em PNG: output/figures/stata_fig10_iv_curve_actual_data.png"
di as text "[Stata] Figura salva em PDF: output/figures/stata_fig10_iv_curve_actual_data.pdf"