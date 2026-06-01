# Pacote — Lista AIDS 2026

Este pacote atualiza a resolução computacional da **Lista: Estimação de Sistema de Demanda AIDS**, de 1 de junho de 2026, usando a base `meatdata.csv`.

A implementação segue a lista nova:

1. calcula dispêndios por produto e participações no dispêndio;
2. verifica se as participações somam 1 em cada ano;
3. calcula o índice de Stone com participações médias;
4. normaliza os logaritmos dos preços pela média temporal;
5. estima três especificações:
   - modelo sem homogeneidade e sem simetria;
   - modelo com homogeneidade;
   - modelo com homogeneidade e simetria;
6. omite apenas a **equação** do frango (`poult`), mas mantém o frango no cálculo de `xtotal`, no índice de Stone e nas restrições;
7. recupera os parâmetros da equação omitida por adding-up;
8. calcula elasticidades-dispêndio, elasticidades Marshallianas e elasticidades compensadas;
9. testa restrições teóricas;
10. executa diagnósticos dos instrumentos;
11. gera tabelas, matrizes e gráficos para dados, resultados e diagnóstico.

## Dados

A base incluída em `data/raw/meatdata.csv` tem dimensão `41 x 23` e cobre `1970–2010`.

Colunas encontradas:

```text
year, beefq, vealq, bfvlq, porkq, poultq, fishq, cbfvlq, cporkq, cpoultq, cfishq, bfvlp, porkp, poultp, fishp, cpi, pop, pce, xbfvl, xpork, xpoult, xfish, xtotal
```

## Como rodar primeiro no Stata

Abra o Stata, defina o diretório de trabalho como a raiz deste pacote e rode:

```stata
do stata/run_all_aids_stata.do
```

Os resultados Stata serão salvos em:

- `data/processed/`
- `output/tables/`
- `output/figures/`
- `output/logs/`
- `output/models/`

## Como rodar depois no R

Abra o R ou RStudio, defina o diretório de trabalho como a raiz deste pacote e rode:

```r
source("R/run_all_aids_R.R")
```

Os resultados R serão salvos nas mesmas pastas `output/`.

## Observação importante

Os scripts são muito comentados para que cada etapa fique clara. Eles não usam rotinas prontas de estimação AIDS. A estimação é implementada diretamente com GMM/IV, conforme a orientação da lista.
