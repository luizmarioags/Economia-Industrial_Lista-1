# Lista 1 de Economia Industrial — Pacote de Replicação

Este pacote replica a **Lista 1: Estimação de Demanda, 2SLS e Instrumentos Fracos** usando a base `chicken` fornecida em `data/raw/`.

O modelo estrutural é:

\[
q_t = \beta_0 + \beta_p p^{ch}_t + \beta_y y_t + \beta_b p^b_t + u_t,
\]

onde:

- `ln_q = ln(Q)` é o log do consumo per capita de frango;
- `ln_pch = ln(PCHICK/CPI)` é o log do preço real do frango;
- `ln_y = ln(Y)` é o log da renda real per capita;
- `ln_pb = ln(PBEEF/CPI)` é o log do preço real da carne bovina;
- `z = ln(PCOR/CPI)` é o log do preço real do milho, usado como instrumento excluído.

## Mudanças em relação à versão anterior

A versão anterior do pacote estava orientada à lista antiga, com dez instrumentos incluindo transformações exponenciais. A lista nova pede sete especificações:

- `Z1 = {z}`;
- `Z2 = {z, z^2}`;
- `Z3 = {z, z^2, z^3}`;
- `Z4 = {z(t-1)}`;
- `Z5 = {z(t-1), z(t-1)^2}`;
- `Z6 = {z, z(t-1)}`;
- `Z7 = {z, z^2, z(t-1), z(t-1)^2}`.

Esta versão também adiciona GMM, Hansen J, intervalos Anderson-Rubin e simulação de instrumentos fracos.

## Estrutura

```text
lista1EI_26_replication_package/
├── data/
│   ├── raw/                 # chicken.dta e chicken.csv originais
│   └── processed/           # bases tratadas por software
├── output/
│   ├── tables/              # resultados em CSV
│   ├── figures/             # gráficos
│   └── logs/                # logs de execução
├── Stata/                   # scripts .do
├── R/                       # scripts .R
├── Python/                  # scripts Python
└── docs/                    # diagnóstico e guia de interpretação
```

## Como rodar no Stata

Abra o Stata na raiz do pacote e execute:

```stata
do "Stata/00_master.do"
```

O Stata é a referência principal para `weakivtest`, porque a lista pede o F efetivo de Montiel Olea-Pflueger.

## Como rodar no R

No R/RStudio, defina o diretório de trabalho na raiz do pacote e execute:

```r
source("R/00_run_all.R")
```

A versão em R calcula MQO, 2SLS, primeiro estágio, GMM, Hansen J, intervalos Anderson-Rubin, gráficos e simulação. O F efetivo MOP oficial continua sendo o do Stata.

## Como rodar no Python

No terminal, a partir da raiz do pacote:

```bash
python -m venv .venv
# Windows:
.venv\Scripts\activate
# Linux/Mac:
# source .venv/bin/activate

pip install -r Python/requirements.txt
python Python/src/run_all.py
```

A versão em Python usa implementação matricial própria para MQO, 2SLS, GMM e Hansen J, evitando dependência de `linearmodels`.


## Plots comparativos entre Stata, R e Python

Depois de rodar os três ambientes, gere os gráficos comparativos com:

```bash
python Comparativo/01_plots_comparativos_software.py
```

O script lê as tabelas da questão 9 produzidas por Stata, R e Python. Ele procura tanto em `output/tables/` quanto em subpastas como `output/tables/Stata/`, `output/tables/R/` e `output/tables/Python/`. Isso evita que os gráficos apareçam apenas com Python quando as tabelas de R ou Stata foram salvas em subdiretórios.

A tabela consolidada sai em:

```text
output/tables/comparative_software_results.csv
```

Os gráficos saem em:

```text
output/figures/comparative_software/
```

O diagnóstico das tabelas encontradas sai em:

```text
docs/relatorio_plots_comparativos.md
output/logs/comparative_software_plots.log
```

Os gráficos comparam `βp`, intervalos de confiança, erros-padrão, F usual do primeiro estágio, F efetivo MOP quando disponível e p-valores do teste J de Hansen. O F efetivo MOP oficial continua sendo o do Stata/`weakivtest`.

## Saídas principais

- `output/tables/stata_question_01_ols.csv`
- `output/tables/stata_question_03_iv_z1.csv`
- `output/tables/stata_question_04_first_stage.csv`
- `output/tables/stata_question_05_gmm.csv`
- `output/tables/stata_question_09_comparative.csv`
- `output/tables/stata_question_11_ar_intervals.csv`
- `output/tables/stata_question_14_simulation.csv`

Os scripts em R e Python salvam arquivos equivalentes com prefixos `r_` e `python_`.

## Marcações no console

Esta versão inclui mensagens de acompanhamento nos scripts de Stata, R, Python e no comparativo. Durante a execução, os códigos imprimem:

- qual questão está sendo resolvida;
- qual modelo está sendo estimado;
- qual variável é dependente, qual é endógena e quais são controles;
- quais instrumentos excluídos entram em cada especificação `Z1` a `Z7`;
- quais variáveis foram calculadas na preparação da base;
- onde cada tabela e gráfico foi salvo;
- resumos rápidos de resultados centrais, como `beta_p`, erro-padrão, F usual, Hansen J e F efetivo MOP quando disponível.

No Stata, essas mensagens também ficam registradas em:

```text
output/logs/stata_master.log
```

No R e no Python, elas aparecem diretamente no console/terminal durante a execução.
