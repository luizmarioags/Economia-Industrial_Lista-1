/****************************************************************************************
 b_program_operational.do
 ---------------------------------------------------------------------------------------
 Base operacional inspirada no arquivo original b_program.do de Victor Gomes (2022).

 O arquivo original definia:
   1) uma função Mata GMM_OBJ(todo, betas, Y, X, Z, W, crit, g, H);
   2) um programa eclass gmm_code que carregava uma base, montava Y, X, Z,
      otimizava o critério GMM em Mata e postava os coeficientes no ereturn.

 Esta versão generaliza a mesma lógica para o pacote Berry/BLP da lista:
   - o usuário define Y, X, Z e os nomes dos parâmetros via globals;
   - o programa berry_gmm_code carrega a base indicada em $BERRY_usefile;
   - o critério estimado é N * gbar(theta)' W gbar(theta), com
     gbar(theta) = N^{-1} Z' [Y - X beta];
   - step(1): W = [N^{-1} Z'Z]^{-1};
   - step(2): primeiro estima com W inicial, depois atualiza W com a matriz robusta
     dos momentos e reotimiza;
   - o resultado é postado como eclass, permitindo estimates store/restore,
     eststo, _b[bp], _se[bp], e(Q), e(N), e(step), etc.

 Observação técnica importante:
   - O Mata que executa a estimação fica em funções Mata fora do program Stata.
   - Dentro de um program Stata, blocos Mata multilinha podem fazer o `end' ser lido
     como fim do program. Isso causava o erro "matrix BERRY_b not found" ao carregar
     o wrapper. Por isso berry_gmm_code chama Mata em uma linha:
         mata: BERRY_RUN_GMM("...", "...", "...", "...")
****************************************************************************************/

capture program drop berry_gmm_code
mata: mata clear

mata:
void BERRY_GMM_OBJ(todo, betas, Y, X, Z, W, crit, g, H)
{
    real scalar N
    real matrix XI, Gbar

    N    = rows(Z)
    XI   = Y - X * betas'
    Gbar = (quadcross(Z, XI)) / N
    crit = N * (Gbar)' * W * (Gbar)
}

real matrix BERRY_SYMINV(real matrix A)
{
    real matrix B
    B = invsym(A)
    if (sum(missing(B)) > 0) B = pinv(A)
    return(B)
}

real rowvector BERRY_OPTIMIZE(real matrix Y, real matrix X, real matrix Z,
                              real matrix W, real rowvector start)
{
    transmorphic S
    real rowvector p

    S = optimize_init()
    optimize_init_evaluator(S, &BERRY_GMM_OBJ())
    optimize_init_evaluatortype(S, "d0")
    optimize_init_technique(S, "nm")
    optimize_init_nmsimplexdeltas(S, 0.01)
    optimize_init_conv_vtol(S, 1e-12)
    optimize_init_conv_ptol(S, 1e-10)
    optimize_init_conv_maxiter(S, 20000)
    optimize_init_which(S, "min")
    optimize_init_params(S, start)
    optimize_init_argument(S, 1, Y)
    optimize_init_argument(S, 2, X)
    optimize_init_argument(S, 3, Z)
    optimize_init_argument(S, 4, W)

    p = optimize(S)
    return(p)
}

