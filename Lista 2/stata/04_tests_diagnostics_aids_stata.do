/*******************************************************************************
Arquivo: stata/04_tests_diagnostics_aids_stata.do
Objetivo: testar restrições teóricas e diagnosticar instrumentos.
*******************************************************************************/

do "stata/00_config_aids.do"                       // Carrega caminhos, macros e opções gerais.

log using "$LOGS/04_tests_diagnostics_aids_stata.log", replace text // Abre log dos testes e diagnósticos.

use "$PROC_DTA", clear                             // Abre dados processados.

drop if missing(w_bfvl, w_pork, w_fish, lngp_bfvl, lngp_pork, lngp_poult, lngp_fish, ln_real_x, L1_lngp_bfvl, L1_lngp_pork, L1_lngp_poult, L1_lngp_fish) // Mantém amostra com instrumentos L1.

********************************************************************************
* Testes de homogeneidade e simetria usando o modelo irrestrito.
********************************************************************************

estimates use "$MODELS/aids_unrestricted.ster"     // Carrega o modelo sem restrições.

test (_b[/gbfvl_bfvl] + _b[/gbfvl_pork] + _b[/gbfvl_poult] + _b[/gbfvl_fish] = 0) ///
     (_b[/gpork_bfvl] + _b[/gpork_pork] + _b[/gpork_poult] + _b[/gpork_fish] = 0) ///
     (_b[/gfish_bfvl] + _b[/gfish_pork] + _b[/gfish_poult] + _b[/gfish_fish] = 0) // Testa homogeneidade nas equações estimadas.

scalar Wald_hom = r(chi2)                          // Guarda estatística qui-quadrado do teste de homogeneidade.
scalar df_hom = r(df)                              // Guarda graus de liberdade do teste de homogeneidade.
scalar p_hom = r(p)                                // Guarda p-valor do teste de homogeneidade.

test (_b[/gbfvl_pork] = _b[/gpork_bfvl]) ///
     (_b[/gbfvl_fish] = _b[/gfish_bfvl]) ///
     (_b[/gpork_fish] = _b[/gfish_pork])            // Testa simetria entre as equações estimadas.

scalar Wald_sym = r(chi2)                          // Guarda estatística qui-quadrado do teste de simetria.
scalar df_sym = r(df)                              // Guarda graus de liberdade do teste de simetria.
scalar p_sym = r(p)                                // Guarda p-valor do teste de simetria.

preserve                                           // Preserva dados para criar tabela de testes.
clear                                              // Limpa a base.
set obs 2                                          // Cria duas linhas para os testes.
gen str30 teste = ""                               // Cria nome do teste.
replace teste = "Homogeneidade" in 1               // Nomeia o teste de homogeneidade.
replace teste = "Simetria" in 2                    // Nomeia o teste de simetria.
gen double estatistica = .                         // Cria coluna da estatística.
replace estatistica = scalar(Wald_hom) in 1        // Salva estatística de homogeneidade.
replace estatistica = scalar(Wald_sym) in 2        // Salva estatística de simetria.
gen double gl = .                                  // Cria coluna de graus de liberdade.
replace gl = scalar(df_hom) in 1                   // Salva graus de liberdade de homogeneidade.
replace gl = scalar(df_sym) in 2                   // Salva graus de liberdade de simetria.
gen double p_valor = .                             // Cria coluna de p-valor.
replace p_valor = scalar(p_hom) in 1               // Salva p-valor de homogeneidade.
replace p_valor = scalar(p_sym) in 2               // Salva p-valor de simetria.
export delimited using "$TABLES/testes_wald_restricoes_stata.csv", replace // Exporta testes de Wald.
restore                                            // Restaura dados originais.

********************************************************************************
* Diagnóstico de primeira etapa com instrumentos L1.
********************************************************************************

