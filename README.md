# Economia Industrial — Pacote de Replicação das Listas 1, 2 e 3

Este repositório reúne três pacotes de replicação para exercícios de Economia Industrial. A organização foi pensada para permitir a execução independente de cada lista, com versões em **Stata**, **R** e **Python** sempre que disponíveis, além de saídas padronizadas em tabelas, gráficos e logs.

O fio condutor das três listas é a estimação empírica de demanda e seu uso em Economia Industrial: elasticidades, endogeneidade de preços, instrumentos, GMM, modelos de produtos homogêneos, sistemas multiproduto e demanda por produtos diferenciados. Como referencial teórico, o pacote segue a apostila **Introdução à Economia Industrial e ao Antitruste**, em especial os capítulos sobre consumidores e elasticidades, estimação da demanda com variáveis instrumentais e GMM, demanda por produtos diferenciados, AIDS/Berry/BLP e markups.

## Visão geral das listas

| Diretório | Tema | Objeto empírico | Principais métodos |
|---|---|---|---|
| `Lista 1/` | Demanda por produto homogêneo, 2SLS e instrumentos fracos | Demanda anual por frango nos EUA | MQO, 2SLS, primeiro estágio, GMM, Hansen J, Montiel Olea-Pflueger, Anderson-Rubin/CLR, simulação de instrumentos fracos |
| `Lista 2/` | Sistema de demanda AIDS | Demanda condicional por carnes nos EUA | Sistema AIDS linear aproximado, índice de Stone, IV/GMM, homogeneidade, simetria, elasticidades Marshallianas e compensadas |
| `Lista 3/` | Demanda por produtos diferenciados à la Berry/BLP | Cereais matinais nos EUA em 1992 | Logit simples, instrumentos BLP, 2SLS, GMM estrutural, nested logit, elasticidades, markups e diagnóstico de instrumentos |

## Estrutura geral do repositório

```text
Economia Industrial_Lista 1/
├── README.md                 # este guia geral
├── Lista 1/
│   ├── README.md             # guia específico da lista 1
│   ├── data/                 # dados brutos e tratados
│   ├── Stata/                # scripts Stata da lista 1
│   ├── R/                    # scripts R da lista 1
│   ├── Python/               # scripts Python da lista 1
│   ├── Comparativo/          # comparação Stata/R/Python
│   ├── docs/                 # notas técnicas, mapas de questões e relatórios
│   └── output/               # tabelas, figuras e logs
├── Lista 2/
│   ├── README.md             # guia específico da lista 2
│   ├── data/                 # dados brutos e tratados
│   ├── stata/                # scripts Stata da lista 2
│   ├── R/                    # scripts R da lista 2
│   ├── Python/               # pacote Python da lista 2
│   ├── docs/                 # enunciado e notas técnicas
│   └── output/               # tabelas, figuras, logs e modelos
└── Lista 3/
    ├── README.md             # guia específico da lista 3
    ├── data/                 # base de cereais
    ├── stata/                # scripts Stata da lista 3
    ├── R/                    # scripts R da lista 3
    ├── python/               # scripts Python da lista 3
    ├── run_all.sh            # execução agregada em ambiente Unix-like
    └── outputs/              # saídas separadas por linguagem
```

## Referencial teórico mínimo

A apostila organiza o conteúdo do pacote em três blocos.

1. **Demanda, elasticidades e poder de mercado.** A análise de Economia Industrial parte da mensuração da sensibilidade da demanda a preços, renda e características dos produtos. A elasticidade-preço é central para interpretar poder de mercado, margens e perda crítica.

2. **Endogeneidade de preços e variáveis instrumentais.** Em equações de demanda, preços podem reagir a choques não observados de qualidade, preferência ou demanda. Por isso, as listas 1 e 3 tratam preços como potencialmente endógenos e usam instrumentos que deslocam oferta/custos ou variação estratégica de características dos produtos.

3. **Modelos multiproduto e produtos diferenciados.** A lista 2 usa o modelo AIDS para estimar um sistema de demanda no espaço dos produtos. A lista 3 usa a inversão de Berry para transformar market shares em utilidade média e estimar modelos logit/nested logit com momentos de GMM.

## Equações centrais por lista

### Lista 1: demanda log-log por frango

$$
q_t = \beta_0 + \beta_p p^{ch}_t + \beta_y y_t + \beta_b p^b_t + u_t.
$$

