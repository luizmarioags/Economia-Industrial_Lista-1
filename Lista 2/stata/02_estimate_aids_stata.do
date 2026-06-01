/*******************************************************************************
Arquivo: stata/02_estimate_aids_stata.do
Objetivo: estimar as três especificações pedidas na lista usando o comando gmm:
          (1) sem restrições teóricas;
          (2) com homogeneidade;
          (3) com homogeneidade e simetria.
*******************************************************************************/

do "stata/00_config_aids.do"                       // Carrega caminhos, macros e opções gerais.

log using "$LOGS/02_estimate_aids_stata.log", replace text // Abre log da estimação.

use "$PROC_DTA", clear                             // Abre os dados processados pela etapa 01.

drop if missing(w_bfvl, w_pork, w_fish, lngp_bfvl, lngp_pork, lngp_poult, lngp_fish, ln_real_x, L1_lngp_bfvl, L1_lngp_pork, L1_lngp_poult, L1_lngp_fish) // Remove observações sem instrumentos de primeira defasagem.

global Z1 "ln_real_x L1_lngp_bfvl L1_lngp_pork L1_lngp_poult L1_lngp_fish" // Define instrumentos principais: escala real e preços defasados.
global Z2 "ln_real_x L1_lngp_bfvl L1_lngp_pork L1_lngp_poult L1_lngp_fish L2_lngp_bfvl L2_lngp_pork L2_lngp_poult L2_lngp_fish" // Define instrumentos alternativos com segunda defasagem.

********************************************************************************
* Modelo 1: sem homogeneidade e sem simetria.
********************************************************************************

gmm                                                                          ///
    (eq_bfvl: w_bfvl - {a_bfvl} - {gbfvl_bfvl}*lngp_bfvl - {gbfvl_pork}*lngp_pork - {gbfvl_poult}*lngp_poult - {gbfvl_fish}*lngp_fish - {b_bfvl}*ln_real_x) ///
    (eq_pork: w_pork - {a_pork} - {gpork_bfvl}*lngp_bfvl - {gpork_pork}*lngp_pork - {gpork_poult}*lngp_poult - {gpork_fish}*lngp_fish - {b_pork}*ln_real_x) ///
    (eq_fish: w_fish - {a_fish} - {gfish_bfvl}*lngp_bfvl - {gfish_pork}*lngp_pork - {gfish_poult}*lngp_poult - {gfish_fish}*lngp_fish - {b_fish}*ln_real_x), ///
    instruments(eq_bfvl: $Z1)                                               ///
    instruments(eq_pork: $Z1)                                               ///
    instruments(eq_fish: $Z1)                                               ///
    winitial(unadjusted, independent) wmatrix(unadjusted) twostep nolog     // Estima o sistema sem restrições por GMM em dois passos.

estimates store aids_unrestricted                                            // Guarda o modelo irrestrito na memória.
estimates save "$MODELS/aids_unrestricted.ster", replace                     // Salva o modelo irrestrito em arquivo.
estat overid                                                                 // Mostra teste de sobreidentificação, quando houver graus de liberdade.

********************************************************************************
* Modelo 2: com homogeneidade.
* A restrição soma_k gamma_gk = 0 é imposta substituindo o coeficiente de poult.
* Assim, cada equação usa diferenças de preço contra poult.
********************************************************************************

gmm                                                                          ///
    (eq_bfvl: w_bfvl - {a_bfvl} - {gbfvl_bfvl}*(lngp_bfvl-lngp_poult) - {gbfvl_pork}*(lngp_pork-lngp_poult) - {gbfvl_fish}*(lngp_fish-lngp_poult) - {b_bfvl}*ln_real_x) ///
    (eq_pork: w_pork - {a_pork} - {gpork_bfvl}*(lngp_bfvl-lngp_poult) - {gpork_pork}*(lngp_pork-lngp_poult) - {gpork_fish}*(lngp_fish-lngp_poult) - {b_pork}*ln_real_x) ///
    (eq_fish: w_fish - {a_fish} - {gfish_bfvl}*(lngp_bfvl-lngp_poult) - {gfish_pork}*(lngp_pork-lngp_poult) - {gfish_fish}*(lngp_fish-lngp_poult) - {b_fish}*ln_real_x), ///
    instruments(eq_bfvl: $Z1)                                               ///
    instruments(eq_pork: $Z1)                                               ///
    instruments(eq_fish: $Z1)                                               ///
    winitial(unadjusted, independent) wmatrix(unadjusted) twostep nolog     // Estima o sistema com homogeneidade por GMM em dois passos.

