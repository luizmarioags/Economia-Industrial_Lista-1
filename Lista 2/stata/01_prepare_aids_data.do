/*******************************************************************************
Arquivo: stata/01_prepare_aids_data.do
Objetivo: importar a base, calcular dispêndios, participações, índice de Stone,
          log-preços normalizados, instrumentos defasados e estatísticas descritivas.
*******************************************************************************/

do "stata/00_config_aids.do"                       // Carrega caminhos, macros e opções gerais.

log using "$LOGS/01_prepare_aids_data.log", replace text // Abre log da preparação dos dados.

import delimited using "$RAW_CSV", clear varnames(1) case(lower) // Importa o CSV e coloca nomes em minúsculas.

describe                                          // Mostra estrutura da base importada.
summarize                                         // Mostra estatísticas descritivas gerais.

isid year                                         // Verifica se o ano identifica unicamente cada observação.
sort year                                         // Ordena a base cronologicamente.
tsset year                                        // Declara a base como série temporal anual.

foreach g in bfvl pork poult fish {               // Percorre cada produto usado no sistema.
    capture confirm variable x`g'                 // Verifica se a variável de dispêndio do produto já existe.
    if _rc {                                      // Entra neste bloco se a variável de dispêndio não existir.
        gen double x`g' = `g'p * `g'q             // Cria dispêndio como preço vezes quantidade se necessário.
    }                                             // Fecha a condição de criação do dispêndio.
    label variable x`g' "Dispendio com `g'"       // Rotula o dispêndio do produto.
}                                                 // Fecha o loop dos produtos.

egen double xtotal_calc = rowtotal(xbfvl xpork xpoult xfish) // Soma os dispêndios dos quatro produtos.
label variable xtotal_calc "Dispendio total condicional com carnes" // Rotula o dispêndio total calculado.

capture confirm variable xtotal                   // Verifica se a base já contém uma variável xtotal.
if !_rc {                                         // Entra se xtotal existir na base original.
    gen double diff_xtotal = xtotal_calc - xtotal // Calcula diferença entre xtotal reconstruído e xtotal original.
    label variable diff_xtotal "xtotal_calc - xtotal original" // Rotula a diferença.
    summarize diff_xtotal                         // Mostra se há divergências numéricas relevantes.
}                                                 // Fecha a condição para xtotal original.

foreach g in bfvl pork poult fish {               // Percorre cada produto para calcular participação.
    gen double w_`g' = x`g' / xtotal_calc          // Calcula participação do produto no dispêndio total de carnes.
    label variable w_`g' "Participacao no dispendio: `g'" // Rotula a participação calculada.
}                                                 // Fecha o loop das participações.

egen double share_sum = rowtotal(w_bfvl w_pork w_poult w_fish) // Soma as participações em cada ano.
label variable share_sum "Soma das participacoes dos quatro produtos" // Rotula a soma das participações.

gen double share_gap = share_sum - 1              // Calcula desvio da soma das participações em relação a 1.
label variable share_gap "Desvio da soma das participacoes em relacao a 1" // Rotula o desvio.

gen byte share_problem = abs(share_gap) > 1e-8    // Marca anos com problema numérico maior que tolerância.
label variable share_problem "Indicador de soma das participacoes diferente de 1" // Rotula o indicador.

summarize share_sum share_gap share_problem       // Resume a checagem da restrição de adding-up nos dados.

foreach g in bfvl pork poult fish {               // Percorre os quatro preços do sistema.
    gen double ln_p_`g' = ln(`g'p)                 // Calcula o logaritmo natural do preço do produto.
    label variable ln_p_`g' "Log do preco de `g'"  // Rotula o log-preço.
    quietly summarize ln_p_`g', meanonly          // Calcula a média temporal do log-preço.
    scalar mean_ln_p_`g' = r(mean)                // Guarda a média temporal em um escalar.
    gen double lngp_`g' = ln_p_`g' - scalar(mean_ln_p_`g') // Normaliza o log-preço retirando sua média.
    label variable lngp_`g' "Log-preco normalizado de `g'" // Rotula o log-preço normalizado.
}                                                 // Fecha o loop dos preços.

foreach g in bfvl pork poult fish {               // Percorre os quatro produtos para obter participação média.
    quietly summarize w_`g', meanonly             // Calcula a média temporal da participação no dispêndio.
    scalar wbar_`g' = r(mean)                     // Guarda a participação média em escalar.
    gen double wbar_`g' = scalar(wbar_`g')        // Cria uma variável constante com a participação média.
    label variable wbar_`g' "Participacao media no dispendio: `g'" // Rotula a participação média.
}                                                 // Fecha o loop das participações médias.