O preço do frango, $p^{ch}_t$, é tratado como endógeno. O instrumento principal é o preço real do milho, $z_t = \ln(P\!COR_t/CPI_t)$, que desloca custos de produção do setor de frango.

### Lista 2: sistema AIDS linear aproximado

$$
w_{gt} = \alpha_g + \sum_{k \in G} \gamma_{gk}\ln p_{kt} + \beta_g\ln\left(\frac{x_t}{P_t}\right) + u_{gt}.
$$

O pacote usa o índice de Stone com participações médias:

$$
\ln P_t^S = \sum_{k \in G} \bar{w}_k \ln p_{kt}.
$$

As restrições teóricas avaliadas são adding-up, homogeneidade e simetria.

### Lista 3: logit de Berry/BLP

$$
\delta_j = \ln(s_j) - \ln(s_0) = X'_j\beta - \alpha p_j + \xi_j.
$$

A estimação estrutural usa momentos de GMM:

$$
g_N(\theta) = \frac{1}{N}\sum_{j=1}^N Z_j \xi_j(\theta), \qquad
\hat{\theta}_{GMM} = \arg\min_{\theta} g_N(\theta)'W_N g_N(\theta).
$$

No nested logit, acrescenta-se o termo de participação dentro do nest:

$$
\ln(s_j) - \ln(s_0) = X'_j\beta - \alpha p_j + \sigma\ln(s_{j|g}) + \xi_j.
$$

## Guia rápido de execução

### 1. Lista 1

```bash
cd "Lista 1"
```

Stata:

```stata
do "Stata/00_master.do"
```

R:

```r
source("R/00_run_all.R")
```

Python:

```bash
python -m venv .venv
# Windows
.venv\Scripts\activate
# Linux/Mac
# source .venv/bin/activate
pip install -r Python/requirements.txt
python Python/src/run_all.py
```

Comparação entre linguagens:

```bash
python Comparativo/01_plots_comparativos_software.py
```

### 2. Lista 2

```bash
cd "Lista 2"
```

Stata:

```stata
do stata/run_all_aids_stata.do
```

R:

```r
source("R/run_all_aids_R.R")
```

Python:

```bash
pip install -r Python/requirements.txt
python Python/run_all_aids_py.py
```

### 3. Lista 3

```bash
cd "Lista 3"
```

Python:

```bash
python python/run_all_python.py
python python/07_extra_visualizations.py
```

R:

```r
source("R/run_all_R.R")
```

Stata:

```stata
do stata/run_all_stata.do
```

Ambiente Unix-like, quando desejado:

```bash
bash run_all.sh
```

## Convenção de saídas

- **Dados tratados:** `data/processed/` ou `outputs/<linguagem>/data/`.
- **Tabelas:** `output/tables/` ou `outputs/<linguagem>/tables/csv` e `outputs/<linguagem>/tables/tex`.
- **Figuras:** `output/figures/` ou `outputs/<linguagem>/figures/png` e `outputs/<linguagem>/figures/pdf`.
- **Logs:** `output/logs/` ou `outputs/<linguagem>/logs/`.
- **Modelos salvos:** `output/models/`, quando aplicável.

## Ordem recomendada para replicação completa

1. Rode cada lista isoladamente, começando pelo Stata quando a lista exigir testes específicos, como `weakivtest`/MO-P.
2. Rode a versão R e a versão Python para comparação de resultados e gráficos.
3. Confira os logs em `output/logs/` ou `outputs/<linguagem>/logs/`.
4. Compare tabelas e figuras geradas com os arquivos já existentes no pacote.
5. Use os documentos em `docs/` para interpretação econômica e mapeamento das questões.

## Dependências gerais

- **Stata:** recomendado para os testes de instrumentos fracos, especialmente Montiel Olea-Pflueger, quando implementado por `weakivtest`.
- **R:** base R e pacotes instalados pelos próprios scripts quando necessário. Em algumas rotinas, os pacotes de tabelas/gráficos podem ser requeridos.
- **Python:** `numpy`, `pandas`, `scipy`, `matplotlib`, `statsmodels` e dependências específicas listadas em `requirements.txt`.

## Observação sobre reprodutibilidade

Os diretórios foram estruturados para separar código, dados brutos, dados tratados e resultados. A regra de ouro é: **não editar manualmente arquivos em `data/processed/`, `output/` ou `outputs/`**. Esses arquivos devem ser regeneráveis a partir dos scripts `run_all` de cada linguagem.
