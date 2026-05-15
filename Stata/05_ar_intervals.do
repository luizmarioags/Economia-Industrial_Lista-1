/********************************************************************
 Questão 11: intervalo Anderson-Rubin por grade ADAPTATIVA

 Ideia: para cada beta0 candidato, estima-se
   ln_q - beta0*ln_pch = controles + instrumentos + erro.
 Se os instrumentos forem conjuntamente significativos nessa regressão,
 rejeita-se beta0. O conjunto não rejeitado forma o intervalo AR.

 VERSÃO ADAPTATIVA COM CAUDA ABERTA:
   - CORREÇÃO: quando a expansão alcança o limite absoluto,
     a grade capada ainda é avaliada uma vez antes de declarar
     conjunto vazio. Isso evita terminar logo após apenas anunciar
     a expansão para [-100, 100].
   - Começa em uma grade inicial, mas expande automaticamente.
   - Se o IC encostar repetidamente em uma borda, a rotina interpreta
     isso como sinal de intervalo aberto/semi-infinito e para de
     "perseguir" a borda.
   - Exemplo típico: se a saída fica sempre [bmin, -0.770], enquanto
     bmin cai de -5 para -7, -9, -11..., o IC é tratado como
     aberto à esquerda: (-infinito, -0.770].

 A tabela final preserva:
   - ar_low / ar_high: intervalo reportado; missing quando aberto;
   - ar_low_grid / ar_high_grid: menor/maior beta aceito dentro da
     grade efetivamente testada;
   - open_left / open_right: flags de cauda aberta;
   - grid_min / grid_max: grade final efetivamente avaliada.
********************************************************************/

use "$PROC/chicken_prepared_stata.dta", clear

di as text _newline "[Stata] Questão 11: intervalos Anderson-Rubin com grade adaptativa e detecção de cauda aberta"
di as text "[Stata] Modelos avaliados: Z1, Z2 e Z7"
di as text "[Stata] Para cada beta0: y_AR = ln_q - beta0*ln_pch; teste dos instrumentos excluídos em y_AR ~ controles + instrumentos"

