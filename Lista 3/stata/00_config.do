/****************************************************************************************
COMENTÁRIOS DETALHADOS
- clear matrix limpa matrizes antigas para evitar contaminação entre execuções.
- set scheme define o tema visual padrão dos gráficos exportados pelo Stata.
- set linesize e set matsize ajustam a exibição e o tamanho máximo das matrizes.
- As globals S0, XVARS, PRICE, DELTA e ENDOG_* padronizam os nomes usados nos scripts seguintes.
- capture which verifica se um comando/pacote existe; se não existir, capture ssc install tenta instalar.
****************************************************************************************/
/****************************************************************************************
Configuração comum - Stata
****************************************************************************************/
clear matrix
set scheme s2color
set linesize 120
set matsize 11000

global S0 = 0.2429
global XVARS "cals fat sugar"
global PRICE "price"
global DELTA "delta"
global ENDOG_SIMPLE "price"
global ENDOG_NESTED "price log_share_within_nest"

* Pacotes opcionais/consolidados. O pacote roda melhor com estout, ivreg2 e weakivtest.
capture which esttab
if _rc capture ssc install estout, replace
capture which ivreg2
if _rc capture ssc install ivreg2, replace
capture which weakivtest
if _rc capture ssc install weakivtest, replace
