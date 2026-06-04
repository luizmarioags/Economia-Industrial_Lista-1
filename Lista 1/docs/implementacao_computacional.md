# Implementação computacional

Este documento descreve como a implementação computacional da Lista 1 foi organizada no repositório. O objetivo é permitir que qualquer pessoa rode os códigos, entenda a sequência dos scripts e saiba onde cada resultado é salvo.

## 1. Organização dos caminhos

A configuração central está em `Stata/config.do`. O projeto foi ajustado para usar uma raiz fixa:

```stata
global ROOT "C:/Users/B03531855158/Documents/Replication/Códigos"
```

A partir dela são definidos:

```stata
global RAW  "$ROOT/data/raw"
global PROC "$ROOT/data/processed"
global OUT  "$ROOT/output"
global TABS "$OUT/tables"
global FIGS "$OUT/figures"
global LOGS "$OUT/logs"
```

Assim, os resultados não dependem do diretório ativo do Stata. Essa alteração evita que tabelas, logs ou figuras sejam salvos fora do repositório caso o usuário esteja com outro `cd` aberto.

## 2. Execução principal

A rotina completa é chamada por:

```stata
do "C:/Users/B03531855158/Documents/Replication/Códigos/Stata/00_master.do"
```

O `00_master.do` executa os scripts em ordem, registra mensagens no console e salva um log geral em:

```text
output/logs/stata_master.log
```

## 3. Preparação da base

O script `01_prepare_data.do` é responsável por:

1. importar a base bruta `chicken`;
2. padronizar nomes das variáveis para minúsculas;
3. corrigir escalas quando identifica valores anormalmente altos;
4. ordenar a série temporal anual;
5. construir as variáveis logarítmicas da demanda;
6. construir instrumentos contemporâneos, potências e defasagens.

A base tratada é salva em dois formatos:

```text
data/processed/chicken_prepared_stata.dta
data/processed/chicken_prepared_stata.csv
```

Também é gerada a base com resíduos e valores ajustados do MQO:

```text
data/processed/chicken_with_ols_residuals_stata.dta
```

Essa base é usada nos gráficos de diagnóstico.

## 4. Estimações principais

O script `02_ols_iv_first_stage.do` cobre três blocos:

### Questão 1 — MQO

Estima a equação de demanda por mínimos quadrados ordinários com erro-padrão robusto:

```stata
reg ln_q ln_pch ln_y ln_pb, vce(robust)
```

São extraídos a elasticidade-preço, erro-padrão, p-valor e intervalo de confiança.

### Questão 3 — 2SLS com `Z1`

Estima a equação estrutural com `ln_pch` instrumentado por `z`:

```stata
ivreg2 ln_q ln_y ln_pb (ln_pch = z), robust first
```

### Questão 4 — primeiro estágio

Estima:

```stata
reg ln_pch z ln_y ln_pb, vce(robust)
```

Depois calcula:

- coeficiente de `z`;
- erro-padrão robusto;
- teste F usual para o instrumento excluído;
- R² parcial do instrumento, residualizando `ln_pch` e `z` contra `ln_y` e `ln_pb`.

## 5. GMM e Hansen J

O script `03_gmm_hansen.do` implementa a questão 5. São estimados dois modelos:

- `GMM_Z1`, com instrumento excluído `{z}`;
- `GMM_Z2`, com instrumentos excluídos `{z, z^2}`.

No caso exatamente identificado, o script compara a estimativa GMM com a estimativa 2SLS. No caso sobreidentificado, o script extrai a estatística J de Hansen e seu valor-p.

Saída:

```text
output/tables/stata_question_05_gmm.csv
```

## 6. Instrumentos alternativos, F efetivo MOP e tabela comparativa

O script `04_alt_instruments_weakiv.do` resolve as questões 6, 8, 9 e 10. Ele define os sete conjuntos de instrumentos `Z1` a `Z7`, estima o primeiro estágio e a equação 2SLS de cada um.

Para cada especificação, são armazenados:

