# Lista 3 — Berry/BLP, Logit, Nested Logit, Elasticidades e Markups

Este diretório contém o pacote de replicação da **Lista 3: Estimação de Demanda por Produtos Diferenciados**, usando dados de cereais matinais comercializados nos Estados Unidos em 1992. A lista implementa a lógica de Berry/BLP: recuperar a utilidade média a partir de market shares, tratar preço como endógeno, construir instrumentos de diferenciação e estimar o modelo por 2SLS e GMM estrutural.

A lista se conecta diretamente aos capítulos da apostila sobre demanda por produtos diferenciados, B-Logit/Berry, BLP, markups e uso de elasticidades para inferir poder de mercado.

## Modelo econômico

A utilidade indireta do consumidor $i$ ao comprar o produto $j$ é:

$$
u_{ij}=X'_j\beta - \alpha p_j + \xi_j + \varepsilon_{ij},
$$

em que $X_j$ são características observadas, $p_j$ é o preço, $\xi_j$ é qualidade não observada pelo econometrista e $\varepsilon_{ij}$ é choque idiossincrático com distribuição valor extremo tipo I.

A utilidade média é:

$$
\delta_j = X'_j\beta - \alpha p_j + \xi_j.
$$

Com bem externo de share $s_0=0{,}2429$, a inversão logit de Berry gera:

$$
\delta_j = \ln(s_j)-\ln(s_0).
$$

Logo, a equação linear do logit simples é:

$$
\ln(s_j)-\ln(s_0)=X'_j\beta-\alpha p_j+\xi_j.
$$

O coeficiente estimado sobre preço corresponde a $-\alpha$. Sob demanda decrescente, espera-se $\alpha>0$ e coeficiente de preço negativo.

## Endogeneidade e instrumentos BLP

O preço pode ser endógeno porque firmas escolhem preços conhecendo componentes de qualidade observados pelos consumidores, mas não observados pelo econometrista. Assim, em geral:

$$
E[p_j\xi_j]\neq 0.
$$

A identificação exige instrumentos $Z_j$ tais que:

$$
E[Z_j\xi_j]=0
$$

com relevância para explicar $p_j$.

Os instrumentos de diferenciação construídos no pacote são:

### Instrumentos da própria firma

$$
Z^{own}_{jk}=\sum_{\ell\neq j:f(\ell)=f(j)}x_{\ell k}.
$$

Para firmas monoproduto, esses instrumentos são tratados como zero.

### Instrumentos de firmas rivais

$$
Z^{rival}_{jk}=\sum_{\ell:f(\ell)\neq f(j)}x_{\ell k}.
$$

## GMM estrutural

A estimação estrutural minimiza momentos dos erros de demanda:

$$
g_N(\theta)=\frac{1}{N}\sum_{j=1}^{N}Z_j\xi_j(\theta),
\qquad
\hat{\theta}_{GMM}=\arg\min_\theta g_N(\theta)'W_Ng_N(\theta).
$$

No logit simples:

$$
\xi_j(\theta)=\ln(s_j)-\ln(s_0)-X'_j\beta+\alpha p_j.
$$

O pacote reporta GMM de primeira etapa e GMM eficiente de duas etapas.

## Nested logit

Os produtos são agrupados em nests por segmentação economicamente defensável. Para o produto $j$ no grupo $g$:

$$
s_{j|g}=\frac{s_j}{s_g},
\qquad
s_g=\sum_{\ell\in g}s_\ell.
$$

A equação estimável é:

$$
\ln(s_j)-\ln(s_0)=X'_j\beta-\alpha p_j+\sigma\ln(s_{j|g})+\xi_j.
$$

O parâmetro $\sigma$ mede a correlação de preferências dentro do nest. O intervalo compatível com o modelo é:

$$
0 \leq \sigma < 1.
$$

Como $\ln(s_{j|g})$ também pode ser endógeno, o pacote constrói instrumentos adicionais baseados no número e nas características de produtos dentro do mesmo nest e em nests rivais.

## Modelos estimados

| Bloco | Modelos/saídas |
|---|---|
| Logit simples | MQO com transaction prices e características dos produtos |
| 2SLS | instrumentos `own_*`, `rival_*` e ambos os conjuntos |
| GMM | GMM primeira etapa e GMM duas etapas para os mesmos conjuntos de instrumentos |
| Nested logit | GMM com preço e `ln(s_j|g)` tratados como endógenos |
| Comparação | tabela do parâmetro de preço entre MQO, 2SLS, GMM e nested logit |
| Elasticidades | próprias e cruzadas do logit simples e nested logit |
| Markups | markups monoproduto e multiproduto com matriz de propriedade |
| Diagnóstico | primeiro estágio, F usual/robusto, MO-P no Stata e validade econômica dos instrumentos |

## Elasticidades do logit simples

A elasticidade-preço própria é:

$$
\varepsilon_{jj}=-\alpha p_j(1-s_j).
$$

