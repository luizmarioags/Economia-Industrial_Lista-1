/* 
Victor Gomes, Set 2022
*/

clear
set more off

// All the code is here
quietly run b_program.do


*---------------------------------------------------------------------------------------------------------------*
*                     Estimativas
*---------------------------------------------------------------------------------------------------------------*

// Bootstrap Replications
local bigreps=1000
global ols=0

/* * organiza��o da base de dados
insheet using exemplo.csv, delimiter(,)
rename suger sugar
rename v1 idProduct
rename v2 firm
rename v3 brandProduct

replace insamplemarketshare = insamplemarketshare/100

save exemplo.dta, replace
*/
use exemplo, clear
drop if idProduct==51

*---------------------------------------------------------------------------------------------------------------*
*  1 Base Model
*---------------------------------------------------------------------------------------------------------------*
// File to use 
global usefile="exemplo2"

* indicators :
* firms
egen idfirm = group(firm)

// Share variable
gen outside = .2429


// GMM
/*---Mean Estimates (not bootstraped)*/
global bootrun=0
bootstrap , reps(2) seed(12345): gmm_code
estimates store base

// Standard Errors
global bootrun=1
bootstrap , reps(`bigreps') seed(12345) saving(bootacf_base, replace): gmm_code

