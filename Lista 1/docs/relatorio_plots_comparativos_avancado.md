# Relatório dos plots comparativos avançados

## Arquivos usados — Questão 09

- Stata: C:\Users\B03531855158\Documents\Replication\lista1EI_replication_package_v4_downloads_plots\output\tables\stata_question_09_comparative.csv
- R: C:\Users\B03531855158\Documents\Replication\lista1EI_replication_package_v4_downloads_plots\output\tables\r_question_09_comparative.csv
- Python: C:\Users\B03531855158\Documents\Replication\lista1EI_replication_package_v4_downloads_plots\output\tables\python_question_09_comparative.csv

## Arquivos usados — Questão 11 / AR

- Stata: C:\Users\B03531855158\Documents\Replication\lista1EI_replication_package_v4_downloads_plots\output\tables\stata_question_11_ar_intervals.csv
- R: C:\Users\B03531855158\Documents\Replication\lista1EI_replication_package_v4_downloads_plots\output\tables\r_question_11_ar_intervals.csv
- Python: C:\Users\B03531855158\Documents\Replication\lista1EI_replication_package_v4_downloads_plots\output\tables\python_question_11_ar_intervals.csv

## Gráficos gerados

- `facet_AR_intervals_by_software.png`
- `facet_beta_p_ci_by_software.png`
- `facet_F_eff_MOP_by_software.png`
- `facet_first_stage_F_usual_by_software.png`
- `facet_first_stage_p_value_by_software.png`
- `facet_hansen_p_by_software.png`
- `facet_pval_beta_p_by_software.png`
- `facet_standard_errors_by_software.png`
- `heatmap_abs_diff_vs_Stata.png`
- `heatmap_relative_abs_diff_vs_Stata.png`
- `scatter_vs_Stata_beta_p.png`
- `scatter_vs_Stata_F_eff_MOP.png`
- `scatter_vs_Stata_F_usual.png`
- `scatter_vs_Stata_hansen_p.png`
- `scatter_vs_Stata_se_p.png`
- `summary_MAE_vs_Stata_by_metric.png`

## Resumo MAE/RMSE em relação ao Stata

| software   | metric    |   n |         mae |        rmse |     max_abs |   mean_relative_abs |
|:-----------|:----------|----:|------------:|------------:|------------:|--------------------:|
| Python     | F_eff_MOP |   7 | 4.47068e-07 | 6.84314e-07 | 1.34614e-06 |         3.0135e-08  |
| R          | F_eff_MOP |   7 | 4.47042e-07 | 6.84305e-07 | 1.34613e-06 |         3.01344e-08 |
| Python     | F_usual   |   7 | 1.26186e-10 | 1.58262e-10 | 2.62681e-10 |         3.41618e-11 |
| R          | F_usual   |   7 | 1.11067e-10 | 1.48628e-10 | 2.92364e-10 |         4.01381e-11 |
| Python     | beta_p    |   7 | 2.18279e-11 | 3.35046e-11 | 8.31479e-11 |         3.57163e-11 |
| R          | beta_p    |   7 | 1.13523e-10 | 1.85252e-10 | 3.69603e-10 |         8.47999e-11 |
| Python     | hansen_p  |   5 | 6.83705e-10 | 1.49021e-09 | 3.33174e-09 |         3.72238e-08 |
| R          | hansen_p  |   5 | 6.66871e-10 | 1.45264e-09 | 3.24773e-09 |         3.72043e-08 |
| Python     | p_F       |   7 | 2.15899e-09 | 3.7062e-09  | 7.90775e-09 |         2.08403e-08 |
| R          | p_F       |   7 | 2.16801e-09 | 3.72275e-09 | 7.93375e-09 |         2.09042e-08 |
| Python     | pval_p    |   7 | 0.00651559  | 0.00943671  | 0.0195683   |         0.366758    |
| R          | pval_p    |   7 | 0.00651559  | 0.00943671  | 0.0195683   |         0.366758    |
| Python     | se_p      |   7 | 0.0257519   | 0.0423293   | 0.101664    |         0.0413195   |
| R          | se_p      |   7 | 0.0257519   | 0.0423293   | 0.101664    |         0.0413195   |