- número de observações;
- número de instrumentos excluídos;
- `beta_p`;
- erro-padrão;
- p-valor de `beta_p`;
- intervalo de confiança convencional;
- F usual do primeiro estágio;
- p-valor do F usual;
- F efetivo de Montiel Olea e Pflueger;
- valores críticos MOP para viés relativo de 5%, 10% e 20%;
- Hansen J e valor-p nos modelos sobreidentificados.

Saídas principais:

```text
output/tables/stata_question_08_first_stage_all.csv
output/tables/stata_question_09_comparative.csv
output/logs/stata_question_06_weakivtest_Z*.txt
```

## 7. Teste J de Hansen

Ainda no `04_alt_instruments_weakiv.do`, a questão 10 recebe uma rotina específica. O código importa a tabela comparativa, mantém apenas os modelos sobreidentificados e calcula os graus de liberdade do teste como:

```text
gl = número de instrumentos excluídos - número de variáveis endógenas
```

Como há uma variável endógena (`ln_pch`), os modelos exatamente identificados não possuem teste J. O script exporta uma tabela em CSV e outra em LaTeX.

Saídas:

```text
output/tables/stata_question_10_hansen_overid.csv
output/tables/stata_question_10_hansen_overid.tex
output/figures/stata_fig12_hansen_pvalues.png
output/figures/stata_fig12_hansen_pvalues.pdf
```

## 8. Intervalos Anderson-Rubin

O script `05_ar_intervals.do` resolve a questão 11. A ideia é testar uma grade de valores candidatos para `beta_p`. Para cada valor candidato `beta0`, constrói-se:

```text
y_AR = ln_q - beta0 * ln_pch
```

Em seguida, testa-se se os instrumentos excluídos são conjuntamente insignificantes na regressão auxiliar de `y_AR` contra controles e instrumentos. O conjunto de valores não rejeitados forma o intervalo Anderson-Rubin.

O código usa uma grade adaptativa para reduzir o risco de perder regiões aceitas nas caudas.

Saída:

```text
output/tables/stata_question_11_ar_intervals.csv
```

## 9. Visualizações

O script `06_visualizations.do` gera figuras usadas no relatório:

- séries logarítmicas principais;
- dispersão entre quantidade e preço do frango;
- resíduos do MQO contra valores ajustados;
- comparação visual entre MQO e 2SLS para os conjuntos de instrumentos;
- figura auxiliar de GMM e Hansen J.

Essas figuras são salvas em `output/figures/`.

## 10. Simulação de instrumentos fracos

O script `07_simulation_weak_instruments.do` implementa a questão 14. O desenho da simulação é:

```text
y = beta*x + u
x = pi*z + v
```

com:

- `beta = -1`;
- `pi` variando para representar diferentes forças do instrumento;
- correlação entre `u` e `v`, gerando endogeneidade;
- várias repetições Monte Carlo para cada valor de `pi`.

O script calcula, para cada nível de força do instrumento:

- estimativa média por 2SLS;
- estimativa média por MQO;
- viés absoluto do 2SLS;
- desvio-padrão do 2SLS;
- F médio do primeiro estágio;
- cobertura do intervalo convencional de 95%.

Saídas:

```text
output/tables/stata_question_14_simulation.csv
output/figures/stata_fig09_q14_simulacao_instrumentos_fracos.png
output/figures/stata_fig09_q14_simulacao_instrumentos_fracos.pdf
```

## 11. Curva IV com dados observados

O script `08_iv_curve_actual_data.do` constrói uma figura conceitual com os dados efetivos. A ideia é mostrar a razão IV:

```text
beta_IV = delta / gamma
```

em que `delta` é a forma reduzida do instrumento sobre a quantidade e `gamma` é o primeiro estágio do instrumento sobre o preço. Quando `gamma` se aproxima de zero, a razão IV se torna instável.

Saídas:

```text
output/figures/stata_fig10_iv_curve_actual_data.png
output/figures/stata_fig10_iv_curve_actual_data.pdf
```

## 12. O que não está no repositório

Este repositório não contém plots comparativos entre Stata, R e Python. A documentação antiga mencionava esse tipo de comparação, mas essa informação foi removida/substituída porque não corresponde ao pacote atual.