estimates store aids_homogeneity                                             // Guarda o modelo com homogeneidade.
estimates save "$MODELS/aids_homogeneity.ster", replace                      // Salva o modelo com homogeneidade em arquivo.
estat overid                                                                 // Mostra teste de sobreidentificação, quando aplicável.

********************************************************************************
* Modelo 3: com homogeneidade e simetria.
* A simetria é imposta fazendo gamma_bfvl,pork = gamma_pork,bfvl,
* gamma_bfvl,fish = gamma_fish,bfvl e gamma_pork,fish = gamma_fish,pork.
********************************************************************************

gmm                                                                          ///
    (eq_bfvl: w_bfvl - {a_bfvl} - {g11}*(lngp_bfvl-lngp_poult) - {g12}*(lngp_pork-lngp_poult) - {g14}*(lngp_fish-lngp_poult) - {b_bfvl}*ln_real_x) ///
    (eq_pork: w_pork - {a_pork} - {g12}*(lngp_bfvl-lngp_poult) - {g22}*(lngp_pork-lngp_poult) - {g24}*(lngp_fish-lngp_poult) - {b_pork}*ln_real_x) ///
    (eq_fish: w_fish - {a_fish} - {g14}*(lngp_bfvl-lngp_poult) - {g24}*(lngp_pork-lngp_poult) - {g44}*(lngp_fish-lngp_poult) - {b_fish}*ln_real_x), ///
    instruments(eq_bfvl: $Z1)                                               ///
    instruments(eq_pork: $Z1)                                               ///
    instruments(eq_fish: $Z1)                                               ///
    winitial(unadjusted, independent) wmatrix(unadjusted) twostep nolog     // Estima o sistema com homogeneidade e simetria.

estimates store aids_hsym                                                    // Guarda o modelo final com homogeneidade e simetria.
estimates save "$MODELS/aids_hsym.ster", replace                             // Salva o modelo final em arquivo.
estat overid                                                                 // Mostra teste de sobreidentificação do modelo final.

********************************************************************************
* Modelo 3 alternativo: homogeneidade e simetria com instrumentos L1 e L2.
* Esta estimação responde à questão 9, que pede uma versão com segunda defasagem.
********************************************************************************

preserve                                                                     // Preserva a amostra usada até aqui.
drop if missing(L2_lngp_bfvl, L2_lngp_pork, L2_lngp_poult, L2_lngp_fish)     // Remove anos sem segunda defasagem.

gmm                                                                          ///
    (eq_bfvl: w_bfvl - {a_bfvl} - {g11}*(lngp_bfvl-lngp_poult) - {g12}*(lngp_pork-lngp_poult) - {g14}*(lngp_fish-lngp_poult) - {b_bfvl}*ln_real_x) ///
    (eq_pork: w_pork - {a_pork} - {g12}*(lngp_bfvl-lngp_poult) - {g22}*(lngp_pork-lngp_poult) - {g24}*(lngp_fish-lngp_poult) - {b_pork}*ln_real_x) ///
    (eq_fish: w_fish - {a_fish} - {g14}*(lngp_bfvl-lngp_poult) - {g24}*(lngp_pork-lngp_poult) - {g44}*(lngp_fish-lngp_poult) - {b_fish}*ln_real_x), ///
    instruments(eq_bfvl: $Z2)                                               ///
    instruments(eq_pork: $Z2)                                               ///
    instruments(eq_fish: $Z2)                                               ///
    winitial(unadjusted, independent) wmatrix(unadjusted) twostep nolog     // Estima o modelo final com instrumentos ampliados.

