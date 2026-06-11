/****************************************************************************************
 b_program_operational.do
 ---------------------------------------------------------------------------------------
 Versão corrigida para a lista Berry/BLP.

 Correção central:
 - Como os modelos estimados são lineares nos parâmetros depois da inversão de Berry,
   o GMM é calculado por fórmula fechada, e não por Nelder-Mead.
 - Isso evita problemas de convergência/escala do otimizador e deixa o step(1) igual ao
   IV/GMM linear usual com W = (Z'Z/N)^(-1).
 - O step(2) atualiza W com a matriz robusta dos momentos e reestima.

 Momentos:
     g_N(beta) = (1/N) Z'(Y - X beta)

 Critério:
     J_N(beta) = N g_N(beta)' W g_N(beta)
****************************************************************************************/

capture program drop berry_gmm_code
mata: mata clear

mata:
real matrix BERRY_SYMINV(real matrix A)
{
    real matrix B
    B = invsym(A)
    if (sum(missing(B)) > 0) B = pinv(A)
    return(B)
}

real colvector BERRY_LINGMM(real matrix Y, real matrix X, real matrix Z, real matrix W)
{
    real scalar N
    real matrix ZX, ZY, A, b

    N  = rows(Y)
    ZX = quadcross(Z, X) / N
    ZY = quadcross(Z, Y) / N

    A = ZX' * W * ZX
    b = BERRY_SYMINV(A) * (ZX' * W * ZY)
    return(b)
}

void BERRY_RUN_GMM(string scalar yvars,
                   string scalar xvars,
                   string scalar zvars,
                   string scalar step_s)
{
    real scalar N, k, q, step, Q
    real matrix Y, X, Z, W, b, xi, Zxi, Szz, Gbar, G, A, B, Ainv, V

    Y = st_data(., tokens(yvars))
    X = st_data(., tokens(xvars))
    Z = st_data(., tokens(zvars))

    step = strtoreal(step_s)
    if (missing(step)) step = 2

    N = rows(Y)
    k = cols(X)
    q = cols(Z)

    if (N <= k) {
        errprintf("Número de observações insuficiente para o número de parâmetros.\n")
        exit(3498)
    }
    if (q < k) {
        errprintf("Modelo subidentificado: número de instrumentos menor que número de parâmetros.\n")
        exit(3498)
    }

    /* Step 1: matriz de ponderação inicial */
    W = BERRY_SYMINV(quadcross(Z, Z) / N)
    b = BERRY_LINGMM(Y, X, Z, W)

    xi  = Y - X * b
    Zxi = Z :* (xi * J(1, q, 1))
    Szz = quadcross(Zxi, Zxi) / N

    /* Step 2: GMM eficiente com matriz robusta dos momentos */
    if (step == 2) {
        W = BERRY_SYMINV(Szz)
        b = BERRY_LINGMM(Y, X, Z, W)
        xi  = Y - X * b
        Zxi = Z :* (xi * J(1, q, 1))
        Szz = quadcross(Zxi, Zxi) / N
    }

    Gbar = quadcross(Z, xi) / N
    G    = quadcross(Z, X) / N
    A    = G' * W * G
    B    = G' * W * Szz * W * G
    Ainv = BERRY_SYMINV(A)
    V    = Ainv * B * Ainv / N
    Q    = N * Gbar' * W * Gbar

    st_matrix("BERRY_b", b')
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
    ereturn local title "Berry/BLP GMM linear operacional"

    restore
end
