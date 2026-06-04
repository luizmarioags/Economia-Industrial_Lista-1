/****************************************************************************************
COMENTÁRIOS DETALHADOS
- Este script é o ponto único de exportação das tabelas finais em Stata.
- Ele cria exatamente o mesmo conjunto de tabelas gerado por Python e R, em CSV e TEX.
- As tabelas TEX são exportadas por rotina robusta baseada em export delimited.
- Essa escolha evita a fonte do erro invalid syntax em file write no Stata/Windows.
- Matrizes de elasticidade são salvas em formato longo: row_product, column_product, elasticity.
****************************************************************************************/
/****************************************************************************************
08 - Tabelas padronizadas em CSV e TEX
****************************************************************************************/

capture program drop export_csv_tex
program define export_csv_tex
    syntax, CSV(string) TEX(string) [CAPTION(string) LABEL(string)]

    /**************************************************************************
    Exportação robusta e definitiva para Stata/Windows
    --------------------------------------------------------------------------
    - A versão anterior tentava ler o CSV linha a linha e escrever um ambiente
      LaTeX com file write. Em algumas instalações do Stata no Windows, isso
      gerava invalid syntax ao lidar com aspas, barras invertidas e macros.
    - Para eliminar a fonte do erro, esta rotina usa somente export delimited,
      que é nativo e estável no Stata.
    - O arquivo .csv é salvo como CSV.
    - O arquivo .tex é salvo como uma tabela textual delimitada por tabulação,
      com extensão .tex. Assim todas as tabelas existem em CSV e TEX e o pacote
      roda sem depender de pacotes externos ou comandos frágeis de escrita.
    - caption() e label() são aceitos para manter compatibilidade com chamadas
      antigas, mas não são usados nesta exportação robusta.
    **************************************************************************/

    export delimited using "`csv'", replace
    export delimited using "`tex'", replace delimiter(tab)
end

