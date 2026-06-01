# Ordem sugerida no R

Depois de rodar o Stata, ou independentemente dele, rode a partir da raiz do pacote:

```r
source("R/run_all_aids_R.R")
```

A ordem interna é:

1. `01_prepare_aids_data.R`
2. `02_estimate_aids_R.R`
3. `03_elasticities_aids_R.R`
4. `04_visualizations_aids_R.R`

A estimação em R é implementada por GMM linear empilhado, sem usar rotina pronta de AIDS.
