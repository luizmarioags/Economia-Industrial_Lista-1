/*******************************************************************************
Arquivo: stata/03_elasticities_aids_stata.do
Objetivo: recuperar parâmetros completos, inclusive frango omitido, e calcular
          elasticidades-dispêndio, Marshallianas e compensadas.
*******************************************************************************/

do "stata/00_config_aids.do"                       // Carrega caminhos, macros e opções gerais.

log using "$LOGS/03_elasticities_aids_stata.log", replace text // Abre log das elasticidades.

use "$PROC_DTA", clear                             // Abre dados processados para recuperar participações médias.

foreach g in bfvl pork poult fish {                // Percorre os quatro produtos.
    quietly summarize w_`g', meanonly              // Calcula a participação média do produto.
    scalar wbar_`g' = r(mean)                      // Guarda a participação média em escalar.
}                                                  // Fecha o loop das médias.

estimates use "$MODELS/aids_hsym.ster"             // Carrega o modelo final com homogeneidade e simetria.

scalar a_bfvl = _b[/a_bfvl]                        // Recupera o intercepto estimado da equação bfvl.
scalar a_pork = _b[/a_pork]                        // Recupera o intercepto estimado da equação pork.
scalar a_fish = _b[/a_fish]                        // Recupera o intercepto estimado da equação fish.
scalar a_poult = 1 - a_bfvl - a_pork - a_fish      // Recupera o intercepto de poult por adding-up.

scalar b_bfvl = _b[/b_bfvl]                        // Recupera beta da equação bfvl.
scalar b_pork = _b[/b_pork]                        // Recupera beta da equação pork.
scalar b_fish = _b[/b_fish]                        // Recupera beta da equação fish.
scalar b_poult = - b_bfvl - b_pork - b_fish        // Recupera beta de poult por adding-up.

scalar g11 = _b[/g11]                              // Recupera gamma bfvl,bfvl.
scalar g12 = _b[/g12]                              // Recupera gamma bfvl,pork = gamma pork,bfvl.
scalar g14 = _b[/g14]                              // Recupera gamma bfvl,fish = gamma fish,bfvl.
scalar g22 = _b[/g22]                              // Recupera gamma pork,pork.
scalar g24 = _b[/g24]                              // Recupera gamma pork,fish = gamma fish,pork.
scalar g44 = _b[/g44]                              // Recupera gamma fish,fish.

scalar g13 = -(g11 + g12 + g14)                    // Recupera gamma bfvl,poult por homogeneidade.
scalar g21 = g12                                   // Impõe simetria gamma pork,bfvl.
scalar g23 = -(g21 + g22 + g24)                    // Recupera gamma pork,poult por homogeneidade.
scalar g31 = g13                                   // Recupera gamma poult,bfvl por simetria e adding-up.
scalar g32 = g23                                   // Recupera gamma poult,pork por simetria e adding-up.
scalar g34 = -(g14 + g24 + g44)                    // Recupera gamma poult,fish por adding-up.
scalar g41 = g14                                   // Impõe simetria gamma fish,bfvl.
scalar g42 = g24                                   // Impõe simetria gamma fish,pork.
scalar g43 = g34                                   // Recupera gamma fish,poult por simetria.
scalar g33 = -(g31 + g32 + g34)                    // Recupera gamma poult,poult por homogeneidade.
scalar g45 = .                                     // Escalar vazio sem uso; mantém bloco legível.

matrix ALPHA = (a_bfvl \ a_pork \ a_poult \ a_fish) // Cria vetor de alfas completos.
matrix rownames ALPHA = bfvl pork poult fish       // Nomeia as linhas do vetor de alfas.
matrix colnames ALPHA = alpha                      // Nomeia a coluna do vetor de alfas.

matrix BETA = (b_bfvl \ b_pork \ b_poult \ b_fish) // Cria vetor de betas completos.
matrix rownames BETA = bfvl pork poult fish        // Nomeia as linhas do vetor de betas.
matrix colnames BETA = beta                        // Nomeia a coluna do vetor de betas.