tempname postfs                                    // Cria nome temporário para arquivo de primeira etapa.
postfile `postfs' str8 preco str12 instrumento double F_excluidos p_valor r2_full r2_reduzido r2_parcial N using "$TABLES/diagnostico_primeira_etapa_stata.dta", replace // Abre arquivo para resultados.

foreach g in bfvl pork poult fish {                // Percorre cada preço potencialmente endógeno.
    quietly regress lngp_`g' ln_real_x L1_lngp_bfvl L1_lngp_pork L1_lngp_poult L1_lngp_fish // Estima primeira etapa completa com L1.
    scalar r2_full = e(r2)                         // Guarda R2 do modelo completo.
    scalar n_full = e(N)                           // Guarda número de observações.
    test L1_lngp_bfvl L1_lngp_pork L1_lngp_poult L1_lngp_fish // Testa significância conjunta dos instrumentos excluídos.
    scalar F_ex = r(F)                             // Guarda F da primeira etapa.
    scalar p_ex = r(p)                             // Guarda p-valor do F.
    quietly regress lngp_`g' ln_real_x             // Estima modelo reduzido apenas com variável incluída.
    scalar r2_red = e(r2)                          // Guarda R2 do modelo reduzido.
    scalar r2_par = (r2_full - r2_red)/(1 - r2_red) // Calcula R2 parcial dos instrumentos.
    post `postfs' ("`g'") ("L1") (F_ex) (p_ex) (r2_full) (r2_red) (r2_par) (n_full) // Grava diagnóstico L1.
}                                                  // Fecha loop de preços.

foreach g in bfvl pork poult fish {                // Percorre cada preço para diagnóstico alternativo.
    quietly regress lngp_`g' ln_real_x L1_lngp_bfvl L1_lngp_pork L1_lngp_poult L1_lngp_fish L2_lngp_bfvl L2_lngp_pork L2_lngp_poult L2_lngp_fish // Estima primeira etapa com L1 e L2.
    scalar r2_full = e(r2)                         // Guarda R2 do modelo completo.
    scalar n_full = e(N)                           // Guarda número de observações.
    test L1_lngp_bfvl L1_lngp_pork L1_lngp_poult L1_lngp_fish L2_lngp_bfvl L2_lngp_pork L2_lngp_poult L2_lngp_fish // Testa instrumentos L1 e L2.
    scalar F_ex = r(F)                             // Guarda F da primeira etapa ampliada.
    scalar p_ex = r(p)                             // Guarda p-valor da primeira etapa ampliada.
    quietly regress lngp_`g' ln_real_x             // Estima modelo reduzido apenas com variável incluída.
    scalar r2_red = e(r2)                          // Guarda R2 do modelo reduzido.
    scalar r2_par = (r2_full - r2_red)/(1 - r2_red) // Calcula R2 parcial dos instrumentos ampliados.
    post `postfs' ("`g'") ("L1_L2") (F_ex) (p_ex) (r2_full) (r2_red) (r2_par) (n_full) // Grava diagnóstico L1+L2.
}                                                  // Fecha loop de preços.

postclose `postfs'                                 // Fecha arquivo de diagnósticos.
use "$TABLES/diagnostico_primeira_etapa_stata.dta", clear // Abre resultados de primeira etapa.
export delimited using "$TABLES/diagnostico_primeira_etapa_stata.csv", replace // Exporta diagnóstico para CSV.

********************************************************************************
* Comparação simples de estatísticas armazenadas dos modelos.
********************************************************************************

tempname postmod                                   // Cria arquivo temporário de comparação de modelos.
postfile `postmod' str20 modelo double N parametros momentos df_overid J_obj using "$TABLES/comparacao_modelos_stata.dta", replace // Abre arquivo de comparação.

foreach m in aids_unrestricted aids_homogeneity aids_hsym aids_hsym_L2 { // Percorre modelos salvos.
    estimates use "$MODELS/`m'.ster"                // Carrega um modelo salvo.
    scalar Nmod = e(N)                              // Guarda número de observações.
    scalar kmod = e(k)                              // Guarda número de parâmetros.
    capture scalar jmod = e(J)                      // Tenta guardar estatística J.
    if _rc {                                        // Entra se e(J) não existir.
        scalar jmod = .                             // Usa missing quando a estatística não estiver armazenada.
    }                                               // Fecha condição.
    capture scalar dfj = e(J_df)                    // Tenta guardar graus de liberdade do teste J.
    if _rc {                                        // Entra se e(J_df) não existir.
        scalar dfj = .                              // Usa missing se não existir.
    }                                               // Fecha condição.
    capture scalar moments = e(k_eq_model)          // Tenta guardar quantidade de equações/momentos.
    if _rc {                                        // Entra se a informação não existir.
        scalar moments = .                          // Usa missing se não existir.
    }                                               // Fecha condição.
    post `postmod' ("`m'") (Nmod) (kmod) (moments) (dfj) (jmod) // Grava linha do modelo.
}                                                   // Fecha loop de modelos.

postclose `postmod'                                // Fecha arquivo temporário.
use "$TABLES/comparacao_modelos_stata.dta", clear   // Abre comparação de modelos.
export delimited using "$TABLES/comparacao_modelos_stata.csv", replace // Exporta comparação para CSV.

log close                                          // Fecha log dos diagnósticos.
