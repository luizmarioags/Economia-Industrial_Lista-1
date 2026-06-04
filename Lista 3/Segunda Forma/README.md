# Pacote de replicação Berry/BLP em Stata, R e Python

Este pacote organiza os códigos Stata enviados e inclui versões equivalentes em **R** e **Python** para a Lista Berry/BLP.

## Estrutura

```text
berry_blp_replication_package/
├── data/
│   ├── README_data.md
│   └── exemplo_schema.csv
├── stata/
│   ├── run_all_stata.do
│   └── ... scripts originais organizados
├── R/
│   ├── run_all_R.R
│   └── ... scripts equivalentes em R
├── python/
│   ├── run_all_python.py
│   ├── requirements.txt
│   └── ... scripts equivalentes em Python
└── outputs/
```

## Como rodar

1. Coloque a base original em `data/exemplo.csv`.
2. Rode uma das versões abaixo a partir da raiz do pacote.

### Stata

```stata
do stata/run_all_stata.do
```

### R

```r
source("R/run_all_R.R")
```

### Python

```bash
cd python
python -m pip install -r requirements.txt
python run_all_python.py
```

## O que as versões R/Python reproduzem

- Preparação da base e construção dos instrumentos BLP.
- Logit simples: MQO, IV/2SLS e GMM operacional de 1 e 2 passos.
- Nested logit: IV/2SLS e GMM operacional de 1 e 2 passos.
- Resíduos estruturais.
- Elasticidades próprias e cruzadas do logit simples.
- Elasticidades numéricas do nested logit.
- Markups monoproduto e multiproduto.
- Diagnósticos de primeiro estágio/IV fracos.
- Tabelas CSV e `.tex` simples, prontas para `\input{}` no Overleaf.
- Gráficos principais e extras em PDF/PNG.

## Observação importante

O arquivo de dados `data/exemplo.csv` não foi enviado junto com os `.do`; por isso o pacote está pronto para execução, mas os outputs finais serão gerados quando esse CSV for colocado na pasta `data/`.
