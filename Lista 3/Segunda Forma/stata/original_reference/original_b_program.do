/*
GMM Code: cross-section
Caso exatamente identificado
Victor Gomes, 2022
*/

clear
set more off


*-------------------------------------BEGIN MATA PROGRAM--------------------------------------------*
mata: mata clear
mata:

void GMM_OBJ(todo,betas,Y,X,Z,W,crit,g,H)
{
    real scalar N
    N = rows(Z)
    XI=Y-X*betas'
    Gbar = 1/N * quadcross(Z,XI)
    crit= N* (Gbar)' *W* (Gbar)
}
end
*-------------------------------------END MATA PROGRAM---------------------------------------*


*------------------------------------------------------------------------------------------------*
*                      C�digo N�o-Linear
*------------------------------------------------------------------------------------------------*


cap program drop gmm_code
program gmm_code, eclass
preserve
use $usefile, clear
if ($bootrun==0) {
    
}
else {
// Draw Bootsrap Sample
bsample
}


// Variables
mata: Y=st_data(.,("share"))
mata: X=st_data(.,("cons","cals","fat","sugar","p1"))
// Instruments
mata: Z=st_data(.,("cons","cals","fat","sugar","z1"))
// Weighting Matrix
mata: W=invsym(Z'Z)
//*mata: W=I(cols(Z))
mata: S=optimize_init()

mata: optimize_init_evaluator(S, &GMM_OBJ())
mata: optimize_init_evaluatortype(S,"d0")
mata: optimize_init_technique(S, "nm")
mata: optimize_init_nmsimplexdeltas(S, 0.01)
*mata: optimize_init_conv_ptol(S, 1e-18)
mata: optimize_init_conv_vtol(S, 1e-16)
mata: optimize_init_which(S,"min")

// These starting values come from OLS Version
mata: optimize_init_params(S,(1,0.009,-0.79,-0.05,1.4))
mata: optimize_init_argument(S, 1, Y)
mata: optimize_init_argument(S, 2, X)
mata: optimize_init_argument(S, 3, Z)
mata: optimize_init_argument(S, 4, W)


// Minimize Criterion
mata: p=optimize(S)
mata: p
mata: p=optimize(S)
mata: p
mata: st_matrix("beta",p)

scalar betac=beta[1,1]
scalar betaX1=beta[1,2]
scalar betaX2=beta[1,3]
scalar betaX3=beta[1,4]
scalar betaP=beta[1,5]

matrix beta=beta
mat colnames beta = c X1 X2 X3 p

ereturn post beta
restore
end 


