/****************************************************************************************
COMENTÁRIOS DETALHADOS
- import delimited lê o CSV original preservando as colunas como texto para evitar conversões erradas.
- Os locals v1...v11 capturam a ordem original das colunas e permitem renomear nomes com espaços.
- destring transforma variáveis numéricas importadas como texto em números utilizáveis nas regressões.
- drop remove o bem externo da amostra interna; ele entra somente por s0 na inversão logit.
- gen cria share, outside_share, delta e constante, conforme a inversão de Berry.
- egen group cria identificadores numéricos de firma e segmento para loops, gráficos e Mata.
- Os loops foreach constroem instrumentos BLP: somas dos demais produtos da mesma firma e de firmas rivais.
- As variáveis de nest calculam s_g, s_{j|g}, ln(s_{j|g}) e instrumentos para o nested logit.
- save/export delimited gravam a base preparada em DTA e CSV para reutilização nas demais etapas.
****************************************************************************************/
/****************************************************************************************
01 - Tratamento da base e construção dos instrumentos BLP
****************************************************************************************/
import delimited "$DATA", clear varnames(1) bindquote(strict) stringcols(_all)

* Renomeia por posição para ficar robusto a nomes importados com espaços.
* O comando ds lista as variáveis existentes após o import.
* Em seguida, r(varlist) é guardado no local `vars'.
* Essa forma é compatível com o Stata; evita o erro "varlist not allowed" gerado por "local vars : varlist _all".
ds
local vars `r(varlist)'
local v1 : word 1 of `vars'
local v2 : word 2 of `vars'
local v3 : word 3 of `vars'
local v4 : word 4 of `vars'
local v5 : word 5 of `vars'
local v6 : word 6 of `vars'
local v7 : word 7 of `vars'
local v8 : word 8 of `vars'
local v9 : word 9 of `vars'
local v10 : word 10 of `vars'
local v11 : word 11 of `vars'
rename `v1' idProduct
rename `v2' firm
rename `v3' product
rename `v4' price
rename `v5' shelf_price
rename `v6' ad_price
rename `v7' share_pct
rename `v8' segment
rename `v9' cals
rename `v10' fat
rename `v11' sugar

foreach v in idProduct price shelf_price ad_price share_pct cals fat sugar {
    destring `v', replace force
}

* Remove bem externo; ele entra apenas por s0 na inversão logit.
drop if lower(firm)=="basketof" | missing(segment)
drop if missing(price, share_pct, cals, fat, sugar)

gen share = share_pct/100
gen outside_share = $S0
gen delta = ln(share) - ln($S0)
gen cons = 1

egen idfirm = group(firm), label
egen idsegment = group(segment), label

* Instrumentos Berry/BLP por firma: soma dos demais produtos da mesma firma e soma dos rivais.
foreach x of global XVARS {
    bysort firm: egen total_firm_`x' = total(`x')
    egen total_all_`x' = total(`x')
    bysort firm: gen n_firm_`x' = _N
    gen own_`x' = total_firm_`x' - `x'
    replace own_`x' = 0 if n_firm_`x' <= 1
    gen rival_`x' = total_all_`x' - total_firm_`x'
}

bysort firm: gen n_products_firm = _N
gen n_total_products = _N
gen n_rival_products = n_total_products - n_products_firm

* Variáveis para nested logit.
bysort segment: egen nest_share = total(share)
gen share_within_nest = share/nest_share
gen log_share_within_nest = ln(share_within_nest)
bysort segment: gen n_products_nest = _N
gen n_same_nest_other = n_products_nest - 1
gen n_rival_nest = n_total_products - n_products_nest
foreach x of global XVARS {
    bysort segment: egen total_nest_`x' = total(`x')
    gen nest_own_`x' = total_nest_`x' - `x'
    gen nest_rival_`x' = total_all_`x' - total_nest_`x'
}

order idProduct firm product segment price share delta cals fat sugar
save "$OUTDATA/prepared_data_stata.dta", replace
export delimited using "$OUTDATA/prepared_data_stata.csv", replace