gen double lnP_stone = scalar(wbar_bfvl)*ln_p_bfvl + scalar(wbar_pork)*ln_p_pork + scalar(wbar_poult)*ln_p_poult + scalar(wbar_fish)*ln_p_fish // Calcula o índice de Stone com pesos médios.
label variable lnP_stone "Indice de Stone em log com participacoes medias" // Rotula o índice de Stone.

gen double ln_xtotal = ln(xtotal_calc)            // Calcula o log do dispêndio total com carnes.
label variable ln_xtotal "Log do dispendio total com carnes" // Rotula o log do dispêndio total.

gen double ln_real_x = ln_xtotal - lnP_stone      // Calcula log(x/P^S), isto é, dispêndio real.
label variable ln_real_x "Log do dispendio real: ln(x/P^S)" // Rotula o dispêndio real.

capture confirm variable pce                      // Verifica se a base contém despesa total de consumo.
if !_rc {                                         // Entra se a variável pce existir.
    gen double meat_pce_share = xtotal_calc / pce // Calcula peso do dispêndio com carnes no consumo agregado.
    label variable meat_pce_share "Peso das carnes no PCE" // Rotula a razão carnes/PCE.
}                                                 // Fecha a condição associada ao PCE.

foreach g in bfvl pork poult fish {               // Percorre os produtos para criar diferenças de preço.
    gen double d_`g'_poult = lngp_`g' - lngp_poult // Cria diferença de log-preço contra frango.
    label variable d_`g'_poult "lngp_`g' - lngp_poult" // Rotula a diferença de preço.
}                                                 // Fecha o loop das diferenças.

foreach g in bfvl pork poult fish {               // Percorre os produtos para criar instrumentos defasados.
    gen double L1_lngp_`g' = L1.lngp_`g'           // Cria a primeira defasagem do log-preço normalizado.
    gen double L2_lngp_`g' = L2.lngp_`g'           // Cria a segunda defasagem do log-preço normalizado.
    label variable L1_lngp_`g' "Defasagem 1 de lngp_`g'" // Rotula a primeira defasagem.
    label variable L2_lngp_`g' "Defasagem 2 de lngp_`g'" // Rotula a segunda defasagem.
}                                                 // Fecha o loop dos instrumentos defasados.

foreach g in bfvl pork fish {                     // Percorre as equações estimadas.
    gen double y_`g' = w_`g'                       // Cria alias da variável dependente da equação.
    label variable y_`g' "Variavel dependente AIDS: w_`g'" // Rotula a variável dependente.
}                                                 // Fecha o loop das variáveis dependentes.

order year bfvlp porkp poultp fishp bfvlq porkq poultq fishq xbfvl xpork xpoult xfish xtotal_calc w_bfvl w_pork w_poult w_fish share_sum lnP_stone ln_real_x // Organiza variáveis principais.

export delimited using "$PROC/meatdata_aids_preparado.csv", replace // Exporta dados processados em CSV.
save "$PROC_DTA", replace                          // Salva dados processados em formato Stata.

preserve                                           // Preserva a base em memória para criar tabela de médias.
clear                                              // Limpa a base temporariamente.
set obs 4                                          // Cria quatro linhas, uma para cada produto.
gen str10 produto = ""                             // Cria variável de nome do produto.
replace produto = "bfvl" in 1                      // Escreve o produto bfvl na primeira linha.
replace produto = "pork" in 2                      // Escreve o produto pork na segunda linha.
replace produto = "poult" in 3                     // Escreve o produto poult na terceira linha.
replace produto = "fish" in 4                      // Escreve o produto fish na quarta linha.
gen double wbar = .                                // Cria coluna para a participação média.
replace wbar = scalar(wbar_bfvl) in 1              // Salva participação média de bfvl.
replace wbar = scalar(wbar_pork) in 2              // Salva participação média de pork.
replace wbar = scalar(wbar_poult) in 3             // Salva participação média de poult.
replace wbar = scalar(wbar_fish) in 4              // Salva participação média de fish.
export delimited using "$TABLES/participacoes_medias_stata.csv", replace // Exporta participações médias.
restore                                            // Restaura a base processada.

log close                                          // Fecha o log da preparação.