void BERRY_RUN_GMM(string scalar yvars,
                   string scalar xvars,
                   string scalar zvars,
                   string scalar step_s)
{
    real scalar N, k, step, q
    real matrix Y, X, Z, XX, XY, W, xi, Zxi, Szz, Gbar, D, A, B, Ainv, V
    real rowvector bstart, p
    real scalar Q

    Y = st_data(., tokens(yvars))
    X = st_data(., tokens(xvars))
    Z = st_data(., tokens(zvars))

    step = strtoreal(step_s)
    if (missing(step)) step = 2

    N = rows(Y)
    k = cols(X)
    q = cols(Z)

    XX = quadcross(X, X)
    XY = quadcross(X, Y)
    bstart = (BERRY_SYMINV(XX) * XY)'
    if (sum(missing(bstart)) > 0) bstart = J(1, k, 0)

    W = BERRY_SYMINV(quadcross(Z, Z) / N)
    p = BERRY_OPTIMIZE(Y, X, Z, W, bstart)

    xi = Y - X * p'
    Zxi = Z :* (xi * J(1, q, 1))
    Szz = quadcross(Zxi, Zxi) / N

    if (step == 2) {
        W = BERRY_SYMINV(Szz)
        p = BERRY_OPTIMIZE(Y, X, Z, W, p)
        xi = Y - X * p'
        Zxi = Z :* (xi * J(1, q, 1))
        Szz = quadcross(Zxi, Zxi) / N
    }

    Gbar = quadcross(Z, xi) / N
    D = -quadcross(Z, X) / N
    A = D' * W * D
    B = D' * W * Szz * W * D
    Ainv = BERRY_SYMINV(A)
    V = Ainv * B * Ainv / N
    Q = N * (Gbar)' * W * (Gbar)

    st_matrix("BERRY_b", p)
    st_matrix("BERRY_V", V)
    st_numscalar("BERRY_Q", Q)
    st_numscalar("BERRY_N", N)
    st_numscalar("BERRY_k", k)
    st_numscalar("BERRY_df_m", k-1)
    st_numscalar("BERRY_q", q)
    st_numscalar("BERRY_j", q-k)
}
end

program define berry_gmm_code, eclass
    version 17

    preserve

    if "$BERRY_usefile" == "" {
        display as error "Defina global BERRY_usefile antes de chamar berry_gmm_code."
        exit 198
    }
    if "$BERRY_y" == "" {
        display as error "Defina global BERRY_y antes de chamar berry_gmm_code."
        exit 198
    }
    if "$BERRY_x" == "" {
        display as error "Defina global BERRY_x antes de chamar berry_gmm_code."
        exit 198
    }
    if "$BERRY_z" == "" {
        display as error "Defina global BERRY_z antes de chamar berry_gmm_code."
        exit 198
    }
    if "$BERRY_bnames" == "" {
        display as error "Defina global BERRY_bnames antes de chamar berry_gmm_code."
        exit 198
    }

    use "$BERRY_usefile", clear

    if "$BERRY_sampleif" != "" {
        keep if $BERRY_sampleif
    }

    if "$BERRY_bootrun" == "1" {
        bsample
    }

    local berry_allvars "$BERRY_y $BERRY_x $BERRY_z"
    local berry_allvars : list uniq berry_allvars
    tempvar berry_missing
    quietly gen byte `berry_missing' = 0
    foreach v of local berry_allvars {
        quietly replace `berry_missing' = 1 if missing(`v')
    }
    quietly drop if `berry_missing'

    local y      "$BERRY_y"
    local x      "$BERRY_x"
    local z      "$BERRY_z"
    local bnames "$BERRY_bnames"
    local step   "$BERRY_step"
    if "`step'" == "" local step "2"

    local kx : word count `x'
    local kb : word count `bnames'
    if `kx' != `kb' {
        display as error "Número de variáveis em BERRY_x (`kx') difere do número de nomes em BERRY_bnames (`kb')."
        exit 198
    }

    * A estimação em Mata é chamada em uma única linha para não fechar o program.
    mata: BERRY_RUN_GMM("`y'", "`x'", "`z'", "`step'")

    matrix colnames BERRY_b = `bnames'
    matrix colnames BERRY_V = `bnames'
    matrix rownames BERRY_V = `bnames'

    ereturn post BERRY_b BERRY_V, obs(`=BERRY_N')
    ereturn scalar Q = BERRY_Q
    ereturn scalar N = BERRY_N
    ereturn scalar k = BERRY_k
    ereturn scalar df_m = BERRY_df_m
    ereturn scalar q = BERRY_q
    ereturn scalar J = BERRY_j
    ereturn scalar step = `step'
    ereturn local depvar "$BERRY_y"
    ereturn local xvars "$BERRY_x"
    ereturn local zvars "$BERRY_z"
    ereturn local vcetype "Robust"
    ereturn local vce "robust"
    ereturn local cmd "berry_gmm_code"
    ereturn local title "Berry/BLP GMM operacional baseado em b_program.do"

    restore
end
