# Lista 3 — Estimação de Demanda por Produtos Diferenciados

## Pacote de replicação Berry/BLP — versão reestimada com `eberry` e `b_program`

Este diretório contém o pacote de replicação da **Lista 3 de Economia Industrial**, dedicada à estimação de demanda por produtos diferenciados no mercado de cereais matinais. A versão atual corresponde à **segunda forma de estimação**, reexecutada a partir dos códigos operacionais inspirados nos arquivos originais disponibilizados para a disciplina: `eberry.do` e `b_program.do`.

A principal diferença em relação à primeira versão do pacote é que, no Stata, a estimação GMM deixou de depender do comando nativo `gmm` como núcleo principal. Nesta versão, os scripts centrais chamam:

```text
stata/eberry_operational.do
stata/b_program_operational.do
```

Esses dois arquivos implementam a lógica operacional dos códigos originais de Berry/BLP: montar as matrizes de dados, definir a função objetivo do GMM, escolher a matriz de ponderação e otimizar os parâmetros estruturais a partir dos momentos dos erros de demanda.

---

## 1. Objetivo da lista

A lista estima a demanda por cereais matinais comercializados nos Estados Unidos em 1992. A base contém preços, market shares e características dos produtos. O conjunto de produtos observados representa os cereais listados na base, enquanto os demais cereais são tratados como **bem externo** (*outside good*).

O market share do bem externo é fixado em:

$$
s_0 = 0{,}2429.
$$

A variável dependente da inversão de Berry é:

$$
\delta_j = \ln(s_j)-\ln(s_0),
$$

em que \(s_j\) é o market share do produto \(j\), medido em relação ao mercado potencial total.

A utilidade indireta do consumidor \(i\) ao comprar o produto \(j\) é:

$$
u_{ij}=X_j'\beta-\alpha p_j+\xi_j+\varepsilon_{ij},
$$

em que:

- \(X_j\) é o vetor de características observadas do produto;
- \(p_j\) é o preço de transação;
- \(\xi_j\) é a característica não observada do produto;
- \(\varepsilon_{ij}\) é o choque idiossincrático de preferência.

Como a utilidade é normalizada em relação ao bem externo, o preço do bem externo é normalizado como zero. A estimação usa **transaction prices**, isto é, preços efetivamente pagos pelos consumidores, e não os preços de prateleira.

---

## 2. Modelo logit simples

No modelo logit simples, a utilidade média do produto é:

$$
\delta_j=X_j'\beta-\alpha p_j+\xi_j.
$$

A inversão de Berry transforma os market shares em uma equação linear:

$$
\ln(s_j)-\ln(s_0)=X_j'\beta-\alpha p_j+\xi_j.
$$

Na implementação deste pacote, o vetor de características observadas é composto por:

```text
cals, fat, sugar
```

Assim, a equação empírica estimada é:

$$
\delta_j=
\beta_0+
\beta_{cals}cals_j+
\beta_{fat}fat_j+
\beta_{sugar}sugar_j-
\alpha p_j+\xi_j.
$$

O coeficiente estimado diretamente sobre o preço corresponde a \(-\alpha\). Portanto, sob demanda decrescente, espera-se:

$$
\alpha>0
\qquad \Longleftrightarrow \qquad
-\alpha<0.
$$

---

## 3. Endogeneidade do preço e instrumentos Berry/BLP

A estimação por MQO é usada como primeira referência, mas o preço pode ser endógeno. A razão econômica é que firmas podem escolher preços conhecendo componentes de qualidade observados por consumidores, mas não observados pelo econometrista.

A hipótese de exogeneidade das características observadas é:

$$
E[X_j\xi_j]=0.
$$

Contudo, para o preço, admite-se que:

$$
E[p_j\xi_j]\neq 0.
$$

Por isso, o pacote constrói instrumentos de diferenciação Berry/BLP. Para cada característica \(k\), o instrumento baseado nos demais produtos da mesma firma é:

