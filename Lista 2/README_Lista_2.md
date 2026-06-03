# Lista 2 — Estimação de Sistema de Demanda AIDS

Este diretório contém o pacote de replicação da **Lista: Estimação de Sistema de Demanda AIDS**, voltada à estimação de uma versão linear aproximada do sistema AIDS de Deaton e Muellbauer para demanda condicional por carnes nos Estados Unidos.

A lista se conecta ao bloco de demanda multiproduto da Economia Industrial: consumidores escolhem entre bens substitutos dentro de um sistema, e as elasticidades próprias/cruzadas são necessárias para discutir substituição, complementaridade e efeitos de preços em mercados com vários produtos.

## Modelo econômico

Considere o conjunto de bens:

$$
G = \{\text{carne bovina e vitela}, \text{suína}, \text{frango}, \text{pescados}\}.
$$

A participação no dispêndio do bem $g$ é:

$$
w_{gt} = \frac{p_{gt}q_{gt}}{x_t},
\qquad
x_t = \sum_{k \in G}p_{kt}q_{kt}.
$$


Como a lista estima uma demanda condicional por carnes, $x_t$ é o dispêndio total com os quatro produtos de carne, e não o consumo total da economia.

A versão linear aproximada do AIDS é:

$$
w_{gt} = \alpha_g + \sum_{k \in G}\gamma_{gk}\ln p_{kt} + \beta_g\ln\left(\frac{x_t}{P_t}\right) + u_{gt}.
$$

O índice de Stone é calculado com participações médias:

$$
\ln P_t^S = \sum_{k \in G}\bar{w}_k\ln p_{kt}.
$$

A variável de dispêndio real usada nas equações é:

$$
\ln\left(\frac{x_t}{P_t^S}\right)=\ln x_t-\ln P_t^S.
$$

## Normalização dos preços

Os logaritmos de preços são normalizados pela média temporal:

$$
lngp_{kt} = \ln p_{kt} - \frac{1}{T}\sum_{s=1}^{T}\ln p_{ks}.
$$

Essa normalização melhora a interpretação dos interceptos e a estabilidade numérica, sem alterar as elasticidades.

## Restrições teóricas

O pacote implementa as restrições usuais do AIDS.

### Adding-up

$$
\sum_{g\in G}\alpha_g = 1,
\qquad
\sum_{g\in G}\gamma_{gk}=0 \; \forall k,
\qquad
\sum_{g\in G}\beta_g=0.
$$

### Homogeneidade

$$
\sum_{k\in G}\gamma_{gk}=0 \; \forall g.
$$

### Simetria

$$
\gamma_{gk}=\gamma_{kg} \; \forall g,k.
$$

Na estimação, a equação do frango é omitida para evitar singularidade, mas o frango permanece no cálculo de $x_t$, do índice de Stone e das restrições. Os parâmetros da equação omitida são recuperados por adding-up.

## Instrumentos

A especificação principal usa log-preços defasados em um período, normalizados, como instrumentos:

\begin{equation}
Z_t = \left(1, lngp_{1,t-1}, \ldots, lngp_{J,t-1}\right).
\end{equation}

A especificação alternativa adiciona a segunda defasagem dos log-preços para avaliar força, excesso de instrumentos e estabilidade das elasticidades.

## Modelos estimados

O pacote estima três blocos principais:

| Modelo | Restrições impostas | Objetivo |
|---|---|---|
| Irrestrito | nenhuma restrição de homogeneidade/simetria | referência flexível |
| Homogeneidade | $\sum_k\gamma_{gk}=0$ | testar ausência de ilusão monetária e coerência com demanda homogênea de grau zero |
| Homogeneidade + Simetria | $\sum_k\gamma_{gk}=0$ e $\gamma_{gk}=\gamma_{kg}$ | impor restrições de teoria do consumidor |

Também são produzidos:

- tabelas de coeficientes, erros-padrão e estatísticas t;
- recuperação dos parâmetros da equação omitida;
- testes de restrições teóricas por Wald ou diferença na estatística objetivo do GMM;
- diagnósticos de primeiro estágio para cada preço potencialmente endógeno;
- comparação entre Stata, R e Python quando disponível.