matrix GAMMA = J(4,4,.)                            // Cria matriz 4x4 para os gammas.
matrix rownames GAMMA = bfvl pork poult fish       // Nomeia linhas da matriz gamma.
matrix colnames GAMMA = bfvl pork poult fish       // Nomeia colunas da matriz gamma.
matrix GAMMA[1,1] = g11                            // Preenche gamma bfvl,bfvl.
matrix GAMMA[1,2] = g12                            // Preenche gamma bfvl,pork.
matrix GAMMA[1,3] = g13                            // Preenche gamma bfvl,poult.
matrix GAMMA[1,4] = g14                            // Preenche gamma bfvl,fish.
matrix GAMMA[2,1] = g21                            // Preenche gamma pork,bfvl.
matrix GAMMA[2,2] = g22                            // Preenche gamma pork,pork.
matrix GAMMA[2,3] = g23                            // Preenche gamma pork,poult.
matrix GAMMA[2,4] = g24                            // Preenche gamma pork,fish.
matrix GAMMA[3,1] = g31                            // Preenche gamma poult,bfvl.
matrix GAMMA[3,2] = g32                            // Preenche gamma poult,pork.
matrix GAMMA[3,3] = g33                            // Preenche gamma poult,poult.
matrix GAMMA[3,4] = g34                            // Preenche gamma poult,fish.
matrix GAMMA[4,1] = g41                            // Preenche gamma fish,bfvl.
matrix GAMMA[4,2] = g42                            // Preenche gamma fish,pork.
matrix GAMMA[4,3] = g43                            // Preenche gamma fish,poult.
matrix GAMMA[4,4] = g44                            // Preenche gamma fish,fish.

matrix WBAR = (scalar(wbar_bfvl) \ scalar(wbar_pork) \ scalar(wbar_poult) \ scalar(wbar_fish)) // Cria vetor de participações médias.
matrix rownames WBAR = bfvl pork poult fish        // Nomeia linhas das participações médias.
matrix colnames WBAR = wbar                        // Nomeia coluna das participações médias.

matrix ETA = J(4,1,.)                              // Cria vetor de elasticidades-dispêndio.
matrix rownames ETA = bfvl pork poult fish         // Nomeia linhas de ETA.
matrix colnames ETA = eta                          // Nomeia coluna de ETA.
matrix ETA[1,1] = 1 + b_bfvl/scalar(wbar_bfvl)     // Calcula elasticidade-dispêndio de bfvl.
matrix ETA[2,1] = 1 + b_pork/scalar(wbar_pork)     // Calcula elasticidade-dispêndio de pork.
matrix ETA[3,1] = 1 + b_poult/scalar(wbar_poult)   // Calcula elasticidade-dispêndio de poult.
matrix ETA[4,1] = 1 + b_fish/scalar(wbar_fish)     // Calcula elasticidade-dispêndio de fish.

matrix EM = J(4,4,.)                               // Cria matriz de elasticidades Marshallianas.
matrix EH = J(4,4,.)                               // Cria matriz de elasticidades compensadas.
matrix rownames EM = bfvl pork poult fish          // Nomeia linhas da matriz Marshalliana.
matrix colnames EM = bfvl pork poult fish          // Nomeia colunas da matriz Marshalliana.
matrix rownames EH = bfvl pork poult fish          // Nomeia linhas da matriz compensada.
matrix colnames EH = bfvl pork poult fish          // Nomeia colunas da matriz compensada.