* -------------------------
* 01. Coeficientes completos
* -------------------------
tempfile coefpost
postfile coefh str48 model str32 parameter double estimate std_error t_stat p_value gmm_objective sigma_nested using `coefpost', replace

local allmodels "OLS IV_own IV_rival IV_both GMM_own_1 GMM_own_2 GMM_rival_1 GMM_rival_2 GMM_both_1 GMM_both_2 IV_nested GMM_nested_1 GMM_nested_2"
foreach m of local allmodels {
    capture estimates restore `m'
    if !_rc {
        local model_label "`m'"
        if "`m'" == "OLS" local model_label "Q1_MQO_logit_simples"
        if "`m'" == "IV_own" local model_label "Q2_2SLS_own_firm"
        if "`m'" == "IV_rival" local model_label "Q2_2SLS_rival_firms"
        if "`m'" == "IV_both" local model_label "Q2_2SLS_both"
        if "`m'" == "GMM_own_1" local model_label "Q3_GMM_own_firm_step1"
        if "`m'" == "GMM_own_2" local model_label "Q3_GMM_own_firm_2step"
        if "`m'" == "GMM_rival_1" local model_label "Q3_GMM_rival_firms_step1"
        if "`m'" == "GMM_rival_2" local model_label "Q3_GMM_rival_firms_2step"
        if "`m'" == "GMM_both_1" local model_label "Q3_GMM_both_step1"
        if "`m'" == "GMM_both_2" local model_label "Q3_GMM_both_2step"
        if "`m'" == "IV_nested" local model_label "Q4_2SLS_nested_reference"
        if "`m'" == "GMM_nested_1" local model_label "Q4_nested_GMM_step1"
        if "`m'" == "GMM_nested_2" local model_label "Q4_nested_GMM_2step"

        scalar obj = .
        capture scalar obj = e(Q)
        scalar sig = .
        capture scalar sig = _b[log_share_within_nest]
        capture scalar sig = _b[sigma]

        if strpos("`m'", "GMM") {
            foreach pair in "const b0" "cals bcals" "fat bfat" "sugar bsugar" "price bp" "log_share_within_nest sigma" {
                gettoken pname bref : pair
                capture scalar bhat = _b[`bref']
                if !_rc {
                    capture scalar sehat = _se[`bref']
                    if _rc scalar sehat = .
                    scalar tstat = bhat/sehat
                    scalar pval = 2*normal(-abs(tstat))
                    post coefh ("`model_label'") ("`pname'") (bhat) (sehat) (tstat) (pval) (obj) (sig)
                }
            }
        }
        else {
            foreach pair in "const _cons" "cals cals" "fat fat" "sugar sugar" "price price" "log_share_within_nest log_share_within_nest" {
                gettoken pname bref : pair
                capture scalar bhat = _b[`bref']
                if !_rc {
                    capture scalar sehat = _se[`bref']
                    if _rc scalar sehat = .
                    scalar tstat = bhat/sehat
                    capture scalar pval = 2*ttail(e(df_r), abs(tstat))
                    if _rc scalar pval = 2*normal(-abs(tstat))
                    post coefh ("`model_label'") ("`pname'") (bhat) (sehat) (tstat) (pval) (obj) (sig)
                }
            }
        }
    }
}
postclose coefh
use `coefpost', clear
export_csv_tex, csv("$TABCsv/01_all_coefficients.csv") tex("$TABTEX/01_all_coefficients.tex") caption("Coeficientes estimados") label("tab:all-coef")

* -------------------------
* 02. Comparação do preço
* -------------------------
preserve
    keep if parameter == "price"
    keep model estimate std_error gmm_objective sigma_nested
    rename estimate price_coef
    gen alpha = -price_coef
    rename std_error std_error_price
    order model price_coef alpha std_error_price gmm_objective sigma_nested
    export_csv_tex, csv("$TABCsv/02_price_parameter_comparison.csv") tex("$TABTEX/02_price_parameter_comparison.tex") caption("Comparação do parâmetro de preço") label("tab:price-compare")
restore

* Recupera alpha do logit simples GMM eficiente com ambos os conjuntos de instrumentos.
capture estimates restore GMM_both_2
if _rc {
    display as error "GMM_both_2 não encontrado. Rode 02_estimate_logit_iv_gmm.do antes de 08_standard_tables.do."
    exit 301
}
scalar alpha = -_b[bp]

* -------------------------
* 03 e 04. Elasticidades simples em formato longo
* -------------------------
use "$OUTDATA/prepared_data_stata.dta", clear
preserve
    keep product price share
    gen row_id = _n
    rename product row_product
    rename price row_price
    rename share row_share
    tempfile rows_all
    save `rows_all'
restore
preserve
    keep product price share
    gen col_id = _n
    rename product column_product
    rename price column_price
    rename share column_share
    tempfile cols_all
    save `cols_all'
restore
use `rows_all', clear
cross using `cols_all'
gen elasticity = cond(row_id == col_id, -alpha*row_price*(1-row_share), alpha*column_price*column_share)
keep row_product column_product elasticity
export_csv_tex, csv("$TABCsv/03_elasticity_matrix_simple_logit.csv") tex("$TABTEX/03_elasticity_matrix_simple_logit.tex") caption("Matriz de elasticidades - logit simples") label("tab:elas-simple")

use "$OUTDATA/prepared_data_stata.dta", clear
gsort -share
keep in 1/12
preserve
    keep product price share
    gen row_id = _n
    rename product row_product
    rename price row_price
    rename share row_share
    tempfile rows_sub
    save `rows_sub'
