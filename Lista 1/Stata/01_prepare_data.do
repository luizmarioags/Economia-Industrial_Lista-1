/********************************************************************
 Questões preparatórias: importa dados, corrige escala e cria variáveis
********************************************************************/


* Carrega configuração se o script for rodado individualmente.
do "Stata/_load_config_if_needed.do"

clear

di as text _newline "[Stata] Preparação dos dados: iniciando"
di as text "[Stata] Variáveis a calcular: ln_q, ln_y, ln_pch, ln_pb, z, z_sq, z_cu, z_lag, z_lag_sq"

* Usa o arquivo .dta como fonte preferencial, porque preserva decimais.
cap confirm file "$RAW/chicken.dta"
if !_rc {
    di as text "[Stata] Fonte usada: data/raw/chicken.dta"
    use "$RAW/chicken.dta", clear
}
else {
    * Se o .dta não existir, importa o CSV separado por ponto e vírgula.
    di as text "[Stata] Fonte usada: data/raw/chicken.csv com separador ';'"
    import delimited "$RAW/chicken.csv", delimiter(";") varnames(1) clear case(lower)
    destring, replace ignore(" ")
}

di as text "[Stata] Base importada: " _N " linhas; colunas listadas abaixo"
describe, short

* Padroniza nomes para minúsculas.
rename *, lower
di as text "[Stata] Nomes padronizados para minúsculas"

* Harmoniza nomes alternativos que aparecem na lista.
cap confirm variable tim
if !_rc {
    cap confirm variable time
    if _rc {
        rename tim time          // só executa se time NÃO existe
    }
    else {
        di as text "[Stata] Variável time já existe; renomeação de tim ignorada"
    }
}
cap confirm variable eatex
if !_rc {
    rename eatex meatex
    di as text "[Stata] Nome harmonizado: eatex -> meatex"
}

* Corrige a escala do CSV quando os decimais aparecem removidos.
* Essas regras não alteram o .dta correto, pois só atuam em valores muito grandes.
di as text "[Stata] Aplicando regras de correção de escala apenas para valores anormalmente altos"
replace year   = year/1000       if year   > 9999
replace q      = q/100000        if q      > 1000
replace y      = y/1000          if y      > 100000
replace pchick = pchick/100000   if pchick > 10000
replace pbeef  = pbeef/100000    if pbeef  > 10000
replace pcor   = pcor/100000     if pcor   > 10000
replace pf     = pf/100000       if pf     > 10000 & pf < .
replace cpi    = cpi/100000      if cpi    > 10000
replace pop    = pop/10000       if pop    > 10000
replace time   = time/100000     if time   > 10000

* Ordena a série anual e declara estrutura temporal para criar defasagens.
sort year
tsset year, yearly
summarize year, meanonly
di as text "[Stata] Série anual ordenada: " r(min) " a " r(max)

* Constrói as variáveis log-log exatamente como definidas na lista.
di as text "[Stata] Calculando ln_q = ln(Q), ln_y = ln(Y), ln_pch = ln(PCHICK/CPI), ln_pb = ln(PBEEF/CPI), z = ln(PCOR/CPI)"
gen double ln_q   = ln(q)              // q_t = ln(Q_t)
gen double ln_y   = ln(y)              // y_t = ln(Y_t)
gen double ln_pch = ln(pchick/cpi)     // p^ch_t = ln(PCHICK_t/CPI_t)
gen double ln_pb  = ln(pbeef/cpi)      // p^b_t = ln(PBEEF_t/CPI_t)
gen double z      = ln(pcor/cpi)       // z_t = ln(PCOR_t/CPI_t)

* Cria instrumentos não lineares e defasados pedidos na questão 8.
di as text "[Stata] Calculando instrumentos alternativos: z_sq=z^2, z_cu=z^3, z_lag=L.z, z_lag_sq=z_lag^2"
gen double z_sq      = z^2             // z_t^2
gen double z_cu      = z^3             // z_t^3
gen double z_lag     = L.z             // z_{t-1}
gen double z_lag_sq  = z_lag^2         // z_{t-1}^2

di as text "[Stata] Variáveis calculadas: ln_q ln_y ln_pch ln_pb z z_sq z_cu z_lag z_lag_sq"
summarize ln_q ln_y ln_pch ln_pb z z_sq z_cu z_lag z_lag_sq

* Salva a base tratada para os demais scripts.
compress
save "$PROC/chicken_prepared_stata.dta", replace

di as text "[Stata] Base tratada salva: data/processed/chicken_prepared_stata.dta"

* Exporta também em CSV para inspeção rápida.
export delimited using "$PROC/chicken_prepared_stata.csv", replace
di as text "[Stata] Base tratada exportada: data/processed/chicken_prepared_stata.csv"