estimates store aids_hsym_L2                                                 // Guarda o modelo com segunda defasagem.
estimates save "$MODELS/aids_hsym_L2.ster", replace                          // Salva o modelo com segunda defasagem.
estat overid                                                                 // Mostra teste de sobreidentificação da versão ampliada.
restore                                                                      // Restaura a amostra com apenas primeira defasagem.

********************************************************************************
* Exportação das tabelas de coeficientes estimados.
********************************************************************************

tempname postcoef                                                            // Cria nome temporário para o arquivo de postagem.
postfile `postcoef' str20 modelo str30 parametro double estimativa erro_padrao estat_t using "$TABLES/coeficientes_stata.dta", replace // Abre arquivo temporário de coeficientes.

estimates restore aids_unrestricted                                          // Ativa o modelo irrestrito.
local p_unres a_bfvl gbfvl_bfvl gbfvl_pork gbfvl_poult gbfvl_fish b_bfvl a_pork gpork_bfvl gpork_pork gpork_poult gpork_fish b_pork a_fish gfish_bfvl gfish_pork gfish_poult gfish_fish b_fish // Lista parâmetros do modelo irrestrito.
foreach p of local p_unres {                                                 // Percorre cada parâmetro do modelo irrestrito.
    scalar coef = _b[/`p']                                                   // Extrai a estimativa pontual.
    scalar se = _se[/`p']                                                    // Extrai o erro-padrão.
    scalar tt = coef / se                                                    // Calcula a estatística t.
    post `postcoef' ("irrestrito") ("`p'") (coef) (se) (tt)                  // Grava linha da tabela.
}                                                                            // Fecha o loop de parâmetros.

estimates restore aids_homogeneity                                           // Ativa o modelo com homogeneidade.
local p_hom a_bfvl gbfvl_bfvl gbfvl_pork gbfvl_fish b_bfvl a_pork gpork_bfvl gpork_pork gpork_fish b_pork a_fish gfish_bfvl gfish_pork gfish_fish b_fish // Lista parâmetros do modelo homogêneo.
foreach p of local p_hom {                                                   // Percorre cada parâmetro do modelo homogêneo.
    scalar coef = _b[/`p']                                                   // Extrai a estimativa pontual.
    scalar se = _se[/`p']                                                    // Extrai o erro-padrão.
    scalar tt = coef / se                                                    // Calcula a estatística t.
    post `postcoef' ("homogeneidade") ("`p'") (coef) (se) (tt)               // Grava linha da tabela.
}                                                                            // Fecha o loop de parâmetros.

estimates restore aids_hsym                                                  // Ativa o modelo com homogeneidade e simetria.
local p_hsym a_bfvl g11 g12 g14 b_bfvl a_pork g22 g24 b_pork a_fish g44 b_fish // Lista parâmetros livres do modelo final.
foreach p of local p_hsym {                                                  // Percorre cada parâmetro do modelo final.
    scalar coef = _b[/`p']                                                   // Extrai a estimativa pontual.
    scalar se = _se[/`p']                                                    // Extrai o erro-padrão.
    scalar tt = coef / se                                                    // Calcula a estatística t.
    post `postcoef' ("homog_simetria") ("`p'") (coef) (se) (tt)              // Grava linha da tabela.
}                                                                            // Fecha o loop de parâmetros.

postclose `postcoef'                                                         // Fecha o arquivo temporário de coeficientes.
use "$TABLES/coeficientes_stata.dta", clear                                   // Abre a tabela de coeficientes em formato Stata.
export delimited using "$TABLES/coeficientes_stata.csv", replace              // Exporta a tabela de coeficientes para CSV.
save "$TABLES/coeficientes_stata.dta", replace                                // Salva novamente a tabela em formato Stata.

log close                                                                     // Fecha o log da estimação.
