# Mapa das questões, implementação e saídas

Este documento indica, para cada questão da Lista 1 de Economia Industrial, o que foi feito no repositório, qual script executa a tarefa e quais arquivos são produzidos. A implementação documentada aqui é a implementação em Stata presente na pasta `Stata/`.

## Visão geral

A lista estima uma demanda log-log por frango, na qual `ln_q` é explicado por `ln_pch`, `ln_y` e `ln_pb`. O preço real do frango (`ln_pch`) é tratado como potencialmente endógeno e é instrumentado pelo preço real do milho (`z`) e por combinações de suas potências e defasagens.

## Questões

| Questão | O que foi feito | Implementação computacional | Saídas principais |
|---:|---|---|---|
| 1 | Estimação da demanda por MQO com erro-padrão robusto à heterocedasticidade. | `02_ols_iv_first_stage.do` roda `reg ln_q ln_pch ln_y ln_pb, vce(robust)` e extrai `beta_p`, erro-padrão, p-valor e IC de 95%. | `output/tables/stata_question_01_ols.csv` |
| 2 | Discussão conceitual da endogeneidade do preço. | Não depende de estimação própria; usa a lógica de equilíbrio simultâneo entre oferta e demanda. A resposta é documentada em `respostas_interpretativas.md`. | `docs/respostas_interpretativas.md` |
| 3 | Estimação 2SLS com um instrumento excluído, `Z1 = {z}`. | `02_ols_iv_first_stage.do` roda `ivreg2 ln_q ln_y ln_pb (ln_pch = z), robust first` e compara a elasticidade IV com a elasticidade MQO. | `output/tables/stata_question_03_iv_z1.csv` |
| 4 | Primeiro estágio de `Z1`, R² parcial e F usual. | `02_ols_iv_first_stage.do` estima `ln_pch ~ z + ln_y + ln_pb`, testa `H0: pi_z = 0` e calcula o R² parcial residualizando `ln_pch` e `z` contra os controles. | `output/tables/stata_question_04_first_stage.csv` |
| 5 | GMM exatamente identificado e sobreidentificado. | `03_gmm_hansen.do` estima GMM com `Z1 = {z}` e `Z2 = {z, z^2}`. No caso exato, compara a estimativa GMM com 2SLS. No caso sobreidentificado, extrai o teste J de Hansen. | `output/tables/stata_question_05_gmm.csv` |
| 6 | Teste de instrumentos fracos de Montiel Olea e Pflueger. | `04_alt_instruments_weakiv.do` roda `weakivtest` após cada especificação IV, capturando `F_eff` e valores críticos TSLS retornados pelo Stata. Logs individuais são salvos por modelo. | `output/logs/stata_question_06_weakivtest_Z*.txt`; colunas em `stata_question_09_comparative.csv` |
| 7 | Discussão sobre heterocedasticidade e inadequação do F usual clássico. | A parte conceitual está em `respostas_interpretativas.md`. A parte empírica é apoiada pelo uso de erros robustos e por figuras de resíduos geradas em `06_visualizations.do`. | `docs/respostas_interpretativas.md`; `output/figures/stata_fig03_residuals_fitted.*` |
| 8 | Estimação do primeiro estágio e da equação estrutural para `Z1` a `Z7`. | `04_alt_instruments_weakiv.do` define os sete conjuntos de instrumentos, estima os primeiros estágios, calcula R² parcial, F usual e roda 2SLS robusto para cada modelo. | `output/tables/stata_question_08_first_stage_all.csv`; `output/tables/stata_question_09_comparative.csv` |
| 9 | Tabela comparativa com instrumentos, N, elasticidade, IC, F usual, F efetivo MOP e Hansen J. | `04_alt_instruments_weakiv.do` junta os resultados de `Z1` a `Z7` em uma tabela única. | `output/tables/stata_question_09_comparative.csv` |
| 10 | Teste J de Hansen e validade dos instrumentos. | `04_alt_instruments_weakiv.do` filtra os modelos sobreidentificados, calcula graus de liberdade, valor-p e decisão a 5%, além de exportar tabela LaTeX. | `output/tables/stata_question_10_hansen_overid.csv`; `output/tables/stata_question_10_hansen_overid.tex`; `output/figures/stata_fig12_hansen_pvalues.*` |
| 11 | Inferência robusta a instrumentos fracos. | `05_ar_intervals.do` constrói intervalos Anderson-Rubin para `Z1`, `Z2` e `Z7` usando uma grade adaptativa de valores candidatos para `beta_p`. | `output/tables/stata_question_11_ar_intervals.csv` |
| 12 | Interpretação de Economia Industrial. | A interpretação usa as estimativas de elasticidade e os diagnósticos de força dos instrumentos. A discussão está em `respostas_interpretativas.md`. | `docs/respostas_interpretativas.md` |
| 13 | Discussão sobre possível endogeneidade do preço da carne bovina. | A resposta é conceitual: discute quando `ln_pb` poderia ser endógeno e que tipo de instrumento seria necessário. | `docs/respostas_interpretativas.md` |
| 14 | Simulação de instrumentos fracos. | `07_simulation_weak_instruments.do` simula `y = beta*x + u` e `x = pi*z + v`, com `beta = -1`, variando `pi` para reduzir a força do instrumento. Calcula viés, dispersão, F médio e cobertura do IC. | `output/tables/stata_question_14_simulation.csv`; `output/figures/stata_fig09_q14_simulacao_instrumentos_fracos.*` |

## Observação sobre gráficos

Os gráficos existentes são figuras da própria análise econométrica: séries, dispersões, resíduos, estimativas por instrumento, GMM/Hansen, simulação e curva IV. Não há, neste repositório, gráficos comparativos entre Stata, R e Python.
