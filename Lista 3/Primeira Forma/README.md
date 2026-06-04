# Pacote de replicação - Lista Berry/BLP: Demanda por Produtos Diferenciados

Este pacote resolve a lista de estimação de demanda por cereais matinais com o arcabouço de Berry/BLP: logit simples, 2SLS, GMM estrutural, nested logit, elasticidades, markups e diagnóstico dos instrumentos.

## Estrutura

```text
berry_replication_package/
├── data/
│   └── exemplo.csv
├── python/
│   ├── run_all_python.py
│   ├── 07_extra_visualizations.py
│   ├── prepare_data.py
│   ├── estimators.py
│   ├── economics.py
│   ├── tables.py
│   ├── visualizations.py
│   └── config.py
├── R/
│   ├── run_all_R.R
│   ├── 00_config.R
│   ├── 01_prepare_data.R
│   ├── 02_estimators_manual.R
│   ├── 03_estimate_logit_iv_gmm.R
│   ├── 04_nested_gmm.R
│   ├── 05_elasticities_markups.R
│   ├── 06_diagnostics.R
│   ├── 07_visualizations.R
│   └── 08_extra_visualizations.R
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
│   ├── original_b_program.do
│   └── original_eberry.do
└── outputs/
    ├── python/
    │   ├── logs/
    │   ├── figures/pdf/
    │   ├── figures/png/
    │   ├── tables/csv/
    │   ├── tables/tex/
    │   └── data/
    ├── r/
    │   ├── logs/
    │   ├── figures/pdf/
    │   ├── figures/png/
    │   ├── tables/csv/
    │   ├── tables/tex/
    │   └── data/
    └── stata/
        ├── logs/
        ├── figures/pdf/
        ├── figures/png/
        ├── tables/csv/
        ├── tables/tex/
        └── data/
```

## Como rodar

### Python

A versão Python foi executada e já deixou outputs em `outputs/python/`.

```bash
cd berry_replication_package
python python/run_all_python.py
python python/07_extra_visualizations.py   # caso queira regenerar apenas as extras
```

Dependências: `numpy`, `pandas`, `scipy`, `matplotlib` e `Pillow`. A estimação é programada por álgebra matricial; não usa bibliotecas prontas de IV/GMM.

### R

```r
setwd("caminho/para/berry_replication_package")
source("R/run_all_R.R")
```

A versão R usa apenas álgebra matricial/base R para MQO, 2SLS, GMM, diagnósticos e gráficos. Não usa `ivreg`, `gmm` ou pacotes prontos de estimação.

### Stata

```stata
cd "caminho/para/berry_replication_package"
do stata/run_all_stata.do
```

A versão Stata usa `ivregress`/`gmm` e tenta instalar, se ausentes, `estout`, `ivreg2` e `weakivtest`. O diagnóstico Montiel-Olea-Pflueger é chamado por `weakivtest` depois das estimações IV, como solicitado.

## Especificação aplicada

- Bem externo: `s0 = 0.2429`.
- Variável dependente: `delta_j = ln(s_j) - ln(s0)`.
- Preço: `average transaction price`.
- Características: `cals`, `fat`, `sugar`.
- Instrumentos BLP por firma:
  - `own_*`: soma das características dos demais produtos da mesma firma.
  - `rival_*`: soma das características dos produtos de firmas rivais.
  - Firma monoproduto: instrumento `own_*` tratado como zero.
- Nested logit:
  - nests definidos por `sgmnt`/`segment` da base.
  - variável endógena adicional: `log_share_within_nest = ln(s_j|g)`.
  - instrumentos adicionais: número e soma de características dentro do mesmo nest e em nests rivais.

## Gráficos padronizados nas três linguagens

Os três pacotes agora geram a mesma sequência de gráficos principais, gráficos clássicos do logit e visualizações extras, com os mesmos nomes de arquivo dentro de cada subdiretório de linguagem:

1. `01_share_vs_transaction_price`
2. `02_top15_market_shares`
3. `03_price_by_segment`
4. `04_delta_vs_price`
5. `05_price_coefficient_comparison`
6. `06_elasticity_matrix_subset`
7. `07_own_price_elasticities`
8. `08_markups_mono_vs_multi`
9. `09_price_vs_multiproduct_markup`
10. `10_first_stage_robust_f`
11. `11_classic_logit_curve_share_vs_utility`
12. `12_focal_product_share_vs_price`
13. `13_focal_product_marginal_effect_vs_price`
14. `14_observed_vs_predicted_shares_simple_logit`
15. `15_structural_residual_histogram`
16. `16_structural_residual_qqplot`
17. `17_price_response_curves_top5_products`
18. `extra_01_firm_share_concentration`
19. `extra_02_nest_sizes`
20. `extra_03_mean_cals_by_segment`
21. `extra_03_mean_fat_by_segment`
22. `extra_03_mean_sugar_by_segment`
23. `extra_04_instrument_correlation_matrix`
24. `extra_05_structural_residuals_vs_price`
25. `extra_06_structural_residuals_by_firm`
26. `extra_07_first_stage_price_fit`

Cada gráfico é salvo em PNG 300 dpi e em PDF. O gráfico 11 é a curva clássica do logit em escala de utilidade relativa, isto é, `V_j - ln(C_j)`, onde `C_j` agrega o outside good e os rivais; nessa escala, `s_j = 1/(1+exp(-(V_j-ln(C_j))))`.

## Observações econométricas importantes

1. A solução GMM nos modelos lineares é computada como o minimizador fechado do critério quadrático de momentos. Isso é uma otimização exata do problema linear.
2. Em Python/R, o diagnóstico de força dos instrumentos é calculado manualmente por primeiro estágio, F parcial homocedástico e Wald-F robusto. O MO-P exato é deixado para o Stata via `weakivtest`, conforme pedido.
3. A especificação principal em Python (`Q3_GMM_both_2step`) gerou coeficiente de preço positivo, isto é, `alpha` negativo. Isso é economicamente problemático e deve ser discutido como fragilidade da especificação/instrumentos. O nested GMM de duas etapas gerou `sigma` dentro do intervalo teórico.
4. As tabelas são salvas em CSV e TeX. Os gráficos são salvos em PNG 300 dpi e PDF.

## Outputs já incluídos

A execução Python já foi rodada no pacote e gerou:

- `outputs/python/logs/run_all_python.log`
- as 9 tabelas padronizadas em `outputs/python/tables/csv` e `outputs/python/tables/tex`
- gráficos principais e extras em `outputs/python/figures/pdf` e `outputs/python/figures/png`

As rotinas R e Stata foram atualizadas para gerar o mesmo conjunto de tabelas e gráficos quando executadas localmente.

## Tabelas padronizadas

Cada linguagem salva o mesmo conjunto de tabelas em `outputs/<linguagem>/tables/csv` e `outputs/<linguagem>/tables/tex`:

1. `01_all_coefficients`
2. `02_price_parameter_comparison`
3. `03_elasticity_matrix_simple_logit`
4. `04_elasticity_matrix_simple_logit_subset`
5. `05_own_elasticities_simple_logit`
6. `06_elasticity_matrix_nested_logit`
7. `07_own_elasticities_nested_logit`
8. `08_markups`
9. `09_first_stage_diagnostics`

As matrizes de elasticidades foram padronizadas em formato longo (`row_product`, `column_product`, `elasticity`) para ficarem comparáveis entre Stata, R e Python e para evitar tabelas excessivamente largas no LaTeX.