/********************************************************************
 Programa auxiliar: avalia uma grade AR na base atualmente carregada.
 O programa deixa carregada a base da grade gerada.
********************************************************************/
capture program drop ar_grid_scan
program define ar_grid_scan, rclass
    version 15
    syntax varlist(min=1), BMIN(real) BMAX(real) STEP(real) ALPHA(real) OUTFILE(string)

    tempname arpost
    postfile `arpost' double beta0 p_value accepted using "`outfile'", replace

    local ngrid   = floor((`bmax' - `bmin') / `step' + 0.5)
    local npoints = `ngrid' + 1

    forvalues i = 0/`ngrid' {
        local b0 = `bmin' + `i' * `step'

        cap drop y_ar
        gen double y_ar = ln_q - (`b0') * ln_pch

        quietly regress y_ar ln_y ln_pb `varlist', vce(robust)
        quietly test `varlist'

        scalar pval = r(p)
        scalar acc  = (pval >= `alpha')
        post `arpost' (`b0') (pval) (acc)
    }
    postclose `arpost'

    use "`outfile'", clear

    quietly count if accepted == 1
    local nacc = r(N)
    return scalar n_accepted = `nacc'
    return scalar npoints    = `npoints'

    quietly summarize p_value, meanonly
    local pmin = r(min)
    local pmax = r(max)
    return scalar p_min = `pmin'
    return scalar p_max = `pmax'

    quietly summarize beta0 if abs(p_value - `pmax') < 1e-12, meanonly
    return scalar beta0_minp = r(mean)

    if (`nacc' > 0) {
        quietly summarize beta0 if accepted == 1, meanonly
        return scalar ar_low  = r(min)
        return scalar ar_high = r(max)
    }
    else {
        return scalar ar_low  = .
        return scalar ar_high = .
    }
end

postfile artab ///
    str5 model int N k_inst ///
    double ar_low ar_high ar_low_grid ar_high_grid beta0_minp p_min p_max ///
    double grid_initial_min grid_initial_max grid_min grid_max grid_step ///
    double coarse_step fine_step ///
    int open_left open_right n_expand left_hits right_hits npoints_final ///
    using "$TABS/stata_question_11_ar_intervals.dta", replace

local Z1 "z"
local Z2 "z z_sq"
local Z7 "z z_sq z_lag z_lag_sq"

* -------------------------------------------------------------------
* Parâmetros principais.
* -------------------------------------------------------------------
local bmin0       = -5
local bmax0       =  2
local alpha       =  0.05

* Busca grossa: barata para localizar a região aceita.
local coarse_step =  0.05

* Busca fina: usada no IC final reportado.
local fine_step   =  0.005

* Expansão mínima e expansão proporcional.
local min_expand  =  1
local expand_mult =  0.75

* Limites de segurança.
local max_expand   = 20
local max_abs_beta = 100
local lower_cap = -1 * `max_abs_beta'
local upper_cap =  1 * `max_abs_beta'

* Detecção de cauda aberta.
* Se a mesma borda for tocada min_tail_hits vezes, a rotina para
* e reporta IC aberto naquele lado.
local min_tail_hits = 3

foreach m in 1 2 7 {
    local inst  "`Z`m''"
    local model "Z`m'"
    local k_inst : word count `inst'

    di as text _newline "[Stata] AR `model': instrumentos excluídos = `inst'"

    preserve
        keep if !missing(ln_q, ln_pch, ln_y, ln_pb)
        foreach v of local inst {
            keep if !missing(`v')
        }
        count
        scalar N_ar = r(N)
        di as text "[Stata] AR `model': N = " N_ar

        tempfile arbase
        save `arbase', replace

        local bmin_model = `bmin0'
        local bmax_model = `bmax0'
        local n_expand   = 0
        local done       = 0
        local left_hits  = 0
        local right_hits = 0

        scalar ar_low_grid  = .
        scalar ar_high_grid = .
        scalar ar_low       = .
        scalar ar_high      = .
        scalar beta0_minp   = .
        scalar p_min        = .
        scalar p_max        = .
        scalar open_left    = 0
        scalar open_right   = 0
        scalar n_accepted   = 0
        scalar npoints_final = .

        /************************************************************
         FASE 1: busca grossa adaptativa.
        ************************************************************/
        while (`done' == 0) {
            use `arbase', clear

            tempfile argrid_coarse
            di as text "[Stata] AR `model': busca grossa em [`bmin_model', `bmax_model'], passo `coarse_step'"

            ar_grid_scan `inst', ///
                bmin(`bmin_model') bmax(`bmax_model') ///
                step(`coarse_step') alpha(`alpha') ///
                outfile("`argrid_coarse'")

            scalar n_accepted  = r(n_accepted)
            scalar ar_low_grid = r(ar_low)
            scalar ar_high_grid = r(ar_high)
            scalar beta0_minp  = r(beta0_minp)
            scalar p_min       = r(p_min)
            scalar p_max       = r(p_max)

            if (n_accepted == 0) {
                di as error "ATENÇÃO: AR `model' não aceitou nenhum beta0 na busca grossa corrente."
                di as text  "[Stata] AR `model': beta0 menos rejeitado = " %9.4f beta0_minp " | p_max = " %9.6f p_max

                * Se a grade atual já está no limite absoluto e ainda assim
                * não há beta0 aceito, aí sim encerramos como conjunto vazio.
                if (`bmin_model' <= `lower_cap' & `bmax_model' >= `upper_cap') {
                    local done = 1
                }
                else if (`n_expand' < `max_expand') {
                    local width = `bmax_model' - `bmin_model'
                    local delta = max(`min_expand', `width' * `expand_mult')

                    local bmin_model = `bmin_model' - `delta'
                    local bmax_model = `bmax_model' + `delta'

                    if (`bmin_model' < `lower_cap') local bmin_model = `lower_cap'
                    if (`bmax_model' > `upper_cap') local bmax_model = `upper_cap'

                    local n_expand = `n_expand' + 1
                    di as error "         Ampliando ambos os lados para [`bmin_model', `bmax_model']."

                    * IMPORTANTE: não encerra imediatamente ao alcançar o cap.
                    * A próxima iteração ainda avalia a grade capada, por exemplo
                    * [-100, 100]. Só depois, se continuar sem aceitação, encerra.
                }
                else {
                    local done = 1
                }
            }
            else {
                scalar open_left  = (ar_low_grid  <= `bmin_model' + `coarse_step')
                scalar open_right = (ar_high_grid >= `bmax_model' - `coarse_step')

                if (open_left == 1)  local left_hits  = `left_hits'  + 1
                if (open_right == 1) local right_hits = `right_hits' + 1

                di as text "[Stata] AR `model': IC grosso provisório = [" %9.3f ar_low_grid ", " %9.3f ar_high_grid "]"
                di as text "[Stata] AR `model': beta0 menos rejeitado = " %9.4f beta0_minp " | p_max = " %9.6f p_max " | p_min = " %9.6f p_min

                * Regra central: se a mesma borda é tocada repetidamente,
                * tratamos como cauda aberta em vez de continuar expandindo.
                if (open_left == 1 & `left_hits' >= `min_tail_hits') {
                    scalar open_left = 1
                    di as error "ATENÇÃO: AR `model' toca repetidamente a borda esquerda. Tratando IC como aberto à esquerda."
                    local done = 1
                }
                if (open_right == 1 & `right_hits' >= `min_tail_hits') {
                    scalar open_right = 1
                    di as error "ATENÇÃO: AR `model' toca repetidamente a borda direita. Tratando IC como aberto à direita."
                    local done = 1
                }

                if (`done' == 0) {
                    if ((open_left == 1 | open_right == 1) & (`n_expand' < `max_expand')) {
                        local width = `bmax_model' - `bmin_model'
                        local delta = max(`min_expand', `width' * `expand_mult')

                        if (open_left == 1) {
                            local bmin_model = `bmin_model' - `delta'
                            if (`bmin_model' < `lower_cap') local bmin_model = `lower_cap'
                            di as error "ATENÇÃO: AR `model' tocou a borda esquerda. Novo bmin = `bmin_model'."
                        }
                        if (open_right == 1) {
                            local bmax_model = `bmax_model' + `delta'
                            if (`bmax_model' > `upper_cap') local bmax_model = `upper_cap'
                            di as error "ATENÇÃO: AR `model' tocou a borda direita. Novo bmax = `bmax_model'."
                        }

                        local n_expand = `n_expand' + 1

                        if (`bmin_model' <= `lower_cap' & open_left == 1) {
                            di as error "ATENÇÃO: AR `model' alcançou lower_cap. Tratando IC como aberto à esquerda."
                            scalar open_left = 1
                            local done = 1
                        }
                        if (`bmax_model' >= `upper_cap' & open_right == 1) {
                            di as error "ATENÇÃO: AR `model' alcançou upper_cap. Tratando IC como aberto à direita."
                            scalar open_right = 1
                            local done = 1
                        }
                    }
                    else {
                        local done = 1
                    }
                }
            }
        }

        /************************************************************
         FASE 2: busca fina final na grade adaptada.
        ************************************************************/
        if (n_accepted > 0) {
            use `arbase', clear
            tempfile argrid_fine

            di as text "[Stata] AR `model': busca fina final em [`bmin_model', `bmax_model'], passo `fine_step'"

            ar_grid_scan `inst', ///
                bmin(`bmin_model') bmax(`bmax_model') ///
                step(`fine_step') alpha(`alpha') ///
                outfile("`argrid_fine'")

            scalar n_accepted    = r(n_accepted)
            scalar npoints_final = r(npoints)
            scalar ar_low_grid   = r(ar_low)
            scalar ar_high_grid  = r(ar_high)
            scalar beta0_minp    = r(beta0_minp)
            scalar p_min         = r(p_min)
            scalar p_max         = r(p_max)

            if (n_accepted > 0) {
                * Mantém as flags de cauda aberta detectadas na fase grossa,
                * e também checa se a busca fina ainda toca a borda.
                scalar open_left  = (open_left  == 1 | ar_low_grid  <= `bmin_model' + `fine_step')
                scalar open_right = (open_right == 1 | ar_high_grid >= `bmax_model' - `fine_step')

                scalar ar_low  = ar_low_grid
                scalar ar_high = ar_high_grid

                * Se for aberto, ar_low/ar_high reportado fica missing no lado aberto.
                if (open_left == 1)  scalar ar_low  = .
                if (open_right == 1) scalar ar_high = .
            }
            else {
                scalar ar_low  = .
                scalar ar_high = .
                scalar open_left  = 0
                scalar open_right = 0
            }
        }

        if missing(ar_low_grid) & missing(ar_high_grid) {
            di as error "ATENÇÃO: AR `model' terminou sem intervalo aceito."
            di as error "         Veja beta0_minp e p_max para diagnosticar o ponto menos rejeitado."
        }
        else if (open_left == 1 & open_right == 1) {
            di as error "[Stata] AR `model': IC final = (-infinito, +infinito) dentro da lógica de inversão AR."
            di as text  "[Stata] AR `model': grade testada = [`bmin_model', `bmax_model']; IC na grade = [" %9.3f ar_low_grid ", " %9.3f ar_high_grid "]"
        }
        else if (open_left == 1) {
            di as error "[Stata] AR `model': IC final = (-infinito, " %9.3f ar_high_grid "]"
            di as text  "[Stata] AR `model': grade testada = [`bmin_model', `bmax_model']; limite inferior da grade aceito = " %9.3f ar_low_grid
        }
        else if (open_right == 1) {
            di as error "[Stata] AR `model': IC final = [" %9.3f ar_low_grid ", +infinito)"
            di as text  "[Stata] AR `model': grade testada = [`bmin_model', `bmax_model']; limite superior da grade aceito = " %9.3f ar_high_grid
        }
        else {
            di as text "[Stata] AR `model': IC final = [" %9.3f ar_low_grid ", " %9.3f ar_high_grid "]"
            di as text "[Stata] AR `model': grade final usada = [`bmin_model', `bmax_model']; passo final = `fine_step'"
        }

    restore

    post artab ("`model'") (N_ar) (`k_inst') ///
               (ar_low) (ar_high) (ar_low_grid) (ar_high_grid) (beta0_minp) (p_min) (p_max) ///
               (`bmin0') (`bmax0') ///
               (`bmin_model') (`bmax_model') (`fine_step') ///
               (`coarse_step') (`fine_step') ///
               (open_left) (open_right) (`n_expand') (`left_hits') (`right_hits') (npoints_final)
}

postclose artab

use "$TABS/stata_question_11_ar_intervals.dta", clear
export delimited using "$TABS/stata_question_11_ar_intervals.csv", replace

di as text "[Stata] Tabela salva: output/tables/stata_question_11_ar_intervals.csv"