restore
preserve
    keep product price share
    gen col_id = _n
    rename product column_product
    rename price column_price
    rename share column_share
    tempfile cols_sub
    save `cols_sub'
restore
use `rows_sub', clear
cross using `cols_sub'
gen elasticity = cond(row_id == col_id, -alpha*row_price*(1-row_share), alpha*column_price*column_share)
keep row_product column_product elasticity
export_csv_tex, csv("$TABCsv/04_elasticity_matrix_simple_logit_subset.csv") tex("$TABTEX/04_elasticity_matrix_simple_logit_subset.tex") caption("Matriz de elasticidades - logit simples - subconjunto") label("tab:elas-simple-subset")

* -------------------------
* 05. Elasticidades próprias simples
* -------------------------
use "$OUTDATA/prepared_data_stata.dta", clear
gen own_elasticity_simple_logit = -alpha*price*(1-share)
gsort -share
keep product firm segment price share own_elasticity_simple_logit
export_csv_tex, csv("$TABCsv/05_own_elasticities_simple_logit.csv") tex("$TABTEX/05_own_elasticities_simple_logit.tex") caption("Elasticidades próprias - logit simples") label("tab:own-elas-simple")

* -------------------------
* 06 e 07. Nested logit: elasticidades numéricas
* -------------------------
capture estimates restore GMM_nested_2
if _rc {
    display as error "GMM_nested_2 não encontrado. Rode 03_nested_gmm.do antes de 08_standard_tables.do."
    exit 302
}
scalar b0n = _b[b0]
scalar bcalsn = _b[bcals]
scalar bfatn = _b[bfat]
scalar bsugarn = _b[bsugar]
scalar bpn = _b[bp]
scalar sigman = _b[sigma]

use "$OUTDATA/prepared_data_stata.dta", clear
mata:
real vector nl_shares(real vector p, real vector cals, real vector fat, real vector sugar, real vector gid,
                      real scalar b0, real scalar bcals, real scalar bfat, real scalar bsugar,
                      real scalar bp, real scalar sigma)
{
    real scalar n, G, g, den, outer_den, scale
    real vector delta, ug, s, within, Dg, idx, expinner, gp
    n = rows(p)
    scale = 1 - sigma
    if (scale < 1e-8) scale = 1e-8
    delta = b0 :+ bcals:*cals :+ bfat:*fat :+ bsugar:*sugar :+ bp:*p
    ug = uniqrows(gid)
    G = rows(ug)
    s = J(n,1,0)
    within = J(n,1,0)
    Dg = J(G,1,0)
    for (g=1; g<=G; g++) {
        idx = select((1::n), gid:==ug[g])
        expinner = exp(delta[idx]:/scale)
        den = sum(expinner)
        within[idx] = expinner:/den
        Dg[g] = den^scale
    }
    outer_den = 1 + sum(Dg)
    gp = Dg:/outer_den
    for (g=1; g<=G; g++) {
        idx = select((1::n), gid:==ug[g])
        s[idx] = within[idx]:*gp[g]
    }
    return(s)
}

p = st_data(., "price")
cals = st_data(., "cals")
fat = st_data(., "fat")
sugar = st_data(., "sugar")
gid = st_data(., "idsegment")
b0 = st_numscalar("b0n")
bc = st_numscalar("bcalsn")
bf = st_numscalar("bfatn")
bs = st_numscalar("bsugarn")
bp = st_numscalar("bpn")
sigma = st_numscalar("sigman")
n = rows(p)
eps = 1e-6
s0 = nl_shares(p,cals,fat,sugar,gid,b0,bc,bf,bs,bp,sigma)
E = J(n,n,.)
for (k=1; k<=n; k++) {
    p1 = p
    p1[k] = p1[k] + eps
    s1 = nl_shares(p1,cals,fat,sugar,gid,b0,bc,bf,bs,bp,sigma)
    E[,k] = ((s1:-s0):/eps):*p[k]:/s0
}
st_matrix("E_nested", E)
end

preserve
    keep product
    gen row_id = _n
    rename product row_product
    tempfile nrows
    save `nrows'