## Elasticidades

A elasticidade-dispêndio é:

$$
\eta_g = 1 + \frac{\beta_g}{\bar{w}_g}.
$$

A elasticidade-preço Marshalliana é:

\begin{equation}
\varepsilon^M_{gk} = -\mathbf{1}\{g=k\} + \frac{\gamma_{gk}}{\bar{w}_g} - \frac{\beta_g\bar{w}_k}{\bar{w}_g}.
\end{equation}

A elasticidade compensada, quando calculada, usa a relação de Slutsky:

$$
\varepsilon^H_{gk} = \varepsilon^M_{gk} + \eta_g\bar{w}_k.
$$

## Estrutura do diretório

```text
Lista 2/
├── README.md
├── MANIFEST.txt
├── data/
│   ├── raw/
│   │   └── meatdata.csv
│   └── processed/
├── docs/
│   ├── listaDS26.pdf
│   └── technical_notes.md
├── stata/
│   ├── 00_config_aids.do
│   ├── 01_prepare_aids_data.do
│   ├── 02_estimate_aids_stata.do
│   ├── 03_elasticities_aids_stata.do
│   ├── 04_tests_diagnostics_aids_stata.do
│   ├── 05_visualizations_aids_stata.do
│   ├── README_STATA.md
│   └── run_all_aids_stata.do
├── R/
│   ├── 00_config_aids.R
│   ├── 01_prepare_aids_data.R
│   ├── 02_estimate_aids_R.R
│   ├── 03_elasticities_aids_R.R
│   ├── 04_visualizations_aids_R.R
│   ├── 05_diagnostico_resultados_aids_R.R
│   ├── 06_compara_resultados_R_Stata.R
│   ├── 07_resumo_comparacao_R_Stata.R
│   ├── README_R.md
│   └── run_all_aids_R.R
├── Python/
│   ├── README_PY.md
│   ├── requirements.txt
│   ├── pyproject.toml
│   ├── run_all_aids_py.py
│   └── py_aids_replication/
│       ├── config.py
│       ├── prepare_aids_data.py
│       ├── estimate_aids.py
│       ├── elasticities_aids.py
│       ├── diagnostics_aids.py
│       ├── visualizations_aids.py
│       ├── compare_results_stata.py
│       ├── summary_compare.py
│       └── run_all_aids.py
└── output/
    ├── tables/
    ├── figures/
    │   ├── PDF/
    │   └── PNG/
    ├── logs/
    └── models/
```

## Guia de execução

### Stata

Na raiz de `Lista 2/`:

```stata
do stata/run_all_aids_stata.do
```

### R

Na raiz de `Lista 2/`:

```r
source("R/run_all_aids_R.R")
```

### Python

Na raiz de `Lista 2/`:

```bash
python -m venv .venv
# Windows
.venv\Scripts\activate
# Linux/Mac
# source .venv/bin/activate
pip install -r Python/requirements.txt
python Python/run_all_aids_py.py
```

## Saídas principais

| Diretório | Conteúdo |
|---|---|
| `data/processed/` | base com dispêndios, shares, índice de Stone, log-preços normalizados e instrumentos |
| `output/tables/` | coeficientes, restrições, elasticidades, diagnósticos e comparações |
| `output/figures/PDF/` | gráficos em PDF |
| `output/figures/PNG/` | gráficos em PNG |
| `output/logs/` | logs de execução |
| `output/models/` | objetos/arquivos de modelos quando gerados |

## Interpretação econômica

- A homogeneidade exige que a demanda responda a preços relativos, e não ao nível nominal de todos os preços.
- A simetria conecta a matriz de substituição à teoria de escolha do consumidor; rejeições podem indicar erro de especificação, agregação inadequada ou problemas de dados.
- Elasticidades próprias negativas e elasticidades cruzadas coerentes com substituição entre carnes são sinais de plausibilidade econômica.
- Instabilidade das elasticidades ao mudar instrumentos pode indicar instrumentos fracos, excesso de instrumentos ou endogeneidade não resolvida.
