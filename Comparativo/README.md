# Plots comparativos entre Stata, R e Python

Este diretório contém a rotina que compara os resultados obtidos nos três softwares.

## Ordem correta de execução

A partir da raiz do pacote, rode primeiro as rotinas principais:

```bash
# Python
python Python/src/run_all.py

# R
Rscript R/00_run_all.R

# Stata, dentro do Stata
do "Stata/00_master.do"
```

Depois rode:

```bash
python Comparativo/01_plots_comparativos_software.py
```

## O que o script procura

O script procura automaticamente as tabelas:

- `stata_question_09_comparative.csv`
- `r_question_09_comparative.csv`
- `python_question_09_comparative.csv`

Ele busca tanto em `output/tables/` quanto em subpastas como:

- `output/tables/Stata/`
- `output/tables/R/`
- `output/tables/Python/`

Isso evita o problema de o gráfico sair apenas com Python quando as tabelas de R ou Stata estão em subdiretórios.

## Saídas

Os gráficos são salvos em:

```text
output/figures/comparative_software/
```

A tabela consolidada é salva em:

```text
output/tables/comparative_software_results.csv
```

O relatório de diagnóstico é salvo em:

```text
docs/relatorio_plots_comparativos.md
output/logs/comparative_software_plots.log
```

Se algum gráfico ainda aparecer só com Python, abra o relatório de diagnóstico: ele dirá quais tabelas foram encontradas e quais softwares ainda estão faltando.
