#!/usr/bin/env bash
# COMENTÁRIOS DETALHADOS
# Este agregador chama as rotinas disponíveis do pacote e imprime o mesmo cabeçalho/rodapé dos run_all internos.
# A opção set -e interrompe a execução se algum comando retornar erro.

set -euo pipefail
cd "$(dirname "$0")"

printf "%s\n" "#########################################################################"
printf "%s\n" "#                            INÍCIO                                     #"
printf "%s\n" "#             Lista 3 - Modelo BLP.                                    #"
printf "%s\n" "#             Grupo: Luiz Mario Andrade (Matrícula: 252029360)          #"
printf "%s\n" "#                    Felipe Santos (Matrícula: 232010719)               #"
printf "%s\n" "#                    Luiza Nodari (Matrícula: 242011335)                #"
printf "%s\n" "#                    Diogo Martins (Matrícula: 232001578)               #"
printf "%s\n" "#                    Sarah Moura (Matrícula: 211060316)                 #"
printf "%s\n" "#                    Pedro Bijos (Matrícula: 241003849)                 #"
printf "%s\n" "#########################################################################"
python python/run_all_python.py
if command -v Rscript >/dev/null 2>&1; then
  Rscript -e 'source("R/run_all_R.R")'
else
  echo "Rscript não encontrado; pulando execução R."
fi
if command -v stata >/dev/null 2>&1; then
  stata -b do stata/run_all_stata.do
else
  echo "Stata não encontrado; rode manualmente: do stata/run_all_stata.do"
fi

printf "%s\n" "#########################################################################"
printf "%s\n" "#                            FIM                                        #"
printf "%s\n" "#                                                                       #"
printf "%s\n" "#########################################################################"