$$
Z^{own}_{jk}=\sum_{\ell\neq j:f(\ell)=f(j)}x_{\ell k}.
$$

O instrumento baseado nos produtos de firmas rivais é:

$$
Z^{rival}_{jk}=\sum_{\ell:f(\ell)\neq f(j)}x_{\ell k}.
$$

Na implementação, se uma firma tem apenas um produto na base, o instrumento de mesma firma é preenchido com zero, pois não há outro produto da própria firma a ser somado.

O pacote estima três especificações IV/GMM para o logit simples:

```text
1. Instrumentos da própria firma:       own_cals own_fat own_sugar
2. Instrumentos das firmas rivais:      rival_cals rival_fat rival_sugar
3. Ambos os conjuntos de instrumentos: own_* e rival_*
```

---

## 4. GMM estrutural com `eberry` e `b_program`

A estimação estrutural é feita por GMM. Para um vetor de parâmetros \(\theta\), o erro estrutural do logit simples é:

$$
\xi_j(\theta)=
[\ln(s_j)-\ln(s_0)]-X_j'\beta+\alpha p_j.
$$

Os momentos amostrais são:

$$
g_N(\theta)=\frac{1}{N}\sum_{j=1}^{N}Z_j\xi_j(\theta).
$$

O estimador GMM resolve:

$$
\widehat{\theta}_{GMM}=
\arg\min_{\theta}
\left[g_N(\theta)'W_Ng_N(\theta)\right].
$$

Nesta segunda versão do pacote, esse problema é resolvido pelo par:

```text
stata/eberry_operational.do
stata/b_program_operational.do
```

O arquivo `b_program_operational.do` contém a função objetivo em Mata. A função objetivo implementada é:

$$
Q(\theta)=N\,\bar g(\theta)'W\bar g(\theta),
\qquad
\bar g(\theta)=\frac{1}{N}Z'\xi(\theta).
$$

O algoritmo faz:

1. estimação inicial por matriz de ponderação baseada em \((Z'Z/N)^{-1}\);
2. recuperação dos resíduos estruturais;
3. atualização da matriz de ponderação com a variância estimada dos momentos;
4. reotimização para obter o GMM de duas etapas.

O arquivo `eberry_operational.do` funciona como *wrapper*. Ele define as variáveis \(Y\), \(X\), \(Z\), os nomes dos parâmetros e chama `berry_gmm_code`, que executa a rotina em Mata e devolve os resultados como um objeto `eclass` do Stata. Isso permite usar comandos como:

```stata
estimates store
estimates restore
_b[nome_do_parametro]
_se[nome_do_parametro]
e(Q)
e(N)
```

---

## 5. Nested logit

A lista também estima uma versão nested logit. Os produtos são agrupados por segmento. Para cada produto \(j\) pertencente ao grupo \(g\), define-se:

$$
s_{j|g}=\frac{s_j}{s_g},
\qquad
s_g=\sum_{\ell\in g}s_{\ell}.
$$

A equação estimável é:

$$
\ln(s_j)-\ln(s_0)=X_j'\beta-\alpha p_j+\sigma\ln(s_{j|g})+\xi_j.
$$

O erro estrutural recuperado é:

$$
\xi_j(\theta)=
[\ln(s_j)-\ln(s_0)]-X_j'\beta+\alpha p_j-\sigma\ln(s_{j|g}).
$$

O parâmetro \(\sigma\) mede a correlação das preferências dentro do mesmo nest. Para ser compatível com o modelo nested logit, espera-se:

$$
0\leq \sigma < 1.
$$

Como \(\ln(s_{j|g})\) também pode ser endógeno, o pacote usa instrumentos adicionais associados à estrutura dos nests:

```text
n_same_nest_other
n_rival_nest
nest_own_cals
nest_own_fat
nest_own_sugar
nest_rival_cals
nest_rival_fat
nest_rival_sugar
```

A estimação nested é feita tanto por 2SLS de referência quanto por GMM operacional usando `eberry_operational.do` e `b_program_operational.do`.

---

## 6. Elasticidades e markups

Após a estimação da demanda, o pacote calcula elasticidades e markups implícitos.

Para o logit simples, a elasticidade-preço própria é:

$$
\varepsilon_{jj}=-\alpha p_j(1-s_j).
$$

Para \(k\neq j\), a elasticidade cruzada é:

$$
\varepsilon_{jk}=\alpha p_ks_k.
$$

Sob a hipótese simplificadora de firmas monoproduto, o markup é:

$$
p_j-mc_j=\frac{1}{\alpha(1-s_j)}.
$$

Para firmas multiproduto, define-se a matriz de propriedade:

$$
O_{jk}=1\{f(j)=f(k)\}.
$$

A matriz relevante para as condições de primeira ordem de Bertrand é:

$$
\Delta_{jk}=-O_{jk}\frac{\partial s_k}{\partial p_j}.
$$

No logit simples:

$$
\Delta_{jj}=\alpha s_j(1-s_j),
\qquad
\Delta_{jk}=-O_{jk}\alpha s_js_k
\quad (j\neq k).
$$

Os markups multiproduto são obtidos por:

$$
p-mc=\Delta^{-1}s.
$$

---

## 7. Estrutura de diretórios

A estrutura principal do pacote é:

```text
Segunda Forma/
├── data/
│   ├── exemplo.csv
│   ├── exemplo_schema.csv
│   ├── README_data.md
│   └── README_coloque_exemplo_csv_aqui.txt
│
├── stata/
│   ├── run_all_stata.do
│   ├── 00_config.do
│   ├── 01_prepare_data.do
│   ├── 02_estimate_logit_iv_gmm.do
│   ├── 03_nested_gmm.do
│   ├── 04_elasticities_markups.do
│   ├── 05_diagnostics_weakiv.do
│   ├── 06_visualizations.do
│   ├── 07_extra_visualizations.do
│   ├── 08_standard_tables.do
│   ├── eberry_operational.do
│   ├── b_program_operational.do
│   ├── stata_graph_theme_snippet.do
│   └── original_reference/
│       ├── original_eberry.do
│       └── original_b_program.do
│
├── R/
│   ├── run_all_R.R
│   ├── 00_config.R
│   ├── 01_prepare_data.R
│   ├── 02_estimate_logit_iv_gmm.R
│   ├── 03_nested_gmm.R
│   ├── 04_elasticities_markups.R
│   ├── 05_diagnostics_weakiv.R
│   ├── 06_visualizations.R
│   ├── 07_extra_visualizations.R
│   ├── 08_standard_tables.R
│   ├── functions_gmm.R
│   └── functions_io_tables.R
│
├── python/
│   ├── run_all_python.py
│   ├── requirements.txt
│   ├── config.py
│   ├── prepare_data.py
│   ├── estimate_logit_iv_gmm.py
│   ├── nested_gmm.py
│   ├── elasticities_markups.py
│   ├── diagnostics_weakiv.py
│   ├── standard_tables.py
│   ├── visualizations.py
│   ├── extra_visualizations.py
│   ├── gmm_core.py
│   └── io_tables.py
│
└── outputs/
    ├── stata/
    │   ├── data/
    │   ├── figures/pdf/
    │   ├── figures/png/
    │   ├── logs/
    │   └── tables/
    │       ├── csv/
    │       └── tex/
    ├── R/
    └── python/
```

---

## 8. Dados de entrada

O arquivo principal de dados deve estar em:

```text
data/exemplo.csv
```

A base deve seguir a ordem de colunas descrita em `data/exemplo_schema.csv`:

```text
idProduct,firm,product,price,shelf_price,ad_price,share_pct,segment,cals,fat,sugar
```

A firma externa `basketof` é removida da amostra interna. O bem externo entra somente por meio de \(s_0=0{,}2429\), usado na inversão de Berry.

O script `01_prepare_data.do` cria:

- `share`: participação do produto em proporção;
- `outside_share`: participação do bem externo;
- `delta`: variável dependente da inversão Berry;
- identificadores numéricos de firma e segmento;
- instrumentos de mesma firma;
- instrumentos de firmas rivais;
- variáveis de share condicional dentro do nest;
- instrumentos baseados em nests.

---

## 9. Guia de execução

### 9.1. Execução principal em Stata

A versão Stata é a referência principal desta reestimação, pois é nela que estão os arquivos operacionais baseados em `eberry` e `b_program`.

Execute a partir da raiz do pacote:

```stata
do stata/run_all_stata.do
```

O script `run_all_stata.do` executa, em ordem:

```text
00_config.do
stata_graph_theme_snippet.do
01_prepare_data.do
02_estimate_logit_iv_gmm.do
03_nested_gmm.do
04_elasticities_markups.do
05_diagnostics_weakiv.do
08_standard_tables.do
06_visualizations.do
07_extra_visualizations.do
```

A ordem é importante: as tabelas são geradas depois da estimação e do cálculo das elasticidades, enquanto os gráficos usam as bases intermediárias já salvas em `outputs/stata/data/`.

### 9.2. Execução em R

A versão R replica a lógica do pacote e serve como implementação paralela:

```r
source("R/run_all_R.R")
```

Pacotes usados pela versão R:

```r
readr
dplyr
tidyr
ggplot2
purrr
tibble
```

### 9.3. Execução em Python

A versão Python também replica o fluxo de tratamento, estimação, elasticidades, markups, tabelas e gráficos.

A partir da raiz do pacote:

```bash
cd python
python -m pip install -r requirements.txt
python run_all_python.py
```

Dependências listadas em `python/requirements.txt`:

```text
pandas>=2.0
numpy>=1.24
scipy>=1.10
matplotlib>=3.7
statsmodels>=0.14
```

---

## 10. Descrição dos scripts Stata

### `00_config.do`

Define parâmetros globais, nomes das variáveis, share do bem externo e pacotes opcionais.

Principais definições:

```stata
global S0 = 0.2429
global XVARS "cals fat sugar"
global PRICE "price"
global DELTA "delta"
global ENDOG_SIMPLE "price"
global ENDOG_NESTED "price log_share_within_nest"
```

Também define o padrão visual dos gráficos exportados.

### `01_prepare_data.do`

Importa `data/exemplo.csv`, padroniza nomes de variáveis, remove o bem externo da amostra interna e constrói a base preparada.

Saídas:

```text
outputs/stata/data/prepared_data_stata.dta
outputs/stata/data/prepared_data_stata.csv
```

### `02_estimate_logit_iv_gmm.do`

Estima o logit simples:

1. MQO;
2. 2SLS com instrumentos da própria firma;
3. 2SLS com instrumentos rivais;
4. 2SLS com ambos os conjuntos;
5. GMM operacional de primeira etapa;
6. GMM operacional de duas etapas.

O GMM é executado via `eberry_fit`, que chama `eberry_operational.do` e `b_program_operational.do`.

Saída intermediária:

```text
outputs/stata/data/stata_after_simple_gmm.dta
```

### `03_nested_gmm.do`

Estima o nested logit:

1. 2SLS de referência com duas variáveis endógenas;
2. GMM operacional de primeira etapa;
3. GMM operacional de duas etapas.

Variáveis endógenas:

```text
price
log_share_within_nest
```

Saída intermediária:

```text
outputs/stata/data/stata_after_nested_gmm.dta
```

### `04_elasticities_markups.do`

Calcula:

- elasticidades próprias do logit simples;
- markups monoproduto;
- markups multiproduto;
- custos marginais implícitos;
- razão markup/preço.

Saída intermediária:

```text
outputs/stata/data/stata_elasticities_markups_work.dta
```

### `05_diagnostics_weakiv.do`

Executa diagnósticos de primeiro estágio e instrumentos fracos:

- primeiro estágio do preço;
- F parcial;
- teste robusto/Wald;
- chamada ao `weakivtest`, quando disponível;
- diagnóstico separado para `price` e `log_share_within_nest` no nested logit.

### `08_standard_tables.do`

Gera tabelas padronizadas em CSV e TEX simples.

As principais tabelas são:

```text
01_all_coefficients.csv/.tex
02_price_parameter_comparison.csv/.tex
03_elasticity_matrix_simple_logit.csv/.tex
04_elasticity_matrix_simple_logit_subset.csv/.tex
05_own_elasticities_simple_logit.csv/.tex
06_elasticity_matrix_nested_logit.csv/.tex
07_own_elasticities_nested_logit.csv/.tex
08_markups.csv/.tex
09_first_stage_diagnostics.csv/.tex
```

Observação: na versão Stata, a rotina de exportação usa `export delimited` de forma robusta para evitar erros de `file write` no Windows. Por isso, os arquivos `.tex` gerados pelo Stata são saídas tabulares simples com extensão `.tex`. Para uso final em Overleaf, recomenda-se usar as versões LaTeX formatadas ou converter os CSVs para `longtable`/`booktabs`.

### `06_visualizations.do`

Gera gráficos principais em PDF e PNG:

```text
01_share_vs_transaction_price
02_top15_market_shares
03_price_by_segment
04_delta_vs_price
05_price_coefficient_comparison
06_elasticity_matrix_subset
07_own_price_elasticities
08_markups_mono_vs_multi
09_price_vs_multiproduct_markup
10_first_stage_robust_f
11_classic_logit_curve_share_vs_utility
12_focal_product_share_vs_price
13_focal_product_marginal_effect_vs_price
14_observed_vs_predicted_shares_simple_logit
15_structural_residual_hist_density
16_structural_residual_qqplot
17_price_response_curves_top5_products
18_own_elasticity_hist_density
19_markup_multiproduct_hist_density
20_own_elasticity_boxplot
21_markup_multiproduct_boxplot
```

### `07_extra_visualizations.do`

Gera gráficos complementares:

```text
extra_01_firm_share_concentration
extra_02_nest_sizes
extra_03_mean_cals_by_segment
extra_03_mean_fat_by_segment
extra_03_mean_sugar_by_segment
extra_04_instrument_correlation_matrix
extra_05_structural_residuals_vs_price
extra_06_structural_residuals_by_firm
extra_07_first_stage_price_fit
```

---

## 11. Saídas do pacote

### 11.1. Saídas Stata

As saídas principais ficam em:

```text
outputs/stata/
```

Subdiretórios:

```text
outputs/stata/data/          bases intermediárias
outputs/stata/logs/          logs de execução
outputs/stata/tables/csv/    tabelas em CSV
outputs/stata/tables/tex/    tabelas em TEX simples
outputs/stata/figures/pdf/   figuras em PDF
outputs/stata/figures/png/   figuras em PNG
```

O log principal é:

```text
outputs/stata/logs/run_all_stata.log
```

### 11.2. Saídas R e Python

As versões R e Python salvam saídas análogas em:

```text
outputs/R/
outputs/python/
```

Essas saídas servem como conferência e implementação paralela. A referência principal da reestimação, porém, é a pasta `outputs/stata/`, pois ela utiliza diretamente a versão operacional baseada em `eberry` e `b_program`.

---

## 12. Uso no Overleaf

Para usar os resultados no arquivo LaTeX da lista, recomenda-se organizar as saídas do Stata no projeto Overleaf da seguinte forma:

```text
Tables/
Figures/Stata/
```

Copie as tabelas finais para:

```text
Tables/nome_da_tabela.tex
```

Copie os gráficos em PDF para:

```text
Figures/Stata/nome_do_grafico.pdf
```

No corpo do texto, use:

```latex
\input{Tables/02_price_parameter_comparison.tex}
```

Para figuras:

```latex
\begin{figure}[H]
    \centering
    \includegraphics[width=0.85\textwidth]{Figures/Stata/05_price_coefficient_comparison.pdf}
    \caption{Comparação do coeficiente de preço entre especificações}
    \label{graf:q5-comparacao-coeficiente-preco}
\end{figure}
```

Use labels específicos por questão e por conteúdo, evitando rótulos genéricos repetidos.

---

## 13. Relação entre as questões da lista e os scripts

| Questão | Conteúdo | Script principal | Saídas principais |
|---|---|---|---|
| Q1 | Logit simples por MQO | `02_estimate_logit_iv_gmm.do` | `01_all_coefficients`, gráficos 04, 11 e 14 |
| Q2 | Instrumentos Berry/BLP e 2SLS | `01_prepare_data.do`, `02_estimate_logit_iv_gmm.do` | `01_all_coefficients`, `extra_04`, `extra_07` |
| Q3 | GMM estrutural | `02_estimate_logit_iv_gmm.do`, `eberry_operational.do`, `b_program_operational.do` | `01_all_coefficients`, gráficos 15 e 16 |
| Q4 | Nested logit por GMM | `03_nested_gmm.do` | `01_all_coefficients`, gráficos 03 e `extra_02` |
| Q5 | Comparação dos modelos | `08_standard_tables.do` | `02_price_parameter_comparison`, gráfico 05 |
| Q6 | Elasticidades e markups | `04_elasticities_markups.do`, `08_standard_tables.do` | tabelas 03 a 08, gráficos 06 a 09 e 17 a 21 |
| Q7 | Diagnóstico dos instrumentos | `05_diagnostics_weakiv.do`, `08_standard_tables.do` | `09_first_stage_diagnostics`, gráfico 10 e extras 05 a 07 |

---

## 14. Observações metodológicas importantes

1. O MQO é apenas uma referência inicial, pois o preço pode estar correlacionado com \(\xi_j\).
2. O 2SLS é usado como referência linear no logit simples, mas a interpretação estrutural principal está associada ao GMM.
3. A segunda forma do pacote reintroduz a lógica dos códigos originais `eberry` e `b_program`, evitando tratar o comando nativo `gmm` do Stata como núcleo da estimação estrutural.
4. No logit simples, as elasticidades cruzadas dependem apenas do produto cujo preço varia, o que é uma limitação conhecida do modelo logit padrão.
5. O nested logit relaxa parcialmente essa limitação ao permitir maior substituição dentro dos nests.
6. Os markups são sensíveis à estimativa de \(\alpha\) e à estrutura de propriedade assumida.
7. Os diagnósticos de primeiro estágio são fundamentais para avaliar se os instrumentos têm força empírica suficiente.
8. A validade dos instrumentos depende de uma hipótese econômica de exclusão; testes estatísticos e diagnósticos de força não provam exogeneidade.

---

## 15. Como reproduzir integralmente

Para reproduzir toda a versão principal:

```stata
cd "caminho/para/Segunda Forma"
do stata/run_all_stata.do
```

Ao final, verifique:

```text
outputs/stata/logs/run_all_stata.log
```

Se o log terminar com a mensagem de encerramento, as bases intermediárias, tabelas e gráficos terão sido gerados corretamente.

---

## 16. Resumo da reestimação

Esta reestimação da Lista 3 deve ser entendida como a versão de referência baseada nos códigos originais do exercício Berry/BLP. O núcleo Stata foi reorganizado para preservar a lógica dos arquivos `eberry` e `b_program`, mas mantendo uma estrutura modular de pacote de replicação. Assim, o fluxo final combina:

- tratamento reprodutível da base;
- construção explícita dos instrumentos Berry/BLP;
- estimação MQO e 2SLS de referência;
- GMM operacional inspirado nos códigos originais;
- nested logit por GMM;
- cálculo de elasticidades e markups;
- diagnóstico dos instrumentos;
- exportação de tabelas, gráficos e logs.

A versão Stata é a referência principal. As versões R e Python funcionam como implementações auxiliares para conferência, robustez computacional e replicação em ambientes alternativos.
