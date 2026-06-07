/*******************************************************************************
Arquivo: stata/run_all_aids_stata.do
Objetivo: rodar, em ordem, toda a resolução Stata da lista AIDS.
Elaborado por:
Luiz Mario Andrade (Matrícula: 252029360)
Felipe Santos (Matrícula: 232010719)
Luiza Nodari (Matrícula: 242011335)
Diogo Martins (Matrícula: 232001578)
Sarah Moura (Matrícula: 211060316)
Pedro Bijos (Matrícula: 241003849)
*******************************************************************************/
display"#########################################################################"
display"#                            INÍCIO                                     #"
display"#             TER FAIXA PRETA É DIFERENTE DE SER FAIXA PRETA            #" 
display"#                                                                       #"
display"#########################################################################"
version 18.0                                      // Define a versão mínima esperada do Stata.
clear all                                         // Limpa a memória antes de iniciar.
set more off                                      // Desativa pausas automáticas.
display "Iniciando Replicação do Pacote - Lista 2 - Modelo AIDS."
display "Configurando e preparando a base de dados"  
do "stata/00_config_aids.do"                      // Carrega configuração do projeto.
do "stata/01_prepare_aids_data.do"                // Prepara dados, participações, Stone e instrumentos.
display "Estimando Modelo e Calculando Elasticidades" 
do "stata/02_estimate_aids_stata.do"              // Estima modelos GMM pedidos na lista.
do "stata/03_elasticities_aids_stata.do"          // Recupera parâmetros e calcula elasticidades.
display "Testes e Diagnósticos de Instrumentos" 
do "stata/04_tests_diagnostics_aids_stata.do"     // Testa restrições e diagnostica instrumentos.
display "Gráficos e Vizualizações" 
do "stata/05_visualizations_aids_stata.do"        // Gera gráficos e matrizes visuais.
do "stata/06_extra_figs_aids_stata.do"
do "stata/07_statistical_extra_figs_aids_stata.do"

display "#########################################################################"
display "#                            FIM                                        #"
display "#                                                                       #"
display "#########################################################################"
display "Pacote AIDS em Stata concluido com sucesso." // Mostra mensagem final.