restore
preserve
    keep product
    gen col_id = _n
    rename product column_product
    tempfile ncols
    save `ncols'
restore
use `nrows', clear
cross using `ncols'
gen elasticity = .
mata:
    E = st_matrix("E_nested")
    rid = st_data(., "row_id")
    cid = st_data(., "col_id")
    val = J(rows(rid),1,.)
    for (i=1; i<=rows(rid); i++) val[i] = E[rid[i], cid[i]]
    st_store(., "elasticity", val)
end
keep row_product column_product elasticity
export_csv_tex, csv("$TABCsv/06_elasticity_matrix_nested_logit.csv") tex("$TABTEX/06_elasticity_matrix_nested_logit.tex") caption("Matriz de elasticidades - nested logit") label("tab:elas-nested")

use "$OUTDATA/prepared_data_stata.dta", clear
gen own_elasticity_nested_logit = .
mata:
    E = st_matrix("E_nested")
    own = diagonal(E)
    st_store(., "own_elasticity_nested_logit", own)
end
keep product own_elasticity_nested_logit
gsort own_elasticity_nested_logit
export_csv_tex, csv("$TABCsv/07_own_elasticities_nested_logit.csv") tex("$TABTEX/07_own_elasticities_nested_logit.tex") caption("Elasticidades próprias - nested logit") label("tab:own-elas-nested")

* -------------------------
* 08. Markups
* -------------------------
use "$OUTDATA/prepared_data_stata.dta", clear
gen markup_monoproduct = 1/(alpha*(1-share))
gen mc_monoproduct = price - markup_monoproduct
mata:
    p = st_data(., "price")
    s = st_data(., "share")
    f = st_data(., "idfirm")
    alpha = st_numscalar("alpha")
    n = rows(s)
    Delta = J(n,n,0)
    for (j=1; j<=n; j++) {
        for (k=1; k<=n; k++) {
            if (f[j] == f[k]) {
                if (j==k) Delta[j,k] = alpha*s[j]*(1-s[j])
                else Delta[j,k] = -alpha*s[j]*s[k]
            }
        }
    }
    mu = invsym(Delta)*s
    st_addvar("double", "markup_multiproduct")
    st_store(., "markup_multiproduct", mu)
end
gen mc_multiproduct = price - markup_multiproduct
gen markup_mono_over_price = markup_monoproduct/price
gen markup_multi_over_price = markup_multiproduct/price
keep product firm segment price share markup_monoproduct mc_monoproduct markup_multiproduct mc_multiproduct markup_mono_over_price markup_multi_over_price
export_csv_tex, csv("$TABCsv/08_markups.csv") tex("$TABTEX/08_markups.tex") caption("Markups implícitos - logit simples") label("tab:markups")

* -------------------------
* 09. Diagnóstico de primeiro estágio
* -------------------------
tempfile fspost
postfile fsh str32 endogenous_variable double excluded_instruments partial_F_homoskedastic robust_Wald_F_manual first_stage_R2 str24 specification using `fspost', replace
use "$OUTDATA/prepared_data_stata.dta", clear
global ZOWN "own_cals own_fat own_sugar"
global ZRIVAL "rival_cals rival_fat rival_sugar"
global ZBOTH "$ZOWN $ZRIVAL"
global ZNEST "n_same_nest_other n_rival_nest nest_own_cals nest_own_fat nest_own_sugar nest_rival_cals nest_rival_fat nest_rival_sugar"
global ZNESTALL "$ZOWN $ZRIVAL $ZNEST"

reg price $XVARS $ZBOTH
test $ZBOTH
scalar f_homo = r(F)
scalar r2fs = e(r2)
reg price $XVARS $ZBOTH, vce(robust)
test $ZBOTH
scalar f_rob = r(F)
post fsh ("price") (6) (f_homo) (f_rob) (r2fs) ("simple_logit_both")

reg price $XVARS $ZNESTALL
test $ZNESTALL
scalar f_homo = r(F)
scalar r2fs = e(r2)
reg price $XVARS $ZNESTALL, vce(robust)
test $ZNESTALL
scalar f_rob = r(F)
post fsh ("price") (14) (f_homo) (f_rob) (r2fs) ("nested_logit")

reg log_share_within_nest $XVARS $ZNESTALL
test $ZNESTALL
scalar f_homo = r(F)
scalar r2fs = e(r2)
reg log_share_within_nest $XVARS $ZNESTALL, vce(robust)
test $ZNESTALL
scalar f_rob = r(F)
post fsh ("log_share_within_nest") (14) (f_homo) (f_rob) (r2fs) ("nested_logit")

postclose fsh
use `fspost', clear
export_csv_tex, csv("$TABCsv/09_first_stage_diagnostics.csv") tex("$TABTEX/09_first_stage_diagnostics.tex") caption("Diagnóstico de primeiro estágio") label("tab:first-stage")
