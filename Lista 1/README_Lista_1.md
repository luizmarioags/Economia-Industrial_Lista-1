# Lista 1 — Estimação de Demanda, 2SLS e Instrumentos Fracos

Este diretório contém o pacote de replicação da **Lista 1 de Economia Industrial**, dedicada à estimação de uma demanda log-log por frango, com tratamento explícito da endogeneidade do preço, diagnóstico de instrumentos fracos e comparação entre MQO, 2SLS e GMM.

A lista parte da ideia central da estimação de demanda em produto homogêneo: choques não observados de demanda podem afetar simultaneamente quantidade e preço. Por isso, o coeficiente de preço estimado por MQO pode estar viesado, e a identificação da elasticidade-preço exige instrumentos válidos e relevantes.

## Modelo econômico

A equação estrutural estimada é:

$$
q_t = \beta_0 + \beta_p p^{ch}_t + \beta_y y_t + \beta_b p^b_t + u_t,
$$

em que:

- $q_t = \ln(Q_t)$ é o logaritmo da quantidade consumida per capita de frango;
- $p^{ch}_t = \ln(PCHICK_t/CPI_t)$ é o logaritmo do preço real do frango;
- $y_t = \ln(Y_t)$ é o logaritmo da renda real per capita;
- $p^b_t = \ln(PBEEF_t/CPI_t)$ é o logaritmo do preço real da carne bovina;
- $u_t$ contém choques não observados de demanda;
- $\beta_p$ é a elasticidade-preço própria da demanda por frango.

O instrumento principal é:

$$
z_t = \ln\left(\frac{PCOR_t}{CPI_t}\right),
$$

interpretado como deslocador de custo da produção de frango, pois o milho é insumo relevante da cadeia produtiva.

## Variáveis construídas

A preparação dos dados cria, pelo menos, as seguintes variáveis:

| Variável | Definição | Interpretação |
|---|---:|---|
| `ln_q` | $\ln(Q_t)$ | consumo per capita de frango |
| `ln_y` | $\ln(Y_t)$ | renda real per capita |
| `ln_pch` | $\ln(PCHICK_t/CPI_t)$ | preço real do frango |
| `ln_pb` | $\ln(PBEEF_t/CPI_t)$ | preço real da carne bovina |
| `z` | $\ln(PCOR_t/CPI_t)$ | preço real do milho |
| `z2`, `z3` | $z_t^2$, $z_t^3$ | instrumentos não lineares |
| `z_lag1`, `z_lag1_sq` | $z_{t-1}$, $z_{t-1}^2$ | instrumentos defasados |

## Modelos estimados

### 1. MQO com erro-padrão robusto

Estima a equação estrutural tratando o preço do frango como exógeno. Serve como referência inicial:

$$
\widehat{\beta}^{OLS} = (X'X)^{-1}X'q.
$$

O pacote reporta o coeficiente de preço, erro-padrão robusto à heterocedasticidade, intervalo de confiança de 95% e interpretação econômica.

### 2. Primeiro estágio

O primeiro estágio básico é:

$$
p^{ch}_t = \pi_0 + \pi_z z_t + \pi_y y_t + \pi_b p^b_t + v_t.
$$

São calculados coeficientes, $R^2$ parcial do instrumento excluído e estatística F para relevância do instrumento.

### 3. 2SLS

O estimador IV/2SLS usa instrumentos excluídos para `ln_pch` e mantém `ln_y` e `ln_pb` como controles exógenos:

$$
\widehat{\beta}^{2SLS} = (X'P_ZX)^{-1}X'P_Zq,
\qquad
P_Z = Z(Z'Z)^{-1}Z'.
$$

### 4. GMM e Hansen J

O pacote estima especificações GMM exatamente identificadas e sobreidentificadas. Os momentos têm a forma:

$$
g_T(\beta) = \frac{1}{T}\sum_{t=1}^T Z_t u_t(\beta).
$$

A função objetivo é:

$$
Q_T(\beta) = g_T(\beta)'W_Tg_T(\beta).
$$

Nos modelos sobreidentificados, o teste J de Hansen avalia a validade conjunta das restrições de sobreidentificação.

### 5. Especificações alternativas de instrumentos

A lista exige sete conjuntos de instrumentos excluídos:

| Especificação | Instrumentos excluídos |
|---|---|
| `Z1` | $\{z_t\}$ |
| `Z2` | $\{z_t, z_t^2\}$ |
| `Z3` | $\{z_t, z_t^2, z_t^3\}$ |
| `Z4` | $\{z_{t-1}\}$ |
| `Z5` | $\{z_{t-1}, z_{t-1}^2\}$ |
| `Z6` | $\{z_t, z_{t-1}\}$ |
| `Z7` | $\{z_t, z_t^2, z_{t-1}, z_{t-1}^2\}$ |

### 6. Diagnóstico de instrumentos fracos

O pacote reporta:

- F usual do primeiro estágio;
- F robusto quando disponível;
- F efetivo de Montiel Olea-Pflueger no Stata;
- intervalos robustos a instrumentos fracos, como Anderson-Rubin ou CLR quando disponíveis;
- simulação demonstrando deterioração do 2SLS quando a correlação entre instrumento e variável endógena cai.

## Estrutura do diretório

```text
Lista 1/
├── README.md
├── data/
│   ├── raw/                 # chicken.csv e chicken.dta
│   └── processed/           # bases tratadas por Stata/R/Python
├── Stata/
│   ├── config.do
│   ├── 00_master.do
│   ├── 01_prepare_data.do
│   ├── 02_ols_iv_first_stage.do
│   ├── 03_gmm_hansen.do
│   ├── 04_alt_instruments_weakiv.do
│   ├── 05_ar_intervals.do
│   ├── 06_visualizations.do
│   └── 07_simulation_weak_instruments.do
├── R/
│   ├── 00_setup.R
│   ├── 00_functions.R
│   ├── 00_run_all.R
│   ├── 01_prepare_data.R
│   ├── 02_estimations.R
│   ├── 03_visualizations.R
│   └── 04_simulation.R
├── Python/
│   ├── requirements.txt
│   └── src/
│       ├── config.py
│       ├── econometrics.py
│       ├── estimations.py
│       ├── prepare_data.py
│       ├── simulation.py
│       ├── visualizations.py
│       └── run_all.py
├── Comparativo/
│   ├── 01_plots_comparativos_software.py
│   ├── 02_plots_comparativos_software_avancado.py
│   ├── 02_plots_comparativos_software_avancado.R
│   ├── 02_plots_comparativos_software_avancado.do
│   └── README.md
├── docs/
│   ├── diagnostico_pacote_original.md
│   ├── mapa_questoes.md
│   ├── relatorio_plots_comparativos.md
│   ├── relatorio_plots_comparativos_avancado.md
│   └── respostas_interpretativas.md
└── output/
    ├── tables/              # tabelas CSV/TeX, com subpastas por linguagem
    ├── figures/             # gráficos, com subpastas por linguagem
    └── logs/                # logs de execução
```

## Guia de execução

### Stata

Abra o Stata na raiz de `Lista 1/` e rode:

```stata
do "Stata/00_master.do"
```

O Stata é a referência principal para o teste Montiel Olea-Pflueger quando `weakivtest` estiver instalado.

### R

No R/RStudio, defina o diretório de trabalho na raiz de `Lista 1/` e rode:

```r
source("R/00_run_all.R")
```

### Python

No terminal, a partir de `Lista 1/`:

```bash
python -m venv .venv
# Windows
.venv\Scripts\activate
# Linux/Mac
# source .venv/bin/activate
pip install -r Python/requirements.txt
python Python/src/run_all.py
```

### Gráficos comparativos

Depois de rodar Stata, R e Python:

```bash
python Comparativo/01_plots_comparativos_software.py
python Comparativo/02_plots_comparativos_software_avancado.py
```

## Saídas principais

| Saída | Conteúdo |
|---|---|
| `output/tables/` | resultados MQO, 2SLS, GMM, Hansen J, F usual, F efetivo e intervalos |
| `output/figures/` | gráficos de séries, instrumentos, estimações, simulações e comparações entre linguagens |
| `output/logs/` | logs de execução por ambiente |
| `docs/` | relatórios interpretativos e mapeamento das questões da lista |

## Como interpretar os resultados

- Se o MQO produz elasticidade menos negativa do que o IV, isso é compatível com viés positivo gerado por choques de demanda que elevam preço e quantidade ao mesmo tempo.
- Um instrumento pode ser estatisticamente relevante no primeiro estágio e ainda assim não ser exógeno.
- O teste J de Hansen avalia a validade conjunta das restrições excedentes, mas não prova que todos os instrumentos são válidos.
- Em análise antitruste, elasticidades obtidas com instrumentos fracos podem levar a conclusões enganosas sobre poder de mercado, margens e perda crítica.