forvalues i = 1/4 {                                // Percorre cada produto demandado na linha.
    forvalues j = 1/4 {                            // Percorre cada preço na coluna.
        scalar indicator = (`i' == `j')             // Cria indicador para elasticidade própria.
        scalar wi = WBAR[`i',1]                    // Recupera participação média do produto da linha.
        scalar wj = WBAR[`j',1]                    // Recupera participação média do produto da coluna.
        scalar bi = BETA[`i',1]                    // Recupera beta do produto da linha.
        scalar etai = ETA[`i',1]                   // Recupera elasticidade-dispêndio do produto da linha.
        matrix EM[`i',`j'] = -indicator + GAMMA[`i',`j']/wi - (bi*wj)/wi // Calcula elasticidade Marshalliana.
        matrix EH[`i',`j'] = EM[`i',`j'] + etai*wj // Calcula elasticidade compensada por Slutsky.
    }                                              // Fecha loop das colunas.
}                                                  // Fecha loop das linhas.

matrix list ALPHA                                  // Mostra vetor de alfas completos.
matrix list BETA                                   // Mostra vetor de betas completos.
matrix list GAMMA                                  // Mostra matriz gamma completa.
matrix list ETA                                    // Mostra elasticidades-dispêndio.
matrix list EM                                     // Mostra matriz de elasticidades Marshallianas.
matrix list EH                                     // Mostra matriz de elasticidades compensadas.

putexcel set "$TABLES/matrizes_parametros_elasticidades_stata.xlsx", replace // Cria planilha Excel para matrizes.
putexcel A1 = matrix(ALPHA), names             // Exporta alfas para Excel.
putexcel D1 = matrix(BETA), names              // Exporta betas para Excel.
putexcel G1 = matrix(WBAR), names              // Exporta participações médias para Excel.
putexcel A8 = matrix(GAMMA), names             // Exporta gamma para Excel.
putexcel A16 = matrix(ETA), names              // Exporta elasticidades-dispêndio para Excel.
putexcel A24 = matrix(EM), names               // Exporta elasticidades Marshallianas para Excel.
putexcel A33 = matrix(EH), names               // Exporta elasticidades compensadas para Excel.

preserve                                           // Preserva os dados em memória.
clear                                              // Limpa a base para exportar alpha.
svmat double ALPHA, names(col)                     // Converte matriz ALPHA em variáveis.
gen str10 produto = ""                             // Cria coluna com nome do produto.
replace produto = "bfvl" in 1                      // Nomeia primeira linha.
replace produto = "pork" in 2                      // Nomeia segunda linha.
replace produto = "poult" in 3                     // Nomeia terceira linha.
replace produto = "fish" in 4                      // Nomeia quarta linha.
order produto alpha                                // Ordena colunas.
export delimited using "$TABLES/alpha_hsym_stata.csv", replace // Exporta alfas.
restore                                            // Restaura dados.

preserve                                           // Preserva os dados em memória.
clear                                              // Limpa a base para exportar beta.
svmat double BETA, names(col)                      // Converte matriz BETA em variáveis.
gen str10 produto = ""                             // Cria coluna com nome do produto.
replace produto = "bfvl" in 1                      // Nomeia primeira linha.
replace produto = "pork" in 2                      // Nomeia segunda linha.
replace produto = "poult" in 3                     // Nomeia terceira linha.
replace produto = "fish" in 4                      // Nomeia quarta linha.
order produto beta                                 // Ordena colunas.
export delimited using "$TABLES/beta_hsym_stata.csv", replace // Exporta betas.
restore                                            // Restaura dados.

preserve                                           // Preserva os dados em memória.
clear                                              // Limpa a base para exportar ETA.
svmat double ETA, names(col)                       // Converte matriz ETA em variáveis.
gen str10 produto = ""                             // Cria coluna com nome do produto.
replace produto = "bfvl" in 1                      // Nomeia primeira linha.
replace produto = "pork" in 2                      // Nomeia segunda linha.
replace produto = "poult" in 3                     // Nomeia terceira linha.
replace produto = "fish" in 4                      // Nomeia quarta linha.
order produto eta                                  // Ordena colunas.
export delimited using "$TABLES/elasticidade_dispendio_hsym_stata.csv", replace // Exporta elasticidades-dispêndio.
restore                                            // Restaura dados.

foreach M in GAMMA EM EH {                         // Percorre matrizes quadradas a exportar.
    preserve                                       // Preserva dados em memória.
    clear                                          // Limpa a base para converter matriz em dataset.
    svmat double `M', names(col)                   // Converte a matriz em colunas.
    gen str10 produto_linha = ""                   // Cria coluna com produto da linha.
    replace produto_linha = "bfvl" in 1            // Nomeia linha 1.
    replace produto_linha = "pork" in 2            // Nomeia linha 2.
    replace produto_linha = "poult" in 3           // Nomeia linha 3.
    replace produto_linha = "fish" in 4            // Nomeia linha 4.
    order produto_linha bfvl pork poult fish       // Organiza a matriz em formato largo.
    if "`M'" == "GAMMA" {                          // Verifica se a matriz é GAMMA.
        export delimited using "$TABLES/gamma_hsym_stata.csv", replace // Exporta gamma.
    }                                              // Fecha condição GAMMA.
    if "`M'" == "EM" {                             // Verifica se a matriz é EM.
        export delimited using "$TABLES/elasticidades_marshallianas_hsym_stata.csv", replace // Exporta Marshallianas.
    }                                              // Fecha condição EM.
    if "`M'" == "EH" {                             // Verifica se a matriz é EH.
        export delimited using "$TABLES/elasticidades_compensadas_hsym_stata.csv", replace // Exporta compensadas.
    }                                              // Fecha condição EH.
    restore                                        // Restaura dados originais.
}                                                  // Fecha loop das matrizes.

log close                                          // Fecha log das elasticidades.
