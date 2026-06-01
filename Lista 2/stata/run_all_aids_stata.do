/*******************************************************************************
Arquivo: stata/run_all_aids_stata.do
Objetivo: rodar, em ordem, toda a resolução Stata da lista AIDS.
*******************************************************************************/

version 18.0                                      // Define a versão mínima esperada do Stata.
clear all                                         // Limpa a memória antes de iniciar.
set more off                                      // Desativa pausas automáticas.

do "stata/00_config_aids.do"                      // Carrega configuração do projeto.
do "stata/01_prepare_aids_data.do"                // Prepara dados, participações, Stone e instrumentos.
do "stata/02_estimate_aids_stata.do"              // Estima modelos GMM pedidos na lista.
do "stata/03_elasticities_aids_stata.do"          // Recupera parâmetros e calcula elasticidades.
do "stata/04_tests_diagnostics_aids_stata.do"     // Testa restrições e diagnostica instrumentos.
do "stata/05_visualizations_aids_stata.do"        // Gera gráficos e matrizes visuais.

display "Pacote AIDS em Stata concluido com sucesso." // Mostra mensagem final.
