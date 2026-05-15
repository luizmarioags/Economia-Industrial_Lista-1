# Mapa das questões e saídas

| Questão | O que é feito | Saída principal |
|---|---|---|
| 1 | MQO com erro-padrão robusto | `*_question_01_ols.csv` |
| 2 | Discussão conceitual de endogeneidade | `docs/respostas_interpretativas.md` |
| 3 | 2SLS com `z` | `*_question_03_iv_z1.csv` |
| 4 | Primeiro estágio, R2 parcial e F usual | `*_question_04_first_stage.csv` |
| 5 | GMM com `{z}` e `{z,z^2}`; Hansen J | `*_question_05_gmm.csv` |
| 6 | Weakivtest/MOP no Stata para `Z1` | `stata_question_06_weakivtest_log.txt` e tabela comparativa |
| 7 | Motivação para heterocedasticidade | gráficos de resíduos e resposta textual |
| 8 | Primeiro estágio e 2SLS para `Z1` a `Z7` | `*_question_08_first_stage_all.csv` e tabela comparativa |
| 9 | Tabela comparativa completa | `*_question_09_comparative.csv` |
| 10 | Hansen J e valor-p em sobreidentificados | `*_question_09_comparative.csv` |
| 11 | Intervalos Anderson-Rubin para `Z1`, `Z2`, `Z7` | `*_question_11_ar_intervals.csv` |
| 12 | Interpretação de EI | `docs/respostas_interpretativas.md` |
| 13 | Discussão sobre endogeneidade de `pb` | `docs/respostas_interpretativas.md` |
| 14 | Simulação de instrumentos fracos | `*_question_14_simulation.csv` e figura |
