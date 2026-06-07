# Pacote Python de replicação — sistema AIDS

## Elaborado por

- Luiz Mario Andrade — Matrícula: 252029360
- Felipe Santos — Matrícula: 232010719
- Luiza Nodari — Matrícula: 242011335
- Diogo Martins — Matrícula: 232001578
- Sarah Moura — Matrícula: 211060316
- Pedro Bijos — Matrícula: 241003849

Este pacote replica, em Python, o fluxo dos scripts R enviados para a lista AIDS:

1. `prepare_aids_data.py` — prepara a base `meatdata.csv`, cria participações, logs, índice de Stone, defasagens e diagnósticos básicos.
2. `estimate_aids.py` — estima os modelos AIDS por GMM linear empilhado, no padrão Stata-like usado no R: dois passos, `unadjusted`, instrumentos em blocos por equação.
3. `elasticities_aids.py` — recupera `alpha`, `beta`, `gamma` completos por adding-up e calcula elasticidades de dispêndio, marshallianas e compensadas.
4. `visualizations_aids.py` — gera os gráficos em PDF e PNG, em subdiretórios separados.
5. `diagnostics_aids.py` — calcula diagnósticos de modelos, diferenças de J, regularidade econômica e matriz de Slutsky.
6. `compare_results_stata.py` — compara automaticamente os resultados Python com tabelas Stata quando elas existirem em `output/tables`.
7. `summary_compare.py` — resume diferenças máximas entre Python e Stata.

## Estrutura esperada

A raiz do pacote é a pasta `Códigos_Lista2/`. O executor Python fica em `Códigos_Lista2/Python/` e localiza automaticamente a base em `../data/raw/meatdata.csv`.

```text
Códigos_Lista2/
├── data/
│   └── raw/
│       └── meatdata.csv
├── output/
└── Python/
    ├── run_all_aids_py.py
    └── py_aids_replication/
```

## Instalação rápida

```bash
pip install -r requirements.txt
```

Ou, se quiser instalar como pacote local:

```bash
pip install -e .
```

## Rodar tudo

```bash
python run_all_aids_py.py
```

Por padrão, os arquivos Python usam sufixo `_PY` para não sobrescrever os arquivos `_R`. Exemplos:

```text
output/tables/coeficientes_PY.csv
output/tables/elasticidades_marshallianas_hsym_PY.csv
output/figures/PDF/PY_22_elasticidades_marshallianas.pdf
output/figures/PNG/PY_22_elasticidades_marshallianas.png
```

Se quiser gerar nomes com sufixo `_R` para encaixar em algum fluxo antigo, altere:

```python
from py_aids_replication.run_all_aids import run_all
run_all(output_tag="R")
```

## Rodar módulo a módulo

```python
from py_aids_replication.config import AIDSConfig
from py_aids_replication.prepare_aids_data import prepare_aids_data
from py_aids_replication.estimate_aids import estimate_all
from py_aids_replication.elasticities_aids import calculate_elasticities
from py_aids_replication.visualizations_aids import generate_visualizations
from py_aids_replication.diagnostics_aids import run_diagnostics
from py_aids_replication.compare_results_stata import compare_results
from py_aids_replication.summary_compare import summarize_comparison

cfg = AIDSConfig(root=".", output_tag="PY")
prepare_aids_data(cfg)
estimate_all(cfg)
calculate_elasticities(cfg, wbar_sample="full")
generate_visualizations(cfg)
run_diagnostics(cfg)
compare_results(cfg)
summarize_comparison(cfg)
```

## Observação sobre a estimação GMM

A rotina de GMM reproduz a lógica do R:

- empilha as equações estimadas para `bfvl`, `pork` e `fish`;
- omite `poult` como equação, recuperando o restante por adding-up;
- usa instrumentos em blocos por equação;
- no primeiro passo usa `I_e \otimes (Z0'Z0/n)^(-1)`;
- no segundo passo usa `(Sigma_u \otimes (Z0'Z0/n))^(-1)`;
- calcula erros-padrão com escala de períodos, não de observações empilhadas.