A elasticidade-preço cruzada, para $k\neq j$, é:

$$
\varepsilon_{jk}=\alpha p_k s_k.
$$

## Markups implícitos

Sob firmas monoproduto:

$$
p_j-mc_j=\frac{1}{\alpha(1-s_j)}.
$$

Com propriedade multiproduto, define-se:

$$
O_{jk}=\mathbf{1}\{f(j)=f(k)\},
\qquad
\Delta_{jk}=-O_{jk}\frac{\partial s_k}{\partial p_j}.
$$

No logit simples:

$$
\Delta_{jj}=\alpha s_j(1-s_j),
\qquad
\Delta_{jk}=-O_{jk}\alpha s_js_k \quad (j\neq k).
$$

Os markups multiproduto são:

$$
p-mc=\Delta^{-1}s.
$$

## Estrutura do diretório

```text
Lista 3/
├── README.md
├── MANIFEST.txt
├── run_all.sh
├── data/
│   └── exemplo.csv
├── stata/
│   ├── 00_config.do
│   ├── 01_prepare_data.do
│   ├── 02_estimate_logit_iv_gmm.do
│   ├── 03_nested_gmm.do
│   ├── 04_elasticities_markups.do
│   ├── 05_diagnostics_weakiv.do
│   ├── 06_visualizations.do
│   ├── 07_extra_visualizations.do
│   ├── 08_standard_tables.do
│   ├── original_b_program.do
│   ├── original_eberry.do
│   └── run_all_stata.do
├── R/
│   ├── 00_config.R
│   ├── 01_prepare_data.R
│   ├── 02_estimators_manual.R
│   ├── 03_estimate_logit_iv_gmm.R
│   ├── 04_nested_gmm.R
│   ├── 05_elasticities_markups.R
│   ├── 06_diagnostics.R
│   ├── 07_visualizations.R
│   ├── 08_extra_visualizations.R
│   └── run_all_R.R
├── python/
│   ├── config.py
│   ├── prepare_data.py
│   ├── estimators.py
│   ├── economics.py
│   ├── tables.py
│   ├── visualizations.py
│   ├── 07_extra_visualizations.py
│   └── run_all_python.py
└── outputs/
    ├── python/
    │   ├── data/
    │   ├── logs/
    │   ├── figures/pdf/
    │   ├── figures/png/
    │   ├── tables/csv/
    │   └── tables/tex/
    ├── r/
    │   ├── data/
    │   ├── logs/
    │   ├── figures/pdf/
    │   ├── figures/png/
    │   ├── tables/csv/
    │   └── tables/tex/
    └── stata/
        ├── data/
        ├── logs/
        ├── figures/pdf/
        ├── figures/png/
        ├── tables/csv/
        └── tables/tex/
```

## Guia de execução

### Python

Na raiz de `Lista 3/`:

```bash
python python/run_all_python.py
python python/07_extra_visualizations.py
```

### R

Na raiz de `Lista 3/`:

```r
source("R/run_all_R.R")
```

### Stata

Na raiz de `Lista 3/`:

```stata
do stata/run_all_stata.do
```

### Execução agregada em Unix-like

```bash
bash run_all.sh
```

## Gráficos gerados

O pacote gera gráficos principais e extras em PNG e PDF, incluindo:

- market share versus preço de transação;
- maiores market shares;
- distribuição de preço por segmento;
- delta de Berry versus preço;
- comparação do coeficiente de preço;
- matriz de elasticidades;
- elasticidades próprias;
- markups monoproduto versus multiproduto;
- ajuste de primeiro estágio;
- curva clássica do logit;
- shares observados versus previstos;
- histograma, densidade e QQ plot dos resíduos estruturais;
- correlação dos instrumentos;
- resíduos por firma e por preço.

## Tabelas padronizadas

Cada linguagem salva tabelas equivalentes em `outputs/<linguagem>/tables/csv` e `outputs/<linguagem>/tables/tex`, com resultados como:

1. coeficientes de todos os modelos;
2. comparação do parâmetro de preço;
3. matriz de elasticidades do logit simples;
4. subconjunto da matriz de elasticidades;
5. elasticidades próprias;
6. elasticidades do nested logit;
7. markups;
8. diagnósticos de primeiro estágio.

## Interpretação econômica

- Coeficiente de preço positivo no logit simples ou GMM é sinal de problema econômico e deve ser discutido como possível consequência de endogeneidade, instrumentos fracos, especificação inadequada ou amostra limitada.
- Instrumentos BLP são plausíveis quando características de produtos rivais ou da mesma firma deslocam preços por competição/posicionamento sem afetar diretamente a qualidade não observada do produto.
- O nested logit relaxa o padrão de substituição rígido do logit simples ao permitir correlação maior dentro de grupos de produtos.
- Markups multiproduto incorporam internalização de substituição entre produtos da mesma firma; por isso, podem diferir substancialmente dos markups monoproduto.
