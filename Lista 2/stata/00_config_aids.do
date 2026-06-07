/*******************************************************************************
Arquivo: stata/00_config_aids.do
Objetivo: definir diretórios, nomes de arquivos e opções gerais do pacote AIDS.
Autor: ChatGPT
Observação: rode este arquivo a partir da raiz do pacote.
Elaborado por:
Luiz Mario Andrade (Matrícula: 252029360)
Felipe Santos (Matrícula: 232010719)
Luiza Nodari (Matrícula: 242011335)
Diogo Martins (Matrícula: 232001578)
Sarah Moura (Matrícula: 211060316)
Pedro Bijos (Matrícula: 241003849)
*******************************************************************************/

version 18.0                                      // Define a versão mínima esperada do Stata.
clear all                                         // Limpa dados, matrizes e programas em memória.
set more off                                      // Impede pausas automáticas na saída do Stata.
set linesize 255                                  // Aumenta a largura da linha no log.
set scheme s2color                                // Usa esquema gráfico padrão e compatível.

global ROOT "`c(pwd)'"                            // Guarda a pasta atual como raiz do projeto.
global RAW      "$ROOT/data/raw"                  // Define a pasta onde ficam os dados brutos.
global PROC     "$ROOT/data/processed"            // Define a pasta onde ficam os dados processados.
global OUT      "$ROOT/output"                    // Define a pasta geral de resultados.
global TABLES   "$ROOT/output/tables"             // Define a pasta de tabelas.
global FIGURES  "$ROOT/output/figures"            // Define a pasta de gráficos.
global LOGS     "$ROOT/output/logs"               // Define a pasta de logs.
global MODELS   "$ROOT/output/models"             // Define a pasta de modelos estimados.

capture mkdir "$PROC"                             // Cria a pasta de dados processados, se ela não existir.
capture mkdir "$OUT"                              // Cria a pasta de saída, se ela não existir.
capture mkdir "$TABLES"                           // Cria a pasta de tabelas, se ela não existir.
capture mkdir "$FIGURES"                          // Cria a pasta de gráficos, se ela não existir.
capture mkdir "$LOGS"                             // Cria a pasta de logs, se ela não existir.
capture mkdir "$MODELS"                           // Cria a pasta de modelos, se ela não existir.

global RAW_CSV "$RAW/meatdata.csv"                // Define o caminho do arquivo CSV bruto.
global PROC_DTA "$PROC/meatdata_aids_preparado.dta" // Define o caminho do arquivo processado em formato Stata.

global GOODS "bfvl pork poult fish"               // Lista os quatro produtos do sistema AIDS.
global ESTGOODS "bfvl pork fish"                  // Lista as equações estimadas; frango é omitido como equação.
global OMITGOOD "poult"                           // Define o produto cuja equação será omitida.

capture log close _all                            // Fecha qualquer log aberto anteriormente.
